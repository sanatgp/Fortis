#!/usr/bin/env python3
# Stencil lift.  When every pre-loop unit of a distributed general body is a section gather from host
# arrays into the call's input temporary, a scalar read of a host-array element, or an elementwise
# expression over the temporary with those scalars and constants, the pre-loop becomes one gather kernel
# in front of the model that reads the host's own arrays, and the pack of the temporary disappears.
#   fortis_gather.py <host.hlfir> <loop.json> -> gather.json
import re, sys, json
L = open(sys.argv[1]).read().split('\n'); d = json.load(open(sys.argv[2]))
def out(o): print(json.dumps(o, indent=1)); sys.exit(0)
def rej(r): out({'ok': False, 'reason': r})
if d.get('verdict') != 'batched' or d.get('mode') != 'expanded': rej('not an expanded batched loop')
if d.get('batch') is None: rej('run-time count; stencil lift needs static bounds')
inner, outer, x = d['inner'], d['outer'], d['in_ssa']; nin = d['in_shape'][0]
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
slots = [None] * nin; scalars = {}; exprs = []
for s in d['statements']:
    if s['side'] not in ('pre', 'both'): continue
    k = s['lo']; t = L[k].strip()
    m = re.match(r'hlfir\.assign (%\w+) to (%[\w#]+)', t)
    if not m or s['hi'] != s['lo']: rej('pre-loop unit at line %d is not a single assignment' % k)
    src, dst = m.group(1), m.group(2); sd = defat(src, k)
    if not sd: rej('line %d: source not found' % k)
    if sd[1].startswith('hlfir.reshape'):
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
        if not tm or tm.group(1).split('#')[0] != x: rej('line %d: reshape target is not the call input' % k)
        tp = [q.strip() for q in tm.group(2).split(':')]
        lo, hi = index_of(tp[0], dd[0]), index_of(tp[1], dd[0])
        if not lo or not hi or lo[0] != 'k' or hi[0] != 'k': rej('line %d: target section is not constant' % k)
        n = hi[1] - lo[1] + 1
        ext = [(dm_[3] - dm_[2] + 1) for dm_ in dims if dm_[0] == 'range']
        if n != eval('*'.join(map(str, ext)) or '1'): rej('line %d: section size does not match target' % k)
        for q in range(n):
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
        S = dst.split('#')[0]; scalars[S] = {'name': 'S%d' % len(scalars), 'decl': decl[S]['name'], 'array': array_id(A), 'idx': idx}
    elif sd[1].startswith('hlfir.elemental'):
        dd = defat(dst.split('#')[0], k); tm = designate(dd[1]) if dd else None
        if not tm or tm.group(1).split('#')[0] != x: rej('line %d: elemental target is not the call input' % k)
        tp = [q.strip() for q in tm.group(2).split(':')]
        if index_of(tp[0], dd[0]) != ('k', 1) or index_of(tp[1], dd[0]) != ('k', nin): rej('line %d: elemental does not cover the call input' % k)
        e = sd[0]
        while not re.search(r'hlfir\.yield_element', L[e]): e += 1
        y = re.search(r'hlfir\.yield_element (%\w+)', L[e]).group(1)
        def tr(v, kk, depth=0):
            if depth > 40: rej('expression too deep')
            vd = defat(v, kk)
            if not vd: rej('line %d: value %s not found' % (kk, v))
            t2 = vd[1]
            m2 = re.match(r'arith\.constant ([-\d.eE+]+) : f(32|64)', t2)
            if m2: return m2.group(1) + ('f' if m2.group(2) == '32' else '')
            m2 = re.match(r'fir\.load (%[\w#]+)', t2)
            if m2:
                r = m2.group(1)
                if r.endswith('#0') and r.split('#')[0] in scalars: return scalars[r.split('#')[0]]['name']
                rd = defat(r, vd[0]); dm = designate(rd[1]) if rd else None
                if dm:
                    base = dm.group(1).split('#')[0]
                    bd = defat(base, rd[0]); bm = designate(bd[1]) if bd else None
                    if bm and bm.group(1).split('#')[0] == x: return 'xv'
                rej('line %d: operand %s is neither the call input nor a lifted scalar' % (vd[0], v))
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
            rej('line %d: unsupported operation in elemental: %s' % (vd[0], t2.split()[0]))
        exprs.append(tr(y, e))
    else: rej('pre-loop unit at line %d is not a gather, a scalar read, or an elementwise expression' % k)
if any(s is None for s in slots): rej('the call input is not fully defined by section gathers')
out({'ok': True, 'nin': nin, 'args': [{'alloca': a, 'name': decl[a]['name']} for a in args],
     'arrays': [{'ssa': a, 'name': decl[a]['name'], 'shape': decl[a]['shape'], 'elt': decl[a]['elt']} for a in arrays],
     'slots': slots, 'scalars': list(scalars.values()), 'exprs': exprs,
     'reason': 'pre-loop lifted: %d slots gathered from %s, %d scalars, %d elementwise expressions' % (nin, ', '.join(decl[a]['name'] for a in arrays), len(scalars), len(exprs))})
