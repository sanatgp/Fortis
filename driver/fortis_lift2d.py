#!/usr/bin/env python3
# 2-D elementwise host statements around a batched call, at HLFIR.
#   fortis_lift2d.py <host.hlfir> <callee> -> JSON
# Matches a 2-deep scalar-store nest  do i / do k : A(i,k) = expr(A(i,k), v1(k), v2(k), ..., consts)
# writing the array A whose transpose-cast feeds the call (pre) or is fed by it (post).
# Also recognizes the transpose-cast nests themselves, T(k,i) = real(A(i,k)), as a layout fact.
import re, sys, json
L = open(sys.argv[1]).read().split('\n'); callee = sys.argv[2]
decl = {}   # ssa -> (name, shape, elt)
for l in L:
    m = re.search(r'(%\w+):2 = hlfir\.declare .*uniq_name = "([^"]+)"\} : \(!fir\.ref<(!fir\.array<([\dx]+)x(f\d+)>|(f\d+|i32))>', l)
    if m:
        decl[m.group(1)] = (m.group(2), [int(x) for x in m.group(4).split('x')] if m.group(4) else None, m.group(5) or m.group(6))
n = [i for i, l in enumerate(L) if re.search(r'fir\.call @' + re.escape(callee) + r'\(', l)][-1]
def sym_of(ssa):
    ssa = ssa.split('#')[0]; return decl.get(ssa)
# constant value of a scalar integer variable assigned exactly once from a constant
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
        # inner loop directly after the index store and constants
        j = i + 1
        while j < len(L) and (L[j].strip().startswith('fir.store') or L[j].strip().startswith('%c')): j += 1
        m2 = re.search(r'^(\s*)fir\.do_loop (%\w+) = (%\S+) to (%\S+) step (%\S+)', L[j])
        if not m2 or len(m2.group(1)) <= len(ind): continue
        k = j + 1
        while not L[k].startswith(m2.group(1) + '}'): k += 1
        out.append({'start': i, 'inner': j, 'end': k, 'ovar': m.group(2), 'ivar': m2.group(2), 'olo': bound(m.group(3)), 'ohi': bound(m.group(4)), 'ilo': bound(m2.group(3)), 'ihi': bound(m2.group(4))})
    return out
def body_expr(nest):
    body = [L[i].strip() for i in range(nest['inner'] + 1, nest['end'])]
    istore = re.match(r'fir\.store (%\S+) to (%\S+)', body[0]); ialloca = istore.group(2)
    ostore = None
    for i in range(nest['start'] + 1, nest['inner']):
        m = re.match(r'\s*fir\.store (%\S+) to (%\S+)', L[i])
        if m: ostore = m.group(2)
    defs = {}; assign = None
    for s in body[1:]:
        if s.startswith('%'):
            k, v = s.split(' = ', 1); defs[k] = v
        elif s.startswith('hlfir.assign'):
            if assign: return None, 'two assigns'
            assign = re.match(r'hlfir\.assign (%\w+) to (%\w+)', s).groups()
        else: return None, 'side effect: ' + s.split()[0]
    def idx(ssa):   # which loop index a load-convert chain refers to
        d = defs.get(ssa, '')
        if d.startswith('fir.convert'): return idx(re.search(r'fir\.convert (%\w+)', d).group(1))
        if d.startswith('fir.load'):
            r = re.search(r'fir\.load (%\S+)', d).group(1)
            return 'i' if r == ostore else 'k' if r == ialloca else None
        return None
    def acc(ssa):
        d = defs.get(ssa, '')
        m = re.match(r'hlfir\.designate (%\w+)#0 \(([^)]*)\)', d)
        if not m: return None
        s = sym_of(m.group(1)); parts = [p.strip() for p in m.group(2).split(',')]
        return (s, tuple(idx(p) for p in parts))
    def ev(ssa):
        d = defs.get(ssa, '')
        if d.startswith('fir.load'):
            a = acc(re.search(r'fir\.load (%\S+)', d).group(1))
            if not a: return ('ERR', 'load of non-array')
            (name, shape, elt), ix = a
            if ix == ('i', 'k') and len(shape) == 2: return ('A', name, shape)
            if ix == ('k',) and len(shape) == 1: return ('V', name, shape[0])
            if ix == ('i',) and len(shape) == 1: return ('U', name, shape[0])
            return ('ERR', f'unsupported access {name}{ix}')
        if d.startswith('hlfir.no_reassoc'): return ev(re.search(r'no_reassoc (%\w+)', d).group(1))
        if d.startswith('arith.constant'): return ('C', re.search(r'arith\.constant ([-\d.eE+]+)', d).group(1))
        m = re.match(r'(arith\.(?:addf|subf|mulf|divf)) (%\w+), (%\w+)', d)
        if m: return (m.group(1), ev(m.group(2)), ev(m.group(3)))
        return ('ERR', 'op ' + d.split()[0])
    tgt = acc(assign[1])
    if not tgt or tgt[1] != ('i', 'k') or len(tgt[0][1]) != 2: return None, 'target is not A(i,k)'
    tree = ev(assign[0])
    def errs(t): return [t[1]] if t[0] == 'ERR' else sum((errs(c) for c in t[1:] if isinstance(c, tuple)), [])
    e = errs(tree)
    if e: return None, e[0]
    return {'target': tgt[0][0], 'shape': tgt[0][1], 'elt': tgt[0][2], 'expr': tree}, None
res = {'pre': [], 'post': [], 'layout': {}}
for nest in nests():
    r, why = body_expr(nest)
    if not r:
        continue
    nest_bounds = (nest['olo'], nest['ohi'], nest['ilo'], nest['ihi'])
    r['bounds'] = nest_bounds; r['line'] = nest['start']
    if None in nest_bounds: r['reject'] = 'loop bound is not a compile-time constant'
    (res['pre'] if nest['start'] < n else res['post']).append(r)
print(json.dumps(res, indent=1))
