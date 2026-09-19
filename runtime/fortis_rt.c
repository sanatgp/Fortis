#include <stdlib.h>
#include <stdio.h>
#include <cuda_runtime.h>

static cudaStream_t fortis_stream = 0;
int fortis_capturing = 0;
void* mgpuStreamCreate(void) {
  if (!fortis_stream) cudaStreamCreate(&fortis_stream);
  return (void*)fortis_stream;
}
void mgpuStreamDestroy(void* s) {}
void mgpuStreamSynchronize(void* s) {}

/* device buffer pool: reuse a released buffer of the same size, else allocate */
#define POOL 256
static struct { long n; void* p; int used; } pool[POOL];
void* fortis_alloc(long n) {
  /* best fit among released buffers */
  int best = -1;
  for (int i = 0; i < POOL; i++)
    if (pool[i].p && !pool[i].used && pool[i].n >= n && (best < 0 || pool[i].n < pool[best].n)) best = i;
  if (best >= 0) { pool[best].used = 1; return pool[best].p; }
  /* new allocation; under memory pressure release everything unused and retry */
  for (int attempt = 0; attempt < 2; attempt++) {
    for (int i = 0; i < POOL; i++)
      if (!pool[i].p) {
        if (cudaMalloc(&pool[i].p, n) == cudaSuccess) { pool[i].n = n; pool[i].used = 1; return pool[i].p; }
        pool[i].p = 0; break;
      }
    cudaGetLastError();
    for (int i = 0; i < POOL; i++)
      if (pool[i].p && !pool[i].used) { cudaFree(pool[i].p); pool[i].p = 0; pool[i].n = 0; }
  }
  fprintf(stderr, "fortis_alloc: cudaMalloc(%ld) failed\n", n);
  return 0;
}
void fortis_free(void* p) {
  for (int i = 0; i < POOL; i++) if (pool[i].p == p) { pool[i].used = 0; return; }
  cudaFree(p);
}

/* large-batch path: C[B][N] = A[B][K] . W[N][K]^T via cuBLAS on the persistent stream */
#include <cublas_v2.h>
static cublasHandle_t fortis_blas = 0;
void fortis_gemm(float* Aa, float* A, long Ao, long As0, long As1, long At0, long At1,
                 float* Wa, float* W, long Wo, long Ws0, long Ws1, long Wt0, long Wt1,
                 float* Ca, float* C, long Co, long Cs0, long Cs1, long Ct0, long Ct1,
                 long B, long N, long K) {
  if (!fortis_blas) {
    cublasCreate(&fortis_blas);
    cublasSetStream(fortis_blas, (cudaStream_t)mgpuStreamCreate());
  }
  const float one = 1.f, zero = 0.f;
  /* Weights are constants: transpose each once at load so the recurring GEMM is N,N
     (cuBLAS picks a different, and here faster, kernel for that layout than for T,N). */
  static struct { const float* w; long n, k; float* wt; } tcache[64]; static int ntc = 0;
  static int no_pretrans = -1; if (no_pretrans < 0) no_pretrans = getenv("FORTIS_NO_PRETRANS") != 0;
  if (!no_pretrans) {
    float* wt = 0;
    for (int i = 0; i < ntc; i++) if (tcache[i].w == W + Wo && tcache[i].n == N && tcache[i].k == K) { wt = tcache[i].wt; break; }
    if (!wt && ntc < 64) {
      cudaMalloc((void**)&wt, (size_t)N * K * sizeof(float));
      cublasSgeam(fortis_blas, CUBLAS_OP_T, CUBLAS_OP_N, (int)N, (int)K, &one, W + Wo, (int)K, &zero, wt, (int)N, wt, (int)N);
      cudaStreamSynchronize((cudaStream_t)mgpuStreamCreate());
      tcache[ntc].w = W + Wo; tcache[ntc].n = N; tcache[ntc].k = K; tcache[ntc].wt = wt; ntc++;
    }
    if (wt) {
      cublasSgemm(fortis_blas, CUBLAS_OP_N, CUBLAS_OP_N, (int)N, (int)B, (int)K,
                  &one, wt, (int)N, A + Ao, (int)K, &zero, C + Co, (int)N);
      return;
    }
  }
  cublasSgemm(fortis_blas, CUBLAS_OP_T, CUBLAS_OP_N, (int)N, (int)B, (int)K,
              &one, W + Wo, (int)K, A + Ao, (int)K, &zero, C + Co, (int)N);
}

void fortis_conv3d_direct(float* xa, float* x, long xo, long x0, long x1, long x2, long x3, long x4, long xt0, long xt1, long xt2, long xt3, long xt4, float* wa, float* w, long wo, long w0, long w1, long w2, long w3, long w4, long wt0, long wt1, long wt2, long wt3, long wt4, float* ya, float* y, long yo, long y0, long y1, long y2, long y3, long y4, long yt0, long yt1, long yt2, long yt3, long yt4, long N, long C, long Din, long Hin, long Win, long F, long KD, long KH, long KW, long Dout, long Hout, long Wout, long sd, long sh, long sw_, long pd, long ph, long pw);
/* large-conv path: cuDNN forward, fixed implicit-precomp-GEMM algorithm, no autotune, pad 0
   (padding is already materialized by the compiler), beta = 0 (init added in the fused epilogue). */
