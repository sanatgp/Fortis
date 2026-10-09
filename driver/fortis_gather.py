#!/usr/bin/env python3
# Stencil lift, either side of the call.
#   fortis_gather.py <host.hlfir> <loop.json> pre  -> gather.json
#   fortis_gather.py <host.hlfir> <loop.json> post -> scatter.json
# pre: every pre-loop unit is a section gather from a host array into the call's input temporary, a scalar
# read of a host-array element, or an elementwise expression over the temporary with such scalars and
# constants; the pre-loop becomes one kernel in front of the model that reads the host's arrays.
# post: every post-loop unit is a scalar read, an elementwise expression over the call's output temporary,
# or a store of one of its elements into a host array at the cell; the post-loop becomes one kernel after
# the model that writes the visited rectangle of each host array.
import re, sys, json
L = open(sys.argv[1]).read().split('\n'); d = json.load(open(sys.argv[2])); side = sys.argv[3]
def out(o): print(json.dumps(o, indent=1)); sys.exit(0)
def rej(r): out({'ok': False, 'reason': r})
if d.get('verdict') != 'batched' or d.get('mode') != 'expanded': rej('not an expanded batched loop')
if d.get('batch') is None: rej('run-time count; stencil lift needs static bounds')
inner, outer = d['inner'], d['outer']
tmp = d['in_ssa'] if side == 'pre' else d['out_ssa']; n = (d['in_shape'] if side == 'pre' else d['out_shape'])[0]
sides = ('pre', 'both') if side == 'pre' else ('post', 'both')
decl = {}
for l in L:
    m = re.search(r'(%\w+):2 = hlfir\.declare .*uniq_name = "([^"]+)"\} : \(!fir\.ref<(!fir\.array<([\dx]+)x(\w+)>|(\w+))>', l)
    if m: decl[m.group(1)] = {'name': m.group(2), 'shape': [int(v) for v in m.group(4).split('x')] if m.group(4) else None, 'elt': m.group(5) or m.group(6)}
defs = {}
for i, l in enumerate(L):
    m = re.match(r'\s*(%\w+)(?::\d+)? = (.*)', l)
    if m: defs.setdefault(m.group(1), []).append((i, m.group(2)))
def defat(name, k):
    best = None
    for dd, txt in defs.get(name, []):
        if dd < k: best = (dd, txt)
    return best
loopvars = set(re.findall(r'fir\.store %arg\d+ to (%\w+)#0', '\n'.join(L)))
allocas = {inner['alloca']: 'i'}
if outer: allocas[outer['alloca']] = 'j'
args = []
def index_of(ssa, k, depth=0):
    if depth > 12: return None
    m = re.match(r'%c(-?\d+)', ssa)
    if m: return ('k', int(m.group(1)))
    dd = defat(ssa, k)
    if not dd: return None
    t = dd[1]
    if t.startswith('fir.convert'): return index_of(re.search(r'fir\.convert (%\S+)', t).group(1), k, depth + 1)
    m = re.match(r'fir\.load (%\w+)#0', t)
    if m:
        a = m.group(1)
        if a in allocas: return (allocas[a], 0)
        if a in loopvars:
            if a not in args: args.append(a)
            return ('v', args.index(a))
        return None
    m = re.match(r'arith\.(addi|subi) (%\w+), (%\w+)', t)
    if m:
        a, b = index_of(m.group(2), k, depth + 1), index_of(m.group(3), k, depth + 1)
        if a and b and a[0] in 'ij' and b[0] == 'k': return (a[0], a[1] + b[1] if m.group(1) == 'addi' else a[1] - b[1])
        if a and b and a[0] == 'k' and b[0] in 'ij' and m.group(1) == 'addi': return (b[0], b[1] + a[1])
    return None
def designate(txt): return re.match(r'hlfir\.designate (%[\w#]+) \(([^)]*)\)', txt)
arrays = []
def array_id(a):
    if a not in arrays: arrays.append(a)
    return arrays.index(a)
def point_idx(parts, k):
    idx = []
    for p in parts:
        c = index_of(p.strip(), k)
        if not c or c[0] == 'k': return None
        idx.append([c[0], c[1]])
    return idx
scalars = []; by_decl = {}; by_read = {}
def scalar_for(A, idx, decl_ssa=None):
    key = (A, json.dumps(idx))
    if key in by_read: return by_read[key]
    s = {'name': 'S%d' % len(scalars), 'array': array_id(A), 'idx': idx}; scalars.append(s); by_read[key] = s['name']
    if decl_ssa: by_decl[decl_ssa] = s['name']
    return s['name']
def is_tmp_element(ref, k):
    # a designate of the temporary, directly (y(1)) or through a section of it (x(1:27)(%arg))
    rd = defat(ref, k); dm = designate(rd[1]) if rd else None
    if not dm: return None
    base = dm.group(1).split('#')[0]
    if base == tmp: return dm
    bd = defat(base, rd[0]); bm = designate(bd[1]) if bd else None
    if bm and bm.group(1).split('#')[0] == tmp: return dm
    return None
