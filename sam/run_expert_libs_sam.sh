#!/bin/bash
# FTorch and TorchFort on the hand-batched SAM expert host, five runs each. Run in $F/sam_run on a GPU node.
set -e
F=/scratch/taghipouranvari.s/FTORCH
TP=$HOME/.conda/envs/rtr/lib/python3.11/site-packages; NV=$TP/nvidia
MPI=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/comm_libs/12.5/hpcx/hpcx-2.19/ompi/lib
TORCH_LD=/usr/lib64:$MPI:$TP/torch/lib:$NV/nccl/lib:$NV/cudnn/lib:$NV/cublas/lib:$NV/cuda_runtime/lib
FT=$F/ftorch-install; TF=$F/torchfort-install
FL="-O2 -ffree-line-length-none"
gfortran $FL -I$FT/include/ftorch fwd_ftorch_sam_b.f90 sam_host_batch.f90 -o sam_expert_ftorch -L$FT/lib64 -lftorch -Wl,-rpath,$FT/lib64
gfortran $FL -I$TF/include fwd_torchfort_sam_b.f90 sam_host_batch.f90 -o sam_expert_torchfort -Wl,--allow-shlib-undefined -L$TF/lib -ltorchfort_fort -ltorchfort -Wl,-rpath,$TF/lib -Wl,-rpath,$F/yaml-install/lib
for x in sam_expert_ftorch sam_expert_torchfort; do
  echo "== $x"
  for i in 1 2 3 4 5; do env LD_LIBRARY_PATH=$TORCH_LD ./$x 2>/dev/null | grep -i "ms\|err" | tr '\n' ' '; echo; done
done
