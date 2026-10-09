# MOM6 Zanna-Bolton ANN host (third host, ocean domain)

Host: compute_stress_ANN_collocated of MOM_Zanna_Bolton.F90, m2lines/MOM6 dev/m2lines commit 89f1fb3,
transcribed as written with ANN_apply(x, y, CS%ann_Tall) replaced by the call mlp_forward(x, y).
Network: Tall.nc of m2lines/ANN-momentum-mesoscale (hidden-layer-20/seed-default), 27 -> 20 -> 3, ReLU.
Grid: one rank's 60x70 subdomain of NeverWorld2 0.25 deg (240x560), 15 layers, halo 4; the ANN loop runs
do k / do j=js-2,je+2 / do i=is-2,ie+2, 64x74 = 4736 cells per layer, 71,040 calls per step.
Expert host: the hand-batched form of the production branch (NOAA-GFDL/MOM6 dev/gfdl, ANN_apply_array_sio).

FORTIS verdict (zb_loop_verdict.json): batched, 4736 iterations of the j/i nest inside do k, 5 pre units
(three RESHAPE stencil packs, input_norm, the normalization), 4 post units (de-scale, three stores),
input_norm recomputed in the post-loop. RESHAPE arrives as hlfir.reshape.

V100, ms per step, mean of 5 runs (per-cell couplings: 2 runs of 3 steps), fp32, max rel err vs the fp64
run of the shipped code:
  FORTIS, unchanged source            2.80   5.98e-7
  expert hand-batched + TensorRT      2.97   5.98e-7   (host compiled by Flang; 12.45 with gfortran's RESHAPE runtime)
  expert hand-batched + FORTIS        3.03   5.98e-7
  host with the model removed (Flang) 1.53
  shipped CPU code, gfortran          26.8   7.20e-7   (Flang 47.5: per-call allocate in ANN_apply)
  TensorRT per cell                   1292   9.77e-7
  FTorch per cell                     6291   9.77e-7
  TorchFort per cell                  7475   9.77e-7

Driver fixes found on this host: column classification of array-section reads (fortis_units.py), and
units needed by both loops kept in both copies (fortis_fission_hlfir.py).

## Run-time extents (zb_host_rt.f90)

The same host with the grid read at run time (zb_grid.txt), allocatable fields, and loop bounds from
is, ie, js, je, nz, as in MOM6 itself.  The driver batches the nest with a run-time count; the ahead-of-time
build links a stub (driver/fortis_stub.c), and fortis_begin(count) specializes the model side at the first
call through the generated zb_fortis_rt.jit.sh, cached in fortis_cache/ as <host>_b<count>.so.

  grid 60x70x15, 4736 cells/layer: 3.10 ms per step (static build 2.80), specialized once in 37.7 s,
      checksum identical to the static FORTIS build, 5.98e-7 vs fp64
  grid 40x50x10, 2376 cells/layer: 1.24 ms per step, specialized once in 49.1 s, 8.20e-7 vs fp64
  second run at either grid: loaded from the cache, no specialization
  run-time host with the model removed (Flang): 1.61 ms

## Stencil lift (gather.json, gather.cu)

Every pre-loop unit is a section gather from a host array into x, a same-cell scalar read, or an
elementwise expression over x; the pre-loop is deleted and one gather kernel in front of the model reads
the host's own sh_xy_h, sh_xx, vort_xy_h, norm_h at the 3x3 stencil of each cell (four 21 KB planes per
layer instead of a 511 KB packed buffer).  V100: 1.68 ms per step (pack on host 2.80, expert+TensorRT
2.97, shipped 26.8), checksum identical to the packed build, 5.98e-7 vs fp64.

## Scatter lift and enclosing-loop distribution (scatter.json, kdist.json)

Post side: the recomputed norm read, the chained scalings of y (composed to one expression in the host's
order, ((y*S0)*S0)*S1 with S0 = norm_h(i,j,k), S1 = kappa_h(i,j)), and the three stores Txy_h(i,j),
Txx(i,j,k), Tyy(i,j,k) become one kernel after the model that writes the visited rectangle of each array
back (cudaMemcpy2D).  Enclosing loop: the gather reads only arrays the k loop never writes, so the gather
and the model run once per step over 15 x 4736 rows; the scatter stays per layer because the corner nest
consumes Txy_h within the layer.  host_fissioned.fir is the rewritten unit.
  V100 ms/step: pack on host 2.80 -> gather 1.68 -> gather+scatter per layer 1.76 -> +k distributed 1.19
  host without the ANN nest 1.11; expert+TensorRT 2.97; checksum identical in every build, 5.98e-7 vs fp64
