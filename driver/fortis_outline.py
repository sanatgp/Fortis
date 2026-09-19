# Turn torch-mlir linalg export into FORTIS kernel form:
#  - weight constants -> extra function args (device-resident, uploaded once)
#  - result -> written into an out-param via linalg.copy
#  - emits weights.mlir (host symbols w0..wN + blobs) and shim.c (residency + ABI)
import re, os, sys, json
src = open(sys.argv[1]).read()
outdir = sys.argv[2] if len(sys.argv) > 2 else "."

head = re.search(r'func\.func @(\w+)\(((?:%\w+: tensor<[^>]+>, )*%\w+: tensor<[^>]+>)\) -> (tensor<[^>]+>) \{', src)
fname, inlist, outtype = head.groups()
inputs = re.findall(r'(%\w+): (tensor<[^>]+>)', inlist)
inarg, intype = inputs[0]
hostg = json.loads(os.environ.get("FORTIS_HOST_GLOBALS", "[]"))    # program-level arrays read by a lifted prologue
assert len(hostg) == len(inputs) - 1, f"{len(inputs)-1} extra inputs but {len(hostg)} host globals"
lift_in = os.environ.get("FORTIS_LIFT_IN_SYM", "")
# weights: dense_resource<key> (torch fx export) or inline dense<...> literals (ONNX import)
consts = [(n, ("res", k), t) for n, k, t in re.findall(r'\n\s*(%\w+) = arith\.constant dense_resource<([\w.]+)> : (tensor<[\dx]+xf32>)', src)]
consts += [(n, ("lit", v), t) for n, v, t in re.findall(r'\n\s*(%\w+) = arith\.constant dense<("0x[0-9A-Fa-f]+"|\[[^>]*|[-\d.eE+]+)> : (tensor<[\dx]+xf32>)', src)]
for name, key, ty in consts:
    src = re.sub(r'\n\s*' + re.escape(name) + r' = arith\.constant dense(_resource)?<[^>]*> : tensor<[^>]+>', '', src)
args = [f"{a}: {t}" for a, t in inputs] + [f"{n}: {t}" for n, _, t in consts]
src = src.replace(head.group(0), f"func.func @mlp_kernel({', '.join(args)}) -> {outtype} {{")
blob = src[src.index('{-#'):] if '{-#' in src else ''
body = src[:src.index('{-#')] if '{-#' in src else src
open(f"{outdir}/model_args.mlir", "w").write(body)

def shape(t): return [int(x) for x in re.match(r'tensor<([\dx]+)xf32>', t).group(1).split('x')]
def arr(s):
    ty = "f32"
    for d in reversed(s): ty = f"array<{d} x {ty}>"
    return ty
w = "module {\n"
for i, (n, key, ty) in enumerate(consts):
    init = f"dense_resource<{key[1]}>" if key[0] == "res" else f"dense<{key[1]}>"
    w += f"  llvm.mlir.global constant @w{i}({init} : {ty}) {{addr_space = 0 : i32, alignment = 64 : i64}} : !llvm.{arr(shape(ty))}\n"
w += "}\n" + blob
open(f"{outdir}/weights.mlir", "w").write(w)

def desc(t):  # descriptor ABI arg list for a memref of this shape
    s = shape(t); return "float*, float*, long" + ", long" * (2 * len(s))
def call(p, t):
    s = shape(t); strides = [1]
    for d in reversed(s[1:]): strides.insert(0, strides[0] * d)
    return f"{p}, {p}, 0, " + ", ".join(map(str, s)) + ", " + ", ".join(map(str, strides))
n_in = 1
for d in shape(intype): n_in *= d
n_out = 1
for d in shape(outtype): n_out *= d
c = "#include <cuda_runtime.h>\n#include <stddef.h>\n#include <stdlib.h>\n#include <stdio.h>\nvoid* mgpuStreamCreate(void);\n"
R = len(shape(outtype))
c += f"typedef struct {{ float *a; float *al; long o; long s[{R}]; long st[{R}]; }} MR;\n"
c += "MR mlp_kernel(" + ", ".join([desc(t) for _, t in inputs] + [desc(t) for _, _, t in consts] + [desc(outtype)]) + ");\n"
c += "extern float " + ", ".join(f"w{i}[]" for i in range(len(consts))) + ";\n"
c += "static float *din = 0, *dout" + "".join(f", *d{i}" for i in range(len(consts))) + "".join(f", *dg{i}" for i in range(len(hostg))) + ";\n"
for g in hostg: c += f"extern float {g['sym']}[];\n"
if lift_in: c += f"extern float {lift_in}[];\n"
c += "static void setup(void) {\n"
for i, (n, key, ty) in enumerate(consts):
    sz = 1
    for d in shape(ty): sz *= d
    c += f"  cudaMalloc((void**)&d{i}, {sz}L*4); cudaMemcpy(d{i}, w{i}, {sz}L*4, cudaMemcpyHostToDevice);\n"
