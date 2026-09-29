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

def tshape(t):
    m = re.match(r'tensor<([\dx]+)x(f\d+)>', t); return [int(x) for x in m.group(1).split('x')], m.group(2)
def shape(t): return tshape(t)[0]
def cty(t): return 'double' if tshape(t)[1] == 'f64' else 'float'
def esz(t): return 8 if tshape(t)[1] == 'f64' else 4
def numel(t):
    n = 1
    for d in shape(t): n *= d
    return n
def desc(t): s = shape(t); c = cty(t); return f"{c}*, {c}*, long" + ", long" * (2 * len(s))
def call(p, t):
    s = shape(t); strides = [1]
    for d in reversed(s[1:]): strides.insert(0, strides[0] * d)
    return f"{p}, {p}, 0, " + ", ".join(map(str, s)) + ", " + ", ".join(map(str, strides))
inputs, consts, outtype = ol["inputs"], ol["weights"], ol["output"]
intype = inputs[0]
BND = H.get('boundary')
hostg = (BND['pre'] + BND['post']) if BND else H.get('lift', {}).get('globals', [])
assert len(hostg) == len(inputs) - 1, f"{len(inputs)-1} extra inputs but {len(hostg)} host globals in fortis.host"
n_in, n_out = numel(intype), numel(outtype)
R = len(shape(outtype))
c = "#include <cuda_runtime.h>\n#include <stddef.h>\n#include <stdlib.h>\n#include <stdio.h>\n#include <string.h>\nvoid* mgpuStreamCreate(void);\n"
c += f"typedef struct {{ void *a, *al; long o; long s[{R}]; long st[{R}]; }} MR;\n"
c += "MR mlp_kernel(" + ", ".join([desc(t) for t in inputs] + [desc(t) for t in consts] + [desc(outtype)]) + ");\n"
c += "extern float " + ", ".join(f"w{i}[]" for i in range(len(consts))) + ";\n"
c += "static void *din = 0, *dout" + "".join(f", *d{i}" for i in range(len(consts))) + "".join(f", *dg{i}" for i in range(len(hostg))) + ";\n"
for g, ty in zip(hostg, inputs[1:]): c += f"extern {cty(ty)} {g}[];\n"
c += "static void setup(void) {\n"
for i, ty in enumerate(consts):
    c += f"  cudaMalloc(&d{i}, {numel(ty)}L*{esz(ty)}); cudaMemcpy(d{i}, w{i}, {numel(ty)}L*{esz(ty)}, cudaMemcpyHostToDevice);\n"
for i, (g, ty) in enumerate(zip(hostg, inputs[1:])):
    c += f"  cudaMalloc(&dg{i}, {numel(ty)}L*{esz(ty)}); cudaMemcpy(dg{i}, {g}, {numel(ty)}L*{esz(ty)}, cudaMemcpyHostToDevice);\n"
c += f"  cudaMalloc(&din, {n_in}L*{esz(intype)}); cudaMalloc(&dout, {n_out}L*{esz(outtype)});\n}}\n"
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
IT, OT, IS, OS = cty(intype), cty(outtype), esz(intype), esz(outtype)
c += f"void mlp_download({OT}* out) {{ cudaMemcpy(out, dout, {n_out}L*{OS}, cudaMemcpyDeviceToHost); }}\n"
c += f"void mlp_upload({IT}* in) {{ if (!din) setup(); cudaMemcpy(din, in, {n_in}L*{IS}, cudaMemcpyHostToDevice); }}\n"
if H.get('verdict') == 'batched':
    # Fissioned host: the loop was split at FIR and the call replaced by one mlp_forward_batched on the
    # whole arrays (Section 4.2). mlp_forward stays as a single-row entry for any call outside the loop.
    Lp = H['loop']; B = Lp['count']; NIN, NOUT = n_in // B, n_out // B
    lo, step, minc = Lp['lo'], Lp['step'], Lp['minc']
    if 'expand' in H:
        # the call's temporaries are expanded across the batch: the pre-loop packs row col of X, one batched
        # call runs X through the model into Y, the post-loop unpacks row col of Y
        E = H['expand']
        c += f"static {IT} *X = 0; static {OT} *Y = 0;\n"
        c += f"static void setup_xy(void) {{ cudaHostAlloc((void**)&X, {n_in}L*{IS}, cudaHostAllocDefault); cudaHostAlloc((void**)&Y, {n_out}L*{OS}, cudaHostAllocDefault); }}\n"
        c += f"void fortis_pack({IT}* f, int col) {{ if (!X) setup_xy(); memcpy(X + (size_t)col*{NIN}L, f, {NIN}L*{IS}); }}\n"
        c += f"void fortis_unpack({OT}* o, int col) {{ memcpy(o, Y + (size_t)col*{NOUT}L, {NOUT}L*{OS}); }}\n"
        c += f"void mlp_forward_batched(void) {{ if (!din) setup(); if (!X) setup_xy(); cudaMemcpy(din, X, {n_in}L*{IS}, cudaMemcpyHostToDevice); mlp_forward_dev(); cudaMemcpy(Y, dout, {n_out}L*{OS}, cudaMemcpyDeviceToHost); }}\n"
    elif step == 1 and minc == 1:
        c += f"void mlp_forward_batched({IT}* in, {OT}* out) {{ mlp_upload(in); mlp_forward_dev(); mlp_download(out); }}\n"
    else:
        c += f"void mlp_forward_batched({IT}* in, {OT}* out) {{\n  if (!din) setup();\n"
        c += f"  cudaMemcpy2D(din, {NIN}L*{IS}, in + ({minc}-1)*{NIN}L, {abs(step)}L*{NIN}L*{IS}, {NIN}L*{IS}, {B}, cudaMemcpyHostToDevice);\n  mlp_forward_dev();\n"
        c += f"  cudaMemcpy2D(out + ({minc}-1)*{NOUT}L, {abs(step)}L*{NOUT}L*{OS}, dout, {NOUT}L*{OS}, {NOUT}L*{OS}, {B}, cudaMemcpyDeviceToHost);\n}}\n"
    c += f"void mlp_forward({IT}* in, {OT}* out) {{ if (!din) setup(); cudaMemcpy(din, in, {NIN}L*{IS}, cudaMemcpyHostToDevice); mlp_forward_dev(); cudaMemcpy(out, dout, {NOUT}L*{OS}, cudaMemcpyDeviceToHost); }}\n"
else:
    # Whole-array call. Under the boundary verdict in/out are the host's own arrays (their element type, their
    # memory order); the analysis proved them program-scope, so they are registered as pinned memory once and
    # every step DMAs straight from them instead of staging through a driver buffer.
    c += "static void *reg_in = 0, *reg_out = 0;\n"
    c += "static void pin(void** reg, void* p, size_t n) {\n  if (*reg == p || getenv(\"FORTIS_NO_PIN\")) return;\n"
    c += "  if (*reg) cudaHostUnregister(*reg);\n  *reg = cudaHostRegister(p, n, cudaHostRegisterDefault) == cudaSuccess ? p : 0;\n  if (!*reg) cudaGetLastError();\n}\n"
    c += f"void mlp_forward({IT}* in, {OT}* out) {{\n  if (!din) setup();\n  pin(&reg_in, in, {n_in}L*{IS}); pin(&reg_out, out, {n_out}L*{OS});\n"
    c += "  mlp_upload(in); mlp_forward_dev(); mlp_download(out);\n}\n"
open(f"{outdir}/shim.c", "w").write(c)
print(f"shim: verdict={H.get('verdict')} batch={H.get('batch')} repeat={H.get('repeat')} graph={GRAPH} in={intype} out={outtype}")
