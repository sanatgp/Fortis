// csrc/fortis_torch_api.h  (if you have one)
#ifdef __cplusplus
#include <torch/script.h>
extern "C" {
#endif

void* fortis_torch_load(const char* model_path, int in_dim, int out_dim, int threads);
int   fortis_torch_forward(void* handle, const float* x, int nfeat, int nbatch, float* y, int ntgt);
void  fortis_torch_free(void* handle);

#ifdef __cplusplus
}
#endif
