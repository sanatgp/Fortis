#include <cuda_runtime.h>
#include <stdio.h>
extern "C" void* mgpuStreamCreate(void);
extern "C" void* fortis_model_input(void);
extern "C" void* fortis_model_output(void);
static void *gd0, *gd1, *gd2, *gd3; static int ginit = 0;
static void gsetup(const float* H0, const float* H1, const float* H2, const float* H3) {
  cudaMalloc(&gd0, 79560L * sizeof(float)); cudaHostRegister((void*)H0, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
  cudaMalloc(&gd1, 79560L * sizeof(float)); cudaHostRegister((void*)H1, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
  cudaMalloc(&gd2, 79560L * sizeof(float)); cudaHostRegister((void*)H2, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
  cudaMalloc(&gd3, 79560L * sizeof(float)); cudaHostRegister((void*)H3, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
  ginit = 1;
}
__global__ void fortis_gather_k(const float* A0, const float* A1, const float* A2, const float* A3, float* X, int count, int ilo, int jlo, int ni) {
  int row = blockIdx.x * blockDim.x + threadIdx.x; if (row >= count * 15) return; int col = row % count, kk = row / count;
  int i = ilo + col % ni, j = jlo + col / ni; float* x = X + (size_t)row * 27; float tv;
  A0 += (size_t)kk * 5304L;
  A1 += (size_t)kk * 5304L;
  A2 += (size_t)kk * 5304L;
  A3 += (size_t)kk * 5304L;
  const float S0 = A3[(i+0 - 1) + (j+0 - 1) * 68];
  tv = A0[(i-1 - 1) + (j-1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[0] = tv;
  tv = A0[(i+0 - 1) + (j-1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[1] = tv;
  tv = A0[(i+1 - 1) + (j-1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[2] = tv;
  tv = A0[(i-1 - 1) + (j+0 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[3] = tv;
  tv = A0[(i+0 - 1) + (j+0 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[4] = tv;
  tv = A0[(i+1 - 1) + (j+0 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[5] = tv;
  tv = A0[(i-1 - 1) + (j+1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[6] = tv;
  tv = A0[(i+0 - 1) + (j+1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[7] = tv;
  tv = A0[(i+1 - 1) + (j+1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[8] = tv;
  tv = A1[(i-1 - 1) + (j-1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[9] = tv;
  tv = A1[(i+0 - 1) + (j-1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[10] = tv;
  tv = A1[(i+1 - 1) + (j-1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[11] = tv;
  tv = A1[(i-1 - 1) + (j+0 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[12] = tv;
  tv = A1[(i+0 - 1) + (j+0 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[13] = tv;
  tv = A1[(i+1 - 1) + (j+0 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[14] = tv;
  tv = A1[(i-1 - 1) + (j+1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[15] = tv;
  tv = A1[(i+0 - 1) + (j+1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[16] = tv;
  tv = A1[(i+1 - 1) + (j+1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[17] = tv;
  tv = A2[(i-1 - 1) + (j-1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[18] = tv;
  tv = A2[(i+0 - 1) + (j-1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[19] = tv;
  tv = A2[(i+1 - 1) + (j-1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[20] = tv;
  tv = A2[(i-1 - 1) + (j+0 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[21] = tv;
  tv = A2[(i+0 - 1) + (j+0 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[22] = tv;
  tv = A2[(i+1 - 1) + (j+0 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[23] = tv;
  tv = A2[(i-1 - 1) + (j+1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[24] = tv;
  tv = A2[(i+0 - 1) + (j+1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[25] = tv;
  tv = A2[(i+1 - 1) + (j+1 - 1) * 68]; tv = (tv / (S0 + 1.000000e-30f)); x[26] = tv;
}
extern "C" void fortis_gather(const float* H0, const float* H1, const float* H2, const float* H3) {
  cudaStream_t s = (cudaStream_t)mgpuStreamCreate(); if (!ginit) gsetup(H0, H1, H2, H3);
  cudaMemcpyAsync(gd0, H0 + (long)(1 - 1) * 5304L, 79560L * sizeof(float), cudaMemcpyHostToDevice, s);
  cudaMemcpyAsync(gd1, H1 + (long)(1 - 1) * 5304L, 79560L * sizeof(float), cudaMemcpyHostToDevice, s);
  cudaMemcpyAsync(gd2, H2 + (long)(1 - 1) * 5304L, 79560L * sizeof(float), cudaMemcpyHostToDevice, s);
  cudaMemcpyAsync(gd3, H3 + (long)(1 - 1) * 5304L, 79560L * sizeof(float), cudaMemcpyHostToDevice, s);
  fortis_gather_k<<<(71040 + 255) / 256, 256, 0, s>>>((const float*)gd0, (const float*)gd1, (const float*)gd2, (const float*)gd3, (float*)fortis_model_input(), 4736, 3, 3, 64);
}
static void *sd0, *sd1, *sd2, *sd3, *sd4; static int sinit = 0;
static void ssetup(const float* H0, const float* H1, const float* H2, const float* H3, const float* H4) {
  cudaMalloc(&sd0, 5304L * sizeof(float)); cudaHostRegister((void*)H0, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
  cudaMalloc(&sd1, 5304L * sizeof(float)); cudaHostRegister((void*)H1, 5304L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
  cudaMalloc(&sd2, 5304L * sizeof(float)); cudaHostRegister((void*)H2, 5304L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
  cudaMalloc(&sd3, 5304L * sizeof(float)); cudaHostRegister((void*)H3, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
  cudaMalloc(&sd4, 5304L * sizeof(float)); cudaHostRegister((void*)H4, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
  sinit = 1;
}
__global__ void fortis_scatter_k(const float* Yd, float* A0, float* A1, float* A2, float* A3, float* A4, int count, int ilo, int jlo, int ni) {
  int col = blockIdx.x * blockDim.x + threadIdx.x; if (col >= count) return;
  int i = ilo + col % ni, j = jlo + col / ni; const float* y = Yd + (size_t)col * 3; float tv; float yv[3];
  yv[0] = y[0];
  yv[1] = y[1];
  yv[2] = y[2];
  const float S0 = A0[(i+0 - 1) + (j+0 - 1) * 68];
  const float S1 = A1[(i+0 - 1) + (j+0 - 1) * 68];
  tv = yv[0]; tv = (((tv * S0) * S0) * S1); yv[0] = tv;
  tv = yv[1]; tv = (((tv * S0) * S0) * S1); yv[1] = tv;
  tv = yv[2]; tv = (((tv * S0) * S0) * S1); yv[2] = tv;
  A2[(i+0 - 1) + (j+0 - 1) * 68] = yv[0];
  A3[(i+0 - 1) + (j+0 - 1) * 68] = yv[1];
  A4[(i+0 - 1) + (j+0 - 1) * 68] = yv[2];
}
extern "C" void fortis_scatter(int a0, float* H0, float* H1, float* H2, float* H3, float* H4) {
  cudaStream_t s = (cudaStream_t)mgpuStreamCreate(); if (!sinit) ssetup(H0, H1, H2, H3, H4);
  cudaMemcpyAsync(sd0, H0 + ((long)(a0 - 1) * 5304L), 5304L * sizeof(float), cudaMemcpyHostToDevice, s);
  cudaMemcpyAsync(sd1, H1 + (0), 5304L * sizeof(float), cudaMemcpyHostToDevice, s);
  fortis_scatter_k<<<(4736 + 255) / 256, 256, 0, s>>>((const float*)fortis_model_output() + (size_t)(a0 - 1) * 14208L, (float*)sd0, (float*)sd1, (float*)sd2, (float*)sd3, (float*)sd4, 4736, 3, 3, 64);
  cudaMemcpy2DAsync(H2 + (0) + ((3 + 0 - 1) + (long)(3 + 0 - 1) * 68), 68L * sizeof(float), (float*)sd2 + ((3 + 0 - 1) + (long)(3 + 0 - 1) * 68), 68L * sizeof(float), 64L * sizeof(float), 74, cudaMemcpyDeviceToHost, s);
  cudaMemcpy2DAsync(H3 + ((long)(a0 - 1) * 5304L) + ((3 + 0 - 1) + (long)(3 + 0 - 1) * 68), 68L * sizeof(float), (float*)sd3 + ((3 + 0 - 1) + (long)(3 + 0 - 1) * 68), 68L * sizeof(float), 64L * sizeof(float), 74, cudaMemcpyDeviceToHost, s);
  cudaMemcpy2DAsync(H4 + ((long)(a0 - 1) * 5304L) + ((3 + 0 - 1) + (long)(3 + 0 - 1) * 68), 68L * sizeof(float), (float*)sd4 + ((3 + 0 - 1) + (long)(3 + 0 - 1) * 68), 68L * sizeof(float), 64L * sizeof(float), 74, cudaMemcpyDeviceToHost, s);
  cudaStreamSynchronize(s);
}
