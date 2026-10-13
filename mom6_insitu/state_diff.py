# Max absolute and relative differences of every prognostic field in MOM.res.nc between two runs.
import sys, numpy as np, netCDF4
a, b = netCDF4.Dataset(sys.argv[1]), netCDF4.Dataset(sys.argv[2])
print("%-10s %12s %12s %12s" % ("field", "max|ref|", "max|diff|", "rel"))
worst = 0.0
for k, v in a.variables.items():
    if v.dtype.kind != "f" or v.ndim < 2 or k not in b.variables: continue
    x, y = np.ma.filled(v[:], 0.0), np.ma.filled(b.variables[k][:], 0.0)
    ref, d = np.abs(x).max(), np.abs(x - y).max()
    rel = d / ref if ref > 0 else 0.0; worst = max(worst, rel)
    print("%-10s %12.4e %12.4e %12.3e" % (k, ref, d, rel))
print("worst relative difference %.3e" % worst)
