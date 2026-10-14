#!/bin/bash
# FTorch and TorchFort on the hand-batched MOM6 expert host, five runs each. Run in $F/zb_run on a GPU node.
set -e
F=/scratch/taghipouranvari.s/FTORCH
TP=$HOME/.conda/envs/rtr/lib/python3.11/site-packages; NV=$TP/nvidia
MPI=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/comm_libs/12.5/hpcx/hpcx-2.19/ompi/lib
TORCH_LD=/usr/lib64:$MPI:$TP/torch/lib:$NV/nccl/lib:$NV/cudnn/lib:$NV/cublas/lib:$NV/cuda_runtime/lib
FT=$F/ftorch-install; TF=$F/torchfort-install
OUT=${OUT:-zb_expert_libs.csv}
gfortran -O2 -I$FT/include/ftorch fwd_ftorch_zb_b.f90 zb_host_expert.f90 -o zb_expert_ftorch -L$FT/lib64 -lftorch -Wl,-rpath,$FT/lib64
gfortran -O2 -I$TF/include fwd_torchfort_zb_b.f90 zb_host_expert.f90 -o zb_expert_torchfort -Wl,--allow-shlib-undefined -L$TF/lib -ltorchfort_fort -ltorchfort -Wl,-rpath,$TF/lib -Wl,-rpath,$F/yaml-install/lib
run() { for i in 1 2 3 4 5; do o=$(env LD_LIBRARY_PATH=$TORCH_LD ./$1 2>/dev/null | tr '\n' ' '); echo "zb,$1,$i,$(echo "$o" | grep -oE 'per-step ms: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$'),$(echo "$o" | grep -oE 'reference: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$')" | tee -a $OUT; done; }
run zb_expert_ftorch
run zb_expert_torchfort
grep "^zb," $OUT | awk -F, '{s[$2]+=$4; ss[$2]+=$4*$4; n[$2]++; e[$2]=$5} END{for (k in s) printf "%-20s %.3f ms  sd %.3f  err %s\n", k, s[k]/n[k], sqrt(ss[k]/n[k]-(s[k]/n[k])^2), e[k]}'