for i, g in enumerate(hostg):
    c += f"  cudaMalloc((void**)&dg{i}, {g['n']}L*4); cudaMemcpy(dg{i}, {g['sym']}, {g['n']}L*4, cudaMemcpyHostToDevice);\n"
c += f"  cudaMalloc((void**)&din, {n_in}L*4); cudaMalloc((void**)&dout, {n_out}L*4);\n}}\n"
c += f"void mlp_upload(float* in) {{ if (!din) setup(); cudaMemcpy(din, in, {n_in if not os.environ.get('FORTIS_LOOP_JSON') else n_in // json.load(open(os.environ['FORTIS_LOOP_JSON']))['batch']}L*4, cudaMemcpyHostToDevice); }}\n"
c += "static cudaGraphExec_t fortis_gexec = 0; static int fortis_ncalls = 0; extern int fortis_capturing;\n"
callargs = ", ".join([call("din", intype)] + [call(f"dg{i}", t) for i, (_, t) in enumerate(inputs[1:])] + [call(f"d{i}", t) for i, (_, _, t) in enumerate(consts)] + [call("dout", outtype)])
c += "void mlp_forward_dev(void) {\n  cudaStream_t s = (cudaStream_t)mgpuStreamCreate();\n"
c += "  if (fortis_gexec) { cudaGraphLaunch(fortis_gexec, s); return; }\n"
c += "#ifndef FORTIS_GRAPH_DEFAULT\n#define FORTIS_GRAPH_DEFAULT 0\n#endif\n"
c += "  int cap = (++fortis_ncalls == 2) && (FORTIS_GRAPH_DEFAULT || getenv(\"FORTIS_GRAPH\") != 0);\n"
c += "  if (cap) { fortis_capturing = 1; cudaStreamBeginCapture(s, cudaStreamCaptureModeThreadLocal); }\n"
c += f"  mlp_kernel({callargs});\n"
c += "  if (cap) { cudaGraph_t g; fortis_capturing = 0;\n"
c += "    if (cudaStreamEndCapture(s, &g) == cudaSuccess && cudaGraphInstantiate(&fortis_gexec, g, 0) == cudaSuccess) cudaGraphLaunch(fortis_gexec, s);\n"
c += f"    else {{ fprintf(stderr, \"fortis: graph capture failed, running eagerly\\n\"); fortis_gexec = 0; cudaGetLastError(); mlp_kernel({callargs}); }}\n"
c += "  }\n}\n"
c += f"void mlp_download(float* out) {{ cudaMemcpy(out, dout, {n_out}L*4, cudaMemcpyDeviceToHost); }}\n"
LJ = os.environ.get("FORTIS_LOOP_JSON", "")
if LJ:
    # Loop-distributed entry. The iteration is identified from the argument address relative to the
    # host array's symbol. At column lo the iterated columns are gathered with a 2-D copy, the step
    # runs, and outputs are scattered back (or downloaded per iteration when a pre-statement writes
    # the output slice). A call that is not on the analyzed array runs as a single row.
    d = json.load(open(LJ)); B, lo, step, minc = d["batch"], d["lo"], d["step"], d["minc"]
    NIN, NOUT = n_in // B, n_out // B
    SIN, SOUT = d["in"], d["out"]
    c += f"extern float {SIN}[], {SOUT}[];\n"
    c += "void mlp_forward(float* in, float* out) {\n"
    c += f"  long col = (out - {SOUT}) / {NOUT}L + 1;\n"
    c += f"  if (out < {SOUT} || out >= {SOUT} + ({minc}-1)*{NOUT}L + {NOUT}L*{B}L*{abs(step)}L || getenv(\"FORTIS_DEBUG_COL\") && fprintf(stderr, \"col %ld\\n\", col) < 0) {{ mlp_upload(in); mlp_forward_dev(); cudaMemcpy(out, dout, {NOUT}L*4, cudaMemcpyDeviceToHost); return; }}\n"
    c += f"  if (col == {lo}) {{\n    if (!din) setup();\n"
    c += f"    cudaMemcpy2D(din, {NIN}L*4, {SIN} + ({minc}-1)*{NIN}L, {abs(step)}L*{NIN}L*4, {NIN}L*4, {B}, cudaMemcpyHostToDevice);\n"
    c += "    mlp_forward_dev();\n"
    if not d["post_download"]:
        c += f"    cudaMemcpy2D({SOUT} + ({minc}-1)*{NOUT}L, {abs(step)}L*{NOUT}L*4, dout, {NOUT}L*4, {NOUT}L*4, {B}, cudaMemcpyDeviceToHost);\n"
    c += "  }\n"
    if d["post_download"]:
        c += f"  cudaMemcpy(out, dout + ((col - {minc}) / {abs(step)}L) * {NOUT}L, {NOUT}L*4, cudaMemcpyDeviceToHost);\n"
    c += "}\n"
else:
    c += "void mlp_forward(float* in, float* out) { mlp_upload(in); mlp_forward_dev(); mlp_download(out); }\n"
open(f"{outdir}/shim.c", "w").write(c)
print(f"outlined {len(consts)} weights; func @mlp_kernel({intype}, {outtype}, ...)")
