// FORTIS large-kernel 3D convolution: whole-volume FFT with weight spectra precomputed once.
// Cross-correlation (linalg/cuDNN semantics): y[f][n] = sum_c sum_k x[c][n+k] w[f][c][k], n in output box.
// Circular correlation on the input volume equals the linear one on the valid region since n+k < N.
#include <cufft.h>
#include <cuda_runtime.h>
#include <stdio.h>
#include <string.h>
#define X3 16
#define Y3 8
#define Z3 4
extern "C" void* fortis_alloc(long n);
extern "C" void fortis_free(void* p);
extern "C" void* mgpuStreamCreate(void);

struct FftConv {
  long key[9]; int C, F, D, H, W, Nc; cufftHandle fwd, inv; cufftComplex *Wspec, *Xspec, *Yspec; float* yfull; bool ready;
};
static FftConv slots[16]; static int nslots = 0;

__global__ void k_pad_weights(const float* w, float* wp, int F, int C, int KD, int KH, int KW, int D, int H, int W) {
  long i = blockIdx.x * (long)blockDim.x + threadIdx.x; long tot = (long)F * C * KD * KH * KW; if (i >= tot) return;
  int kw = i % KW, kh = (i / KW) % KH, kd = (i / KW / KH) % KD; long fc = i / KW / KH / KD;
  wp[fc * (long)D * H * W + ((long)kd * H + kh) * W + kw] = w[i];
}
__global__ void k_pointwise(const cufftComplex* X, const cufftComplex* Wsp, cufftComplex* Y, int C, int F, int Nc, float scale) {
  long i = blockIdx.x * (long)blockDim.x + threadIdx.x; if (i >= (long)F * Nc) return;
  int f = i / Nc, n = i % Nc; float re = 0.f, im = 0.f;
  for (int c = 0; c < C; c++) {
    cufftComplex x = X[(long)c * Nc + n], w = Wsp[((long)f * C + c) * Nc + n];
    re += x.x * w.x + x.y * w.y;      // x * conj(w)
    im += x.y * w.x - x.x * w.y;
  }
  Y[i].x = re * scale; Y[i].y = im * scale;
}
__global__ void k_crop(const float* yf, float* y, int F, int D, int H, int W, int Do, int Ho, int Wo) {
  long i = blockIdx.x * (long)blockDim.x + threadIdx.x; long tot = (long)F * Do * Ho * Wo; if (i >= tot) return;
  int wo = i % Wo, ho = (i / Wo) % Ho, dd = (i / Wo / Ho) % Do, f = i / Wo / Ho / Do;
  y[i] = yf[(((long)f * D + dd) * H + ho) * W + wo];
}

