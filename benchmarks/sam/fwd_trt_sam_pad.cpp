// TensorRT coupling for sam_host, per column, through a batch-2 engine with the row duplicated:
// TensorRT 10.3 mis-compiles this network at batch 1 on Volta (checked against the ONNX reference).
#include <NvInfer.h>
#include <cuda_runtime.h>
#include <fstream>
#include <vector>
#include <cstdio>
#include <cstring>
class L : public nvinfer1::ILogger { void log(Severity s, const char* m) noexcept override { if (s <= Severity::kWARNING) fprintf(stderr, "[TRT] %s\n", m); } } logger;
static nvinfer1::IExecutionContext* ctx = 0; static float *dx, *dy, *hx, *hy; static cudaStream_t s;
static const long NIN = 61, NOUT = 148;
extern "C" void mlp_forward(float* x, float* y) {
  if (!ctx) {
    std::ifstream f("sam_b2.plan", std::ios::binary);
    std::vector<char> blob((std::istreambuf_iterator<char>(f)), {});
    auto* rt = nvinfer1::createInferRuntime(logger);
    auto* eng = rt->deserializeCudaEngine(blob.data(), blob.size());
    ctx = eng->createExecutionContext();
    cudaMalloc(&dx, 2 * NIN * 4); cudaMalloc(&dy, 2 * NOUT * 4);
    cudaHostAlloc((void**)&hx, 2 * NIN * 4, cudaHostAllocDefault); cudaHostAlloc((void**)&hy, 2 * NOUT * 4, cudaHostAllocDefault);
    ctx->setTensorAddress(eng->getIOTensorName(0), dx); ctx->setTensorAddress(eng->getIOTensorName(1), dy);
    cudaStreamCreate(&s);
  }
  memcpy(hx, x, NIN * 4); memcpy(hx + NIN, x, NIN * 4);
  cudaMemcpyAsync(dx, hx, 2 * NIN * 4, cudaMemcpyHostToDevice, s);
  ctx->enqueueV3(s);
  cudaMemcpyAsync(hy, dy, 2 * NOUT * 4, cudaMemcpyDeviceToHost, s);
  cudaStreamSynchronize(s);
  memcpy(y, hy, NOUT * 4);
}
