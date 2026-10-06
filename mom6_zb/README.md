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