#include <cudnn.h>
static cudnnHandle_t fortis_dnn = 0;
static void dnn_init(void) {
  if (!fortis_dnn) { cudnnCreate(&fortis_dnn); cudnnSetStream(fortis_dnn, (cudaStream_t)mgpuStreamCreate()); }
}

/* Algorithm choice: cuDNN's shape heuristic (no benchmarking), FFT family excluded, cached per shape. */
static cudnnConvolutionFwdAlgo_t fortis_pick_algo(cudnnTensorDescriptor_t xd, cudnnFilterDescriptor_t wd,
                                                  cudnnConvolutionDescriptor_t cd, cudnnTensorDescriptor_t yd) {
  cudnnConvolutionFwdAlgoPerf_t perf[CUDNN_CONVOLUTION_FWD_ALGO_COUNT]; int n = 0;
  if (cudnnGetConvolutionForwardAlgorithm_v7(fortis_dnn, xd, wd, cd, yd, CUDNN_CONVOLUTION_FWD_ALGO_COUNT, &n, perf) != CUDNN_STATUS_SUCCESS)
    return CUDNN_CONVOLUTION_FWD_ALGO_IMPLICIT_PRECOMP_GEMM;
  static int allow_fft = -1, report = -1;
  if (allow_fft < 0) { allow_fft = getenv("FORTIS_ALLOW_FFT") != 0; report = getenv("FORTIS_REPORT_ALGO") != 0; }
  if (report) { int d[8], s_[8], nd; cudnnDataType_t dt; cudnnGetTensorNdDescriptor(yd, 8, &dt, &nd, d, s_);
    fprintf(stderr, "conv out %dx%dx%dx%dx%d:", d[0], d[1], d[2], d[3], nd > 4 ? d[4] : 1);
    for (int i = 0; i < n; i++) fprintf(stderr, " [algo %d st %d %.2fms ws %.0fMB]", perf[i].algo, perf[i].status, perf[i].time, perf[i].memory / 1e6);
    fprintf(stderr, "\n"); }
  static int force = -2;
  if (force == -2) { const char* e = getenv("FORTIS_FORCE_ALGO"); force = e ? atoi(e) : -1; }
  if (force >= 0) for (int i = 0; i < n; i++) if (perf[i].algo == (cudnnConvolutionFwdAlgo_t)force && perf[i].status == CUDNN_STATUS_SUCCESS) return perf[i].algo;
  for (int i = 0; i < n; i++) {
    if (perf[i].status != CUDNN_STATUS_SUCCESS) continue;
    if (!allow_fft && (perf[i].algo == CUDNN_CONVOLUTION_FWD_ALGO_FFT || perf[i].algo == CUDNN_CONVOLUTION_FWD_ALGO_FFT_TILING)) continue;
    return perf[i].algo;
  }
  return CUDNN_CONVOLUTION_FWD_ALGO_IMPLICIT_PRECOMP_GEMM;
}
void fortis_conv2d(float* xa, float* x, long xo, long x0, long x1, long x2, long x3, long xt0, long xt1, long xt2, long xt3,
                   float* wa, float* w, long wo, long w0, long w1, long w2, long w3, long wt0, long wt1, long wt2, long wt3,
                   float* ya, float* y, long yo, long y0, long y1, long y2, long y3, long yt0, long yt1, long yt2, long yt3,
                   long N, long C, long Hin, long Win, long F, long KH, long KW, long Hout, long Wout, long sh, long sw, long ph, long pw) {
  dnn_init();
  cudnnTensorDescriptor_t xd, yd; cudnnFilterDescriptor_t wd; cudnnConvolutionDescriptor_t cd;
  cudnnCreateTensorDescriptor(&xd); cudnnSetTensor4dDescriptor(xd, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT, N, C, Hin, Win);
  cudnnCreateTensorDescriptor(&yd); cudnnSetTensor4dDescriptor(yd, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT, N, F, Hout, Wout);
  cudnnCreateFilterDescriptor(&wd); cudnnSetFilter4dDescriptor(wd, CUDNN_DATA_FLOAT, CUDNN_TENSOR_NCHW, F, C, KH, KW);
  cudnnCreateConvolutionDescriptor(&cd);
  cudnnSetConvolution2dDescriptor(cd, ph, pw, sh, sw, 1, 1, CUDNN_CROSS_CORRELATION, CUDNN_DATA_FLOAT);
  cudnnConvolutionFwdAlgo_t algo = fortis_pick_algo(xd, wd, cd, yd);
  size_t ws = 0; cudnnGetConvolutionForwardWorkspaceSize(fortis_dnn, xd, wd, cd, yd, algo, &ws);
  void* wsp = ws ? fortis_alloc((long)ws) : 0;
  const float one = 1.f, zero = 0.f;
  cudnnStatus_t st = cudnnConvolutionForward(fortis_dnn, &one, xd, x + xo, wd, w + wo, cd, algo, wsp, ws, &zero, yd, y + yo);
  if (st != CUDNN_STATUS_SUCCESS) fprintf(stderr, "fortis_conv2d: %s  N%ld C%ld in%ldx%ld F%ld K%ldx%ld out%ldx%ld s%ld,%ld p%ld,%ld xo%ld wo%ld yo%ld\n", cudnnGetErrorString(st), N, C, Hin, Win, F, KH, KW, Hout, Wout, sh, sw, ph, pw, xo, wo, yo);
  if (wsp) fortis_free(wsp);
  cudnnDestroyTensorDescriptor(xd); cudnnDestroyTensorDescriptor(yd); cudnnDestroyFilterDescriptor(wd); cudnnDestroyConvolutionDescriptor(cd);
}
void fortis_conv3d(float* xa, float* x, long xo, long x0, long x1, long x2, long x3, long x4, long xt0, long xt1, long xt2, long xt3, long xt4,
                   float* wa, float* w, long wo, long w0, long w1, long w2, long w3, long w4, long wt0, long wt1, long wt2, long wt3, long wt4,
                   float* ya, float* y, long yo, long y0, long y1, long y2, long y3, long y4, long yt0, long yt1, long yt2, long yt3, long yt4,
                   long N, long C, long Din, long Hin, long Win, long F, long KD, long KH, long KW, long Dout, long Hout, long Wout, long sd, long sh, long sw, long pd, long ph, long pw) {
  static int direct = -1; if (direct < 0) direct = getenv("FORTIS_DIRECT") != 0;
  if (direct && KD <= 5 && KH <= 5 && KW <= 5 && N == 1 && sd == 1 && sh == 1 && sw == 1) {
    fortis_conv3d_direct(xa, x, xo, x0, x1, x2, x3, x4, xt0, xt1, xt2, xt3, xt4, wa, w, wo, w0, w1, w2, w3, w4, wt0, wt1, wt2, wt3, wt4, ya, y, yo, y0, y1, y2, y3, y4, yt0, yt1, yt2, yt3, yt4, N, C, Din, Hin, Win, F, KD, KH, KW, Dout, Hout, Wout, sd, sh, sw, pd, ph, pw);
    return;
  }
  dnn_init();
  cudnnTensorDescriptor_t xd, yd; cudnnFilterDescriptor_t wd; cudnnConvolutionDescriptor_t cd;
  int xdim[5] = {(int)N, (int)C, (int)Din, (int)Hin, (int)Win}, xstr[5] = {(int)(C*Din*Hin*Win), (int)(Din*Hin*Win), (int)(Hin*Win), (int)Win, 1};
  int ydim[5] = {(int)N, (int)F, (int)Dout, (int)Hout, (int)Wout}, ystr[5] = {(int)(F*Dout*Hout*Wout), (int)(Dout*Hout*Wout), (int)(Hout*Wout), (int)Wout, 1};
  int wdim[5] = {(int)F, (int)C, (int)KD, (int)KH, (int)KW};
  int pad[3] = {(int)pd, (int)ph, (int)pw}, str[3] = {(int)sd, (int)sh, (int)sw}, dil[3] = {1, 1, 1};
  cudnnCreateTensorDescriptor(&xd); cudnnSetTensorNdDescriptor(xd, CUDNN_DATA_FLOAT, 5, xdim, xstr);
  cudnnCreateTensorDescriptor(&yd); cudnnSetTensorNdDescriptor(yd, CUDNN_DATA_FLOAT, 5, ydim, ystr);
  cudnnCreateFilterDescriptor(&wd); cudnnSetFilterNdDescriptor(wd, CUDNN_DATA_FLOAT, CUDNN_TENSOR_NCHW, 5, wdim);
  cudnnCreateConvolutionDescriptor(&cd);
  cudnnSetConvolutionNdDescriptor(cd, 3, pad, str, dil, CUDNN_CROSS_CORRELATION, CUDNN_DATA_FLOAT);
  cudnnConvolutionFwdAlgo_t algo = fortis_pick_algo(xd, wd, cd, yd);
  size_t ws = 0; cudnnGetConvolutionForwardWorkspaceSize(fortis_dnn, xd, wd, cd, yd, algo, &ws);
  void* wsp = ws ? fortis_alloc((long)ws) : 0;
  const float one = 1.f, zero = 0.f;
  cudnnStatus_t st = cudnnConvolutionForward(fortis_dnn, &one, xd, x + xo, wd, w + wo, cd, algo, wsp, ws, &zero, yd, y + yo);
  if (st != CUDNN_STATUS_SUCCESS) fprintf(stderr, "fortis_conv3d: %s\n", cudnnGetErrorString(st));
  if (wsp) fortis_free(wsp);
  cudnnDestroyTensorDescriptor(xd); cudnnDestroyTensorDescriptor(yd); cudnnDestroyFilterDescriptor(wd); cudnnDestroyConvolutionDescriptor(cd);
}
