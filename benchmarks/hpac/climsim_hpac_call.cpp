// ClimSim per-column loop under HPAC-ML: the pragma wraps the call, one region invocation per column.
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
  for (int step = 0; step < nsteps; step++) {
    for (int i = 0; i < NCOL; i++) {
      float *xi = &x[i][0]; float *yi = &y[i][0];
      #pragma approx declare tensor_functor(ifn: [c, 0:124] = ([c*124:c*124+124]))
      #pragma approx declare tensor_functor(ofn: [c, 0:128] = ([c*128:c*128+128]))
      #pragma approx declare tensor(ipt: ifn(xi[0:1]))
      #pragma approx ml(infer) in(ipt) out(ofn(yi[0:1])) label("climsim_call")
      mlp_forward(xi, yi);
      hit[i] = 1;
    }
  }
}
