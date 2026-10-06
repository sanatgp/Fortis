#!/bin/bash
# Per-cell library couplings and the TensorRT expert of the ZB host, five runs each. Run in $F/zb_run.
set -e
CUDA=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5
TP=$HOME/.conda/envs/rtr/lib/python3.11/site-packages; NV=$TP/nvidia
MPI=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/comm_libs/12.5/hpcx/hpcx-2.19/ompi/lib
TORCH_LD=/usr/lib64:$MPI:$TP/torch/lib:$NV/nccl/lib:$NV/cudnn/lib:$NV/cublas/lib:$NV/cuda_runtime/lib
TRT=$F/venv-trt/lib/python3.12/site-packages/tensorrt_libs; TRTI=$F/trt_run/trt-oss/include
FT=$F/ftorch-install; TF=$F/torchfort-install
OUT=${OUT:-zb_results.csv}
echo "== engines"
(source ~/venvs/tmlir/bin/activate && python export_zb.py && python export_zb_onnx.py && deactivate)
(source $F/venv-trt/bin/activate && python build_zb_trt.py && deactivate)
echo "== build"
gfortran -O2 -I$FT/include/ftorch fwd_ftorch_zb.f90 zb_host_short.f90 -o zb_ftorch -L$FT/lib64 -lftorch -Wl,-rpath,$FT/lib64
gfortran -O2 -I$TF/include fwd_torchfort_zb.f90 zb_host_short.f90 -o zb_torchfort -Wl,--allow-shlib-undefined -L$TF/lib -ltorchfort_fort -ltorchfort -Wl,-rpath,$TF/lib -Wl,-rpath,$F/yaml-install/lib
g++ -O2 -I$TRTI -I$CUDA/include -c fwd_trt_zb.cpp -o fwd_trt_zb.o 2>/dev/null
gfortran -O2 zb_host_short.f90 fwd_trt_zb.o -o zb_trt $TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64
g++ -O2 -DTRT_BATCH=4736 -DTRT_PLAN='"zb_b4736.plan"' -I$TRTI -I$CUDA/include -c fwd_trt_zb.cpp -o fwd_trt_zb_b.o 2>/dev/null
gfortran -O2 zb_host_expert.f90 fwd_trt_zb_b.o -o zb_expert_trt $TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64
echo "== run"
run() { N=${3:-5}; for i in $(seq $N); do o=$(env $2 ./$1 2>/dev/null | tr '\n' ' '); echo "zb,$1,$i,$(echo "$o" | grep -oE 'per-step ms: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$'),$(echo "$o" | grep -oE 'reference: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$')" | tee -a $OUT; done; }
run zb_expert_trt "-u LD_LIBRARY_PATH"
run zb_fortis "-u LD_LIBRARY_PATH"
run zb_expert_fortis "-u LD_LIBRARY_PATH"
run zb_native_gf "-u LD_LIBRARY_PATH"
run zb_trt "-u LD_LIBRARY_PATH" 2
run zb_ftorch "LD_LIBRARY_PATH=$TORCH_LD" 2
run zb_torchfort "LD_LIBRARY_PATH=$TORCH_LD" 2
grep "^zb," $OUT | awk -F, '{s[$2]+=$4; n[$2]++; e[$2]=$5} END{for (k in s) printf "%-18s %.3f ms  err %s\n", k, s[k]/n[k], e[k]}' | sort -k2 -n
