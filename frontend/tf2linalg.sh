#!/bin/bash
# usage: tf2linalg.sh <saved_model_dir> <input_name> <N,...,C> <out_prefix>
# Step 1 needs a TensorFlow venv with tf2onnx; steps 2+ need the torch-mlir venv and torch-mlir-opt on PATH.
set -e
SM=$1; IN=$2; SHAPE=$3; OUT=$4
python - "$SM" "$IN" "$SHAPE" "$OUT" << 'PY'
import sys, tensorflow as tf, tf2onnx
sm, name, shape, out = sys.argv[1], sys.argv[2], tuple(int(x) for x in sys.argv[3].split(",")), sys.argv[4]
f = tf.saved_model.load(sm).signatures["serving_default"]
spec = (tf.TensorSpec(shape, tf.float32, name=name),)
@tf.function(input_signature=list(spec))
def fixed(x): return f(**{name: x})
tf2onnx.convert.from_function(fixed, input_signature=spec, opset=17, output_path=out + ".onnx")
PY
python -m torch_mlir.tools.import_onnx $OUT.onnx -o ${OUT}_onnx.mlir
sed -i 's/tf_half_pixel_for_nn/asymmetric/g' ${OUT}_onnx.mlir
torch-mlir-opt ${OUT}_onnx.mlir --torch-onnx-to-torch-backend-pipeline -o ${OUT}_torch.mlir
torch-mlir-opt ${OUT}_torch.mlir --torch-backend-to-linalg-on-tensors-backend-pipeline -o ${OUT}_linalg.mlir
sed -i 's/@"Extracted from {tf2onnx}"/@main/' ${OUT}_linalg.mlir
echo "-> ${OUT}_linalg.mlir"
