#!/usr/bin/env python3
# Attach the host facts to the model entry function as one MLIR attribute, fortis.host.
#   fortis_hostattr.py <model.mlir> <hostinfo.json> <loop.json> <-|disabled> [lift2d.json] > annotated.mlir
import re, sys, json
model, hi, lp = sys.argv[1:4]; disabled = len(sys.argv) > 4 and sys.argv[4] == 'disabled'
bnd = json.load(open(sys.argv[5])) if len(sys.argv) > 5 else None
src = open(model).read(); H = json.load(open(hi)); L = json.load(open(lp))
def i64(v): return f"{int(v)} : i64"
def s(v): return '"' + str(v) + '"'
verdict = 'disabled' if disabled else ('boundary' if bnd and bnd.get('ok') else L['verdict'])
parts = [f"shape = [{', '.join(str(x) for x in H['in_shape'])}]",
         f"batch = {i64(L['batch'] if verdict == 'batched' else H['batch'])}",
         f"repeat = {i64(H.get('trip') or 0) if H.get('in_loop') else i64(0)}",
         f"verdict = {s(verdict)}"]
if verdict == 'batched':
    parts.append("loop = {" + ", ".join([f"lo = {i64(L['lo'])}", f"step = {i64(L['step'])}", f"count = {i64(L['batch'])}", f"minc = {i64(L['minc'])}",
                 f"in = {s(L['in'])}", f"out = {s(L['out'])}", f"post_download = {'true' if L['post_download'] else 'false'}"]) + "}")
    if L.get('lift'):
        parts.append("lift = {globals = [" + ", ".join(s(g['sym']) for g in L['lift']['globals']) + "], in = " + s(L['lift']['in_sym']) + "}")
if verdict == 'boundary':
    li, lo = bnd['layout']['in'], bnd['layout']['out']
    pre = (bnd.get('pre') or {}).get('globals', []); post = (bnd.get('post') or {}).get('globals', [])
    parts.append("boundary = {" + ", ".join([f"in = {s(li['from'])}", f"in_elt = {s(li['from_elt'])}", f"out = {s(lo['to'])}", f"out_elt = {s(lo['to_elt'])}",
                 "pre = [" + ", ".join(s(g) for g in pre) + "]", "post = [" + ", ".join(s(g) for g in post) + "]"]) + "}")
attr = "fortis.host = {" + ", ".join(parts) + "}"
m = re.search(r'(func\.func @(?:main|fortis_main)\([^{]*?\) -> tensor<[^>]+>)(\s*attributes \{([^}]*)\})?\s*\{', src)
assert m, "entry function not found"
existing = (m.group(3) + ", ") if m.group(3) else ""
sys.stdout.write(src[:m.start()] + m.group(1) + " attributes {" + existing + attr + "} {" + src[m.end():])
