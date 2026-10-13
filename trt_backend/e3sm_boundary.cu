#include <cuda_runtime.h>
#include <cstdio>
extern "C" void fortis_trt_forward(const void*, void*, cudaStream_t);
extern "C" double _QFEin_mean[124]; static double* g__QFEin_mean = 0;
extern "C" double _QFEin_max[124]; static double* g__QFEin_max = 0;
extern "C" double _QFEin_min[124]; static double* g__QFEin_min = 0;
extern "C" double _QFEout_scale[128]; static double* g__QFEout_scale = 0;
static float *x32 = 0, *y32 = 0;
__global__ void fortis_pre_k(const double* A, float* x, const double* g__QFEin_mean, const double* g__QFEin_max, const double* g__QFEin_min) {
  int t = blockIdx.x * blockDim.x + threadIdx.x; if (t >= 47616) return; int i = t / 124, k = t % 124;
  double a = A[i + 384L * k];
  a = ((a - g__QFEin_mean[k]) / (g__QFEin_max[k] - g__QFEin_min[k]));
  x[i * 124 + k] = (float)a;
}
__global__ void fortis_post_k(const float* y, double* B, const double* g__QFEout_scale) {
  int t = blockIdx.x * blockDim.x + threadIdx.x; if (t >= 49152) return; int i = t / 128, k = t % 128;
  double b = (double)y[i * 128 + k];
  b = (b / g__QFEout_scale[k]);
  B[i + 384L * k] = b;
}
extern "C" void fortis_trt_boundary(const void* din, void* dout, cudaStream_t s) {
  if (!x32) {
    cudaMalloc(&x32, 47616L * 4); cudaMalloc(&y32, 49152L * 4);
    cudaMalloc(&g__QFEin_mean, 124L * sizeof(double)); cudaMemcpy(g__QFEin_mean, _QFEin_mean, 124L * sizeof(double), cudaMemcpyHostToDevice);
    cudaMalloc(&g__QFEin_max, 124L * sizeof(double)); cudaMemcpy(g__QFEin_max, _QFEin_max, 124L * sizeof(double), cudaMemcpyHostToDevice);
    cudaMalloc(&g__QFEin_min, 124L * sizeof(double)); cudaMemcpy(g__QFEin_min, _QFEin_min, 124L * sizeof(double), cudaMemcpyHostToDevice);
    cudaMalloc(&g__QFEout_scale, 128L * sizeof(double)); cudaMemcpy(g__QFEout_scale, _QFEout_scale, 128L * sizeof(double), cudaMemcpyHostToDevice);
  }
  fortis_pre_k<<<(47616 + 255) / 256, 256, 0, s>>>((const double*)din, x32, g__QFEin_mean, g__QFEin_max, g__QFEin_min);
  fortis_trt_forward(x32, y32, s);
  fortis_post_k<<<(49152 + 255) / 256, 256, 0, s>>>(y32, (double*)dout, g__QFEout_scale);
  cudaStreamSynchronize(s);
}
