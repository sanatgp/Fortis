#!/bin/bash
set -e
export F=/scratch/taghipouranvari.s/FTORCH
GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1 | awk '{print tolower($2)}')
export OUT=$F/results/$GPU.csv
TP=$HOME/.conda/envs/rtr/lib/python3.11/site-packages; NV=$TP/nvidia
MPI=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/comm_libs/12.5/hpcx/hpcx-2.19/ompi/lib
TORCH_LD=/usr/lib64:$MPI:$TP/torch/lib:$NV/nccl/lib:$NV/cudnn/lib:$NV/cublas/lib:$NV/cuda_runtime/lib
cd $F/climsim_run
run() { for i in 1 2 3 4 5; do o=$(env $2 ./$1 2>/dev/null | tr '\n' ' '); echo "climsim_col,$1,$i,$(echo "$o" | grep -oE 'per-step ms: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$'),$(echo "$o" | grep -oE 'max rel err: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$')" | tee -a $OUT; done; }
echo "== TensorRT per call (engine rebuilt on this GPU), per-step = per-call x 384"
for i in 1 2 3; do (unset LD_LIBRARY_PATH; $F/trt_run/bench_trt climsim_b1.plan col0.bin 124 128 2000 2>&1 | grep -v "^\[TRT\]"); done
echo "== FORTIS"
unset LD_LIBRARY_PATH
FORTIS_NO_DIST=1 FORTIS_GRAPH=0 $F/torch-mlir/fortisc_$GPU.sh "export_climsim.py linalg" climsim_host.f90 climsim_fortis_shape_$GPU 2>&1 | grep "fortisc:\|shim:\|rror"
FORTIS_NO_DIST=1 FORTIS_GRAPH=1 $F/torch-mlir/fortisc_$GPU.sh "export_climsim.py linalg" climsim_host.f90 climsim_fortis_graph_$GPU 2>&1 | grep "fortisc:\|shim:\|rror"
$F/torch-mlir/fortisc_$GPU.sh "export_climsim.py linalg" climsim_host.f90 climsim_fortis_lb_$GPU 2>&1 | grep "fortisc:\|shim:\|rror"
$F/torch-mlir/fortisc_$GPU.sh "export_climsim.py linalg" climsim_host_norm.f90 climsim_fortis_lift_$GPU 2>&1 | grep "fortisc:\|shim:\|rror"
run climsim_fortis_shape_$GPU "-u LD_LIBRARY_PATH"
run climsim_fortis_graph_$GPU "-u LD_LIBRARY_PATH"
run climsim_fortis_lb_$GPU "-u LD_LIBRARY_PATH"
run climsim_fortis_lift_$GPU "-u LD_LIBRARY_PATH"
echo "== library couplings"
run climsim_ftorch "LD_LIBRARY_PATH=$TORCH_LD"
run climsim_torchfort "LD_LIBRARY_PATH=$TORCH_LD"
echo "== summary ($OUT)"
grep "^climsim_col," $OUT | awk -F, '{s[$2]+=$4; n[$2]++; e[$2]=$5} END{for (k in s) printf "%-28s %.3f ms  err %s\n", k, s[k]/n[k], e[k]}' | sort -k2 -n
