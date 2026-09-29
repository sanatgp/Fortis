import os, shutil, tensorrt as trt
for B in (1, 384):
    if not os.path.exists(f"climsim_b{B}.plan.v100"): shutil.copy(f"climsim_b{B}.plan", f"climsim_b{B}.plan.v100")
    logger = trt.Logger(trt.Logger.WARNING); builder = trt.Builder(logger)
    net = builder.create_network(1 << int(trt.NetworkDefinitionCreationFlag.EXPLICIT_BATCH))
    parser = trt.OnnxParser(net, logger)
    assert parser.parse(open(f"climsim_b{B}.onnx", "rb").read()), [parser.get_error(i) for i in range(parser.num_errors)]
    cfg = builder.create_builder_config(); cfg.set_memory_pool_limit(trt.MemoryPoolType.WORKSPACE, 1 << 30)
    plan = builder.build_serialized_network(net, cfg)
    open(f"climsim_b{B}.plan", "wb").write(plan); print("built climsim_b%d.plan" % B, plan.nbytes, "bytes")
