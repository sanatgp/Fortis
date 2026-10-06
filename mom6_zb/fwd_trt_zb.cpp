// TensorRT coupling for zb_host: per-call semantics (H2D, enqueue, D2H, sync), batch fixed at compile time.
#include <NvInfer.h>
#include <cuda_runtime.h>
#include <fstream>
#include <vector>
#include <cstdio>
#ifndef TRT_BATCH
#define TRT_BATCH 1
#endif
#ifndef TRT_PLAN
#define TRT_PLAN "zb_b1.plan"
#endif
class L : public nvinfer1::ILogger { void log(Severity s, const char* m) noexcept override { if (s <= Severity::kWARNING) fprintf(stderr, "[TRT] %s\n", m); } } logger;
static nvinfer1::IExecutionContext* ctx = 0; static float *dx, *dy; static cudaStream_t s;
static const long NIN = 27L * TRT_BATCH, NOUT = 3L * TRT_BATCH;
extern "C" void mlp_forward(float* x, float* y) {
  if (!ctx) {
    std::ifstream f(TRT_PLAN, std::ios::binary);
    std::vector<char> blob((std::istreambuf_iterator<char>(f)), {});
    auto* rt = nvinfer1::createInferRuntime(logger);
    auto* eng = rt->deserializeCudaEngine(blob.data(), blob.size());
    ctx = eng->createExecutionContext();
    cudaMalloc(&dx, NIN * 4); cudaMalloc(&dy, NOUT * 4);
    ctx->setTensorAddress(eng->getIOTensorName(0), dx); ctx->setTensorAddress(eng->getIOTensorName(1), dy);
    cudaStreamCreate(&s);
    cudaHostRegister(x, NIN * 4, cudaHostRegisterDefault);
    cudaHostRegister(y, NOUT * 4, cudaHostRegisterDefault);
  }
  cudaMemcpyAsync(dx, x, NIN * 4, cudaMemcpyHostToDevice, s);
  ctx->enqueueV3(s);
  cudaMemcpyAsync(y, dy, NOUT * 4, cudaMemcpyDeviceToHost, s);
  cudaStreamSynchronize(s);
}
