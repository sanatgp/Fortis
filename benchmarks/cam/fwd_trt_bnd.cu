// Expert rewrite of the E3SM boundary: hand-written normalize+transpose+cast and de-scale+transpose+cast
// kernels around a TensorRT batch-384 engine, host arrays pinned once. Called on the host's own fp64 arrays.
#include <NvInfer.h>
#include <cuda_runtime.h>
#include <fstream>
#include <vector>
#include <cstdio>
#define NC 384
#define NI 124
#define NO 128
class L : public nvinfer1::ILogger { void log(Severity s, const char* m) noexcept override { if (s <= Severity::kWARNING) fprintf(stderr, "[TRT] %s\n", m); } } logger;
static nvinfer1::IExecutionContext* ctx = 0; static float *dx, *dy; static double *din, *dout, *dmean, *dmax, *dmin, *dscale; static cudaStream_t s;
__global__ void pre_k(const double* in, const double* mean, const double* mx, const double* mn, float* x) {
  int idx = blockIdx.x * blockDim.x + threadIdx.x; if (idx >= NC * NI) return;
  int i = idx / NI, k = idx % NI;                       // x is (NC, NI) row-major, in is Fortran input(NC, NI)
  x[idx] = (float)((in[i + (long)k * NC] - mean[k]) / (mx[k] - mn[k]));
}
__global__ void post_k(const float* y, const double* scale, double* out) {
  int idx = blockIdx.x * blockDim.x + threadIdx.x; if (idx >= NC * NO) return;
  int i = idx / NO, k = idx % NO;
  out[i + (long)k * NC] = (double)y[idx] / scale[k];
}
extern "C" void mlp_forward_bnd(double* in, double* mean, double* mx, double* mn, double* scale, double* out) {
  if (!ctx) {
    std::ifstream f("/scratch/taghipouranvari.s/FTORCH/climsim_run/climsim_b384.plan", std::ios::binary);
    std::vector<char> blob((std::istreambuf_iterator<char>(f)), {});
    auto* rt = nvinfer1::createInferRuntime(logger);
    auto* eng = rt->deserializeCudaEngine(blob.data(), blob.size());
    ctx = eng->createExecutionContext();
    cudaMalloc(&dx, NC * NI * 4); cudaMalloc(&dy, NC * NO * 4);
    cudaMalloc(&din, NC * NI * 8); cudaMalloc(&dout, NC * NO * 8);
    cudaMalloc(&dmean, NI * 8); cudaMalloc(&dmax, NI * 8); cudaMalloc(&dmin, NI * 8); cudaMalloc(&dscale, NO * 8);
    cudaMemcpy(dmean, mean, NI * 8, cudaMemcpyHostToDevice); cudaMemcpy(dmax, mx, NI * 8, cudaMemcpyHostToDevice);
    cudaMemcpy(dmin, mn, NI * 8, cudaMemcpyHostToDevice); cudaMemcpy(dscale, scale, NO * 8, cudaMemcpyHostToDevice);
    ctx->setTensorAddress(eng->getIOTensorName(0), dx); ctx->setTensorAddress(eng->getIOTensorName(1), dy);
    cudaStreamCreate(&s);
    cudaHostRegister(in, NC * NI * 8, cudaHostRegisterDefault);
    cudaHostRegister(out, NC * NO * 8, cudaHostRegisterDefault);
  }
  cudaMemcpyAsync(din, in, NC * NI * 8, cudaMemcpyHostToDevice, s);
  pre_k<<<(NC * NI + 255) / 256, 256, 0, s>>>(din, dmean, dmax, dmin, dx);
  ctx->enqueueV3(s);
  post_k<<<(NC * NO + 255) / 256, 256, 0, s>>>(dy, dscale, dout);
  cudaMemcpyAsync(out, dout, NC * NO * 8, cudaMemcpyDeviceToHost, s);
  cudaStreamSynchronize(s);
}