def tr(v, kk, depth=0):
    if depth > 60: rej('expression too deep')
    vd = defat(v, kk)
    if not vd: rej('line %d: value %s not found' % (kk, v))
    t2 = vd[1]
    m2 = re.match(r'arith\.constant ([-\d.eE+]+) : f(32|64)', t2)
    if m2: return m2.group(1) + ('f' if m2.group(2) == '32' else '')
    m2 = re.match(r'hlfir\.apply (%\w+), ', t2)
    if m2: return elem_expr(m2.group(1), vd[0], depth + 1)
    m2 = re.match(r'fir\.load (%[\w#]+)', t2)
    if m2:
        r = m2.group(1)
        if r.endswith('#0') and r.split('#')[0] in by_decl: return by_decl[r.split('#')[0]]
        if is_tmp_element(r, vd[0]): return 'tv'
        rd = defat(r, vd[0]); dm = designate(rd[1]) if rd else None
        if dm:
            base = dm.group(1).split('#')[0]
            if base in decl and decl[base]['shape']:
                idx = point_idx(dm.group(2).split(','), rd[0])
                if idx is None: rej('line %d: array read with a non-affine subscript' % rd[0])
                return scalar_for(base, idx)
        rej('line %d: operand %s is neither the temporary nor a host-array element' % (vd[0], v))
    m2 = re.match(r'hlfir\.no_reassoc (%\w+)', t2)
    if m2: return tr(m2.group(1), vd[0], depth + 1)
    m2 = re.match(r'arith\.(addf|subf|mulf|divf) (%\w+), (%\w+)', t2)
    if m2:
        op = {'addf': '+', 'subf': '-', 'mulf': '*', 'divf': '/'}[m2.group(1)]
        return '(' + tr(m2.group(2), vd[0], depth + 1) + ' ' + op + ' ' + tr(m2.group(3), vd[0], depth + 1) + ')'
    m2 = re.match(r'arith\.negf (%\w+)', t2)
    if m2: return '(-' + tr(m2.group(1), vd[0], depth + 1) + ')'
    m2 = re.match(r'math\.(sqrt|exp|log|tanh) (%\w+)', t2)
    if m2: return m2.group(1) + 'f(' + tr(m2.group(2), vd[0], depth + 1) + ')'
    m2 = re.match(r'arith\.(maximumf|minimumf) (%\w+), (%\w+)', t2)
    if m2: return ('fmaxf' if m2.group(1) == 'maximumf' else 'fminf') + '(' + tr(m2.group(2), vd[0], depth + 1) + ', ' + tr(m2.group(3), vd[0], depth + 1) + ')'
    rej('line %d: unsupported operation: %s' % (vd[0], t2.split()[0]))
def elem_expr(E, k, depth=0):
    ed = defat(E, k)
    if not ed or not ed[1].startswith('hlfir.elemental'): rej('line %d: %s is not an elemental' % (k, E))
    e = ed[0]
    while not re.search(r'hlfir\.yield_element', L[e]): e += 1
    return tr(re.search(r'hlfir\.yield_element (%\w+)', L[e]).group(1), e, depth)
def full_range(dst, k):
    dd = defat(dst.split('#')[0], k); tm = designate(dd[1]) if dd else None
    if not tm or tm.group(1).split('#')[0] != tmp: return False
    tp = [q.strip() for q in tm.group(2).split(':')]
    return len(tp) == 3 and index_of(tp[0], dd[0]) == ('k', 1) and index_of(tp[1], dd[0]) == ('k', n)
