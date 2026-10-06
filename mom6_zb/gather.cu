#include <cuda_runtime.h>
#include <stdio.h>
extern "C" void* mgpuStreamCreate(void);
extern "C" void* fortis_model_input(void);
static void *dA0, *dA1, *dA2, *dA3; static int ginit = 0;
static const void *pA0, *pA1, *pA2, *pA3;
__global__ void fortis_gather_k(const float* A0, const float* A1, const float* A2, const float* A3, float* X, int count, int ilo, int jlo, int ni) {
  int col = blockIdx.x * blockDim.x + threadIdx.x; if (col >= count) return;
  int i = ilo + col % ni, j = jlo + col / ni; float* x = X + (size_t)col * 27; float xv;
  const float S0 = A3[(i+0 - 1) + (j+0 - 1) * 68];
  xv = A0[(i-1 - 1) + (j-1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[0] = xv;
  xv = A0[(i+0 - 1) + (j-1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[1] = xv;
  xv = A0[(i+1 - 1) + (j-1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[2] = xv;
  xv = A0[(i-1 - 1) + (j+0 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[3] = xv;
  xv = A0[(i+0 - 1) + (j+0 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[4] = xv;
  xv = A0[(i+1 - 1) + (j+0 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[5] = xv;
  xv = A0[(i-1 - 1) + (j+1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[6] = xv;
  xv = A0[(i+0 - 1) + (j+1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[7] = xv;
  xv = A0[(i+1 - 1) + (j+1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[8] = xv;
  xv = A1[(i-1 - 1) + (j-1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[9] = xv;
  xv = A1[(i+0 - 1) + (j-1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[10] = xv;
  xv = A1[(i+1 - 1) + (j-1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[11] = xv;
  xv = A1[(i-1 - 1) + (j+0 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[12] = xv;
  xv = A1[(i+0 - 1) + (j+0 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[13] = xv;
  xv = A1[(i+1 - 1) + (j+0 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[14] = xv;
  xv = A1[(i-1 - 1) + (j+1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[15] = xv;
  xv = A1[(i+0 - 1) + (j+1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[16] = xv;
  xv = A1[(i+1 - 1) + (j+1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[17] = xv;
  xv = A2[(i-1 - 1) + (j-1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[18] = xv;
  xv = A2[(i+0 - 1) + (j-1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[19] = xv;
  xv = A2[(i+1 - 1) + (j-1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[20] = xv;
  xv = A2[(i-1 - 1) + (j+0 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[21] = xv;
  xv = A2[(i+0 - 1) + (j+0 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[22] = xv;
  xv = A2[(i+1 - 1) + (j+0 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[23] = xv;
  xv = A2[(i-1 - 1) + (j+1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[24] = xv;
  xv = A2[(i+0 - 1) + (j+1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[25] = xv;
  xv = A2[(i+1 - 1) + (j+1 - 1) * 68]; xv = (xv / (S0 + 1.000000e-30f)); x[26] = xv;
}
extern "C" void fortis_gather(int a0, const float* H0, const float* H1, const float* H2, const float* H3) {
  cudaStream_t s = (cudaStream_t)mgpuStreamCreate();
  if (!ginit) {
    cudaMalloc(&dA0, 5304L * sizeof(float)); pA0 = H0; cudaHostRegister((void*)H0, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
    cudaMalloc(&dA1, 5304L * sizeof(float)); pA1 = H1; cudaHostRegister((void*)H1, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
    cudaMalloc(&dA2, 5304L * sizeof(float)); pA2 = H2; cudaHostRegister((void*)H2, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
    cudaMalloc(&dA3, 5304L * sizeof(float)); pA3 = H3; cudaHostRegister((void*)H3, 79560L * sizeof(float), cudaHostRegisterDefault); cudaGetLastError();
    ginit = 1;
  }
  cudaMemcpyAsync(dA0, H0 + ((long)(a0 - 1) * 5304L), 5304L * sizeof(float), cudaMemcpyHostToDevice, s);
  cudaMemcpyAsync(dA1, H1 + ((long)(a0 - 1) * 5304L), 5304L * sizeof(float), cudaMemcpyHostToDevice, s);
  cudaMemcpyAsync(dA2, H2 + ((long)(a0 - 1) * 5304L), 5304L * sizeof(float), cudaMemcpyHostToDevice, s);
  cudaMemcpyAsync(dA3, H3 + ((long)(a0 - 1) * 5304L), 5304L * sizeof(float), cudaMemcpyHostToDevice, s);
  float* X = (float*)fortis_model_input();
  fortis_gather_k<<<(4736 + 255) / 256, 256, 0, s>>>((const float*)dA0, (const float*)dA1, (const float*)dA2, (const float*)dA3, X, 4736, 3, 3, 64);
}
