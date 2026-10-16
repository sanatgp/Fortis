# Build an FP32 TensorRT plan of the ZB-ANN at a given batch straight from zb_nn.npz
# (y = (A1 relu(A0 (x / in_norms) + b0) + b1) * out_norms), on the current GPU.
import sys, numpy as np, tensorrt as trt
B = int(sys.argv[1]); W = np.load("zb_nn.npz"); keep = []
logger = trt.Logger(trt.Logger.WARNING); builder = trt.Builder(logger)
net = builder.create_network(1 << int(trt.NetworkDefinitionCreationFlag.EXPLICIT_BATCH))
x = net.add_input("x", trt.float32, (B, 27))
def const(a):
    a = np.ascontiguousarray(a, dtype=np.float32); keep.append(a)
    return net.add_constant(a.shape, trt.Weights(a)).get_output(0)
E, M = trt.ElementWiseOperation, trt.MatrixOperation.NONE
h = net.add_elementwise(x, const(W["in_norms"].reshape(1, 27)), E.DIV).get_output(0)
h = net.add_matrix_multiply(h, M, const(W["A0"].T), M).get_output(0)
h = net.add_elementwise(h, const(W["b0"].reshape(1, 20)), E.SUM).get_output(0)
h = net.add_activation(h, trt.ActivationType.RELU).get_output(0)
h = net.add_matrix_multiply(h, M, const(W["A1"].T), M).get_output(0)
h = net.add_elementwise(h, const(W["b1"].reshape(1, 3)), E.SUM).get_output(0)
y = net.add_elementwise(h, const(W["out_norms"].reshape(1, 3)), E.PROD).get_output(0)
y.name = "y"; net.mark_output(y)
cfg = builder.create_builder_config()
cfg.clear_flag(trt.BuilderFlag.TF32); cfg.set_memory_pool_limit(trt.MemoryPoolType.WORKSPACE, 1 << 30)
plan = bytes(builder.build_serialized_network(net, cfg))
open(f"zb_b{B}.plan", "wb").write(plan); print("built zb_b%d.plan" % B, len(plan), "bytes")
