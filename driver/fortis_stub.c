// FORTIS run-time extent stub.  The host was distributed ahead of time with the loop count left to run
// time; fortis_begin(count) loads the model side specialized for that count from the cache, building it
// once through the generated jit script if it is missing, and the other entries forward to it.
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
typedef void (*packf)(void*, int); typedef void (*vf)(void);
static int cur = -1; static packf p_pack, p_unpack; static vf p_run;
void fortis_begin(int count) {
  if (count == cur) return;
  const char* jit = getenv("FORTIS_JIT"); if (!jit) jit = FORTIS_JIT_SCRIPT;
  const char* cache = getenv("FORTIS_CACHE"); if (!cache) cache = FORTIS_CACHE_DIR;
  char so[1024]; snprintf(so, sizeof so, "%s/%s_b%d.so", cache, FORTIS_HOST_TAG, count);
  if (access(so, R_OK) != 0) {
    struct timespec t0, t1; clock_gettime(CLOCK_MONOTONIC, &t0);
    char cmd[2048]; snprintf(cmd, sizeof cmd, "mkdir -p %s && bash %s %d %s", cache, jit, count, so);
    fprintf(stderr, "fortis: specializing the model for %d rows\n", count);
    int rc = system(cmd);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    if (rc != 0 || access(so, R_OK) != 0) { fprintf(stderr, "fortis: specialization failed (see %s.log)\n", so); exit(1); }
    fprintf(stderr, "fortis: specialized in %.1f s\n", (t1.tv_sec - t0.tv_sec) + 1e-9 * (t1.tv_nsec - t0.tv_nsec));
  }
  void* h = dlopen(so, RTLD_NOW | RTLD_LOCAL);
  if (!h) { fprintf(stderr, "fortis: %s\n", dlerror()); exit(1); }
  p_pack = (packf)dlsym(h, "fortis_pack"); p_unpack = (packf)dlsym(h, "fortis_unpack"); p_run = (vf)dlsym(h, "mlp_forward_batched");
  if (!p_pack || !p_unpack || !p_run) { fprintf(stderr, "fortis: entries missing in %s\n", so); exit(1); }
  cur = count;
}
void fortis_pack(void* x, int col) { p_pack(x, col); }
void fortis_unpack(void* y, int col) { p_unpack(y, col); }
void mlp_forward_batched(void) { p_run(); }
void mlp_forward(void* x, void* y) { fprintf(stderr, "fortis: a per-row call outside the distributed loop is not specialized\n"); exit(1); }
