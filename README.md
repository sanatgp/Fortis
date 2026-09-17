# FORTIS — Fortran–ML co-compiler

Compiles a Fortran host and an ML model (PyTorch export, or TensorFlow SavedModel via ONNX) into one executable
with no framework runtime. Passes: fortis-fuse (fusion, shape-chosen mappings, cuBLAS/cuDNN/FFT rules, residency).

## Build
    module load cmake/3.30.2
    mkdir build && cd build
    CC=gcc CXX=g++ CUDAHOSTCXX=g++ cmake .. \
      -DMLIR_DIR=<llvm-build>/lib/cmake/mlir -DLLVM_DIR=<llvm-build>/lib/cmake/llvm \
      -DCUDAToolkit_ROOT=<cuda 12.x> -DCMAKE_CUDA_COMPILER=<cuda>/bin/nvcc \
      -DMATH_LIBS_DIR=<dir with lib64/libcublas.so, libcufft.so> -DCUDNN_DIR=<cudnn root> \
      -DCMAKE_INSTALL_PREFIX=$PWD/../install
    make -j8 && make install

## Use
    export FORTIS_VENV=~/venvs/tmlir          # torch-mlir venv (PyTorch export only)
    install/bin/fortisc export_mlp.py host.f90 out     # or: fortisc model_linalg.mlir host.f90 out
    frontend/tf2linalg.sh <saved_model> keras_tensor 1,33,33,33,3 tsrgan   # TF models -> linalg

Env switches: FORTIS_GRAPH=1 (CUDA-graph replay of the step), FORTIS_DIRECT=1 (library-free 3D conv),
FORTIS_FORCE_ALGO=n / FORTIS_ALLOW_FFT=1 / FORTIS_REPORT_ALGO=1 (cuDNN algorithm experiments).

## Correctness stamps
toy MLP checksum 7.775037; conv probe 9617.28; ClimSim 260048.81; UNet and TSRGAN vs TensorFlow to ~1e-5.
Run tests/run_micro.sh for the op micro-suite.
