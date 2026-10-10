#!/usr/bin/env python3
# Result plots for the FORTIS paper: fig_ladders.pdf (three host ladders) and fig_scale.pdf (chunk size, V100 vs A100, four hosts).
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 7, 'pdf.fonttype': 42, 'axes.linewidth': 0.6,
                     'xtick.major.width': 0.5, 'ytick.major.width': 0.5, 'xtick.major.size': 2, 'ytick.major.size': 2})
GRAY, GRAY2, BLUE, BLUE2, WHITE, EC = '#d9d9d9', '#8c8c8c', '#3182bd', '#9ecae1', '#ffffff', '#555555'

def fmt(v): return '%.3f' % v if v < 1 and abs(round(v, 2) - v) > 1e-9 else '%.2f' % v if v < 10 else '%.1f' % v if v < 100 else '%.0f' % v
def ladder(ax, rows, log, xlabel, xmax=None):
    names = [r[0] for r in rows]; vals = np.array([r[1] for r in rows]); cols = [r[2] for r in rows]; sd = np.array([r[3] for r in rows])
    y = np.arange(len(rows))[::-1]
    bars = ax.barh(y, vals, xerr=sd, error_kw={'elinewidth': 0.6, 'capsize': 1.5, 'capthick': 0.6, 'ecolor': '#222222'}, color=cols, edgecolor=EC, lw=0.5, height=0.66)
    for b, c in zip(bars, cols):
        if c == BLUE2: b.set_hatch('////'); b.set_edgecolor('#1f5f9a'); b.set_linewidth(0.4)
    ax.set_yticks(y); ax.set_yticklabels(names, fontsize=7.4)
    if log: ax.set_xscale('log')
    lim = xmax or (vals.max() * (6 if log else 1.28))
    ax.set_xlim(vals.min() * 0.4 if log else 0, lim)
    for yi, v, e in zip(y, vals, sd):
        ax.text(v * (1.18 if log else 1) + (0 if log else lim * 0.012) + (0 if log else e), yi, fmt(v), va='center', fontsize=7.0)
    if log:
        from matplotlib.ticker import FixedLocator, NullLocator, FuncFormatter
        ax.xaxis.set_major_locator(FixedLocator([0.1, 1, 10, 100, 1000])); ax.xaxis.set_minor_locator(NullLocator())
        ax.xaxis.set_major_formatter(FuncFormatter(lambda v, p: ('%g' % v)))
    ax.set_xlabel(xlabel, fontsize=7.4)
    ax.tick_params(axis='y', length=0); ax.grid(axis='x', color='#eeeeee', lw=0.5); ax.set_axisbelow(True)
    for s in ('top', 'right'): ax.spines[s].set_visible(False)

# ---------------- fig_ladders: the three hosts on the V100 ----------------
fig, axs = plt.subplots(1, 3, figsize=(7.0, 2.45))
e3sm = [('FTorch', 1.70, GRAY, 0.029), ('TorchFort', 1.66, GRAY, 0.012), ('FORTIS, call only', 0.96, BLUE2, 0.019), ('TensorRT', 0.90, GRAY, 0.011),
        ('host, no model', 0.61, WHITE, 0.010), ('FORTIS, unpinned', 0.60, BLUE2, 0.005), ('FORTIS, boundary', 0.46, BLUE, 0.008),
        ('TensorRT, expert rewrite', 0.451, GRAY2, 0.003)]
ladder(axs[0], e3sm, False, 'ms per step')
axs[0].set_title('(a) E3SM host, 384 columns', fontsize=7.8, fontweight='bold', loc='left')
clim = [('FTorch', 70.1, GRAY, 0.16), ('TorchFort', 83.8, GRAY, 0.23), ('TensorRT', 21.2, GRAY, 0.10), ('FORTIS, shape', 19.1, BLUE2, 0.067),
        ('+ repetition', 16.1, BLUE2, 0.025), ('+ independence', 0.33, BLUE, 0.009), ('+ Lift', 0.32, BLUE, 0.002),
        ('TensorRT, hand-batched', 0.302, GRAY2, 0.003), ('FORTIS, hand-batched', 0.348, BLUE, 0.001)]
