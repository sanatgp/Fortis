import sys, numpy as np, torch
W = np.load("sam_nn.npz")

def lin(w, b):
    l = torch.nn.Linear(w.shape[1], w.shape[0]); l.weight.data = torch.tensor(w.copy()); l.bias.data = torch.tensor(b.copy()); return l
class SamNN(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.body = torch.nn.Sequential(
            lin(W["w1"], W["b1"]), torch.nn.ReLU(),
            lin(W["w2"], W["b2"]), torch.nn.ReLU(),
            lin(W["w3"], W["b3"]), torch.nn.ReLU(),
            lin(W["w4"], W["b4"]), torch.nn.ReLU(),
            lin(W["w5"], W["b5"]))
    def forward(self, x):
        return self.body(x)
m = SamNN().eval()
# a normalized sample column for tracing and the checksum: the mean profile is x = 0 after normalization
x0 = torch.zeros(1, 61, dtype=torch.float32)
with torch.no_grad():
    ref = m(x0).numpy()
torch.jit.trace(m, x0).save("sam_nn.pt")
if len(sys.argv) > 1 and sys.argv[1] == "linalg":
    from torch_mlir import fx
    import os; B = int(os.environ.get("FORTIS_BATCH", "1"))
    print(fx.export_and_import(m, x0.repeat(B, 1), output_type="linalg-on-tensors"))
else:
    print("ref checksum:", float(ref.sum()), "ref[0,:4]:", ref[0, :4])
