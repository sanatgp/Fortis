#!/bin/bash
# fortisc: Fortran + PyTorch model -> one executable. Usage: fortisc.sh export.py host.f90 out
set -e
EXPORT=$1; HOST=$2; OUT=$3
ROOT=/scratch/taghipouranvari.s/FTORCH/torch-mlir
CUDNN=$(ls -d /scratch/taghipouranvari.s/FTORCH/Fortran-ML-Interface/venv-fortran-ml/lib64/python3.9/site-packages/nvidia/cudnn)
MATH=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/math_libs/12.5
CUDA=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5
B=$ROOT/build/bin
W=$ROOT/fortisc_work; mkdir -p $W
J() { python3 -c "import json;d=json.load(open('$1'));print($2)"; }

# --- host analysis: call-site shapes and loop context (FIR), loop distribution (HLFIR)
$B/flang -fc1 -emit-fir $HOST -o $W/host.fir
$B/flang -fc1 -emit-hlfir $HOST -o $W/host.hlfir
python3 $ROOT/fortis_hostinfo.py $W/host.fir mlp_forward > $W/hostinfo.json
PYTHONPATH=$ROOT python3 $ROOT/fortis_loopdist.py $W/host.hlfir mlp_forward > $W/loop.json
LV=$(J $W/loop.json "d['verdict']"); DIS=-
if [ -n "$FORTIS_NO_DIST" ]; then LV=disabled; DIS=disabled; fi
echo "fortisc: loop verdict $LV ($(J $W/loop.json "d['reason'][:100]"))"
if [ "$LV" = "batched" ]; then export FORTIS_BATCH=$(J $W/loop.json "d['batch']"); else export FORTIS_BATCH=$(J $W/hostinfo.json "d['batch']"); fi
echo "fortisc: call site batch=$FORTIS_BATCH in_loop=$(J $W/hostinfo.json "d['in_loop']")"

# --- whole-array call: the boundary analysis (2-D lifts, layout casts) decides whether the model can take the host's own arrays
BND=no; BNDJ=""
if [ "$LV" != "batched" ] && [ -z "$FORTIS_NO_DIST" ] && [ -z "$FORTIS_NO_BOUNDARY" ]; then
  python3 $ROOT/fortis_lift2d.py $W/host.hlfir mlp_forward > $W/lift2d.json
  if [ "$(J $W/lift2d.json "d['ok']")" = "True" ]; then BND=yes; BNDJ=$W/lift2d.json; fi
  echo "fortisc: boundary $BND ($(J $W/lift2d.json "d.get('reject') or ('drop %d host statements, pre=%s post=%s' % (len(d['drop']), (d['pre'] or {}).get('globals'), (d['post'] or {}).get('globals')))"))"
fi

# --- model export at the host's batch; lifted host expressions are merged around it
if [[ "$EXPORT" == *.mlir ]]; then cp $EXPORT $W/model_linalg.mlir; else source ~/venvs/tmlir/bin/activate && python $EXPORT > $W/model_linalg.mlir && deactivate; fi
if [ "$LV" = "batched" ] && [ "$(J $W/loop.json "d['lift'] is not None")" = "True" ]; then
  python3 -c "import json;json.dump(json.load(open('$W/loop.json'))['lift'], open('$W/lift.json','w'))"
  python3 $ROOT/fortis_hostlift.py --prologue $W/lift.json $W/model_linalg.mlir > $W/model_lifted.mlir
  $B/mlir-opt $W/model_lifted.mlir -inline -symbol-dce -o $W/model_linalg.mlir
elif [ "$BND" = yes ]; then
  python3 $ROOT/fortis_emit2d.py $W/lift2d.json $W/model_linalg.mlir > $W/model_lifted.mlir
  $B/mlir-opt $W/model_lifted.mlir -inline -symbol-dce -o $W/model_linalg.mlir
fi

# --- the contract: host facts become one attribute on the entry function
python3 $ROOT/fortis_hostattr.py $W/model_linalg.mlir $W/hostinfo.json $W/loop.json $DIS $BNDJ > $W/model_annot.mlir
python3 $ROOT/fortis_outline.py $W/model_annot.mlir $W

