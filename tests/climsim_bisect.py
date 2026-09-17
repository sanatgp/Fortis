import os, sys, numpy as np, torch
from torch_mlir import fx
W = np.load("climsim_mlp.npz")
def lin(k, b):
    l = torch.nn.Linear(k.shape[0], k.shape[1]); l.weight.data = torch.tensor(k.T.copy()); l.bias.data = torch.tensor(b.copy()); return l
names = ["dense_k"] if "dense_k" in W else []
keys = [k for k in W.files if k.endswith("_k") and not k.startswith("dense_6") and not k.startswith("dense_7")]
# preserve body order: first layer key is whatever export_climsim.py calls K1
pairs = [("dense_k", "dense_b")] if "dense_k" in W.files else []
pairs += [(f"dense_{i}_k", f"dense_{i}_b") for i in range(1, 6)]
K = int(os.environ.get("FORTIS_LAYERS", "1"))
layers = []
for i, (kk, bb) in enumerate(pairs[:K]):
    layers += [lin(W[kk], W[bb]), torch.nn.LeakyReLU(0.15)]
m = torch.nn.Sequential(*layers).eval()
nin = pairs[0] and W[pairs[0][0]].shape[0]
x = torch.arange(1, nin + 1, dtype=torch.float32) / nin; x = (x - x.mean()) / x.std(unbiased=False)
with torch.no_grad(): y = m(x.view(1, nin))
print(f"REF layers={K} nin={nin} nout={y.numel()} checksum {float(y.sum()):.6f} y[:3] {y.flatten()[:3].tolist()}", file=sys.stderr)
print(fx.export_and_import(m, x.view(1, nin), output_type="linalg-on-tensors"))
