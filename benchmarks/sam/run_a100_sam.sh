#!/bin/bash
# SAM ladder on a non-Volta GPU. Run on the GPU node from anywhere: bash run_a100_sam.sh
# Writes rows "sam,<binary>,<run>,<per-step ms>,<dt err>" to $F/results/<gpu>.csv.
set -e
export F=/scratch/taghipouranvari.s/FTORCH
GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1 | awk '{print tolower($2)}')   # a100 / h200
case $GPU in a100) ARCH=sm_80;; h100|h200) ARCH=sm_90;; l40s|l40) ARCH=sm_89;; *) echo "unknown GPU $GPU"; exit 1;; esac
export OUT=$F/results/$GPU.csv; mkdir -p $F/results; touch $OUT
echo "== $GPU -> $ARCH, driver $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)"

# fortisc for this architecture (same toolchain, only the cubin target and the nvcc arch change)
sed "s/sm_70/$ARCH/g" $F/torch-mlir/fortisc.sh > $F/torch-mlir/fortisc_$GPU.sh; chmod +x $F/torch-mlir/fortisc_$GPU.sh

cd $F/sam_run
echo "== native (fp64 reference and the shipped fp32 code, this node's CPU)"
bash run_native.sh > native_$GPU.log 2>&1 || true      # the loopdist printout at its end fails on SAM by design
test -s sam_ref.bin || { echo "run_native.sh did not produce sam_ref.bin"; tail -30 native_$GPU.log; exit 1; }
grep -E "per-step|dt " native_$GPU.log | head -4

echo "== library couplings, TensorRT engine rebuilt on this GPU"
bash run_baselines_sam.sh 2>&1 | tail -4

echo "== FORTIS"
unset LD_LIBRARY_PATH
$F/torch-mlir/fortisc_$GPU.sh export_sam.py sam_host.f90 sam_fortis_$GPU
FORTIS_NO_DIST=1 $F/torch-mlir/fortisc_$GPU.sh export_sam.py sam_host.f90 sam_fortis_col_$GPU
run() { for i in 1 2 3 4 5; do o=$(./$1 2>/dev/null | tr '\n' ' '); echo "sam,$1,$i,$(echo "$o" | grep -oE 'per-step ms: *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$'),$(echo "$o" | grep -oE 'dt *[0-9.E+-]+' | grep -oE '[0-9.E+-]+$')" | tee -a $OUT; done; }
run sam_fortis_$GPU
run sam_fortis_col_$GPU

echo "== summary ($OUT)"
grep "^sam," $OUT | awk -F, '{s[$2]+=$4; n[$2]++; e[$2]=$5} END{for (k in s) printf "%-22s %.3f ms  dt err %s\n", k, s[k]/n[k], e[k]}' | sort -k2 -n
