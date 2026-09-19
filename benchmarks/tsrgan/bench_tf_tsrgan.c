#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <tensorflow/c/c_api.h>
#define NIN (33L*33L*33L*3L)
#define N (132L*132L*132L*3L)
static void noop(void* d, size_t l, void* a) {}
int main() {
  TF_Status* st = TF_NewStatus(); TF_Graph* g = TF_NewGraph(); TF_SessionOptions* o = TF_NewSessionOptions();
  const char* tags = "serve";
  TF_Session* s = TF_LoadSessionFromSavedModel(o, NULL, "../Fortran-ML-Interface/model/tsrgan/TSRGAN_3D_36_4X_decay_gaussian.tf", &tags, 1, g, NULL, st);
  if (TF_GetCode(st) != TF_OK) { printf("load: %s\n", TF_Message(st)); return 1; }
  TF_Output in = { TF_GraphOperationByName(g, "serving_default_keras_tensor"), 0 };
  TF_Output out = { TF_GraphOperationByName(g, "StatefulPartitionedCall_1"), 0 };
  if (!in.oper || !out.oper) { printf("op lookup failed\n"); return 1; }
  float* x = malloc(NIN * 4); FILE* f = fopen("tsrgan_in.bin", "rb"); fread(x, 4, NIN, f); fclose(f);
  int64_t dims[5] = {1, 33, 33, 33, 3};
  TF_Tensor* y = NULL;
  for (int i = 0; i < 3; i++) {   /* warmup incl. cuDNN autotune */
    TF_Tensor* t = TF_NewTensor(TF_FLOAT, dims, 5, x, NIN * 4, noop, NULL);
    TF_SessionRun(s, NULL, &in, &t, 1, &out, &y, 1, NULL, 0, NULL, st);
    if (TF_GetCode(st) != TF_OK) { printf("run: %s\n", TF_Message(st)); return 1; }
    TF_DeleteTensor(t); TF_DeleteTensor(y);
  }
  struct timespec t0, t1; clock_gettime(CLOCK_MONOTONIC, &t0);
  for (int i = 0; i < 20; i++) {
    TF_Tensor* t = TF_NewTensor(TF_FLOAT, dims, 5, x, NIN * 4, noop, NULL);
    TF_SessionRun(s, NULL, &in, &t, 1, &out, &y, 1, NULL, 0, NULL, st);
    TF_DeleteTensor(t); if (i < 19) TF_DeleteTensor(y);
  }
  clock_gettime(CLOCK_MONOTONIC, &t1);
  float* z = TF_TensorData(y); double cs = 0; for (long i = 0; i < N; i++) cs += z[i];
  printf("per-call ms: %.2f\n", ((t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6) / 20);
  printf("checksum: %f  y[:3] %f %f %f\n", cs, z[0], z[1], z[2]);
  return 0;
}
