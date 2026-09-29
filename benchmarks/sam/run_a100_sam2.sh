#!/bin/bash
set -e
export F=/scratch/taghipouranvari.s/FTORCH
GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1 | awk '{print tolower($2)}')
export OUT=$F/results/$GPU.csv
CUDA=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5
TRT=$F/venv-trt/lib/python3.12/site-packages/tensorrt_libs; TRTI=$F/trt_run/trt-oss/include
cd $F/sam_run
run() { for i in 1 2 3 4 5; do o=$(./$1 2>/dev/null | tr '\n' ' '); echo "sam,$1,$i,$(echo "$o" | grep -oE 'per-step ms: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$'),$(echo "$o" | grep -oE 'dt *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$')" | tee -a $OUT; done; }
echo "== TensorRT batch-2 padded engine and the hand-batched TensorRT host"
sed 's/for B in (1, 3240)/for B in (2,)/' build_sam_trt.py > build_sam_b2.py
(source $F/venv-trt/bin/activate && python build_sam_b2.py && deactivate)
g++ -O2 -I$TRTI -I$CUDA/include -c fwd_trt_sam_pad.cpp -o fwd_trt_sam_pad.o
gfortran -O2 -ffree-line-length-none sam_host.f90 fwd_trt_sam_pad.o -o sam_trt_pad_$GPU $TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64
g++ -O2 -DTRT_BATCH=3240 -DTRT_PLAN='"sam_b3240.plan"' -I$TRTI -I$CUDA/include -c fwd_trt_sam.cpp -o fwd_trt_sam_b.o
gfortran -O2 -ffree-line-length-none sam_host_batch.f90 fwd_trt_sam_b.o -o sam_trt_batch_$GPU $TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64
run sam_trt_pad_$GPU
run sam_trt_batch_$GPU
echo "== FORTIS"
unset LD_LIBRARY_PATH
$F/torch-mlir/fortisc_$GPU.sh "export_sam.py linalg" sam_host.f90 sam_fortis_$GPU 2>&1 | grep "fortisc:\|shim:\|rror"
FORTIS_NO_DIST=1 $F/torch-mlir/fortisc_$GPU.sh "export_sam.py linalg" sam_host.f90 sam_fortis_col_$GPU 2>&1 | grep "fortisc:\|shim:\|rror"
FORTIS_NO_DIST=1 $F/torch-mlir/fortisc_$GPU.sh "export_sam.py linalg" sam_host_batch.f90 sam_fortis_batch_$GPU 2>&1 | grep "fortisc:\|shim:\|rror"
run sam_fortis_$GPU
run sam_fortis_col_$GPU
run sam_fortis_batch_$GPU
echo "== summary ($OUT)"
grep "^sam," $OUT | awk -F, '{s[$2]+=$4; n[$2]++; e[$2]=$5} END{for (k in s) printf "%-24s %.3f ms  dt err %s\n", k, s[k]/n[k], e[k]}' | sort -k2 -n