static FftConv* get_slot(long N, long C, long D, long H, long W, long F, long KD, long KH, long KW, const float* w) {
  long key[9] = {N, C, D, H, W, F, KD, KH, KW};
  for (int s = 0; s < nslots; s++) if (!memcmp(slots[s].key, key, sizeof key)) return &slots[s];
  FftConv* fc = &slots[nslots++]; memcpy(fc->key, key, sizeof key);
  fc->C = C; fc->F = F; fc->D = D; fc->H = H; fc->W = W; fc->Nc = D * H * (W / 2 + 1);
  cudaStream_t st = (cudaStream_t)mgpuStreamCreate();
  int n[3] = {(int)D, (int)H, (int)W};
  int inembed[3] = {(int)D, (int)H, (int)W}, onembed[3] = {(int)D, (int)H, (int)(W / 2 + 1)};
  cufftPlanMany(&fc->fwd, 3, n, inembed, 1, D * H * W, onembed, 1, fc->Nc, CUFFT_R2C, C); cufftSetStream(fc->fwd, st);
  cufftPlanMany(&fc->inv, 3, n, onembed, 1, fc->Nc, inembed, 1, D * H * W, CUFFT_C2R, F); cufftSetStream(fc->inv, st);
  fc->Wspec = (cufftComplex*)fortis_alloc((long)F * C * fc->Nc * sizeof(cufftComplex));
  fc->Xspec = (cufftComplex*)fortis_alloc((long)C * fc->Nc * sizeof(cufftComplex));
  fc->Yspec = (cufftComplex*)fortis_alloc((long)F * fc->Nc * sizeof(cufftComplex));
  fc->yfull = (float*)fortis_alloc((long)F * D * H * W * sizeof(float));
  // weight spectra, once: zero-pad each (f,c) kernel into a full volume and transform
  float* wp = (float*)fortis_alloc((long)F * C * D * H * W * sizeof(float));
  cudaMemsetAsync(wp, 0, (long)F * C * D * H * W * sizeof(float), st);
  long tot = (long)F * C * KD * KH * KW;
  k_pad_weights<<<(tot + 255) / 256, 256, 0, st>>>(w, wp, F, C, KD, KH, KW, D, H, W);
  cufftHandle wplan; cufftPlanMany(&wplan, 3, n, inembed, 1, D * H * W, onembed, 1, fc->Nc, CUFFT_R2C, F * C); cufftSetStream(wplan, st);
  cufftExecR2C(wplan, wp, fc->Wspec);
  cudaStreamSynchronize(st); cufftDestroy(wplan); fortis_free(wp);
  fc->ready = true; return fc;
}

extern "C" void fortis_conv3d_fft(float* xa, float* x, long xo, long x0, long x1, long x2, long x3, long x4, long xt0, long xt1, long xt2, long xt3, long xt4,
                   float* wa, float* w, long wo, long w0, long w1, long w2, long w3, long w4, long wt0, long wt1, long wt2, long wt3, long wt4,
                   float* ya, float* y, long yo, long y0, long y1, long y2, long y3, long y4, long yt0, long yt1, long yt2, long yt3, long yt4,
                   long N, long C, long Din, long Hin, long Win, long F, long KD, long KH, long KW, long Dout, long Hout, long Wout, long sd, long sh, long sw, long pd, long ph, long pw) {
  if (N != 1 || sd != 1 || sh != 1 || sw != 1 || pd || ph || pw) { fprintf(stderr, "fortis_conv3d_fft: unsupported shape\n"); return; }
  FftConv* fc = get_slot(N, C, Din, Hin, Win, F, KD, KH, KW, w + wo);
  cudaStream_t st = (cudaStream_t)mgpuStreamCreate();
  cufftExecR2C(fc->fwd, x + xo, fc->Xspec);
  long tot = (long)F * fc->Nc;
  k_pointwise<<<(tot + 255) / 256, 256, 0, st>>>(fc->Xspec, fc->Wspec, fc->Yspec, C, F, fc->Nc, 1.f / (float)((long)Din * Hin * Win));
  cufftExecC2R(fc->inv, fc->Yspec, fc->yfull);
  long ot = (long)F * Dout * Hout * Wout;
  k_crop<<<(ot + 255) / 256, 256, 0, st>>>(fc->yfull, y + yo, F, Din, Hin, Win, Dout, Hout, Wout);
}

