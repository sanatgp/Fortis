# Build an FP32 TensorRT plan with full tactic search from an ONNX file at a fixed batch.
# usage: python3 build_trt_plan.py model.onnx out.plan
import sys, tensorrt as trt
onnx, out = sys.argv[1], sys.argv[2]
logger = trt.Logger(trt.Logger.WARNING); builder = trt.Builder(logger)
net = builder.create_network(1 << int(trt.NetworkDefinitionCreationFlag.EXPLICIT_BATCH))
parser = trt.OnnxParser(net, logger)
assert parser.parse(open(onnx, "rb").read()), [parser.get_error(i) for i in range(parser.num_errors)]
cfg = builder.create_builder_config(); cfg.set_memory_pool_limit(trt.MemoryPoolType.WORKSPACE, 1 << 30)
plan = builder.build_serialized_network(net, cfg)
open(out, "wb").write(bytes(plan)); print("built", out, len(bytes(plan)), "bytes, input", net.get_input(0).shape, "output", net.get_output(0).shape)
