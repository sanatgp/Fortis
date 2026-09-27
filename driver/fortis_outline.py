#!/usr/bin/env python3
# Turn the torch-mlir linalg export into FORTIS kernel form:
#  - weight constants -> extra function args (device-resident, uploaded once)
#  - the entry function renamed to @mlp_kernel, its fortis.* attributes preserved
#  - emits weights.mlir (host symbols w0..wN + blobs) and outline.json (signature for the shim)
import re, sys, json
src = open(sys.argv[1]).read()
outdir = sys.argv[2] if len(sys.argv) > 2 else "."

head = re.search(r'func\.func @(\w+)\(((?:%\w+: tensor<[^>]+>, )*%\w+: tensor<[^>]+>)\) -> (tensor<[^>]+>)( attributes \{.*?\})? \{', src)
fname, inlist, outtype, attrs = head.groups()
inputs = re.findall(r'(%\w+): (tensor<[^>]+>)', inlist)
consts = [(n, ("res", k), t) for n, k, t in re.findall(r'\n\s*(%\w+) = arith\.constant dense_resource<([\w.]+)> : (tensor<[\dx]+xf32>)', src)]
consts += [(n, ("lit", v), t) for n, v, t in re.findall(r'\n\s*(%\w+) = arith\.constant dense<("0x[0-9A-Fa-f]+"|\[[^>]*|[-\d.eE+]+)> : (tensor<[\dx]+xf32>)', src)]
for name, key, ty in consts:
    src = re.sub(r'\n\s*' + re.escape(name) + r' = arith\.constant dense(_resource)?<[^>]*> : tensor<[^>]+>', '', src)
args = [f"{a}: {t}" for a, t in inputs] + [f"{n}: {t}" for n, _, t in consts]
src = src.replace(head.group(0), f"func.func @mlp_kernel({', '.join(args)}) -> {outtype}{attrs or ''} {{")
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
json.dump({"inputs": [t for _, t in inputs], "weights": [t for _, _, t in consts], "output": outtype}, open(f"{outdir}/outline.json", "w"))
print(f"outlined {len(consts)} weights; func @mlp_kernel({inputs[0][1]}, {outtype}, ...)")
