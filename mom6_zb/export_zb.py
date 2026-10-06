import sys, os, numpy as np, torch
W = np.load("zb_nn.npz")

def lin(w, b):
    l = torch.nn.Linear(w.shape[1], w.shape[0]); l.weight.data = torch.tensor(w.copy()); l.bias.data = torch.tensor(b.copy()); return l
class ZbNN(torch.nn.Module):
    # ANN_apply of MOM_ANN.F90: divide by input_norms, Linear 27->20, ReLU, Linear 20->3, multiply by output_norms
    def __init__(self):
        super().__init__()
        self.register_buffer("in_norms", torch.tensor(W["in_norms"].copy()))
        self.register_buffer("out_norms", torch.tensor(W["out_norms"].copy()))
        self.l0 = lin(W["A0"], W["b0"]); self.l1 = lin(W["A1"], W["b1"])
    def forward(self, x):
        return self.l1(torch.relu(self.l0(x / self.in_norms))) * self.out_norms
m = ZbNN().eval()
x0 = torch.tensor(W["x_test"].copy()).reshape(1, 27)
with torch.no_grad():
    ref = m(x0).numpy()
torch.jit.trace(m, x0).save("zb_nn.pt")
if (len(sys.argv) > 1 and sys.argv[1] == "linalg") or "FORTIS_BATCH" in os.environ:
    from torch_mlir import fx
    B = int(os.environ.get("FORTIS_BATCH", "1"))
    print(fx.export_and_import(m, x0.repeat(B, 1), output_type="linalg-on-tensors"))
else:
    print("y_test rel err:", float(np.abs(ref[0] - W["y_test"]).max() / np.abs(W["y_test"]).max()))
