// TensorRT as a second consumer of the host-fact contract.  The generated FORTIS entry keeps
// everything the contract gave it (batch, lifted pre and post kernels, stencil gather and
// scatter, pinning) and hands the model's device buffers to a TensorRT engine instead of the
// FORTIS-lowered kernels.  Plan path from FORTIS_TRT_PLAN; engine I/O is (B, n_in) -> (B, n_out)
// fp32 row-major, which is the layout of the entry's din/dout buffers.
#include <NvInfer.h>
#include <cuda_runtime.h>
#include <fstream>
#include <vector>
#include <cstdio>
#include <cstdlib>
class L : public nvinfer1::ILogger { void log(Severity s, const char* m) noexcept override { if (s <= Severity::kWARNING) fprintf(stderr, "[TRT] %s\n", m); } } logger;
static nvinfer1::ICudaEngine* eng = 0; static nvinfer1::IExecutionContext* ctx = 0;
static const void* bound_in = 0; static void* bound_out = 0;
extern "C" void fortis_trt_forward(const void* din, void* dout, cudaStream_t s) {
  if (!ctx) {
    const char* p = getenv("FORTIS_TRT_PLAN"); if (!p) { fprintf(stderr, "fortis_trt_backend: FORTIS_TRT_PLAN not set\n"); exit(1); }
    std::ifstream f(p, std::ios::binary); if (!f) { fprintf(stderr, "fortis_trt_backend: cannot open %s\n", p); exit(1); }
    std::vector<char> blob((std::istreambuf_iterator<char>(f)), {});
    auto* rt = nvinfer1::createInferRuntime(logger);
    eng = rt->deserializeCudaEngine(blob.data(), blob.size());
    ctx = eng->createExecutionContext();
    fprintf(stderr, "fortis_trt_backend: engine %s, %d I/O tensors\n", p, eng->getNbIOTensors());
  }
  if (din != bound_in || dout != bound_out) {
    ctx->setTensorAddress(eng->getIOTensorName(0), const_cast<void*>(din));
    ctx->setTensorAddress(eng->getIOTensorName(1), dout);
    bound_in = din; bound_out = dout;
  }
  ctx->enqueueV3(s);
  if (!s) cudaDeviceSynchronize();
}
