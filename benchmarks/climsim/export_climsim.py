import sys, numpy as np, torch
W = np.load("climsim_mlp.npz")
s = (W["in_max"] - W["in_min"]).astype(np.float32); s[s == 0] = 1.0
mean = W["in_mean"].astype(np.float32); oscale = W["out_scale"].astype(np.float32)

def lin(k, b): 
    l = torch.nn.Linear(k.shape[0], k.shape[1]); l.weight.data = torch.tensor(k.T.copy()); l.bias.data = torch.tensor(b.copy()); return l
# layer 1 with input normalization folded: y = ((x-mean)/s) @ K + b
K1 = W["dense_k"]; b1 = W["dense_b"]
# merged head with output de-scaling folded: [K6|K7] / oscale
Kh = np.concatenate([W["dense_6_k"], W["dense_7_k"]], axis=1) / oscale[None, :]
bh = np.concatenate([W["dense_6_b"], W["dense_7_b"]]) / oscale
class ClimSimMLP(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.body = torch.nn.Sequential(
            lin(K1, b1), torch.nn.LeakyReLU(0.15),
            lin(W["dense_1_k"], W["dense_1_b"]), torch.nn.LeakyReLU(0.15),
            lin(W["dense_2_k"], W["dense_2_b"]), torch.nn.LeakyReLU(0.15),
            lin(W["dense_3_k"], W["dense_3_b"]), torch.nn.LeakyReLU(0.15),
            lin(W["dense_4_k"], W["dense_4_b"]), torch.nn.LeakyReLU(0.15),
            lin(W["dense_5_k"], W["dense_5_b"]), torch.nn.LeakyReLU(0.15),
            lin(Kh, bh))
        m = torch.zeros(128); m[120:] = 1.0
        self.register_buffer("mask", m)
    def forward(self, x):
        y = self.body(x)
        return y + self.mask * (torch.relu(y) - y)   # relu on the last 8 outputs only
m = ClimSimMLP().eval()
cols = torch.tensor((W["columns"] - mean) / s)
np.stack([mean, s]).astype(np.float32).tofile("norm.bin")
with torch.no_grad():
    ref = m(cols).numpy()
ref.astype(np.float32).tofile("ref.bin")
torch.jit.trace(m, cols[:1]).save("climsim_mlp.pt")
if len(sys.argv) > 1 and sys.argv[1] == "linalg":
    from torch_mlir import fx
    import os; B = int(os.environ.get("FORTIS_BATCH", "1"))
    print(fx.export_and_import(m, cols[:B], output_type="linalg-on-tensors"))
else:
    print("ref checksum:", float(ref.sum()), "ref[0,:4]:", ref[0, :4])
