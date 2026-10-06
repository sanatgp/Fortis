#!/bin/bash
# MOM6 ZB-ANN host: fp64 reference, shipped fp32 code (gfortran and Flang), null host, expert hosts, FORTIS analysis.
set -e
B=$F/torch-mlir/build/bin
python3 make_zb_weights.py
python3 make_expert.py
for R in 8 4; do sed "s/RKVAL/$R/" fwd_native_zb.f90 > fwd_native$R.f90; sed "s/RKVAL/$R/" fwd_native_zb_mod.f90 > fwd_native_mod$R.f90; done
sed 's/rk = 4/rk = 8/' zb_host.f90 > zb_host_r8.f90; sed 's/rk = 4/rk = 8/' zb_host_expert.f90 > zb_host_expert_r8.f90
gfortran -O3 fwd_native8.f90 zb_host_r8.f90 -o zb_native_r8
gfortran -O3 fwd_native4.f90 zb_host.f90 -o zb_native_gf
$B/flang -O3 fwd_native4.f90 zb_host.f90 -o zb_native_flang
gfortran -O3 fwd_null.f90 zb_host.f90 -o zb_null
gfortran -O3 fwd_native_mod8.f90 fwd_native_zb_batched.f90 zb_host_expert_r8.f90 -o zb_expert_r8
gfortran -O3 fwd_native_mod4.f90 fwd_native_zb_batched.f90 zb_host_expert.f90 -o zb_expert_native
echo "== fp64 reference (MOM6's own precision)"; ./zb_native_r8 && cp zb_out.bin zb_ref.bin
echo "== as shipped, fp32, gfortran"; ./zb_native_gf
echo "== as shipped, fp32, Flang"; ./zb_native_flang
echo "== host with the model removed"; ./zb_null | head -1
echo "== expert hand-batched host, fp64 and fp32 CPU"; ./zb_expert_r8; ./zb_expert_native
echo "== FORTIS analysis on the per-cell host"
$B/flang -fc1 -emit-hlfir zb_host.f90 -o zb_host.hlfir
$B/flang -fc1 -emit-fir zb_host.f90 -o zb_host.fir
python3 $F/torch-mlir/fortis_hostinfo.py zb_host.fir mlp_forward | head -c 600; echo
python3 $F/torch-mlir/fortis_units.py zb_host.hlfir mlp_forward | python3 -c "import json,sys; d=json.load(sys.stdin); print({k: d[k] for k in d if k not in ('statements','lift')}); [print('  ', s) for s in d.get('statements', [])]"
echo "reshape lowering:"; grep -c "hlfir.reshape" zb_host.hlfir || true; grep -c "_FortranAReshape" zb_host.hlfir || true
