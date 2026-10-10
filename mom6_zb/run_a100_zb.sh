#!/bin/bash
# MOM6 ZB-ANN ladder on a non-Volta GPU. Run on the GPU node: bash run_a100_zb.sh
# Rows "zb,<binary>,<run>,<per-step ms>,<rel err>" go to $F/results/<gpu>.csv.
set -e
export F=/scratch/taghipouranvari.s/FTORCH
module load OpenMPI/4.1.6 netcdf/4.9.3-gcc HDF5/1.14.6 2>/dev/null; module load cmake 2>/dev/null
GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1 | awk '{print tolower($2)}')
case $GPU in a100) ARCH=sm_80;; h100|h200) ARCH=sm_90;; l40s|l40) ARCH=sm_89;; *) echo "unknown GPU $GPU"; exit 1;; esac
export OUT=$F/results/$GPU.csv; mkdir -p $F/results; touch $OUT
echo "== $GPU -> $ARCH"
sed "s/sm_70/$ARCH/g" $F/torch-mlir/fortisc.sh > $F/torch-mlir/fortisc_$GPU.sh; chmod +x $F/torch-mlir/fortisc_$GPU.sh
CUDA=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5
TRT=$F/venv-trt/lib/python3.12/site-packages/tensorrt_libs; TRTI=$F/trt_run/trt-oss/include
cd $F/zb_run
run() { N=${3:-5}; for i in $(seq $N); do o=$(env $2 ./$1 2>/dev/null | tr '\n' ' '); echo "zb,$1,$i,$(echo "$o" | grep -oE 'per-step ms: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$'),$(echo "$o" | grep -oE 'reference: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$')" | tee -a $OUT; done; }
echo "== reference and shipped code on this node's CPU"
echo "60 70 15" > zb_grid.txt
./zb_native_r8 > /dev/null && cp zb_out.bin zb_ref.bin
run zb_native_gf "-u LD_LIBRARY_PATH"
echo "== TensorRT engines rebuilt on this GPU"
(source $F/venv-trt/bin/activate && python build_zb_trt.py && deactivate) | tail -1
g++ -O2 -fPIE -DTRT_BATCH=4736 -DTRT_PLAN='"zb_b4736.plan"' -I$TRTI -I$CUDA/include -c fwd_trt_zb.cpp -o fwd_trt_zb_b_pie.o 2>/dev/null
$F/torch-mlir/build/bin/flang -O3 zb_host_expert.f90 fwd_trt_zb_b_pie.o -o zb_expert_trt_$GPU $TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64
g++ -O2 -I$TRTI -I$CUDA/include -c fwd_trt_zb.cpp -o fwd_trt_zb.o 2>/dev/null
gfortran -O2 zb_host_short.f90 fwd_trt_zb.o -o zb_trt_$GPU $TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64
run zb_expert_trt_$GPU "-u LD_LIBRARY_PATH"
run zb_trt_$GPU "-u LD_LIBRARY_PATH" 2
echo "== FORTIS ladder, lowered for $ARCH"
unset LD_LIBRARY_PATH
FORTIS_NO_GATHER=1 $F/torch-mlir/fortisc_$GPU.sh export_zb.py zb_host.f90 zb_fortis_pack_$GPU 2>&1 | grep "fortisc:.*->"
FORTIS_NO_SCATTER=1 $F/torch-mlir/fortisc_$GPU.sh export_zb.py zb_host.f90 zb_fortis_g_$GPU 2>&1 | grep "fortisc:.*->"
$F/torch-mlir/fortisc_$GPU.sh export_zb.py zb_host.f90 zb_fortis_k_$GPU 2>&1 | grep "fortisc:.*->"
$F/torch-mlir/fortisc_$GPU.sh export_zb.py zb_host_expert.f90 zb_expert_fortis_$GPU 2>&1 | grep "fortisc:.*->"
run zb_fortis_pack_$GPU "-u LD_LIBRARY_PATH"
run zb_fortis_g_$GPU "-u LD_LIBRARY_PATH"
run zb_fortis_k_$GPU "-u LD_LIBRARY_PATH"
run zb_expert_fortis_$GPU "-u LD_LIBRARY_PATH"
$F/torch-mlir/build/bin/flang -O3 fwd_null.f90 zb_host.f90 -o zb_null_flang_$GPU && echo "null host:" && ./zb_null_flang_$GPU | head -1
echo "== summary"
grep "^zb,.*$GPU" $OUT | awk -F, '{s[$2]+=$4; n[$2]++; e[$2]=$5} END{for (k in s) printf "%-26s %.3f ms  err %s\n", k, s[k]/n[k], e[k]}' | sort -k2 -n
