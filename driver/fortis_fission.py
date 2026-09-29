#!/usr/bin/env python3
# Loop fission around the model call, at FIR.
#   fortis_fission.py <host.fir> <loop.json> <callee> > fissioned.fir
# The loop containing the call becomes: pre-loop (statements before the call, minus Lift), one
# call to <callee>_batched on the whole arrays, post-loop (statements after the call). Empty loops
# are dropped. Statements are SSA groups delimited by top-level fir.store / fir.call terminators;
# an inner fir.do_loop, Fortran runtime calls and fir.freemem are statement-internal. FIR groups
# re-load the loop index themselves, so moving them between loops is sound.
import re, sys, json
fir = open(sys.argv[1]).read().split('\n'); L = json.load(open(sys.argv[2])); callee = sys.argv[3]
assert L['verdict'] == 'batched', 'fission applies to batched verdicts only'
n = [i for i, l in enumerate(fir) if re.search(r'fir\.call @' + re.escape(callee) + r'\(', l)][-1]
def enclosing(i0):
    depth = 0
    for i in range(i0 - 1, -1, -1):
        s = fir[i].strip()
        if s == '}': depth += 1
        elif s.endswith('{'):
            if depth: depth -= 1
            else: return i
def closing(i0):
    depth = 0
    for i in range(i0 + 1, len(fir)):
        s = fir[i].strip()
        if s.endswith('{'): depth += 1
        elif s == '}':
            if depth: depth -= 1
            else: return i
start = enclosing(n); end = closing(start)
# perfect nest flattened by the analysis: fission the outer loop, whose body is only the inner loop
if L.get('batch', 0) and L['batch'] != (L.get('loop') or {}).get('count', L['batch']) or False: pass
outer = enclosing(start)
if outer is not None and 'fir.do_loop' in fir[outer]:
    between = [fir[i].strip() for i in range(outer + 1, start)]
    tail = [fir[i].strip() for i in range(end + 1, closing(outer))]
    if between and between[0].startswith('fir.store') and all(t == '' or t.startswith('%c') for t in between[1:]) \
       and all(t == '' or re.match(r'%\w+ = (fir\.convert|arith\.\w+) ', t) or t.startswith('fir.store') for t in tail) and L['batch'] > int(re.search(r'to %c(\d+)', fir[start]).group(1)):
        start = outer; end = closing(outer)
hdr = fir[start]; indent = re.match(r'\s*', hdr).group(0)
assert 'fir.do_loop' in hdr, 'call is not directly inside a fir.do_loop'
body = fir[start + 1:end]
# group statements: top-level SSA groups ending in fir.store / fir.call; a brace-delimited inner
# region (an inner fir.do_loop) is one statement, and in a perfect nest it holds the call.
groups, cur, depth = [], [], 0
for l in body:
    cur.append(l); s_ = l.strip()
    if s_.endswith('{'): depth += 1; continue
    if s_ == '}':
        depth -= 1
        if depth == 0: groups.append(cur); cur = []
        continue
    if depth: continue
    if s_.startswith('fir.call @_Fortran') or s_.startswith('fir.freemem'): continue
    if s_.startswith('fir.store') or s_.startswith('fir.call'): groups.append(cur); cur = []
if cur:
    assert all(l.strip().startswith('fir.freemem') or not l.strip() for l in cur), 'trailing non-statement lines: ' + cur[0]
    groups[-1] += cur
istore = groups[0]; assert istore[-1].strip().startswith('fir.store'), 'loop body must start with the index store'
ci = [k for k, g in enumerate(groups) if re.search(r'fir\.call @' + re.escape(callee) + r'\(', '\n'.join(g))][0]
pre, callg, post = groups[1:ci], groups[ci], groups[ci + 1:]
nested = callg[-1].strip() == '}'
if nested:
    # perfect nest: fission the inner loop exactly like a flat loop; the batch covers the outer range,
    # so the outer loop is dropped and the inner loop's pre/post statements run once over all columns
    inner_hdr = callg[0]; inner = callg[1:-1]; inner_indent = re.match(r'\s*', inner_hdr).group(0)
    ig, cur2, d2 = [], [], 0
    for l in inner:
        cur2.append(l); t = l.strip()
        if t.endswith('{'): d2 += 1; continue
        if t == '}': d2 -= 1; continue
        if d2: continue
        if t.startswith('fir.call @_Fortran') or t.startswith('fir.freemem'): continue
        if t.startswith('fir.store') or t.startswith('fir.call'): ig.append(cur2); cur2 = []
    if cur2: ig[-1] += cur2
    istore = ig[0]; hdr = inner_hdr; indent = inner_indent
    ci2 = [k for k, g in enumerate(ig) if re.search(r'fir\.call @' + re.escape(callee) + r'\(', g[-1])][0]
    pre, callg, post = ig[1:ci2], ig[ci2], ig[ci2 + 1:]
    others = groups[1:ci] + groups[ci + 1:]
    assert all(all(re.match(r'%\w+ = (fir\.convert|arith\.\w+|fir\.load) ', l.strip()) or l.strip().startswith('fir.store') or not l.strip() for l in g) for g in others), 'outer loop of a perfect nest must contain only the inner loop and index bookkeeping'
