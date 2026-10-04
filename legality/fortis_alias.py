#!/usr/bin/env python3
# Aliasing check for the FORTIS driver. The legality propositions assume distinct array symbols do not alias.
# This scans the HLFIR of the function that calls the model entry for variables whose storage can alias,
# POINTER, TARGET, COMMON, and EQUIVALENCE, and reports them so the driver can refuse the transformations.
#   python3 fortis_alias.py host.hlfir mlp_forward   ->  {"ok": bool, "reasons": [...]}
import sys, re, json
src = open(sys.argv[1]).read(); entry = sys.argv[2]
funcs = re.split(r'(?m)^\s*func\.func\s+', src)
body = next((f for f in funcs if re.search(r'fir\.call\s+@%s\b' % re.escape(entry), f)), None)
if body is None:
    print(json.dumps({"ok": False, "reasons": ["no call to %s found" % entry]})); sys.exit(0)
commons = set(re.findall(r'fir\.global\s+common\s+@(\w+)', src))
defs = {}
for line in body.splitlines():
    m = re.match(r'\s*(%[\w]+)(?::\d+)?\s*=\s*(.*)$', line)
    if m: defs[m.group(1)] = m.group(2)
def storage(ref, depth=0):
    """Walk the declared memref back to its storage. Returns 'common', 'shared', or None."""
    if depth > 6 or ref not in defs: return None
    d = defs[ref]
    g = re.search(r'fir\.address_of\(@(\w+)\)', d)
    if g: return 'common' if g.group(1) in commons else ('shared' if re.search(r'x\s*i8>', d) else None)
    if 'fir.alloca' in d or 'fir.alloc' in d: return 'shared' if re.search(r'!fir\.array<\d+\s*x\s*i8>', d) else None
    m = re.search(r'(fir\.convert|fir\.coordinate_of|fir\.box_addr|fir\.load|fir\.declare|hlfir\.declare)\s+(%[\w]+)', d)
    return storage(m.group(2), depth + 1) if m else None
reasons = []
for m in re.finditer(r'hlfir\.declare\s+(%[\w]+)[^{\n]*\{([^}]*)\}', body):
    ref, attrs = m.group(1), m.group(2)
    name = re.search(r'uniq_name\s*=\s*"([^"]+)"', attrs)
    if not name: continue
    short = re.sub(r'^_Q.*?E', '', name.group(1))
    fa = re.search(r'fortran_attrs\s*=\s*#fir\.var_attrs<([^>]*)>', attrs)
    fa = fa.group(1) if fa else ''
    if 'pointer' in fa: reasons.append("%s is a POINTER" % short)
    if 'target' in fa: reasons.append("%s has the TARGET attribute" % short)
    s = storage(ref)
    if s == 'common': reasons.append("%s is in COMMON" % short)
    elif s == 'shared': reasons.append("%s shares storage (EQUIVALENCE)" % short)
print(json.dumps({"ok": not reasons, "reasons": sorted(set(reasons))}))
