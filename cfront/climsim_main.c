/* I/O, timing, and the check, as in v3_canonical.f90. Reads the same columns.bin, norm.bin, ref.bin. */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#define NIN 124
#define NOUT 128
#define NCOL 384
float x[NCOL][NIN], y[NCOL][NOUT], yref[NCOL][NOUT], mean[NIN], scale[NIN];
int hit[NCOL];
void run_steps(int nsteps);
static void rd(const char *f, void *p, size_t n) { FILE *u = fopen(f, "rb"); if (!u || fread(p, 1, n, u) != n) { fprintf(stderr, "cannot read %s\n", f); exit(1); } fclose(u); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + 1e-9 * t.tv_nsec; }
int main(void) {
  rd("columns.bin", x, sizeof x); rd("norm.bin", mean, sizeof mean);
  { FILE *u = fopen("norm.bin", "rb"); fseek(u, sizeof mean, SEEK_SET); fread(scale, 1, sizeof scale, u); fclose(u); }
  rd("ref.bin", yref, sizeof yref);
  for (int i = 0; i < NCOL; i++) for (int k = 0; k < NIN; k++) x[i][k] = (x[i][k] - mean[k]) / scale[k];
  run_steps(1);
  double t0 = now(); run_steps(998); double t1 = now();
  for (int i = 0; i < NCOL; i++) for (int k = 0; k < NOUT; k++) y[i][k] = -999.0f;
  run_steps(1);
  float err = 0.f, untouched = 0.f, ymax = 0.f; int n = 0;
  for (int i = 0; i < NCOL; i++) for (int k = 0; k < NOUT; k++) if (fabsf(yref[i][k]) > ymax) ymax = fabsf(yref[i][k]);
  for (int i = 0; i < NCOL; i++) {
    if (hit[i]) { n++; for (int k = 0; k < NOUT; k++) { float e = fabsf(y[i][k] - yref[i][k]) / ymax; if (e > err) err = e; } }
    else for (int k = 0; k < NOUT; k++) { float e = fabsf(y[i][k] + 999.0f); if (e > untouched) untouched = e; }
  }
  printf(" per-step ms: %.6f\n", (t1 - t0) * 1e3 / 998);
  printf(" iterated %d  max rel err: %.3e  untouched-columns disturbance: %.3e\n", n, err, untouched);
  return 0;
}
