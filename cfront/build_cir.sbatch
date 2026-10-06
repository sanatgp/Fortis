#!/bin/bash
#SBATCH -J clang-cir
#SBATCH --partition=ce-mri
#SBATCH -t 04:00:00
#SBATCH -c 48
#SBATCH --mem=120G
#SBATCH -o /scratch/taghipouranvari.s/FTORCH/cfront/build_cir.log
module load cmake
export PATH=/home/taghipouranvari.s/.local/bin:$PATH
F=/scratch/taghipouranvari.s/FTORCH; B=$F/torch-mlir/build/bin; S=$F/torch-mlir/externals/llvm-project
cmake -G Ninja -S $S/llvm -B $F/torch-mlir/build-cir \
  -DLLVM_ENABLE_PROJECTS="clang;mlir" -DCLANG_ENABLE_CIR=ON \
  -DLLVM_TARGETS_TO_BUILD="host" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DCMAKE_C_COMPILER=$B/clang -DCMAKE_CXX_COMPILER=$B/clang++ \
  -DLLVM_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_TESTS=OFF -DMLIR_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF
ninja -C $F/torch-mlir/build-cir -j 48 clang cir-opt cir-translate mlir-opt mlir-translate
echo BUILD_DONE