# a temp assigned in the loop and passed as the call's input marks the Lift group; its assign lands in
# _FortranAAssign whose box was built from the temp's base. Drop that group and read the raw array instead.
call_args = re.findall(r'%\w+', callg[-1].split('(', 1)[1])[:2]
def base_of(ssa, lines):
    txt = '\n'.join(lines)
    while True:
        m = re.search(re.escape(ssa) + r' = fir\.convert (%\w+) :', txt)
        if not m: return ssa
        ssa = m.group(1)
alltxt = callg
in_ssa = base_of(call_args[0], callg); out_ssa = base_of(call_args[1], callg)
lifted = []
if L.get('lift'):
    keep = []
    for g in pre:
        txt = '\n'.join(g)
        if re.search(r'fir\.embox ' + re.escape(in_ssa) + r'\(', txt) and '_FortranAAssign' in txt: lifted.append(g)
        elif re.search(r'fir\.store .* to %\w+ : !fir\.ref<!fir\.box<!fir\.array<\d+xf32>>>', txt) and re.search(r'fir\.embox ' + re.escape(in_ssa) + r'\(', txt): lifted.append(g)
        else: keep.append(g)
    assert len(lifted) == 1, f'expected one lifted assign into the call temp, found {len(lifted)}'
    pre = keep
# whole-array bases: the 2-D arrays the slices were taken from
def slice_base(ssa, g):
    # ssa is the array_coor result after base_of has stripped the converts
    txt = '\n'.join(g)
    m2 = re.search(re.escape(ssa) + r' = fir\.array_coor (%\w+)\((%\w+)\) %c1, [%\w, ]+ : \((!fir\.ref<!fir\.array<[\dx]+xf32>>)', txt)
    return (m2.group(1), m2.group(3)) if m2 else None
out_b = slice_base(out_ssa, callg); assert out_b, 'call output is not a column slice'
if L.get('lift'):
    # input: the raw array named by the analysis; find its FIR base by the declare with that uniq_name
    sym = L['lift']['in_sym']
    m = [l for l in fir if f'uniq_name = "{sym}"' in l and 'fir.declare' in l or (f'uniq_name = "{sym}"' in l and 'fir.address_of' in l)]
    dm = re.search(r'(%\w+) = fir\.declare .*uniq_name = "' + re.escape(sym) + r'"\} : \((!fir\.ref<!fir\.array<[\dx]+xf32>>)', '\n'.join(fir))
    assert dm, f'no declare for {sym}'
    in_b = (dm.group(1), dm.group(2))
else:
    in_b = slice_base(in_ssa, callg); assert in_b, 'call input is not a column slice'
callsite = [f'{indent}%fb_in = fir.convert {in_b[0]} : ({in_b[1]}) -> !fir.ref<!fir.array<?xf32>>',
            f'{indent}%fb_out = fir.convert {out_b[0]} : ({out_b[1]}) -> !fir.ref<!fir.array<?xf32>>',
            f'{indent}fir.call @{callee}_batched(%fb_in, %fb_out) proc_attrs<bind_c> fastmath<contract> : (!fir.ref<!fir.array<?xf32>>, !fir.ref<!fir.array<?xf32>>) -> ()']
def loop(gs):
    if not gs: return []
    return [hdr] + [l for g in [istore] + gs for l in g] + [indent + '}']
out = fir[:start] + loop(pre) + callsite + loop(post) + fir[end + 1:]
decl = [i for i, l in enumerate(out) if re.search(r'func\.func private @' + re.escape(callee) + r'\(', l)]
assert decl, 'no private declaration of the callee'
out.insert(decl[0] + 1, out[decl[0]].replace(f'@{callee}(', f'@{callee}_batched('))
sys.stderr.write(f'fission: pre={len(pre)} lifted={len(lifted)} post={len(post)} statements\n')
print('\n'.join(out))
