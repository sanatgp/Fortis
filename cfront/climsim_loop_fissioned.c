/* What the front end must produce from climsim_loop.c: one call to the batched entry on the whole arrays, the Stay statement in a post-loop. */
#define NIN 124
#define NOUT 128
#define NCOL 384
extern float x[NCOL][NIN];
extern float y[NCOL][NOUT];
extern int hit[NCOL];
void mlp_forward_batched(const float *x, float *y);
void run_steps(int nsteps) {
  for (int step = 0; step < nsteps; step++) {
    mlp_forward_batched(&x[0][0], &y[0][0]);
    for (int i = 0; i < NCOL; i++) hit[i] = 1;
  }
}