ladder(axs[1], clim, True, 'ms per step (log)')
axs[1].set_title('(b) ClimSim loop, 384 columns', fontsize=7.8, fontweight='bold', loc='left')
sam = [('TorchFort', 498.9, GRAY, 4.9), ('FTorch', 411.5, GRAY, 4.2), ('shipped, CPU', 54.3, GRAY, 0.29), ('TensorRT', 123.8, GRAY, 3.7),
       ('FORTIS, per column', 86.7, BLUE2, 0.22), ('FORTIS, fission', 3.31, BLUE, 0.036), ('host, no model', 1.89, WHITE, 0.017),
       ('TensorRT, hand-batched', 4.22, GRAY2, 0.006), ('FORTIS, hand-batched', 3.23, BLUE, 0.004)]
ladder(axs[2], sam, True, 'ms per step (log)')
axs[2].set_title('(c) SAM host, 3240 columns', fontsize=7.8, fontweight='bold', loc='left')
from matplotlib.patches import Patch
fig.legend(handles=[Patch(fc=GRAY, ec=EC, lw=0.5, label='coupling library or TensorRT'), Patch(fc=WHITE, ec=EC, lw=0.5, label='host with the call removed'),
                    Patch(fc=BLUE2, ec='#1f5f9a', lw=0.4, hatch='////', label='FORTIS, some host facts withheld'), Patch(fc=BLUE, ec=EC, lw=0.5, label='FORTIS, all host facts'),
                    Patch(fc=GRAY2, ec=EC, lw=0.5, label='TensorRT on an expert rewrite of the host')],
           fontsize=7, frameon=False, loc='lower center', ncol=5, handlelength=1.2, columnspacing=1.0, handletextpad=0.5, bbox_to_anchor=(0.5, -0.08))
fig.tight_layout(w_pad=1.2)
fig.savefig('fig_ladders.pdf', bbox_inches='tight'); fig.savefig('fig_ladders.png', dpi=220, bbox_inches='tight')

# ---------------- fig_scale: chunk size and the second GPU ----------------
fig, (a1, a2) = plt.subplots(2, 1, figsize=(3.35, 3.9), gridspec_kw={'height_ratios': [1, 1.2]})
cols = [96, 192, 384, 768]
nomodel = [0.07, 0.26, 0.62, 1.35]; callonly = [0.23, 0.46, 0.90, 1.84]; bnd = [0.20, 0.28, 0.47, 0.83]
sd1 = {'host with no model': [0.0005, 0.002, 0.0087, 0.0113], 'FORTIS, call only': [0.0016, 0.0019, 0.0109, 0.0219], 'FORTIS, boundary compiled': [0.0007, 0.0010, 0.0016, 0.0043]}
EK = {'elinewidth': 0.6, 'capsize': 1.5, 'capthick': 0.6, 'ecolor': '#222222'}
x = np.arange(4); w = 0.26
for k, (v, c, lab) in enumerate([(nomodel, WHITE, 'host with no model'), (callonly, BLUE2, 'FORTIS, call only'), (bnd, BLUE, 'FORTIS, boundary compiled')]):
    b = a1.bar(x + (k - 1) * w, v, w, yerr=sd1[lab], error_kw=EK, color=c, edgecolor=EC, lw=0.5, label=lab)
    for xi, vi in zip(x + (k - 1) * w, v): a1.text(xi, vi + 0.03, '%.2f' % vi, ha='center', fontsize=5.6)