// ---------------------------------------------------------------------------
// Direct tiled 3D convolution (cross-correlation), NCDHW, N = 1, stride 1, K <= 5.
// Block: 8x8x4 output tile, 8 output channels per thread; per input channel the haloed
// input tile and the 8 x K^3 weights are staged in shared memory.
#define TX 8
#define TY 8
#define TZ 4
#define FB 8
#define KMAX 5
#define HALO (KMAX - 1)
__global__ void k_conv3d_direct(const float* __restrict__ x, const float* __restrict__ w, float* __restrict__ y,
                                int C, int D, int H, int W, int F, int KD, int KH, int KW, int Do, int Ho, int Wo, int pd, int ph, int pw) {
  __shared__ float sx[(TZ + HALO) * (TY + HALO) * (TX + HALO)];
  __shared__ float sw[FB * KMAX * KMAX * KMAX];
  const int tx = threadIdx.x, ty = threadIdx.y, tz = threadIdx.z;
  const int ox = blockIdx.x * TX + tx, oy = blockIdx.y * TY + ty;
  const int zb = blockIdx.z % ((Do + TZ - 1) / TZ), fb = blockIdx.z / ((Do + TZ - 1) / TZ);
  const int oz = zb * TZ + tz, f0 = fb * FB;
  const int SX = TX + KW - 1, SY = TY + KH - 1, SZ = TZ + KD - 1;
  const int tid = (tz * TY + ty) * TX + tx, nthr = TX * TY * TZ;
  float acc[FB];
  for (int i = 0; i < FB; i++) acc[i] = 0.f;
  const int ix0 = blockIdx.x * TX - pw, iy0 = blockIdx.y * TY - ph, iz0 = zb * TZ - pd;
  for (int c = 0; c < C; c++) {
    for (int i = tid; i < SZ * SY * SX; i += nthr) {
      int sxi = i % SX, syi = (i / SX) % SY, szi = i / SX / SY;
      int ix = ix0 + sxi, iy = iy0 + syi, iz = iz0 + szi;
      sx[i] = (ix >= 0 && ix < W && iy >= 0 && iy < H && iz >= 0 && iz < D) ? x[(((long)c * D + iz) * H + iy) * W + ix] : 0.f;
    }
    for (int i = tid; i < FB * KD * KH * KW; i += nthr) {
      int f = i / (KD * KH * KW), k = i % (KD * KH * KW);
      sw[i] = (f0 + f < F) ? w[(((long)(f0 + f) * C + c) * KD * KH * KW) + k] : 0.f;
    }
    __syncthreads();
    for (int kd = 0; kd < KD; kd++)
      for (int kh = 0; kh < KH; kh++)
        for (int kw = 0; kw < KW; kw++) {
          float xv = sx[((tz + kd) * SY + (ty + kh)) * SX + (tx + kw)];
          int k = (kd * KH + kh) * KW + kw;
#pragma unroll
          for (int f = 0; f < FB; f++) acc[f] += xv * sw[f * KD * KH * KW + k];
        }
    __syncthreads();
  }
  if (ox < Wo && oy < Ho && oz < Do)
    for (int f = 0; f < FB; f++)
      if (f0 + f < F) y[(((long)(f0 + f) * Do + oz) * Ho + oy) * Wo + ox] = acc[f];
}

__global__ void k_conv3d_direct3(const float*, const float*, float*, int, int, int, int, int, int, int, int, int, int, int);
extern "C" void fortis_conv3d_direct(float* xa, float* x, long xo, long x0, long x1, long x2, long x3, long x4, long xt0, long xt1, long xt2, long xt3, long xt4,
                   float* wa, float* w, long wo, long w0, long w1, long w2, long w3, long w4, long wt0, long wt1, long wt2, long wt3, long wt4,
                   float* ya, float* y, long yo, long y0, long y1, long y2, long y3, long y4, long yt0, long yt1, long yt2, long yt3, long yt4,
                   long N, long C, long Din, long Hin, long Win, long F, long KD, long KH, long KW, long Dout, long Hout, long Wout, long sd, long sh, long sw_, long pd, long ph, long pw) {
  if (N != 1 || sd != 1 || sh != 1 || sw_ != 1 || KD > KMAX || KH > KMAX || KW > KMAX) { fprintf(stderr, "fortis_conv3d_direct: unsupported shape\n"); return; }
  cudaStream_t st = (cudaStream_t)mgpuStreamCreate();
  if (KD == 3 && KH == 3 && KW == 3) {
    dim3 block(X3, Y3, 1);
    dim3 grid((Wout + X3 - 1) / X3, (Hout + Y3 - 1) / Y3, ((Dout + Z3 - 1) / Z3) * ((F + FB - 1) / FB));
    k_conv3d_direct3<<<grid, block, 0, st>>>(x + xo, w + wo, y + yo, C, Din, Hin, Win, F, Dout, Hout, Wout, pd, ph, pw);
    return;
  }
  dim3 block(TX, TY, TZ);
  dim3 grid((Wout + TX - 1) / TX, (Hout + TY - 1) / TY, ((Dout + TZ - 1) / TZ) * ((F + FB - 1) / FB));
  k_conv3d_direct<<<grid, block, 0, st>>>(x + xo, w + wo, y + yo, C, Din, Hin, Win, F, KD, KH, KW, Dout, Hout, Wout, pd, ph, pw);
}

