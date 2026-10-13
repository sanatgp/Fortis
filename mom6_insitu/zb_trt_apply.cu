#include <NvInfer.h>
#include <cuda_runtime.h>
#include <fstream>
#include <vector>
#include <cstdio>
#include <cstdlib>
class L : public nvinfer1::ILogger { void log(Severity s, const char* m) noexcept override { if (s <= Severity::kWARNING) fprintf(stderr, "[TRT] %s\n", m); } };
static L logger;
static nvinfer1::IExecutionContext* ctx = 0; static cudaStream_t s;
static double *dxd, *dyd; static float *dxf, *dyf;
static const double* xreg = 0; static double* yreg = 0;
__global__ void pre_k(const double* x, float* xf, int n) {
  int m = blockIdx.x * blockDim.x + threadIdx.x;
  if (m < n) for (int f = 0; f < 27; ++f) xf[m * 27 + f] = (float)x[m + (long)n * f];
}
__global__ void post_k(const float* yf, double* y, int n) {
  int m = blockIdx.x * blockDim.x + threadIdx.x;
  if (m < n) for (int o = 0; o < 3; ++o) y[m + (long)n * o] = (double)yf[m * 3 + o];
}
extern "C" void zb_trt_apply(const int* nij, const double* x, double* y) {
  int n = *nij;
  if (!ctx) {
    const char* p = getenv("ZB_TRT_PLAN"); if (!p) p = "zb_b35216.plan";
    std::ifstream f(p, std::ios::binary);
    if (!f) { fprintf(stderr, "zb_trt_apply: cannot open plan %s\n", p); abort(); }
    std::vector<char> blob((std::istreambuf_iterator<char>(f)), {});
    auto* rt = nvinfer1::createInferRuntime(logger);
    auto* eng = rt->deserializeCudaEngine(blob.data(), blob.size());
    ctx = eng->createExecutionContext();
    int B = eng->getTensorShape(eng->getIOTensorName(0)).d[0];
    if (B != n) { fprintf(stderr, "zb_trt_apply: plan batch %d but nij %d\n", B, n); abort(); }
    cudaMalloc(&dxd, (size_t)n * 27 * 8); cudaMalloc(&dyd, (size_t)n * 3 * 8);
    cudaMalloc(&dxf, (size_t)n * 27 * 4); cudaMalloc(&dyf, (size_t)n * 3 * 4);
    ctx->setTensorAddress(eng->getIOTensorName(0), dxf); ctx->setTensorAddress(eng->getIOTensorName(1), dyf);
    cudaStreamCreate(&s);
  }
  if (x != xreg) { if (xreg) cudaHostUnregister((void*)xreg); xreg = cudaHostRegister((void*)x, (size_t)n * 27 * 8, cudaHostRegisterDefault) == cudaSuccess ? x : 0; }
  if (y != yreg) { if (yreg) cudaHostUnregister((void*)yreg); yreg = cudaHostRegister((void*)y, (size_t)n * 3 * 8, cudaHostRegisterDefault) == cudaSuccess ? y : 0; }
  cudaMemcpyAsync(dxd, x, (size_t)n * 27 * 8, cudaMemcpyHostToDevice, s);
  pre_k<<<(n + 255) / 256, 256, 0, s>>>(dxd, dxf, n);
  ctx->enqueueV3(s);
  post_k<<<(n + 255) / 256, 256, 0, s>>>(dyf, dyd, n);
  cudaMemcpyAsync(y, dyd, (size_t)n * 3 * 8, cudaMemcpyDeviceToHost, s);
  cudaStreamSynchronize(s);
}
