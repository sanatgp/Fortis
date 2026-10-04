# ClimSim-shaped MLP with the hidden width widened: 124 -> W x5 -> 128, LeakyReLU(0.15), relu on the last 8 outputs.
# Random weights (seeded), same structure as export_climsim.py, for the model-size sweep.
# Modes: linalg (torch-mlir, tmlir venv), onnx (torch, tmlir venv), trt (tensorrt only, venv-trt).
import sys, os
Wd = int(sys.argv[1]); mode = sys.argv[2] if len(sys.argv) > 2 else "linalg"
if mode == "trt":
    import tensorrt as trt
    for Bt in (1, 384):
        logger = trt.Logger(trt.Logger.WARNING); builder = trt.Builder(logger)
        net = builder.create_network(1 << int(trt.NetworkDefinitionCreationFlag.EXPLICIT_BATCH)); parser = trt.OnnxParser(net, logger)
        assert parser.parse(open(f"climsim_w{Wd}_b{Bt}.onnx", "rb").read()), [parser.get_error(i) for i in range(parser.num_errors)]
        cfg = builder.create_builder_config(); cfg.set_memory_pool_limit(trt.MemoryPoolType.WORKSPACE, 1 << 30)
        plan = builder.build_serialized_network(net, cfg); open(f"climsim_w{Wd}_b{Bt}.plan", "wb").write(plan); print("built", f"climsim_w{Wd}_b{Bt}.plan", plan.nbytes)
    sys.exit(0)
import torch
torch.manual_seed(0)
def lin(i, o):
    l = torch.nn.Linear(i, o); torch.nn.init.normal_(l.weight, std=(2.0 / i) ** 0.5); torch.nn.init.zeros_(l.bias); return l
class Wide(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.body = torch.nn.Sequential(lin(124, Wd), torch.nn.LeakyReLU(0.15), lin(Wd, Wd), torch.nn.LeakyReLU(0.15), lin(Wd, Wd), torch.nn.LeakyReLU(0.15),
                                        lin(Wd, Wd), torch.nn.LeakyReLU(0.15), lin(Wd, Wd), torch.nn.LeakyReLU(0.15), lin(Wd, Wd), torch.nn.LeakyReLU(0.15), lin(Wd, 128))
        m = torch.zeros(128); m[120:] = 1.0; self.register_buffer("mask", m)
    def forward(self, x):
        y = self.body(x); return y + self.mask * (torch.relu(y) - y)
m = Wide().eval()
if mode == "linalg":
    from torch_mlir import fx
    B = int(os.environ.get("FORTIS_BATCH", "1"))
    print(fx.export_and_import(m, torch.zeros(B, 124), output_type="linalg-on-tensors"))
else:
    print("params", sum(p.numel() for p in m.parameters()))
    for Bt in (1, 384):
        torch.onnx.export(m, torch.zeros(Bt, 124), f"climsim_w{Wd}_b{Bt}.onnx", input_names=["x"], output_names=["y"], opset_version=17, dynamo=False)
