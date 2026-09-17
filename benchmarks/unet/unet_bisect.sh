#!/bin/bash
# usage: unet_bisect.sh NODE_INDEX   -> builds the ONNX sub-model ending at that node, compares FORTIS vs ONNX Runtime
set -e
IDX=$1; W=/scratch/taghipouranvari.s/FTORCH/torch-mlir; B=$W/build/bin
source ../Fortran-ML-Interface/venv-fortran-ml/bin/activate
python - "$IDX" << 'PY'
import sys, onnx, numpy as np, onnxruntime as ort
idx = int(sys.argv[1]); m = onnx.load("unet2d.onnx")
out = m.graph.node[idx].output[0]
onnx.utils.extract_model("unet2d.onnx", "sub.onnx", ["input_1"], [out])
x = np.fromfile("unet_in.bin", dtype=np.float32).reshape(1, 2044, 2044, 1)
y = ort.InferenceSession("sub.onnx", providers=["CPUExecutionProvider"]).run(None, {"input_1": x})[0]
y.astype(np.float32).reshape(-1).tofile("sub_ref.bin")
print("ORT: shape", y.shape, "checksum", float(y.sum()), "y[:3]", y.reshape(-1)[:3])
open("sub_nout.txt", "w").write(str(y.size))
PY
deactivate
source ~/venvs/tmlir/bin/activate
python -m torch_mlir.tools.import_onnx sub.onnx -o sub_onnx.mlir 2>&1 | grep -v Deprecation | grep -v "import onnx" || true
deactivate
sed -i 's/tf_half_pixel_for_nn/asymmetric/g' sub_onnx.mlir
$B/torch-mlir-opt sub_onnx.mlir --torch-onnx-to-torch-backend-pipeline -o sub_torch.mlir
$B/torch-mlir-opt sub_torch.mlir --torch-backend-to-linalg-on-tensors-backend-pipeline -o sub_linalg.mlir
sed -i "s/@\"Extracted from {tf2onnx}\"/@main/" sub_linalg.mlir
NOUT=$(cat sub_nout.txt)
sed "s/n = 2044\*2044, nsteps = 1/n = 2044*2044, nsteps = 1/; s/real, allocatable :: x(:), y(:)/real, allocatable :: x(:), y(:)\n  integer, parameter :: nout = $NOUT/; s/allocate(x(n), y(n))/allocate(x(n), y(nout))/" unet_host.f90 > sub_host.f90
sed -i "s/open(newunit=u, file=\"unet_in.bin\".*//; s/unet_out.bin/sub_out.bin/" sub_host.f90
$W/fortisc.sh sub_linalg.mlir sub_host.f90 sub_fortis 2>&1 | grep -E "error|kernels"
./sub_fortis | tail -1
python3 -c "
import numpy as np
o=np.fromfile('sub_out.bin',dtype=np.float32); y=np.fromfile('sub_ref.bin',dtype=np.float32)
print('FORTIS checksum',float(o.sum()),'o[:3]',o[:3]); print('max abs err',float(np.abs(o-y).max()),' rel',float(np.abs(o-y).max()/(np.abs(y).max()+1e-30)))"
