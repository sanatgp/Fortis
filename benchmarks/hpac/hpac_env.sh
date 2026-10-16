#!/bin/bash
export PATH=/scratch/taghipouranvari.s/FTORCH/hpac-install/bin:$PATH
export LD_LIBRARY_PATH=/scratch/taghipouranvari.s/FTORCH/hpac-install/lib:/home/taghipouranvari.s/.conda/envs/rtr/lib/python3.11/site-packages/torch/lib:/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5/lib64:$LD_LIBRARY_PATH
export CC=clang CPP=clang++
export HPAC_GPU_ARCH=sm_70 HPAC_GPU_SM=70
export HPAC_LIBRARY_LOCATION=/scratch/taghipouranvari.s/FTORCH/hpac-install/lib
