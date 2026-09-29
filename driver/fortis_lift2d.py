#!/usr/bin/env python3
# 2-D host statements around a batched (whole-array) call, at HLFIR.
#   fortis_lift2d.py <host.hlfir> <callee> -> JSON
# Recognizes three kinds of 2-deep scalar-store nests:
#   lift    do i / do k : A(i,k) = expr(A(i,k), v(k)..., consts)           (pre or post, on the model's own arrays)
#   layout  do i / do k : T(k,i) = cast(A(i,k))   before the call           (host array A -> call temporary T)
#           do i / do k : A(i,k) = cast(T(k,i))   after the call            (call temporary T -> host array A)
# and decides whether the whole boundary (pre lifts, layout in, call, layout out, post lifts) can be compiled
# as one GPU region: the call then reads A directly (its own element type and memory order) and the nests
# listed in 'drop' are removed from the host.
import re, sys, json
L = open(sys.argv[1]).read().split('\n'); callee = sys.argv[2]
decl = {}   # declare ssa -> (name, shape, elt)
for l in L:
    m = re.search(r'(%\w+):2 = hlfir\.declare .*uniq_name = "([^"]+)"\} : \(!fir\.ref<(!fir\.array<([\dx]+)x(f\d+)>|(f\d+|i32))>', l)
    if m:
        decl[m.group(1)] = (m.group(2), [int(x) for x in m.group(4).split('x')] if m.group(4) else None, m.group(5) or m.group(6))
calls = [i for i, l in enumerate(L) if re.search(r'fir\.call @' + re.escape(callee) + r'\(', l)]
if not calls:
    print(json.dumps({'ok': False, 'reject': 'no call to ' + callee})); sys.exit(0)
n = calls[-1]
defs = {}   # ssa -> rhs text (whole file, first definition wins)
for l in L:
    m = re.match(r'\s*(%[\w#]+)(?::\d+)? = (.*)', l)
    if m and m.group(1) not in defs: defs[m.group(1)] = m.group(2)
def sym_of(ssa):
    ssa = ssa.split('#')[0]; return decl.get(ssa)
def const_int(ref):
    ref = ref.split('#')[0]
    stores = [l for l in L if re.search(r'hlfir\.assign (%\w+) to ' + re.escape(ref) + r'#0 : i32', l)]
    if len(stores) != 1: return None
    v = re.search(r'hlfir\.assign (%\w+) to', stores[0]).group(1)
    d = [l for l in L if re.search(r'^\s*' + re.escape(v) + r' = ', l)]
    if d and 'fir.load' in d[0]:
        src = re.search(r'fir\.load (%\w+)', d[0]).group(1).split('#')[0]
        s2 = sym_of(src)
        if s2 and 'fortran_attrs = #fir.var_attrs<parameter>' in ''.join(l for l in L if src in l and 'declare' in l):
            g = [l for l in L if re.search(r'fir\.global .* @' + re.escape(s2[0]) + r'\b', l)]
            if g:
                gi = L.index(g[0]); c = re.search(r'arith\.constant (\d+) : i32', L[gi + 1])
                return int(c.group(1)) if c else None
    m = re.match(r'%c(\d+)_i32', v)
    return int(m.group(1)) if m else None
def bound(tok):
    m = re.match(r'%c(\d+)_i32', tok)
    if m: return int(m.group(1))
    d = [l for l in L if re.search(r'^\s*' + re.escape(tok) + r' = fir\.load ', l)]
    return const_int(re.search(r'fir\.load (%\w+)', d[0]).group(1)) if d else None
