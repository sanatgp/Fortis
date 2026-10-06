/* The ClimSim per-column loop in C. This translation unit is what the C front end analyzes. */
#define NIN 124
#define NOUT 128
#define NCOL 384
extern float x[NCOL][NIN];
extern float y[NCOL][NOUT];
extern int hit[NCOL];
float s = 0.f, t = 0.f;
void mlp_forward(const float *x, float *y);
void run_steps(int nsteps) {
  for (int step = 0; step < nsteps; step++) {
    for (int i = 0; i < NCOL; i++) {
      s += x[i][0];
      mlp_forward(x[i], y[i]);
      hit[i] = 1;
      t += y[i][0];
    }
  }
}
