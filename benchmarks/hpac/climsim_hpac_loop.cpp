// ClimSim loop under HPAC-ML: the pragma wraps the whole loop, the programmer supplies the batch.
#include <cstdio>
#include <cstdlib>
#define NIN 124
#define NOUT 128
#define NCOL 384
extern "C" float x[NCOL][NIN];
extern "C" float y[NCOL][NOUT];
extern "C" int hit[NCOL];
static void mlp_forward(const float *xi, float *yi) { std::fprintf(stderr, "accurate path executed\n"); std::exit(2); }
extern "C" void run_steps(int nsteps) {
  float *xp = &x[0][0]; float *yp = &y[0][0];
  for (int step = 0; step < nsteps; step++) {
    #pragma approx declare tensor_functor(ifn: [c, 0:124] = ([c*124:c*124+124]))
    #pragma approx declare tensor_functor(ofn: [c, 0:128] = ([c*128:c*128+128]))
    #pragma approx declare tensor(ipt: ifn(xp[0:384]))
    #pragma approx ml(infer) in(ipt) out(ofn(yp[0:384])) label("climsim_loop")
    for (int i = 0; i < NCOL; i++) { mlp_forward(x[i], y[i]); }
    for (int i = 0; i < NCOL; i++) hit[i] = 1;
  }
}
