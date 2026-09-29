#!/bin/bash
# Rebuild every E3SM coupling on the current cam_host.f90 and run each five times (timing from step 2).
set -e
cd $F/cam_run
CUDA=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5
TP=$HOME/.conda/envs/rtr/lib/python3.11/site-packages
TL=$TP/torch/lib; NV=$TP/nvidia
TORCH_LD=/usr/lib64:$TL:$NV/nccl/lib:$NV/cudnn/lib:$NV/cublas/lib:$NV/cuda_runtime/lib
TRT=$F/venv-trt/lib/python3.12/site-packages/tensorrt_libs; TRTI=$F/trt_run/trt-oss/include
FT=$F/ftorch-install; TF=$F/torchfort-install
B=$F/torch-mlir/build/bin

echo "== build"
gfortran -O2 -I$FT/include/ftorch fwd_ftorch.f90 cam_host.f90 -o cam_ftorch -L$FT/lib64 -lftorch -Wl,-rpath,$FT/lib64
gfortran -O2 -I$TF/include fwd_torchfort.f90 cam_host.f90 -o cam_torchfort -Wl,--allow-shlib-undefined -L$TF/lib -ltorchfort_fort -ltorchfort -Wl,-rpath,$TF/lib -Wl,-rpath,$F/yaml-install/lib
g++ -O2 -I$TRTI -I$CUDA/include -c fwd_trt.cpp -o fwd_trt.o
gfortran -O2 cam_host.f90 fwd_trt.o -o cam_trt $TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64
$B/flang -O3 fwd_null.f90 cam_host.f90 -o cam_null_flang
(unset LD_LIBRARY_PATH; FORTIS_BATCH=384 FORTIS_NO_BOUNDARY=1 $F/torch-mlir/fortisc.sh "$F/climsim_run/export_climsim.py linalg" cam_host.f90 cam_fortis_glue 2>&1 | grep "shim:\|rror" || true)
(unset LD_LIBRARY_PATH; FORTIS_BATCH=384 $F/torch-mlir/fortisc.sh "$F/climsim_run/export_climsim.py linalg" cam_host.f90 cam_fortis_bnd 2>&1 | grep "shim:\|rror" || true)

echo "== run"
run() {
  for i in 1 2 3 4 5; do
    out=$(env $2 ./$1 2>/dev/null | tr '\n' ' ')
    ms=$(echo "$out" | grep -oE 'per-step ms: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$')
    err=$(echo "$out" | grep -oE 'max rel err \(model out\): *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$')
    echo "cam_e3sm_v2,$1,$i,$ms,$err" | tee -a $OUT
  done
}
run cam_null_flang "-u LD_LIBRARY_PATH"
run cam_fortis_bnd "-u LD_LIBRARY_PATH"
run cam_fortis_glue "-u LD_LIBRARY_PATH"
run cam_trt "-u LD_LIBRARY_PATH"
run cam_ftorch "LD_LIBRARY_PATH=$TORCH_LD"
run cam_torchfort "LD_LIBRARY_PATH=$TORCH_LD"
echo "== summary (ms, five runs)"
grep "^cam_e3sm_v2," $OUT | awk -F, '{s[$2]+=$4; ss[$2]+=$4*$4; n[$2]++; e[$2]=$5} END{for (k in s) {m=s[k]/n[k]; printf "%-16s %.3f ± %.3f   err %s\n", k, m, sqrt(ss[k]/n[k]-m*m), e[k]}}'