// K = 3 specialization: block tile 16x8x4 outputs x 8 channels; thread = one (x,y), 4 z-outputs x 8 channels.
__global__ void __launch_bounds__(128) k_conv3d_direct3(const float* __restrict__ x, const float* __restrict__ w, float* __restrict__ y,
                                 int C, int D, int H, int W, int F, int Do, int Ho, int Wo, int pd, int ph, int pw) {
  __shared__ float sx[(Z3 + 2) * (Y3 + 2) * (X3 + 2)];
  __shared__ float sw[FB * 27];
  const int tx = threadIdx.x, ty = threadIdx.y, tid = ty * X3 + tx;
  const int nz = (Do + Z3 - 1) / Z3;
  const int zb = blockIdx.z % nz, fb = blockIdx.z / nz, f0 = fb * FB;
  const int ox = blockIdx.x * X3 + tx, oy = blockIdx.y * Y3 + ty, oz0 = zb * Z3;
  const int ix0 = blockIdx.x * X3 - pw, iy0 = blockIdx.y * Y3 - ph, iz0 = oz0 - pd;
  const int SX = X3 + 2, SY = Y3 + 2, SZ = Z3 + 2;
  float acc[Z3][FB];
#pragma unroll
  for (int z = 0; z < Z3; z++)
#pragma unroll
    for (int f = 0; f < FB; f++) acc[z][f] = 0.f;
  for (int c = 0; c < C; c++) {
    for (int i = tid; i < SZ * SY * SX; i += X3 * Y3) {
      int sxi = i % SX, syi = (i / SX) % SY, szi = i / SX / SY;
      int ix = ix0 + sxi, iy = iy0 + syi, iz = iz0 + szi;
      sx[i] = (ix >= 0 && ix < W && iy >= 0 && iy < H && iz >= 0 && iz < D) ? x[(((long)c * D + iz) * H + iy) * W + ix] : 0.f;
    }
    for (int i = tid; i < FB * 27; i += X3 * Y3) {
      int f = i / 27, k = i % 27;
      sw[i] = (f0 + f < F) ? w[((long)(f0 + f) * C + c) * 27 + k] : 0.f;
    }
    __syncthreads();
#pragma unroll
    for (int kh = 0; kh < 3; kh++)
#pragma unroll
      for (int kw = 0; kw < 3; kw++) {
        float xin[Z3 + 2];
#pragma unroll
        for (int z = 0; z < Z3 + 2; z++) xin[z] = sx[(z * SY + (ty + kh)) * SX + (tx + kw)];
#pragma unroll
        for (int kd = 0; kd < 3; kd++) {
#pragma unroll
          for (int f = 0; f < FB; f++) {
            float wv = sw[f * 27 + (kd * 3 + kh) * 3 + kw];
#pragma unroll
            for (int z = 0; z < Z3; z++) acc[z][f] += xin[z + kd] * wv;
          }
        }
      }
    __syncthreads();
  }
  if (ox < Wo && oy < Ho)
#pragma unroll
    for (int z = 0; z < Z3; z++)
      if (oz0 + z < Do)
#pragma unroll
        for (int f = 0; f < FB; f++)
          if (f0 + f < F) y[(((long)(f0 + f) * Do + oz0 + z) * Ho + oy) * Wo + ox] = acc[z][f];
}
