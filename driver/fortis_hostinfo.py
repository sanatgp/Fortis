#!/usr/bin/env python3
# Extract what the compiler needs from the Fortran host's FIR: the static shapes passed at each
# call of the model entry point, and whether the call sits inside a loop (and its trip count).
import re, sys, json
fir, callee = open(sys.argv[1]).read().split('\n'), sys.argv[2]
defs = {}   # (line, ssa) definitions, resolved backwards from a call
def define(line_no, ssa):
    for i in range(line_no - 1, -1, -1):
        m = re.match(r'\s*' + re.escape(ssa) + r' = (\S+) ([^:]*?)\s*:\s*(.*)$', fir[i])
        if m: return i, m.group(1), m.group(2), m.group(3)
        if re.match(r'\s*func\.func', fir[i]): break
    return None
def static_shape(ssa, line_no):
    seen = 0
    while seen < 8:
        d = define(line_no, ssa)
        if not d: return None
        i, op, operands, types = d
        m = re.search(r'!fir\.(?:ref|box)<!fir\.array<((?:\d+x)*\d+)xf32>>', types.split('->')[0])
        if m and op in ('fir.convert', 'fir.declare', 'hlfir.declare', 'fir.alloca', 'fir.address_of', 'fir.embox', 'fir.array_coor'):
            return [int(x) for x in m.group(1).split('x')]
        nxt = re.findall(r'%[\w]+', operands)
        if not nxt: return None
        ssa, line_no, seen = nxt[0], i, seen + 1
    return None
def loop_context(line_no):
    depth, trip = 0, None
    for i in range(line_no - 1, -1, -1):
        l = fir[i].strip()
        if l == '}': depth += 1
        elif l.endswith('{'):
            if depth: depth -= 1
            else:
                m = re.search(r'fir\.do_loop \S+ = %c(\d+)\S* to %c(\d+)\S* step', l)
                if m: return True, int(m.group(2)) - int(m.group(1)) + 1
                if re.match(r'func\.func', l): return False, None
    return False, None
# Loop batching: the enclosing loop body is exactly column slices of two static 2-D arrays,
# indexed by the loop variable on the trailing dimension, passed to the call, and nothing else.
def loop_batch(line_no):
    start = None; depth = 0
    for i in range(line_no - 1, -1, -1):
        l = fir[i].strip()
        if l == '}': depth += 1
        elif l.endswith('{'):
            if depth: depth -= 1
            else: start = i; break
    if start is None or fir[start].strip().startswith('func.func'): return ('reject', 'call is not inside a loop')
    m = re.search(r'fir\.do_loop (%\S+) = %c(-?\d+)\S* to %c(-?\d+)\S* step %c(-?\d+)', fir[start])
    if not m: return ('reject', 'enclosing loop is not a fir.do_loop with constant bounds')
    if m.group(4) != '1': return ('reject', f'loop step is {m.group(4)}, not 1')
    lo, hi = int(m.group(2)), int(m.group(3)); trip = hi - lo + 1
    body = [fir[i].strip() for i in range(start + 1, line_no)]
    ivar = re.match(r'fir\.store (%\S+) to (%\S+)', body[0]) if body else None
    if not ivar or ivar.group(1) != m.group(1): return ('reject', 'loop body does not start with the index store')
    ialloca = ivar.group(2)
    for b in body:
        if 'fir.array_coor' in b and re.search(r'!fir\.array<(\d+x){2,}\d+xf32>', b): return ('reject', 'slice of an array with rank above 2')
    allowed = ('fir.load', 'fir.convert', 'fir.shape', 'fir.array_coor')
    for b in body[1:]:
        if not b.startswith('%'): return ('reject', 'side effect in loop body: ' + b.split()[0])
        op = b.split('=', 1)[1].split()[0]
        if op not in allowed: return ('reject', 'non-slice operation in loop body: ' + op)
        if op == 'fir.load' and ialloca not in b: return ('reject', 'load of a value other than the loop index')
    coors = [b for b in body if 'fir.array_coor' in b]
    if len(coors) != 2: return ('reject', f'{len(coors)} array slices in loop body, expected 2')
    shapes = []
    for c in coors:
        mm = re.search(r'!fir\.ref<!fir\.array<(\d+)x(\d+)xf32>>, !fir\.shape<2>', c)
        if not mm:
            if re.search(r'!fir\.array<(\d+x){2,}\d+xf32>', c): return ('reject', 'slice of an array with rank above 2')
            return ('reject', 'argument is not a slice of a static 2-D array')
        if int(mm.group(2)) != trip: return ('reject', f'trip count {trip} differs from trailing extent {mm.group(2)}')
        if not re.search(r'%c1, %\w+ :', c): return ('reject', 'slice does not start at the first row')
        shapes.append([int(mm.group(1)), int(mm.group(2))])
    if lo != 1: return ('reject', f'loop starts at {lo}, not at the first column')
    return {'trip': trip, 'in_full': shapes[0], 'out_full': shapes[1]}

calls = []
for n, l in enumerate(fir):
    if re.search(r'fir\.call @' + re.escape(callee) + r'\(', l):
        ops = re.findall(r'%[\w]+', l.split('(', 1)[1])[:2]
        in_loop, trip = loop_context(n)
        calls.append({'line': n + 1, 'in_shape': static_shape(ops[0], n), 'out_shape': static_shape(ops[1], n), 'in_loop': in_loop, 'trip': trip, 'loop_batch': loop_batch(n)})
# Fortran is column-major: the feature dimension is first, a trailing dimension is the batch
def batch(shape): return shape[1] if shape and len(shape) == 2 else 1
summary = {'calls': calls,
           'in_shape': next((c['in_shape'] for c in calls if c['in_shape']), None),
           'out_shape': next((c['out_shape'] for c in calls if c['out_shape']), None),
           'in_loop': any(c['in_loop'] for c in calls),
           'trip': max((c['trip'] or 0) for c in calls) if calls else 0}
summary['batch'] = batch(summary['in_shape'])
hits = [c['loop_batch'] for c in calls if isinstance(c['loop_batch'], dict)]
rej = [c['loop_batch'][1] for c in sorted(calls, key=lambda c: not c['in_loop']) if isinstance(c['loop_batch'], (tuple, list))]
summary['loop_batch'] = hits[0] if hits and all(x == hits[0] for x in hits) and not rej else None
summary['loop_batch_reject'] = rej[0] if rej else None
print(json.dumps(summary, indent=1))
