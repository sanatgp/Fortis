#!/bin/bash
# fortisc for a C host through ClangIR. Usage: fortisc_c.sh export.py host_loop.c host_main.c out
# The model side is fortisc.sh's, unchanged; only the host analysis and the host rewrite differ.
set -e
EXPORT=$1; HOST=$2; MAIN=$3; OUT=$4
ROOT=/scratch/taghipouranvari.s/FTORCH/torch-mlir
CUDNN=$(ls -d /scratch/taghipouranvari.s/FTORCH/Fortran-ML-Interface/venv-fortran-ml/lib64/python3.9/site-packages/nvidia/cudnn)
MATH=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/math_libs/12.5
CUDA=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5
B=$ROOT/build/bin; C=$ROOT/build-cir/bin
W=$ROOT/fortisc_work_c; mkdir -p $W
J() { python3 -c "import json;d=json.load(open('$1'));print($2)"; }

# --- host analysis at ClangIR
$C/clang -fclangir -emit-cir -O0 -S $HOST -o $W/host.cir 2>/dev/null
python3 $ROOT/fortis_cir.py analyze $W/host.cir mlp_forward $W > $W/analysis.json
LV=$(J $W/loop.json "d['verdict']")
if [ -n "$FORTIS_NO_DIST" ]; then LV=disabled; fi
echo "fortisc_c: loop verdict $LV ($(J $W/loop.json "d['reason'][:110]"))"
if [ "$LV" = "batched" ]; then export FORTIS_BATCH=$(J $W/loop.json "d['batch']"); else export FORTIS_BATCH=1; fi
echo "fortisc_c: call site batch=$FORTIS_BATCH in_loop=True"
DIS=-; if [ "$LV" != "batched" ]; then DIS=disabled; fi

# --- model side, as in fortisc.sh
source ~/venvs/tmlir/bin/activate && python $EXPORT > $W/model_linalg.mlir && deactivate
python3 $ROOT/fortis_hostattr.py $W/model_linalg.mlir $W/hostinfo.json $W/loop.json $DIS > $W/model_annot.mlir
python3 $ROOT/fortis_outline.py $W/model_annot.mlir $W
$B/mlir-opt $W/model_args.mlir -linalg-generalize-named-ops -o $W/m1.mlir
$ROOT/fortis-pass/build/fortis-opt $W/m1.mlir -fortis-fold-transpose -o $W/m2a.mlir
$B/mlir-opt $W/m2a.mlir -canonicalize -cse -o $W/m2.mlir
$B/mlir-opt $W/m2.mlir -one-shot-bufferize="bufferize-function-boundaries function-boundary-type-conversion=identity-layout-map" -buffer-results-to-out-params -o $W/m3.mlir
$ROOT/fortis-pass/build/fortis-opt $W/m3.mlir -fortis-fuse -fortis-host-decide -o $W/m4.mlir
$B/mlir-opt $W/m4.mlir -gpu-lower-to-nvvm-pipeline="cubin-chip=sm_70 cubin-format=fatbin" -o $W/m5.mlir
sed -i 's/@malloc/@fortis_alloc/g; s/@free/@fortis_free/g' $W/m5.mlir
$B/mlir-translate $W/m5.mlir --mlir-to-llvmir -o $W/model.ll && $B/clang -O2 -c $W/model.ll -o $W/model.o
$B/mlir-translate $W/weights.mlir --mlir-to-llvmir -o $W/weights.ll && $B/clang -O2 -c $W/weights.ll -o $W/weights.o
python3 $ROOT/fortis_shim.py $W/m4.mlir $W/outline.json $W
$B/clang -O2 -I$CUDA/include -c $W/shim.c -o $W/shim.o
$B/clang -O2 -I$CUDA/include -I$MATH/include -I$CUDNN/include -c $ROOT/fortis_rt.c -o $W/fortis_rt.o
$CUDA/bin/nvcc -O2 -arch=sm_70 -Xcompiler -fPIC -I$CUDA/include -I$MATH/include -c $ROOT/fortis_fft.cu -o $W/fortis_fft.o

# --- host rewrite at ClangIR: fission around the call, then ClangIR's own lowering to an object
if [ "$LV" = "batched" ]; then
  python3 $ROOT/fortis_cir.py fission $W/host.cir $W/loop.json mlp_forward > $W/host_fissioned.cir
  $C/cir-translate --cir-to-llvmir $W/host_fissioned.cir -o $W/host.ll
  $B/clang -O2 -c $W/host.ll -o $W/host.o
else
  $B/clang -O2 -c $HOST -o $W/host.o
fi
$B/clang -O2 -c $MAIN -o $W/main.o
$B/clang -O2 $W/main.o $W/host.o $W/model.o $W/shim.o $W/weights.o $W/fortis_rt.o $W/fortis_fft.o \
  -L$ROOT/build/lib -lmlir_cuda_runtime -L$CUDA/lib64 -lcudart -L$MATH/lib64 -lcublas $CUDNN/lib/libcudnn.so.8 -lcufft -lm \
  -Wl,-rpath,$ROOT/build/lib -Wl,-rpath,$CUDA/lib64 -Wl,-rpath,$MATH/lib64 -Wl,-rpath,$CUDNN/lib -o $OUT
echo "fortisc_c: kernels=$(grep -c gpu.launch_func $W/m4.mlir) library calls=$(grep -c 'call @fortis_' $W/m4.mlir || true) -> $OUT"