def nests():
    out = []
    for i, l in enumerate(L):
        m = re.search(r'^(\s*)fir\.do_loop (%\w+) = (%\S+) to (%\S+) step (%\S+)', l)
        if not m: continue
        ind = m.group(1)
        j = i + 1
        while j < len(L) and (L[j].strip().startswith('fir.store') or L[j].strip().startswith('%c')): j += 1
        m2 = re.search(r'^(\s*)fir\.do_loop (%\w+) = (%\S+) to (%\S+) step (%\S+)', L[j])
        if not m2 or len(m2.group(1)) <= len(ind): continue
        k = j + 1
        while not L[k].startswith(m2.group(1) + '}'): k += 1
        e = k + 1
        while not L[e].startswith(ind + '}'): e += 1
        out.append({'start': i, 'inner': j, 'end': k, 'oend': e, 'ovar': m.group(2), 'ivar': m2.group(2),
                    'olo': bound(m.group(3)), 'ohi': bound(m.group(4)), 'ilo': bound(m2.group(3)), 'ihi': bound(m2.group(4))})
    return out
def body_expr(nest):
    body = [L[i].strip() for i in range(nest['inner'] + 1, nest['end'])]
    istore = re.match(r'fir\.store (%\S+) to (%\S+)', body[0])
    if not istore: return None, 'inner loop does not start with the index store'
    ialloca = istore.group(2)
    ostore = None
    for i in range(nest['start'] + 1, nest['inner']):
        m = re.match(r'\s*fir\.store (%\S+) to (%\S+)', L[i])
        if m: ostore = m.group(2)
    ld = {}; assign = None
    for s in body[1:]:
        if s.startswith('%'):
            k, v = s.split(' = ', 1); ld[k] = v
        elif s.startswith('hlfir.assign'):
            if assign: return None, 'two assigns'
            assign = re.match(r'hlfir\.assign (%\w+) to (%\w+)', s).groups()
        else: return None, 'side effect: ' + s.split()[0]
    if not assign: return None, 'no assign'
    def idx(ssa):
        d = ld.get(ssa, '')
        if d.startswith('fir.convert'): return idx(re.search(r'fir\.convert (%\w+)', d).group(1))
        if d.startswith('fir.load'):
            r = re.search(r'fir\.load (%\S+)', d).group(1)
            return 'i' if r == ostore else 'k' if r == ialloca else None
        return None
    def acc(ssa):
        d = ld.get(ssa, '')
        m = re.match(r'hlfir\.designate (%\w+)#0 \(([^)]*)\)', d)
        if not m: return None
        s = sym_of(m.group(1)); parts = [p.strip() for p in m.group(2).split(',')]
        if not s: return None
        return (s, tuple(idx(p) for p in parts))
    def ev(ssa):
        d = ld.get(ssa, '')
        if d.startswith('fir.load'):
            a = acc(re.search(r'fir\.load (%\S+)', d).group(1))
            if not a: return ('ERR', 'load of non-array')
            (name, shape, elt), ix = a
            if ix == ('i', 'k') and len(shape) == 2: return ('A', name, shape)
            if ix == ('k', 'i') and len(shape) == 2: return ('T', name, shape)
            if ix == ('k',) and len(shape) == 1: return ('V', name, shape[0])
            if ix == ('i',) and len(shape) == 1: return ('U', name, shape[0])
            return ('ERR', 'unsupported access %s%s' % (name, ix))
        if d.startswith('hlfir.no_reassoc'): return ev(re.search(r'no_reassoc (%\w+)', d).group(1))
        if d.startswith('arith.constant'): return ('C', re.search(r'arith\.constant ([-\d.eE+]+)', d).group(1))
        m = re.match(r'fir\.convert (%\w+) : \((\w+)\) -> (\w+)', d)
        if m: return ('cast', m.group(3), ev(m.group(1)))
        m = re.match(r'(arith\.(?:addf|subf|mulf|divf)) (%\w+), (%\w+)', d)
        if m: return (m.group(1), ev(m.group(2)), ev(m.group(3)))
        return ('ERR', 'op ' + d.split()[0])
    tgt = acc(assign[1])
    if not tgt or len(tgt[0][1]) != 2: return None, 'target is not a 2-D array element'
    tree = ev(assign[0])
    def errs(t): return [t[1]] if t[0] == 'ERR' else sum((errs(c) for c in t[1:] if isinstance(c, tuple)), [])
    e = errs(tree)
    if e: return None, e[0]
    (tname, tshape, telt), tix = tgt
    bounds = (nest['olo'], nest['ohi'], nest['ilo'], nest['ihi'])
    if None in bounds: return None, 'loop bound is not a compile-time constant'
    src = tree[2] if tree[0] == 'cast' else tree
    if tix == ('k', 'i'):
        if src[0] != 'A' or (tree[0] == 'cast' and tree[1] != telt): return None, 'T(k,i) target with non-transpose body'
        if bounds != (1, src[2][0], 1, src[2][1]) or tshape != src[2][::-1]: return None, 'transpose nest does not cover the arrays'
        return {'kind': 'layout', 'dir': 'in', 'from': src[1], 'from_shape': src[2], 'from_elt': sym_elt(src[1]),
                'to': tname, 'to_shape': tshape, 'to_elt': telt}, None
    if src[0] == 'T':
        if tree[0] == 'cast' and tree[1] != telt: return None, 'A(i,k) target with non-transpose body'
        if bounds != (1, tshape[0], 1, tshape[1]) or src[2] != tshape[::-1]: return None, 'transpose nest does not cover the arrays'
        return {'kind': 'layout', 'dir': 'out', 'from': src[1], 'from_shape': src[2], 'from_elt': sym_elt(src[1]),
                'to': tname, 'to_shape': tshape, 'to_elt': telt}, None
    def leaves(t): return [t] if t[0] in ('A', 'T', 'V', 'U', 'C', 'cast') else sum((leaves(c) for c in t[1:]), [])
    for lf in leaves(tree):
        if lf[0] == 'A' and lf[1] != tname: return None, 'reads another 2-D array ' + lf[1]
        if lf[0] in ('T', 'U', 'cast'): return None, 'unsupported leaf ' + lf[0]
    if bounds != (1, tshape[0], 1, tshape[1]): return None, 'lift nest does not cover the array'
    return {'kind': 'lift', 'target': tname, 'shape': tshape, 'elt': telt, 'expr': tree}, None