slots = [None] * n; exprs = []; stores = []
for s in d['statements']:
    if s['side'] not in sides: continue
    k = s['lo']; t = L[k].strip()
    m = re.match(r'hlfir\.assign (%\w+) to (%[\w#]+)', t)
    if not m or s['hi'] != s['lo']: rej('unit at line %d is not a single assignment' % k)
    src, dst = m.group(1), m.group(2); sd = defat(src, k)
    if not sd: rej('line %d: source not found' % k)
    if side == 'pre' and sd[1].startswith('hlfir.reshape'):
        sec = re.match(r'hlfir\.reshape (%\w+)', sd[1]).group(1); secd = defat(sec, sd[0]); dm = designate(secd[1]) if secd else None
        if not dm: rej('line %d: reshape of something other than an array section' % k)
        A = dm.group(1).split('#')[0]
        if A not in decl or not decl[A]['shape']: rej('line %d: section of a non-static array' % k)
        dims = []
        for p in dm.group(2).split(','):
            p = p.strip()
            if ':' in p:
                lo, hi, st = [q.strip() for q in p.split(':')]
                if index_of(st, secd[0]) != ('k', 1): rej('line %d: section stride is not 1' % k)
                a, b = index_of(lo, secd[0]), index_of(hi, secd[0])
                if not a or not b or a[0] != b[0] or a[0] not in 'ij': rej('line %d: section bounds are not affine in the loop index' % k)
                dims.append(('range', a[0], a[1], b[1]))
            else:
                c = index_of(p, secd[0])
                if not c or c[0] == 'k': rej('line %d: section subscript is not a loop index' % k)
                dims.append(('point', c[0], c[1]))
        dd = defat(dst.split('#')[0], k); tm = designate(dd[1]) if dd else None
        if not tm or tm.group(1).split('#')[0] != tmp: rej('line %d: reshape target is not the call input' % k)
        tp = [q.strip() for q in tm.group(2).split(':')]
        lo, hi = index_of(tp[0], dd[0]), index_of(tp[1], dd[0])
        if not lo or not hi or lo[0] != 'k' or hi[0] != 'k': rej('line %d: target section is not constant' % k)
        cnt = hi[1] - lo[1] + 1
        ext = [(dm_[3] - dm_[2] + 1) for dm_ in dims if dm_[0] == 'range']
        if cnt != eval('*'.join(map(str, ext)) or '1'): rej('line %d: section size does not match target' % k)
        for q in range(cnt):
            r, idx = q, []
            for dm_ in dims:
                if dm_[0] == 'range':
                    e = dm_[3] - dm_[2] + 1; idx.append([dm_[1], dm_[2] + r % e]); r //= e
                else: idx.append([dm_[1], dm_[2]])
            if slots[lo[1] - 1 + q] is not None: rej('line %d: slot %d defined twice' % (k, lo[1] + q))
            slots[lo[1] - 1 + q] = {'array': array_id(A), 'idx': idx}
    elif sd[1].startswith('fir.load') and dst.endswith('#0') and dst.split('#')[0] in decl and decl[dst.split('#')[0]]['shape'] is None:
        ref = re.match(r'fir\.load (%\w+)', sd[1]).group(1); rd = defat(ref, sd[0]); dm = designate(rd[1]) if rd else None
        if not dm: rej('line %d: scalar is not a host-array element' % k)
        A = dm.group(1).split('#')[0]
        if A not in decl or not decl[A]['shape']: rej('line %d: scalar read of a non-static array' % k)
        idx = point_idx(dm.group(2).split(','), rd[0])
        if idx is None: rej('line %d: scalar subscript is not a loop index' % k)
        scalar_for(A, idx, dst.split('#')[0])
    elif sd[1].startswith('hlfir.elemental'):
        if not full_range(dst, k): rej('line %d: elemental does not cover the temporary' % k)
        exprs.append(elem_expr(src, k))
    elif side == 'post' and sd[1].startswith('fir.load'):
        ref = re.match(r'fir\.load (%\w+)', sd[1]).group(1); em = is_tmp_element(ref, sd[0])
        if not em: rej('line %d: store source is not an element of the call output' % k)
        c = index_of(em.group(2).strip(), sd[0])
        if not c or c[0] != 'k': rej('line %d: stored element is not a constant slot' % k)
        dd = defat(dst.split('#')[0], k); dm = designate(dd[1]) if dd else None
        if not dm: rej('line %d: store target is not a host-array element' % k)
        A = dm.group(1).split('#')[0]
        if A not in decl or not decl[A]['shape']: rej('line %d: store into a non-static array' % k)
        idx = point_idx(dm.group(2).split(','), dd[0])
        if idx is None: rej('line %d: store subscript is not a loop index' % k)
        stores.append({'slot': c[1] - 1, 'array': array_id(A), 'idx': idx})
    else: rej('unit at line %d is not liftable (%s)' % (k, sd[1].split()[0]))
if side == 'pre' and any(s is None for s in slots): rej('the call input is not fully defined by section gathers')
if side == 'post' and not stores: rej('no store of the call output into a host array')
res = {'ok': True, 'n': n, 'args': [{'alloca': a, 'name': decl[a]['name']} for a in args],
       'arrays': [{'ssa': a, 'name': decl[a]['name'], 'shape': decl[a]['shape'], 'elt': decl[a]['elt']} for a in arrays],
       'scalars': scalars, 'exprs': exprs}
if side == 'pre':
    res['slots'] = slots
    res['reason'] = 'pre-loop lifted: %d slots gathered from %s, %d scalars, %d expressions' % (n, ', '.join(decl[a]['name'] for a in arrays), len(scalars), len(exprs))
else:
    res['stores'] = stores
    res['reason'] = 'post-loop lifted: %d expressions, %d stores into %s' % (len(exprs), len(stores), ', '.join(decl[arrays[s['array']]]['name'] for s in stores))
out(res)
