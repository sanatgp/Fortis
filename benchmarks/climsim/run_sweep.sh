#!/bin/bash
# Model-size sweep: E3SM (TensorRT, expert rewrite, FORTIS boundary) and ClimSim per column (TensorRT per call, FORTIS batched) at three hidden widths.
set -e
export F=/scratch/taghipouranvari.s/FTORCH; export OUT=$F/results/variance_final.csv; B=$F/torch-mlir/build/bin
CUDA=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5; TRT=$F/venv-trt/lib/python3.12/site-packages/tensorrt_libs; TRTI=$F/trt_run/trt-oss/include
LINK="$TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64"
run() { for i in 1 2 3 4 5; do o=$(env -u LD_LIBRARY_PATH ./$2 2>/dev/null | tr '\n' ' '); echo "$1,$2,$i,$(echo "$o" | grep -oE 'per-step ms: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$')" | tee -a $OUT; done; }
for W in 512 1024 2048; do
  echo "==== width $W"
  cd $F/climsim_run
  (source ~/venvs/tmlir/bin/activate && python export_wide.py $W onnx && deactivate); (source $F/venv-trt/bin/activate && python export_wide.py $W trt && deactivate)
  cd $F/cam_run; unset LD_LIBRARY_PATH
  sed "s#climsim_run/climsim_b384.plan#climsim_run/climsim_w${W}_b384.plan#" fwd_trt.cpp > fwd_trt_w$W.cpp
  sed "s#climsim_run/climsim_b384.plan#climsim_run/climsim_w${W}_b384.plan#" fwd_trt_bnd.cu > fwd_trt_bnd_w$W.cu
  g++ -O2 -I$TRTI -I$CUDA/include -c fwd_trt_w$W.cpp -o fwd_trt_w$W.o 2>/dev/null
  gfortran -O2 cam_host.f90 fwd_trt_w$W.o -o cam_trt_w$W $LINK
  $CUDA/bin/nvcc -O2 -arch=sm_70 -I$TRTI -c fwd_trt_bnd_w$W.cu -o fwd_trt_bnd_w$W.o 2>/dev/null
  gfortran -O2 cam_host_expert.f90 fwd_trt_bnd_w$W.o -o cam_trt_expert_w$W $LINK
  FORTIS_BATCH=384 $F/torch-mlir/fortisc.sh "export_wide.py $W linalg" cam_host.f90 cam_fortis_bnd_w$W 2>&1 | grep "shim:\|rror"
  run sweep_w$W cam_trt_w$W; run sweep_w$W cam_trt_expert_w$W; run sweep_w$W cam_fortis_bnd_w$W
  cd $F/climsim_run
  for i in 1 2 3 4 5; do us=$($F/trt_run/bench_trt climsim_w${W}_b1.plan col0.bin 124 128 2000 2>&1 | grep -oE 'per-call us: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$'); echo "sweep_w$W,climsim_trt_percol,$i,$(python3 -c "print($us*384/1000)")" | tee -a $OUT; done
  $F/torch-mlir/fortisc.sh "export_wide.py $W linalg" climsim_host.f90 climsim_fortis_lb_w$W 2>&1 | grep "shim:\|rror"
  run sweep_w$W climsim_fortis_lb_w$W
done
grep "^sweep_w" $OUT | awk -F, '{s[$1","$2]+=$4; n[$1","$2]++} END{for (k in s) printf "%-40s %.3f\n", k, s[k]/n[k]}' | sort
