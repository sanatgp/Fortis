#!/usr/bin/env python3
# Generate shim.c from the fortis.host and fortis.graph attributes on the fused module.
#   fortis_shim.py <m4.mlir> <outline.json> <outdir>
import re, sys, json
m4 = open(sys.argv[1]).read(); ol = json.load(open(sys.argv[2])); outdir = sys.argv[3]

# --- minimal parser for the attribute dictionary syntax fortis_hostattr.py writes
def parse_attr(text, pos):
    def skip(p):
        while p < len(text) and text[p] in ' \n': p += 1
        return p
    pos = skip(pos)
    if text[pos] == '{':
        d, p = {}, pos + 1
        while True:
            p = skip(p)
            if text[p] == '}': return d, p + 1
            km = re.match(r'([\w.]+)\s*=', text[p:]); k = km.group(1); p += km.end()
            v, p = parse_attr(text, p); d[k] = v
            p = skip(p)
            if text[p] == ',': p += 1
    if text[pos] == '[':
        a, p = [], pos + 1
        while True:
            p = skip(p)
            if text[p] == ']': return a, p + 1
            v, p = parse_attr(text, p); a.append(v); p = skip(p)
            if text[p] == ',': p += 1
    if text[pos] == '"':
        e = text.index('"', pos + 1); return text[pos + 1:e], e + 1
    m = re.match(r'(true|false|-?\d+)(\s*:\s*i\d+)?', text[pos:])
    v = m.group(1); return (v == 'true' if v in ('true', 'false') else int(v)), pos + m.end()
def func_attrs(src):
    m = re.search(r'func\.func @mlp_kernel\(.*?\)\s*(?:->\s*\S+\s*)?attributes\s*', src)
    if not m: return {}
    d, _ = parse_attr(src, m.end()); return d
A = func_attrs(m4); H = A.get('fortis.host', {}); GRAPH = 1 if A.get('fortis.graph', False) else 0

def shape(t): return [int(x) for x in re.match(r'tensor<([\dx]+)xf32>', t).group(1).split('x')]
def desc(t):
    s = shape(t); return "float*, float*, long" + ", long" * (2 * len(s))
def call(p, t):
    s = shape(t); strides = [1]
    for d in reversed(s[1:]): strides.insert(0, strides[0] * d)
    return f"{p}, {p}, 0, " + ", ".join(map(str, s)) + ", " + ", ".join(map(str, strides))
inputs, consts, outtype = ol["inputs"], ol["weights"], ol["output"]
intype = inputs[0]
hostg = H.get('lift', {}).get('globals', [])
assert len(hostg) == len(inputs) - 1, f"{len(inputs)-1} extra inputs but {len(hostg)} host globals in fortis.host"
n_in = 1
for d in shape(intype): n_in *= d
n_out = 1
for d in shape(outtype): n_out *= d
R = len(shape(outtype))
c = "#include <cuda_runtime.h>\n#include <stddef.h>\n#include <stdlib.h>\n#include <stdio.h>\nvoid* mgpuStreamCreate(void);\n"
c += f"typedef struct {{ float *a; float *al; long o; long s[{R}]; long st[{R}]; }} MR;\n"
c += "MR mlp_kernel(" + ", ".join([desc(t) for t in inputs] + [desc(t) for t in consts] + [desc(outtype)]) + ");\n"
c += "extern float " + ", ".join(f"w{i}[]" for i in range(len(consts))) + ";\n"
c += "static float *din = 0, *dout" + "".join(f", *d{i}" for i in range(len(consts))) + "".join(f", *dg{i}" for i in range(len(hostg))) + ";\n"
for g in hostg: c += f"extern float {g}[];\n"
c += "static void setup(void) {\n"
for i, ty in enumerate(consts):
    sz = 1
    for d in shape(ty): sz *= d
    c += f"  cudaMalloc((void**)&d{i}, {sz}L*4); cudaMemcpy(d{i}, w{i}, {sz}L*4, cudaMemcpyHostToDevice);\n"
for i, (g, ty) in enumerate(zip(hostg, inputs[1:])):
    sz = shape(ty)[0]
    c += f"  cudaMalloc((void**)&dg{i}, {sz}L*4); cudaMemcpy(dg{i}, {g}, {sz}L*4, cudaMemcpyHostToDevice);\n"