$B/mlir-opt $W/model_args.mlir -linalg-generalize-named-ops -o $W/m1.mlir
$ROOT/fortis-pass/build/fortis-opt $W/m1.mlir -fortis-fold-transpose -o $W/m2a.mlir
$B/mlir-opt $W/m2a.mlir -canonicalize -cse -o $W/m2.mlir
$B/mlir-opt $W/m2.mlir -one-shot-bufferize="bufferize-function-boundaries function-boundary-type-conversion=identity-layout-map" -buffer-results-to-out-params -o $W/m3.mlir
$ROOT/fortis-pass/build/fortis-opt $W/m3.mlir -fortis-fuse -fortis-host-decide -o $W/m4.mlir
$B/mlir-opt $W/m4.mlir -gpu-lower-to-nvvm-pipeline="cubin-chip=sm_70 cubin-format=fatbin" -o $W/m5.mlir
sed -i 's/@malloc/@fortis_alloc/g; s/@free/@fortis_free/g' $W/m5.mlir
$B/mlir-translate $W/m5.mlir --mlir-to-llvmir -o $W/model.ll
$B/clang -O2 -c $W/model.ll -o $W/model.o

$B/mlir-translate $W/weights.mlir --mlir-to-llvmir -o $W/weights.ll
$B/clang -O2 -c $W/weights.ll -o $W/weights.o

# --- shim and host object from the attributes on the fused module
python3 $ROOT/fortis_shim.py $W/m4.mlir $W/outline.json $W
$B/clang -O2 -I$CUDA/include -c $W/shim.c -o $W/shim.o
$B/clang -O2 -I$CUDA/include -I$MATH/include -I$CUDNN/include -c $ROOT/fortis_rt.c -o $W/fortis_rt.o && $CUDA/bin/nvcc -O2 -arch=sm_70 -Xcompiler -fPIC -I$CUDA/include -I$MATH/include -c $ROOT/fortis_fft.cu -o $W/fortis_fft.o
if [ "$LV" = "batched" ]; then
  # loop fission at FIR: pre-loop, one batched call, post-loop; Lift statements move into the model
  python3 $ROOT/fortis_fission.py $W/host.fir $W/loop.json mlp_forward > $W/host_fissioned.fir
  $B/flang -fc1 -emit-llvm -O3 $W/host_fissioned.fir -o $W/host.ll
  for sym in $(J $W/loop.json "' '.join([g['sym'] for g in (d['lift'] or {}).get('globals', [])])"); do
    sed -i "s/^@$sym = internal global/@$sym = global/" $W/host.ll; done
  $B/clang -O2 -c $W/host.ll -o $W/host.o; HOSTOBJ=$W/host.o
elif [ "$BND" = yes ]; then
  # boundary at HLFIR: lifted nests and layout casts removed, the call takes the host's own arrays
  python3 $ROOT/fortis_boundary.py $W/host.hlfir $W/lift2d.json > $W/host_boundary.fir
  $B/flang -fc1 -emit-llvm -O3 $W/host_boundary.fir -o $W/host.ll
  for sym in $(J $W/lift2d.json "' '.join((d['pre'] or {}).get('globals', []) + (d['post'] or {}).get('globals', []))"); do
    sed -i "s/^@$sym = internal global/@$sym = global/" $W/host.ll; done
  $B/clang -O2 -c $W/host.ll -o $W/host.o; HOSTOBJ=$W/host.o
else HOSTOBJ=$HOST; fi
$B/flang -O3 $HOSTOBJ $W/model.o $W/shim.o $W/weights.o $W/fortis_rt.o \
  -L$ROOT/build/lib -lmlir_cuda_runtime -L$CUDA/lib64 -lcudart -L$MATH/lib64 -lcublas -Wl,-rpath,$MATH/lib64 $CUDNN/lib/libcudnn.so.8 -Wl,-rpath,$CUDNN/lib -lcufft $W/fortis_fft.o \
  -Wl,-rpath,$ROOT/build/lib -Wl,-rpath,$CUDA/lib64 -o $OUT
echo "fortisc: kernels=$(grep -c gpu.launch_func $W/m4.mlir) library calls=$(grep -c 'call @fortis_' $W/m4.mlir || true) -> $OUT"