def sym_elt(name):
    for k, v in decl.items():
        if v[0] == name: return v[2]
    return None
def decl_ssa(name):
    for k, v in decl.items():
        if v[0] == name: return k
    return None
# call operands -> host symbols
def arg_sym(op):
    seen = 0
    while op in defs and seen < 8:
        d = defs[op]
        m = re.match(r'fir\.convert (%[\w#]+)', d)
        if not m: break
        op = m.group(1); seen += 1
    s = sym_of(op); return s[0] if s else None
call_ops = [o.strip() for o in re.search(r'fir\.call @' + re.escape(callee) + r'\((.*?)\)', L[n]).group(1).split(',')]
call_args = [arg_sym(o) for o in call_ops]
res = {'ok': False, 'callee': callee, 'call_line': n, 'call_args': call_args, 'nests': [], 'layout': {}, 'pre': None, 'post': None, 'drop': []}
found = []
for nest in nests():
    r, why = body_expr(nest)
    if not r: continue
    r['line'] = nest['start']; r['end'] = nest['oend']; r['side'] = 'pre' if nest['start'] < n else 'post'
    found.append(r); res['nests'].append(r)
def reject(msg):
    res['reject'] = msg; print(json.dumps(res, indent=1)); sys.exit(0)
if len(call_args) < 2 or None in call_args: reject('call operands are not host arrays')
lin = [r for r in found if r['kind'] == 'layout' and r['dir'] == 'in' and r['side'] == 'pre' and r['to'] == call_args[0]]
lout = [r for r in found if r['kind'] == 'layout' and r['dir'] == 'out' and r['side'] == 'post' and r['from'] == call_args[1]]
if not lin: reject('no transpose nest feeding the call input ' + call_args[0])
if not lout: reject('no transpose nest reading the call output ' + call_args[1])
lin = lin[-1]; lout = lout[0]
res['layout'] = {'in': lin, 'out': lout}
pre = [r for r in found if r['kind'] == 'lift' and r['side'] == 'pre' and r['target'] == lin['from'] and r['line'] < lin['line']]
post = [r for r in found if r['kind'] == 'lift' and r['side'] == 'post' and r['target'] == lout['to'] and r['line'] > lout['line']]
def compose(nests_):
    if not nests_: return None
    expr = nests_[0]['expr']
    def subst(t, a):
        if t[0] == 'A': return a
        if t[0] in ('V', 'C'): return t
        return (t[0],) + tuple(subst(c, a) for c in t[1:])
    for r in nests_[1:]: expr = subst(r['expr'], expr)
    def vs(t): return [(t[1], t[2])] if t[0] == 'V' else sum((vs(c) for c in t[1:] if isinstance(c, tuple)), []) if t[0] not in ('A', 'C') else []
    syms = []; sizes = {}
    for s, k in vs(expr):
        if s not in sizes: syms.append(s); sizes[s] = k
    return {'target': nests_[0]['target'], 'shape': nests_[0]['shape'], 'elt': nests_[0]['elt'], 'expr': expr, 'globals': syms, 'sizes': sizes,
            'lines': [[r['line'], r['end']] for r in nests_]}
