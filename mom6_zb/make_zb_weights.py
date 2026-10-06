# Tall.nc (m2lines/ANN-momentum-mesoscale, hidden-layer-20/seed-default) -> zb_nn.npz and zb_nn.bin.
# In the file A0 is stored C-order (27,20), which is the Fortran A0(20,27) that MOM_read_data loads, so the
# raw bytes go to zb_nn.bin unchanged and the npz holds A0 as (out,in) for PyTorch.
import numpy as np
try:
    import netCDF4
    f = netCDF4.Dataset("Tall.nc"); g = lambda k: np.array(f.variables[k][:])
except ImportError:
    import h5py
    f = h5py.File("Tall.nc"); g = lambda k: f[k][()]
raw = {k: g(k).astype(np.float32) for k in ("A0", "b0", "A1", "b1", "input_norms", "output_norms", "x_test", "y_test")}
W = dict(A0=raw["A0"].T, b0=raw["b0"], A1=raw["A1"].T, b1=raw["b1"], in_norms=raw["input_norms"], out_norms=raw["output_norms"],
         x_test=raw["x_test"], y_test=raw["y_test"])
np.savez("zb_nn.npz", **W)
with open("zb_nn.bin", "wb") as o:
    for k in ("A0", "b0", "A1", "b1", "input_norms", "output_norms"):
        o.write(np.ascontiguousarray(raw[k]).tobytes())
x = W["x_test"] / W["in_norms"]
y = (W["A1"] @ np.maximum(W["A0"] @ x + W["b0"], 0) + W["b1"]) * W["out_norms"]
print("layer sizes", g("layer_sizes"), " y_test rel err:", float(np.abs(y - W["y_test"]).max() / np.abs(W["y_test"]).max()))