c += f"  cudaMalloc((void**)&din, {n_in}L*4); cudaMalloc((void**)&dout, {n_out}L*4);\n}}\n"
c += "static cudaGraphExec_t fortis_gexec = 0; static int fortis_ncalls = 0; extern int fortis_capturing;\n"
callargs = ", ".join([call("din", intype)] + [call(f"dg{i}", t) for i, t in enumerate(inputs[1:])] + [call(f"d{i}", t) for i, t in enumerate(consts)] + [call("dout", outtype)])
c += "void mlp_forward_dev(void) {\n  cudaStream_t s = (cudaStream_t)mgpuStreamCreate();\n"
c += "  if (fortis_gexec) { cudaGraphLaunch(fortis_gexec, s); return; }\n"
c += f"  int cap = (++fortis_ncalls == 2) && ({GRAPH} || getenv(\"FORTIS_GRAPH\") != 0);\n"
c += "  if (cap) { fortis_capturing = 1; cudaStreamBeginCapture(s, cudaStreamCaptureModeThreadLocal); }\n"
c += f"  mlp_kernel({callargs});\n"
c += "  if (cap) { cudaGraph_t g; fortis_capturing = 0;\n"
c += "    if (cudaStreamEndCapture(s, &g) == cudaSuccess && cudaGraphInstantiate(&fortis_gexec, g, 0) == cudaSuccess) cudaGraphLaunch(fortis_gexec, s);\n"
c += f"    else {{ fprintf(stderr, \"fortis: graph capture failed, running eagerly\\n\"); fortis_gexec = 0; cudaGetLastError(); mlp_kernel({callargs}); }}\n"
c += "  }\n}\n"
c += f"void mlp_download(float* out) {{ cudaMemcpy(out, dout, {n_out}L*4, cudaMemcpyDeviceToHost); }}\n"
if H.get('verdict') == 'batched':
    # Fissioned host: the loop was split at FIR and the call replaced by one mlp_forward_batched on the
    # whole arrays (Section 4.2). No per-iteration identification is needed. mlp_forward stays as a
    # single-row entry for any remaining call outside the fissioned loop.
    Lp = H['loop']; B = Lp['count']; NIN, NOUT = n_in // B, n_out // B
    c += f"void mlp_upload(float* in) {{ if (!din) setup(); cudaMemcpy(din, in, {n_in}L*4, cudaMemcpyHostToDevice); }}\n"
    lo, step, minc = Lp['lo'], Lp['step'], Lp['minc']
    if step == 1 and minc == 1:
        c += "void mlp_forward_batched(float* in, float* out) { mlp_upload(in); mlp_forward_dev(); mlp_download(out); }\n"
    else:
        # strided or offset iteration set: gather the iterated columns with a 2-D copy and scatter them back
        c += f"void mlp_forward_batched(float* in, float* out) {{\n  if (!din) setup();\n"
        c += f"  cudaMemcpy2D(din, {NIN}L*4, in + ({minc}-1)*{NIN}L, {abs(step)}L*{NIN}L*4, {NIN}L*4, {B}, cudaMemcpyHostToDevice);\n  mlp_forward_dev();\n"
        c += f"  cudaMemcpy2D(out + ({minc}-1)*{NOUT}L, {abs(step)}L*{NOUT}L*4, dout, {NOUT}L*4, {NOUT}L*4, {B}, cudaMemcpyDeviceToHost);\n}}\n"
    c += f"void mlp_forward(float* in, float* out) {{ if (!din) setup(); cudaMemcpy(din, in, {NIN}L*4, cudaMemcpyHostToDevice); mlp_forward_dev(); cudaMemcpy(out, dout, {NOUT}L*4, cudaMemcpyDeviceToHost); }}\n"
else:
    c += f"void mlp_upload(float* in) {{ if (!din) setup(); cudaMemcpy(din, in, {n_in}L*4, cudaMemcpyHostToDevice); }}\n"
    c += "void mlp_forward(float* in, float* out) { mlp_upload(in); mlp_forward_dev(); mlp_download(out); }\n"
open(f"{outdir}/shim.c", "w").write(c)
print(f"shim: verdict={H.get('verdict')} batch={H.get('batch')} repeat={H.get('repeat')} graph={GRAPH}")
