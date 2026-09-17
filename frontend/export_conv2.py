import sys, torch
from torch_mlir import fx
torch.manual_seed(3)
m = torch.nn.Sequential(torch.nn.Conv3d(3, 8, 3, padding=1), torch.nn.LeakyReLU(0.1), torch.nn.Conv3d(8, 4, 3, padding=1), torch.nn.LeakyReLU(0.1)).eval()
n = 3 * 16 * 16 * 16
x = torch.arange(1, n + 1, dtype=torch.float32) / n; x = (x - x.mean()) / x.std(unbiased=False)
with torch.no_grad(): y = m(x.view(1, 3, 16, 16, 16))
print("torch ref: checksum", float(y.sum()), "y[:4]", y.flatten()[:4].tolist(), file=sys.stderr)
print(fx.export_and_import(m, x.view(1, 3, 16, 16, 16), output_type="linalg-on-tensors"))
