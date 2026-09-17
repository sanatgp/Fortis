import torch
from torch_mlir import fx
torch.manual_seed(42)
class MLP(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.net = torch.nn.Sequential(
            torch.nn.Linear(1024, 256),
            torch.nn.ReLU(),
            torch.nn.Linear(256, 1024),
        )
    def forward(self, x):
        return self.net(x)
m = MLP().eval()
x = torch.randn(1, 1024)
print(fx.export_and_import(m, x, output_type="linalg-on-tensors"))