res['pre'] = compose(pre); res['post'] = compose(post)
# statements between the first dropped nest and the last one must not touch the boundary arrays
drop = [[r['line'], r['end']] for r in pre + [lin, lout] + post]
lo = min(d[0] for d in drop); hi = max(d[1] for d in drop)
involved = {lin['from'], lin['to'], lout['from'], lout['to']}
for side in (res['pre'], res['post']):
    if side: involved |= set(side['globals'])
ssas = {decl_ssa(s): s for s in involved if decl_ssa(s)}
# operands of the call itself (their fir.convert chains) are rewritten by the transform, so they are exempt
exempt = set()
for o in call_ops:
    op = o
    while op in defs:
        exempt.add(op.split('#')[0]); m = re.match(r'fir\.convert (%[\w#]+)', defs[op])
        if not m: break
        op = m.group(1)
def uses(r, a, b):
    return [j for j in range(a, b + 1) if re.search(re.escape(r) + r'\b', L[j]) and not re.match(r'\s*' + re.escape(r) + r'(:\d+)? = ', L[j])]
dead = []
for i in range(lo, hi + 1):
    if any(a <= i <= b for a, b in drop + dead) or i == n: continue
    l = L[i]
    m = re.match(r'\s*(%[\w#]+)(?::\d+)? = ', l)
    if m and m.group(1).split('#')[0] in exempt: continue
    for ssa, name in ssas.items():
        if not re.search(re.escape(ssa) + r'#', l): continue
        if name in (lin['to'], lout['from']):
            # a whole-array constant fill of a call temporary (direct, or through a section designate) is dead once the transposes go
            if re.match(r'\s*hlfir\.assign %cst\w* to ' + re.escape(ssa) + r'#0 : f\d+, !fir\.ref<!fir\.array<[\dx]+xf\d+>>', l):
                dead.append([i, i]); break
            md = re.match(r'\s*(%\w+) = hlfir\.designate ' + re.escape(ssa) + r'#0 \(', l)
            if md:
                u = uses(md.group(1), lo, hi)
                if len(u) == 1 and re.match(r'\s*hlfir\.assign %cst\w* to ' + re.escape(md.group(1)) + r' :', L[u[0]]):
                    dead += [[i, i], [u[0], u[0]]]; break
        reject('statement between the lifted nests touches ' + name + ' (line %d)' % i)
# the call temporaries must be dead outside the region (Theorem 2, last hypothesis)
for name in (lin['to'], lout['from']):
    ssa = decl_ssa(name)
    if not ssa: continue
    for i, l in enumerate(L):
        if lo <= i <= hi or 'hlfir.declare' in l or 'fir.address_of' in l: continue
        if re.search(re.escape(ssa) + r'#', l): reject('call temporary ' + name + ' is referenced outside the region (line %d)' % i)
res['drop'] = sorted(drop + dead)
res['new_args'] = [lin['from'], lout['to']]
res['ok'] = True
print(json.dumps(res, indent=1))
