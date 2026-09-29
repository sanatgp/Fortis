#!/bin/bash
# Build the SAM host with the network as shipped (fp32 inline matmul), and the fp64 reference of the same code.
set -e
B=$F/torch-mlir/build/bin
sed 's/RKVAL/4/' fwd_native.f90 > fwd_native4.f90
sed 's/RKVAL/8/' fwd_native.f90 > fwd_native8.f90
sed 's/rk = 4/rk = 8/' sam_host.f90 > sam_host_r8.f90
$B/flang -O3 fwd_native8.f90 sam_host_r8.f90 -o sam_native_r8
$B/flang -O3 fwd_native4.f90 sam_host.f90 -o sam_native
echo "== fp64 reference (the authors' code in double precision)"; ./sam_native_r8 && cp sam_out.bin sam_ref.bin
echo "== as shipped, fp32 inline matmul on the CPU"; ./sam_native
echo "== FORTIS analysis on this host"
$B/flang -fc1 -emit-hlfir sam_host.f90 -o sam_host.hlfir
$B/flang -fc1 -emit-fir sam_host.f90 -o sam_host.fir
python3 $F/torch-mlir/fortis_hostinfo.py sam_host.fir mlp_forward | head -c 600; echo
PYTHONPATH=$F/torch-mlir python3 $F/torch-mlir/fortis_loopdist.py sam_host.hlfir mlp_forward | python3 -c "import json,sys; d=json.load(sys.stdin); print({k: d[k] for k in d if k not in ('statements','lift')}); print('lift', d.get('lift')); [print('  ', s) for s in d.get('statements', [])[:40]]"
