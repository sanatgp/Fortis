import sys, torch
from torch_mlir import fx
torch.manual_seed(5)
name = sys.argv[1]
C, H = 4, 16
models = {
  "maxpool":   torch.nn.Sequential(torch.nn.Conv2d(1, C, 3, padding=1), torch.nn.MaxPool2d(2)),
  "upsample":  torch.nn.Sequential(torch.nn.Conv2d(1, C, 3, padding=1), torch.nn.Upsample(scale_factor=2, mode="nearest")),
  "convT":     torch.nn.Sequential(torch.nn.Conv2d(1, C, 3, padding=1), torch.nn.ConvTranspose2d(C, C, 3, stride=2, padding=1, output_padding=1)),
  "bn":        torch.nn.Sequential(torch.nn.Conv2d(1, C, 3, padding=1), torch.nn.BatchNorm2d(C)),
  "convT_s1":  torch.nn.Sequential(torch.nn.Conv2d(1, C, 3, padding=1), torch.nn.ConvTranspose2d(C, C, 3, padding=1)),
  "convT_only": torch.nn.Sequential(torch.nn.ConvTranspose2d(1, C, 3, padding=1)),
  "two_convs":  torch.nn.Sequential(torch.nn.Conv2d(1, C, 3, padding=1), torch.nn.Conv2d(C, C, 3, padding=1)),
}
class Cat(torch.nn.Module):
    def __init__(self):
        super().__init__(); self.a = torch.nn.Conv2d(1, C, 3, padding=1); self.b = torch.nn.Conv2d(1, C, 3, padding=1); self.c = torch.nn.Conv2d(2*C, C, 1)
    def forward(self, x): return self.c(torch.cat([self.a(x), self.b(x)], dim=1))
models["concat"] = Cat()
class CatOnly(torch.nn.Module):
    def __init__(self):
        super().__init__(); self.a = torch.nn.Conv2d(1, C, 3, padding=1); self.b = torch.nn.Conv2d(1, C, 3, padding=1)
    def forward(self, x): return torch.cat([self.a(x), self.b(x)], dim=1)
models["cat_only"] = CatOnly()
m = models[name].eval()
if name == "bn":
    bn = m[1]; bn.running_mean.uniform_(-1, 1); bn.running_var.uniform_(0.5, 2); bn.weight.data.uniform_(0.5, 1.5); bn.bias.data.uniform_(-1, 1)
n = H * H
x = torch.arange(1, n + 1, dtype=torch.float32) / n; x = (x - x.mean()) / x.std(unbiased=False)
with torch.no_grad(): y = m(x.view(1, 1, H, H))
print(f"REF {name} nout={y.numel()} checksum {float(y.sum()):.6f} y[:3] {y.flatten()[:3].tolist()}", file=sys.stderr)
print(fx.export_and_import(m, x.view(1, 1, H, H), output_type="linalg-on-tensors"))
