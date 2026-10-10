# Run-time extents, second host: the ClimSim column loop (v3_rt.f90)

ncol read from ncol.txt, x/y/yref/hit allocated to it, the call on a per-column temporary as CAM-GW and
SPCAM write it.  Verdict: batched, run-time count, 1 pre unit (xcol = x(:,i)), 1 post unit (y(:,i) = ycol).
Built once with the stub; specialized at first call per column count, cached in fortis_cache/.
A100 node, ms/step over 999 steps, max rel err vs the fp64 reference:
  384 columns: 0.241 (static batched build on this GPU 0.23), 4.8e-7, specialized once in 18-35 s
  200 columns: 0.196, 4.8e-7, specialized once in 27 s
  per call (FORTIS_NO_DIST), 384 columns: 16.6
Driver fixes found here: descriptor extents (fir.box_dims) and arithmetic on them are loop-independent;
allocatables of non-numeric element type (logical) are recognized.
