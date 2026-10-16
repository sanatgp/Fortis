#!/bin/bash
# build_mom6.sh percell|fortis|expert_trt  -> $F/mom6/nw2/build_<variant>/MOM6
# shipped is $F/mom6/nw2/build/MOM6 (HEAD, hand-batched ANN on the CPU).
# percell:    the nest as one unit compiled by gfortran, the ANN on the CPU per cell (fwd_native, real(8)).
# fortis:     the same unit compiled by fortisc; its objects are linked into MOM6 built by gfortran.
# expert_trt: HEAD's hand-batched routine with ANN_apply_array_sio replaced by a TensorRT engine (GPU expert).
set -e
V=$1; F=/scratch/taghipouranvari.s/FTORCH; I=$F/mom6/insitu; U=$F/mom6/unit
ROOT=$F/torch-mlir; B=$ROOT/build/bin
CUDNN=$(ls -d $F/Fortran-ML-Interface/venv-fortran-ml/lib64/python3.9/site-packages/nvidia/cudnn)
MATH=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/math_libs/12.5
CUDA=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5
TRT=$F/venv-trt/lib/python3.12/site-packages/tensorrt_libs; TRTI=$F/trt_run/trt-oss/include
H5=/shared/EL9/explorer/HDF5/1.14.6/lib
module load OpenMPI/4.1.6 netcdf/4.9.3-gcc HDF5/1.14.6 2>/dev/null || true
unset FC F77 F90 CC CXX
export OMPI_FC=gfortran OMPI_CC=gcc OMPI_CXX=g++
NETLIBS="-L$F/mom6/nw2/build -lh5stub -Wl,-rpath,$F/mom6/nw2/build $(nf-config --flibs) -L$H5 -lhdf5_hl -lhdf5 -Wl,-rpath,$H5"
SRC=$I/MOM_Zanna_Bolton.F90
if [ "$V" = expert_trt ]; then
  SRC=$I/MOM_Zanna_Bolton_expert_trt.F90
  python3 $I/make_expert_trt.py $F/mom6/src/src/parameterizations/lateral/MOM_Zanna_Bolton.F90 $SRC
fi
BD=$F/mom6/nw2/build_$V; rm -rf $BD; cp -r $F/mom6/nw2/build $BD; cd $BD
sed -i "s|.*/MOM_Zanna_Bolton.F90|$SRC|" path_names
../src/mkmf/bin/mkmf -t ../src/mkmf/templates/nu-gnu.mk -p MOM6 -c "-Duse_libMPI -Duse_netCDF -DSPMD" path_names > /dev/null
rm -f MOM_Zanna_Bolton.o MOM6
mkdir -p $I/obj_$V
case $V in
percell)
  sed 's/RKVAL/8/' $F/zb_run/fwd_native_zb.f90 > $I/fwd_native8.f90
  gfortran -O2 -c $I/fwd_native8.f90 -o $I/obj_$V/fwd_native8.o
  gfortran -O2 -c $U/zb_nest.f90 -o $I/obj_$V/zb_nest.o
  OBJS="$I/obj_$V/zb_nest.o $I/obj_$V/fwd_native8.o"; LIBS="";;
fortis)
  unset LD_LIBRARY_PATH; W=$ROOT/fortisc_work; rm -f $W/*.o
  (cd $U && $ROOT/fortisc.sh export_zb.py zb_nest.f90 unused 2>&1 | grep "fortisc:\|shim:\|rror" || true)
  test -f $W/model.o -a -f $W/shim.o -a -f $W/host.o -a -f $W/gather.o || { echo "fortisc did not produce the objects, see above"; exit 1; }
  cp $W/host.o $W/model.o $W/shim.o $W/weights.o $W/fortis_rt.o $W/fortis_fft.o $W/gather.o $I/obj_$V/
  FRT=""; for l in libflang_rt.runtime.a libFortranRuntime.a libFortranDecimal.a; do test -f $ROOT/build/lib/$l && FRT="$FRT $ROOT/build/lib/$l"; done
  OBJS="$(ls $I/obj_$V/*.o | tr '\n' ' ')"
  LIBS="-L$ROOT/build/lib -lmlir_cuda_runtime -L$CUDA/lib64 -lcudart -L$MATH/lib64 -lcublas $CUDNN/lib/libcudnn.so.8 -lcufft $FRT -lstdc++ -Wl,-rpath,$ROOT/build/lib -Wl,-rpath,$CUDA/lib64 -Wl,-rpath,$MATH/lib64 -Wl,-rpath,$CUDNN/lib";;
fortis_trt)
  unset LD_LIBRARY_PATH; W=$ROOT/fortisc_work; rm -f $W/*.o
  (cd $U && FORTIS_BACKEND=trt FORTIS_TRT_PLAN=build $ROOT/fortisc.sh export_zb.py zb_nest.f90 unused 2>&1 | grep "fortisc:\|shim:\|rror" || true)
  test -f $W/model.o -a -f $W/shim.o -a -f $W/host.o -a -f $W/gather.o -a -f $W/trt_backend.o || { echo "fortisc did not produce the objects, see above"; exit 1; }
  echo "contract batch: $(grep -o 'batch = [0-9]*' $W/m4.mlir | head -1)"
  cp $W/host.o $W/model.o $W/shim.o $W/weights.o $W/fortis_rt.o $W/fortis_fft.o $W/gather.o $W/trt_backend.o $I/obj_$V/
  FRT=""; for l in libflang_rt.runtime.a libFortranRuntime.a libFortranDecimal.a; do test -f $ROOT/build/lib/$l && FRT="$FRT $ROOT/build/lib/$l"; done
  OBJS="$(ls $I/obj_$V/*.o | tr '\n' ' ')"
  LIBS="-L$ROOT/build/lib -lmlir_cuda_runtime -L$CUDA/lib64 -lcudart -L$MATH/lib64 -lcublas $CUDNN/lib/libcudnn.so.8 -lcufft $TRT/libnvinfer.so.10 $FRT -lstdc++ -Wl,-rpath,$ROOT/build/lib -Wl,-rpath,$CUDA/lib64 -Wl,-rpath,$MATH/lib64 -Wl,-rpath,$CUDNN/lib -Wl,-rpath,$TRT";;
expert_trt)
  $CUDA/bin/nvcc -O2 -w -arch=sm_70 -I$TRTI -I$CUDA/include -c $I/zb_trt_apply.cu -o $I/obj_$V/zb_trt_apply.o
  OBJS="$I/obj_$V/zb_trt_apply.o"
  LIBS="$TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64";;
*) echo "usage: build_mom6.sh percell|fortis|fortis_trt|expert_trt"; exit 1;;
esac
echo "compiler: $(mpif90 --version | head -1)"
make -s MOM6 REPRO=1 LIBS="$OBJS $LIBS $NETLIBS" 2>&1 | grep -iE "error|undefined" | head -10 || true
test -x MOM6 && echo "built $BD/MOM6" || { echo "no MOM6 in $BD"; exit 1; }
