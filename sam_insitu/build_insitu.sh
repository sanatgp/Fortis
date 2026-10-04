#!/bin/bash
# Build SAM with the NN unit coupled one of four ways. Run on the V100 node from $F/sam_nn:
#   bash insitu/build_insitu.sh shipped|trt|ftorch|fortis     -> ./SAM_<variant>
# shipped: the authors' inline matmul on the CPU, through the same wrapper (validates the unit split)
# trt:     TensorRT per column, batch-2 padded engine (the batch-1 engine miscompiles), rebuilt for this GPU
# ftorch:  FTorch per column, model on the GPU
# fortis:  nn_core.f90 compiled by fortisc (fission + batched model), objects linked into the gfortran SAM
set -e
V=$1; F=/scratch/taghipouranvari.s/FTORCH; S=$F/sam_nn; I=$S/insitu; R=$F/sam_run; cd $S
CUDA=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5
MATH=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/math_libs/12.5
CUDNN=$(ls -d $F/Fortran-ML-Interface/venv-fortran-ml/lib64/python3.9/site-packages/nvidia/cudnn)
TRT=$F/venv-trt/lib/python3.12/site-packages/tensorrt_libs; TRTI=$F/trt_run/trt-oss/include
FT=$F/ftorch-install; ROOT=$F/torch-mlir; B=$ROOT/build/bin
GF="gfortran -O2 -ffree-line-length-none"

# the wrapper replaces the shipped module (original kept); Makefile gets EXTRA_OBJS/EXTRA_LIBS on the link line
test -f $I/nn_convection_flux.orig.f90 || cp sam_code_NN/nn_convection_flux.f90 $I/nn_convection_flux.orig.f90
cmp -s $I/nn_convection_flux.f90 sam_code_NN/nn_convection_flux.f90 || cp $I/nn_convection_flux.f90 sam_code_NN/
grep -q EXTRA_OBJS Makefile.sam || sed -i 's/-Wl,--allow-shlib-undefined/-Wl,--allow-shlib-undefined $(EXTRA_OBJS) $(EXTRA_LIBS)/' Makefile.sam
for f in sam_nn.bin sam_nn.pt; do ln -sf $R/$f $S/$f; done      # the couplings open the model by relative name

case $V in
shipped)
  sed 's/RKVAL/4/' $R/fwd_native.f90 > $I/fwd_native4.f90
  $GF -J $I -c $I/fwd_native4.f90 -o $I/fwd_native4.o
  $GF -c $I/nn_core.f90 -o $I/nn_core_gf.o
  OBJS="$I/nn_core_gf.o $I/fwd_native4.o"; LIBS="";;
trt)
  (source ~/venvs/tmlir/bin/activate && cd $R && python export_sam.py > /dev/null && deactivate)
  (source $F/venv-trt/bin/activate && cd $R && python build_sam_b2.py && deactivate)   # plan files are per GPU
  ln -sf $R/sam_b2.plan $S/sam_b2.plan
  g++ -O2 -I$TRTI -I$CUDA/include -c $R/fwd_trt_sam_pad.cpp -o $I/fwd_trt_sam_pad.o
  $GF -c $I/nn_core.f90 -o $I/nn_core_gf.o
  OBJS="$I/nn_core_gf.o $I/fwd_trt_sam_pad.o"
  LIBS="$TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64";;
ftorch)
  $GF -J $I -I$FT/include/ftorch -c $R/fwd_ftorch_sam.f90 -o $I/fwd_ftorch_sam.o
  $GF -c $I/nn_core.f90 -o $I/nn_core_gf.o
  OBJS="$I/nn_core_gf.o $I/fwd_ftorch_sam.o"; LIBS="-L$FT/lib64 -lftorch -Wl,-rpath,$FT/lib64";;
fortis)
  # fortisc on the unit alone: its final link has no main and fails; the objects it made before that are what we link
  unset LD_LIBRARY_PATH; W=$ROOT/fortisc_work; rm -f $W/*.o
  (cd $R && $ROOT/fortisc.sh "export_sam.py linalg" $I/nn_core.f90 $I/unused 2>&1 | grep "fortisc:\|shim:\|rror" || true)
  test -f $W/model.o -a -f $W/shim.o || { echo "fortisc did not get to the model objects, see above"; exit 1; }
  test -f $W/host.o || { echo "no fissioned host from fortisc: compiling the unit as written"; $B/flang -O3 -c $I/nn_core.f90 -o $W/host.o; }
  mkdir -p $I/fortis_obj; cp $W/host.o $W/model.o $W/shim.o $W/weights.o $W/fortis_rt.o $W/fortis_fft.o $I/fortis_obj/
  FRT=""; for l in libflang_rt.runtime.a libFortranRuntime.a libFortranDecimal.a; do test -f $ROOT/build/lib/$l && FRT="$FRT $ROOT/build/lib/$l"; done
  OBJS="$(ls $I/fortis_obj/*.o | tr '\n' ' ')"
  LIBS="-L$ROOT/build/lib -lmlir_cuda_runtime -L$CUDA/lib64 -lcudart -L$MATH/lib64 -lcublas $CUDNN/lib/libcudnn.so.8 -lcufft $FRT -lstdc++ -Wl,-rpath,$ROOT/build/lib -Wl,-rpath,$CUDA/lib64 -Wl,-rpath,$MATH/lib64 -Wl,-rpath,$CUDNN/lib";;
*) echo "usage: build_insitu.sh shipped|trt|ftorch|fortis"; exit 1;;
esac

find . -maxdepth 3 -type f -name SAM -delete            # force the relink with this variant's objects
export EXTRA_OBJS="$OBJS" EXTRA_LIBS="$LIBS"
bash Build.sh > $I/build_$V.log 2>&1 || { echo "build failed"; grep -iE "error|undefined" $I/build_$V.log | head -20; exit 1; }
test -x SAM || { echo "no ./SAM after build"; tail -5 $I/build_$V.log; exit 1; }
cp SAM SAM_$V; echo "built ./SAM_$V"
