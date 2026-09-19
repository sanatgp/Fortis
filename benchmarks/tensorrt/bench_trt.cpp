// TensorRT per-call harness: engine plan, input file, nin, nout, iters. Same semantics as the
// FTorch/TF harnesses: H2D copy, execute, D2H copy, per call, timed after warmup.
#include <NvInfer.h>
#include <cuda_runtime.h>
#include <fstream>
#include <vector>
#include <chrono>
#include <cstdio>
#include <cstdlib>
class L : public nvinfer1::ILogger { void log(Severity s, const char* m) noexcept override { if (s <= Severity::kWARNING) fprintf(stderr, "[TRT] %s\n", m); } } logger;
int main(int argc, char** argv) {
  const char* plan = argv[1]; const char* infile = argv[2]; long nin = atol(argv[3]), nout = atol(argv[4]); int iters = atoi(argv[5]);
  std::ifstream f(plan, std::ios::binary); std::vector<char> blob((std::istreambuf_iterator<char>(f)), {});
  auto* rt = nvinfer1::createInferRuntime(logger);
  auto* eng = rt->deserializeCudaEngine(blob.data(), blob.size());
  auto* ctx = eng->createExecutionContext();
  std::vector<float> x(nin), y(nout);
  FILE* fi = fopen(infile, "rb"); fread(x.data(), 4, nin, fi); fclose(fi);
  float *dx, *dy; cudaMalloc(&dx, nin * 4); cudaMalloc(&dy, nout * 4);
  ctx->setTensorAddress(eng->getIOTensorName(0), dx); ctx->setTensorAddress(eng->getIOTensorName(1), dy);
  cudaStream_t s; cudaStreamCreate(&s);
  auto call = [&]() {
    cudaMemcpyAsync(dx, x.data(), nin * 4, cudaMemcpyHostToDevice, s);
    ctx->enqueueV3(s);
    cudaMemcpyAsync(y.data(), dy, nout * 4, cudaMemcpyDeviceToHost, s);
    cudaStreamSynchronize(s);
  };
  for (int i = 0; i < 5; i++) call();
  auto t0 = std::chrono::steady_clock::now();
  for (int i = 0; i < iters; i++) call();
  auto t1 = std::chrono::steady_clock::now();
  double us = std::chrono::duration<double, std::micro>(t1 - t0).count() / iters;
  double cs = 0; for (long i = 0; i < nout; i++) cs += y[i];
  if (us > 1000) printf("per-call ms: %.4f\n", us / 1000); else printf("per-call us: %.4f\n", us);
  printf("checksum: %f y[:3] %f %f %f\n", cs, y[0], y[1], y[2]);
  FILE* fo = fopen("trt_out.bin", "wb"); fwrite(y.data(), 4, nout, fo); fclose(fo);
  return 0;
}
