#!/usr/bin/env python3
# Call-centric loop distribution over a general host loop body, at HLFIR.
#   fortis_units.py <host.hlfir> <callee> -> JSON
# The body is a sequence of units in program order: assignments, stores, runtime calls, and compound
# blocks (inner do loops, if, where), each with the host variables it reads and writes and, for every
# host-array access, the column it touches (this iteration's column, another column, or unknown).
# The call reads one temporary and writes one temporary.  Pre is the transitive dependence closure of
# the call, Post is the rest.  Theorem 1 holds when every write to a host array is to this iteration's
# column and no host array is read by Pre and written by Post at a different column.  The two call
# temporaries are expanded across the batch (packed after the pre-loop body, unpacked before the
# post-loop body); every other variable the body writes must be private, written before it is read.
import re, sys, json

def analyze(path, callee):
    L = open(path).read().split('\n')
    decl = {}   # declare ssa -> {name, shape (list or None), elt}
    for l in L:
        m = re.search(r'(%\w+):2 = hlfir\.declare .*uniq_name = "([^"]+)"\} : \(!fir\.ref<(!fir\.array<([\dx]+)x(\w+)>|(\w+))>', l)
        if m:
            decl[m.group(1)] = {'name': m.group(2), 'shape': [int(x) for x in m.group(4).split('x')] if m.group(4) else None, 'elt': m.group(5) or m.group(6)}
            continue
        m = re.search(r'(%\w+):2 = hlfir\.declare .*uniq_name = "([^"]+)"\} : \(!fir\.ref<!fir\.box<!fir\.heap<!fir\.array<((?:\?x)*\?)x([\w!<>.]+)>>>>', l)
        if m:
            decl[m.group(1)] = {'name': m.group(2), 'shape': [None] * (m.group(3).count('?')), 'elt': m.group(4), 'box': True}
    def rej(r): return {'verdict': 'reject', 'reason': r}
    calls = [i for i, l in enumerate(L) if re.search(r'fir\.call @' + re.escape(callee) + r'\(', l)]
    if not calls: return rej('no call to ' + callee)
    n = calls[-1]
    def opens(s): return s.endswith('{') and not s.startswith('}')
    def closes(s): return s.startswith('}') and not s.endswith('{')
    # block stack of every line (list of opener lines)
    stack, stacks = [], []
    for i, l in enumerate(L):
        s = l.strip()
        if closes(s): stack.pop()
        stacks.append(tuple(stack))
        if opens(s): stack.append(i)
    def block_end(k):
        depth = 0
        for i in range(k + 1, len(L)):
            s = L[i].strip()
            if opens(s): depth += 1
            elif closes(s):
                if depth: depth -= 1
                else: return i
        return None
    # definitions by name, resolved by scope: the nearest earlier definition whose block encloses the use
    defl = {}
    for i, l in enumerate(L):
        m = re.match(r'\s*(%\w+)(?::\d+)? = (.*)', l)
        if m: defl.setdefault(m.group(1), []).append((i, m.group(2)))
    def defat(name, k):
        best = None
        for d, txt in defl.get(name, []):
            if d < k and stacks[k][:len(stacks[d])] == stacks[d]: best = (d, txt)
        return best
    lm = r'fir\.do_loop (%\w+) = (%\S+) to (%\S+) step (%\S+) : i32 \{'
    def tok(t):
        m = re.match(r'%c(-?\d+)', t); return int(m.group(1)) if m else t
    istart = stacks[n][-1] if stacks[n] else None
    if istart is None or not re.search(lm, L[istart]): return rej('call is not inside a constant-bound loop')
    iend = block_end(istart)
    im = re.search(lm, L[istart]); ilo, ihi, istep = tok(im.group(2)), tok(im.group(3)), tok(im.group(4))
    if istep != 1: return rej('inner loop step is not 1')
    ivs = re.match(r'\s*fir\.store (%\w+) to (%\w+)#0', L[istart + 1])
    if not ivs or ivs.group(1) != im.group(1): return rej('loop body does not start with the index store')
    ialloca = ivs.group(2)
    jstart = stacks[istart][-1] if stacks[istart] else None; outer = None
    if jstart is not None and re.search(lm, L[jstart]):
        jend = block_end(jstart)
        between = [L[i].strip() for i in range(jstart + 1, istart)]
        after = [L[i].strip() for i in range(iend + 1, jend)]
        jm = re.search(lm, L[jstart]); jvs = re.match(r'fir\.store (%\w+) to (%\w+)#0', between[0]) if between else None
        # between the two loop headers Flang evaluates the inner bounds: loads of scalars, converts, and arithmetic
        ok_between = jvs and jvs.group(1) == jm.group(1) and all(t == '' or re.match(r'%\w+ = (arith\.\w+|fir\.load|fir\.convert) ', t) for t in between[1:])
        ok_after = all(t == '' or re.match(r'%\w+ = (fir\.convert|arith\.\w+) ', t) or re.match(r'fir\.store %\w+ to %\w+#0 : !fir\.ref<i32>', t) for t in after)
        if ok_between and ok_after and tok(jm.group(4)) == 1:
            outer = {'alloca': jvs.group(2), 'lo': tok(jm.group(2)), 'hi': tok(jm.group(3)), 'start': jstart, 'end': jend, 'arg': jm.group(1)}
    # ---- index classification at a use line k
    def index_of(ssa, k, seen=0):
        if seen > 12: return None
        ssa = ssa.split('#')[0]
        mm = re.match(r'%c(-?\d+)', ssa)
        if mm: return ('k', int(mm.group(1)))
        dd = defat(ssa, k)
        if not dd: return ('v', None) if ssa.startswith('%arg') else None
        d = dd[1]
        if d.startswith('fir.convert'): return index_of(re.search(r'fir\.convert (%\S+)', d).group(1), k, seen + 1)
        if d.startswith('fir.box_dims'): return ('k', None)   # an extent of an allocatable: independent of the loop index
        if d.startswith('fir.load'):
            r = re.search(r'fir\.load (%\w+)', d).group(1)
            if r == ialloca: return ('i', 0)
            if outer and r == outer['alloca']: return ('j', 0)
            if r in decl and decl[r]['shape'] is None: return ('v', r)
            return None
        am = re.match(r'arith\.(addi|subi) (%\S+), (%\S+)', d)
        if am:
            a, b = index_of(am.group(2), k, seen + 1), index_of(am.group(3), k, seen + 1)
            if a and b and a[0] in 'ij' and b[0] == 'k': return (a[0], a[1] + b[1] if am.group(1) == 'addi' else a[1] - b[1])
            if a and b and a[0] == 'k' and b[0] in 'ij' and am.group(1) == 'addi': return (b[0], b[1] + a[1])
            if a and b and a[0] == 'k' and b[0] == 'k': return ('k', None if None in (a[1], b[1]) else (a[1] + b[1] if am.group(1) == 'addi' else a[1] - b[1]))
            if (a and a[0] == 'v') or (b and b[0] == 'v'): return ('v', None)
        return None
    def designate_base(ssa, k, parts_acc):
        ssa = ssa.split('#')[0]
        if ssa in decl: return (ssa, parts_acc)
        dd = defat(ssa, k)
        if not dd: return None
        m = re.match(r'hlfir\.designate (%[\w#]+) \(([^)]*)\)', dd[1])
        if not m:
            lb = re.match(r'fir\.load (%\w+)#0', dd[1])
            if lb and lb.group(1) in decl and decl[lb.group(1)].get('box'): return (lb.group(1), parts_acc)
            return None
        parts = [p.strip() for p in m.group(2).split(',')]
        return designate_base(m.group(1), dd[0], [parts] + parts_acc)
    def column_class(parts_lists, k):
        # a section (lb:ub:st) spans every column between its bounds: if a bound depends on the loop index
        # with a nonzero offset it touches other columns, if both bounds are the index itself it is this
        # column, and bounds independent of the index (a k or feature range) do not name a column
        keys = []
        for parts in parts_lists:
            for p in parts:
                if ':' in p:
                    for q in p.split(':')[:2]:
                        c = index_of(q.strip(), k)
                        if c is None: return 'unknown'
                        if c[0] in 'ij': keys.append(c)
                    continue
                c = index_of(p, k)
                if c is None: return 'unknown'
                if c[0] in 'ij': keys.append(c)
        if not keys: return 'none'
        return 'same' if all(c[1] == 0 for c in keys) else 'other'
    def var_of(ssa, k):
        b = designate_base(ssa, k, [])
        if not b: return None
        return (b[0], column_class(b[1], k))
    def index_reads(ssa, k, reads):
        # scalars loaded inside the index expressions of a designate chain
        ssa = ssa.split('#')[0]
        while ssa not in decl:
            dd = defat(ssa, k)
            if not dd: return
            m = re.match(r'hlfir\.designate (%[\w#]+) \(([^)]*)\)', dd[1])
            if not m: return
            todo = [(p.strip(), dd[0]) for part in m.group(2).split(',') for p in part.split(':')]
            seen = set()
            while todo:
                v, kk = todo.pop()
                if (v, kk) in seen or not v.startswith('%'): continue
                seen.add((v, kk))
                d2 = defat(v, kk)
                if not d2: continue
                lm2 = re.match(r'fir\.load (%\w+)', d2[1])
                if lm2 and lm2.group(1) in decl: merge(reads, (lm2.group(1), 'none'))
                for w in re.findall(r'%[\w#]+', d2[1]): todo.append((w.split('#')[0], d2[0]))
            ssa = m.group(1).split('#')[0]; k = dd[0]
    # ---- units
    units = []
    i = istart + 2
    while i < iend:
        s = L[i].strip()
        if not s or s.startswith('hlfir.destroy'): i += 1; continue
        if re.match(r'(%\w+)(?::\d+)? = ', s):
            i = (block_end(i) if opens(s) else i) + 1; continue
        if opens(s):
            e = block_end(i); units.append({'lo': i, 'hi': e, 'kind': s.split()[0]}); i = e + 1; continue
        if s.startswith('hlfir.assign') or s.startswith('fir.store') or s.startswith('fir.call'):
            units.append({'lo': i, 'hi': i, 'kind': 'call ' + s.split('(')[0].split('@')[1] if s.startswith('fir.call') else s.split()[0]}); i += 1; continue
        return rej('unsupported statement at line %d: %s' % (i, s.split()[0]))
    def merge(dct, v):
        if v is None: return
        dssa, cls = v
        prev = dct.get(dssa)
        if prev is None or prev == cls: dct[dssa] = cls
        elif 'unknown' in (prev, cls): dct[dssa] = 'unknown'
        elif 'other' in (prev, cls): dct[dssa] = 'other'
        else: dct[dssa] = 'same'
    def reads_from(src, k, reads, seen):
        # every declared variable or designate reachable from value src used at line k
        todo = [(src.split('#')[0], k)]
        while todo:
            v, kk = todo.pop()
            if (v, kk) in seen: continue
            seen.add((v, kk))
            if v in decl: merge(reads, (v, 'none')); continue
            dd = defat(v, kk)
            if not dd: continue
            d, txt = dd
            if txt.startswith('hlfir.designate'): merge(reads, var_of(v, kk))
            if txt.startswith('hlfir.elemental'):
                for j in range(d + 1, block_end(d)):
                    for w in re.findall(r'%[\w#]+', L[j]): todo.append((w.split('#')[0], j))
            for w in re.findall(r'%[\w#]+', txt): todo.append((w.split('#')[0], d))
    for u in units:
        reads, writes = {}, {}
        if u['lo'] == u['hi'] and u['lo'] != n:
            s = L[u['lo']].strip()
            m = re.match(r'(?:hlfir\.assign|fir\.store) (%[\w#]+) to (%[\w#]+)', s)
            if m:
                merge(writes, var_of(m.group(2), u['lo'])); reads_from(m.group(1), u['lo'], reads, set()); index_reads(m.group(2), u['lo'], reads)
            else:   # runtime call: operands are read and written
                for w in re.findall(r'%[\w#]+', s):
                    b = w.split('#')[0]
                    if b in decl: merge(reads, (b, 'none')); merge(writes, (b, 'none'))
                    else:
                        vv = var_of(b, u['lo']); merge(reads, vv); merge(writes, vv)
        elif u['lo'] != n:
            # compound unit: loads are reads; assign and store targets, and the targets of where blocks, are writes
            in_to = 0
            for k in range(u['lo'], u['hi'] + 1):
                s = L[k].strip()
                if s.startswith('} to {'): in_to = 1
                elif in_to and closes(s): in_to = 0
                m = re.match(r'(?:hlfir\.assign|fir\.store) (%[\w#]+) to (%[\w#]+)', s)
                if m:
                    if not (s.startswith('fir.store %arg')): merge(writes, var_of(m.group(2), k)); index_reads(m.group(2), k, reads)
                    reads_from(m.group(1), k, reads, set())
                lm2 = re.match(r'%\w+ = fir\.load (%[\w#]+)', s)
                if lm2:
                    b = lm2.group(1).split('#')[0]
                    if b in decl: merge(reads, (b, 'none'))
                    else: merge(reads, var_of(b, k)); index_reads(b, k, reads)
                dm = re.match(r'(%\w+) = hlfir\.designate', s)
                if dm and in_to: merge(writes, var_of(dm.group(1), k + 1)); index_reads(dm.group(1), k + 1, reads)
        u['reads'] = reads; u['writes'] = writes
    ci = [k for k, u in enumerate(units) if u['lo'] == n]
    if not ci: return rej('call is not a top-level statement of the loop body')
    ci = ci[0]
    cargs = [a.split('#')[0] for a in re.findall(r'%[\w#]+', L[n].split('(', 1)[1])[:2]]
    def base(ssa, k):
        while True:
            dd = defat(ssa, k)
            if dd and dd[1].startswith('fir.convert'): ssa = re.search(r'fir\.convert (%\S+)', dd[1]).group(1).split('#')[0]
            else: return ssa
    tin, tout = base(cargs[0], n), base(cargs[1], n)
    for t in (tin, tout):
        if t not in decl or not decl[t]['shape'] or len(decl[t]['shape']) != 1: return rej('call operand is not a declared rank-1 temporary')
    units[ci]['reads'] = {tin: 'none'}; units[ci]['writes'] = {tout: 'none'}; units[ci]['kind'] = 'call'
    # loop indices, of the distributed nest and of inner loops, are owned by their loops
    loopvars = {ialloca, outer['alloca'] if outer else None}
    for k in range(istart, iend):
        m = re.match(r'\s*fir\.store %arg\d+ to (%\w+)#0', L[k])
        if m: loopvars.add(m.group(1))
    for u in units:
        for v in loopvars:
            u['reads'].pop(v, None); u['writes'].pop(v, None)
    units = [u for u in units if u['reads'] or u['writes'] or u['lo'] == n]
    def deps(a, b):
        return any(v in a['writes'] for v in b['reads']) or any(v in a['writes'] or v in a['reads'] for v in b['writes'])
    pre = {ci}; changed = True
    while changed:
        changed = False
        for k in range(ci - 1, -1, -1):
            if k not in pre and any(deps(units[k], units[p]) for p in pre if p > k): pre.add(k); changed = True
    pre.discard(ci)
    post = [k for k in range(len(units)) if k != ci and k not in pre]
    # a unit before the call that nothing later depends on and that writes only privates (a counter's last
    # increment) goes with the pre-loop, so the units it depends on are not recomputed in the post-loop
    hostarr = lambda v: decl[v]['shape'] is not None and len(decl[v]['shape']) >= 2 and v not in (tin, tout)
    for k in list(post):
        if k < ci and not any(deps(units[k], units[j]) for j in range(k + 1, len(units)) if j != ci) and all(not hostarr(v) for v in units[k]['writes']):
            pre.add(k); post.remove(k)
    both = set()
    for k in post:
        for p in pre:
            # a write to the output temporary before the call is dead, the call overwrites it
            if p < k and tout not in units[p]['writes'] and deps(units[p], units[k]): both.add(p)
    for u in units:
        for v, c in u['writes'].items():
            if hostarr(v) and c != 'same': return {'verdict': 'block', 'reason': 'line %d writes %s at another or unknown column (%s)' % (u['lo'], decl[v]['name'], c)}
    for p in pre:
        for v, c in units[p]['reads'].items():
            if hostarr(v):
                for k in post:
                    if v in units[k]['writes'] and c != 'same':
                        return {'verdict': 'block', 'reason': 'pre-loop line %d reads %s at another column and post-loop line %d writes it (loop-carried through the model)' % (units[p]['lo'], decl[v]['name'], units[k]['lo'])}
    first = {}
    for u in units:
        for v in u['reads']: first.setdefault(v, 'r')
        for v in u['writes']: first.setdefault(v, 'w')
    # a variable that is read before it is written carries a value between iterations; if the post-loop
    # writes it and the pre-loop reads it, the split would change which iteration's value the read sees
    for p in pre:
        for v in units[p]['reads']:
            if not hostarr(v) and v not in (tin, tout) and first.get(v) == 'r' and any(v in units[k]['writes'] for k in post):
                return {'verdict': 'block', 'reason': 'pre-loop line %d reads %s, which is carried between iterations and which the post-loop writes' % (units[p]['lo'], decl[v]['name'])}
    for p in both:
        for v in units[p]['writes']:
            if hostarr(v): return rej('line %d is needed by both loops but writes host array %s' % (units[p]['lo'], decl[v]['name']))
    for k in post:
        if tin in units[k]['writes'] or tin in units[k]['reads']: return rej('post-loop line %d touches the call input temporary' % units[k]['lo'])
    accum = sorted(decl[v]['name'] for v in first if first[v] == 'r' and any(v in u['writes'] for u in units) and not hostarr(v) and v not in (tin, tout))
    static = all(isinstance(v, int) for v in (ilo, ihi) + ((outer['lo'], outer['hi']) if outer else ()))
    ni = (ihi - ilo + 1) if static else None; count = (ni * ((outer['hi'] - outer['lo'] + 1) if outer else 1)) if static else None
    stmts = [{'lo': u['lo'], 'hi': u['hi'], 'kind': u['kind'], 'side': 'call' if k == ci else ('both' if k in both else ('pre' if k in pre else 'post')),
              'reads': sorted(decl[v]['name'] + ('' if c == 'none' else '@' + c) for v, c in u['reads'].items()),
              'writes': sorted(decl[v]['name'] + ('' if c == 'none' else '@' + c) for v, c in u['writes'].items())} for k, u in enumerate(units)]
    return {'verdict': 'batched', 'mode': 'expanded', 'batch': count, 'lo': 1, 'step': 1, 'minc': 1,
            'inner': {'start': istart, 'end': iend, 'alloca': ialloca, 'lo': ilo, 'hi': ihi, 'arg': im.group(1), 'n': ni},
            'outer': outer, 'call_line': n,
            'in': decl[tin]['name'], 'in_ssa': tin, 'in_shape': decl[tin]['shape'], 'in_elt': decl[tin]['elt'],
            'out': decl[tout]['name'], 'out_ssa': tout, 'out_shape': decl[tout]['shape'], 'out_elt': decl[tout]['elt'],
            'accumulators': accum, 'pre': sorted(pre), 'post': post, 'both': sorted(both), 'statements': stmts, 'lift': None, 'post_download': False,
            'reason': 'call is on no loop-carried cycle; %s iterations over the %s nest; %d pre units, %d post units, %d recomputed' % (count if static else 'run-time', 'j/i' if outer else 'i', len(pre), len(post), len(both))}

if __name__ == '__main__':
    print(json.dumps(analyze(sys.argv[1], sys.argv[2]), indent=1))