a1.set_xticks(x); a1.set_xticklabels(['%d' % c for c in cols]); a1.set_xlabel('columns per call', fontsize=6.8); a1.set_ylabel('ms per step', fontsize=6.8)
a1.set_ylim(0, 2.25); a1.legend(fontsize=5.8, frameon=False, loc='lower center', ncol=3, handlelength=1.0, columnspacing=0.8, handletextpad=0.4, bbox_to_anchor=(0.5, 0.99))
for xi, g in zip(x, ['1.16×', '1.67×', '1.93×', '2.23×']): a1.text(xi, 2.02, 'gain ' + g if xi == 0 else g, ha='center', fontsize=6.2, color=BLUE, fontweight='bold')
a1.set_title('(a) E3SM host at four chunk sizes, V100', fontsize=7.2, fontweight='bold', loc='left', pad=14)
a1.grid(axis='y', color='#eeeeee', lw=0.5); a1.set_axisbelow(True)
for s in ('top', 'right'): a1.spines[s].set_visible(False)

hosts = ['E3SM', 'ClimSim loop', 'SAM', 'MOM6']
trt = [(0.90, 0.85), (21.2, 22.3), (123.8, 126.5), (1367, 1718)]; fx = [(0.46, 0.41), (0.33, 0.23), (3.31, 2.39), (1.19, 1.05)]
trt_sd = [(0.011, 0.007), (0.10, 0.012), (3.7, 0.3), (1.6, 7.0)]; fx_sd = [(0.008, 0.002), (0.009, 0.001), (0.036, 0.045), (0.008, 0.006)]
gain = [('1.95×', '2.1×'), ('64×', '95×'), ('37×', '53×'), ('1149×', '1644×')]
x = np.arange(4); w = 0.2
for k, (vals, sds, c, lab) in enumerate([([t[0] for t in trt], [t[0] for t in trt_sd], GRAY, 'TensorRT, V100'), ([t[1] for t in trt], [t[1] for t in trt_sd], GRAY2, 'TensorRT, A100'),
                                    ([f[0] for f in fx], [f[0] for f in fx_sd], BLUE2, 'FORTIS, V100'), ([f[1] for f in fx], [f[1] for f in fx_sd], BLUE, 'FORTIS, A100')]):
    b = a2.bar(x + (k - 1.5) * w, vals, w, yerr=sds, error_kw=EK, color=c, edgecolor=EC, lw=0.5, label=lab)
    for xi, v in zip(x + (k - 1.5) * w, vals): a2.text(xi, v * 1.3, fmt(v), ha='center', va='bottom', fontsize=6.0, rotation=90)
for xi, (g1, g2) in zip(x, gain): a2.text(xi, 90000, g1 + '\n→ ' + g2, ha='center', va='bottom', fontsize=6.2, color=BLUE, fontweight='bold', linespacing=0.95)
a2.set_yscale('log'); a2.set_ylim(0.1, 2000000); a2.set_xticks(x); a2.set_xticklabels(hosts, fontsize=7.2)
from matplotlib.ticker import FixedLocator, NullLocator, FuncFormatter
a2.yaxis.set_major_locator(FixedLocator([0.1, 1, 10, 100, 1000, 10000])); a2.yaxis.set_minor_locator(NullLocator()); a2.yaxis.set_major_formatter(FuncFormatter(lambda v, p: '%g' % v))
a2.set_ylabel('ms per step (log)', fontsize=6.8); a2.set_xlim(-0.75, 3.6)
a2.legend(fontsize=6, frameon=False, loc='upper center', ncol=2, handlelength=1.0, columnspacing=0.8, handletextpad=0.4, bbox_to_anchor=(0.5, -0.12))
a2.set_title('(b) FORTIS over TensorRT, V100 → A100', fontsize=7.2, fontweight='bold', loc='left')
a2.grid(axis='y', color='#eeeeee', lw=0.5); a2.set_axisbelow(True)
for s in ('top', 'right'): a2.spines[s].set_visible(False)
fig.tight_layout(h_pad=1.6)
fig.savefig('fig_scale.pdf', bbox_inches='tight'); fig.savefig('fig_scale.png', dpi=220, bbox_inches='tight')
print('ok')
