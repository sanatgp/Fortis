import sys, tensorrt as trt
onnx, plan = sys.argv[1], sys.argv[2]
L = trt.Logger(trt.Logger.INFO); b = trt.Builder(L)
net = b.create_network(0)
p = trt.OnnxParser(net, L)
assert p.parse(open(onnx, "rb").read()), [p.get_error(i) for i in range(p.num_errors)]
cfg = b.create_builder_config(); cfg.set_memory_pool_limit(trt.MemoryPoolType.WORKSPACE, 8 << 30)
eng = b.build_serialized_network(net, cfg); assert eng is not None, "build failed"
open(plan, "wb").write(eng)
print(plan, "input", net.get_input(0).name, net.get_input(0).shape, "output", net.get_output(0).name, net.get_output(0).shape)
