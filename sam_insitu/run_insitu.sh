#!/bin/bash
# Run one coupled build on the 300-step case, 4 ranks on the one V100, and report the NN unit time and total CPU time.
#   bash insitu/run_insitu.sh shipped|trt|ftorch|fortis
V=$1; F=/scratch/taghipouranvari.s/FTORCH; S=$F/sam_nn; cd $S
TP=$HOME/.conda/envs/rtr/lib/python3.11/site-packages; NV=$TP/nvidia
TORCH_LD=/usr/lib64:$TP/torch/lib:$NV/nccl/lib:$NV/cudnn/lib:$NV/cublas/lib:$NV/cuda_runtime/lib
rm -f NNRUN/*.stat RESTART/* OUT_2D/* OUT_3D/* OUT_STAT/* OUT_MOVIES/*
X=""; [ "$V" = ftorch ] && X="-x LD_LIBRARY_PATH=$TORCH_LD:$LD_LIBRARY_PATH"
mpirun --oversubscribe -np 4 -x CUDA_MPS_PIPE_DIRECTORY $X ./SAM_$V > insitu/run_$V.log 2>&1 ; grep -q "CPU TIME" insitu/run_$V.log || { echo "run failed"; tail -20 insitu/run_$V.log; exit 1; }
cp NNRUN/*.stat insitu/stat_$V.stat 2>/dev/null
grep -E "nn_core|CPU TIME" insitu/run_$V.log
