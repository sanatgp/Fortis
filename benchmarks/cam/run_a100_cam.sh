#!/bin/bash
set -e
export F=/scratch/taghipouranvari.s/FTORCH
GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1 | awk '{print tolower($2)}')
case $GPU in a100) ARCH=sm_80;; h100|h200) ARCH=sm_90;; l40s|l40) ARCH=sm_89;; *) echo "unknown GPU $GPU"; exit 1;; esac
export OUT=$F/results/$GPU.csv; mkdir -p $F/results; touch $OUT
echo "== $GPU -> $ARCH"
sed "s/sm_70/$ARCH/g" $F/torch-mlir/fortisc.sh > $F/torch-mlir/fortisc_$GPU.sh; chmod +x $F/torch-mlir/fortisc_$GPU.sh
echo "== TensorRT plans for this GPU"
(cd $F/climsim_run && source $F/venv-trt/bin/activate && python rebuild_climsim_plans.py && deactivate)
echo "== E3SM ladder"
cd $F/cam_run
sed "s#\$F/torch-mlir/fortisc.sh#\$F/torch-mlir/fortisc_$GPU.sh#g" build_baselines.sh > build_baselines_$GPU.sh
bash build_baselines_$GPU.sh
