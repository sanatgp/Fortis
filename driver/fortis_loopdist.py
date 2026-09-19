#!/usr/bin/env python3
# Call-centric loop distribution over HLFIR.
# The model call is a statement in a host loop. Statements before and after it are classified
# by their dependence on the call's input and output slices. Verdicts: Lift (elementwise on the
# input slice -> compiled into the step), Stay (loop-independent -> the host keeps running it),
# Block (loop-carried dependence through the call -> not batched).
#   fortis_loopdist.py <host.hlfir> <callee>            -> JSON
#   fortis_loopdist.py --prologue <json> <model.mlir>   -> merged module (delegates to fortis_hostlift)
import re, sys, json
from fortis_hostlift import emit_prologue

def analyze(path, callee):
    L = open(path).read().split('\n')
    decl = {}      # ssa -> (name, shape or None for scalars)
    for l in L:
        m = re.search(r'(%\w+):2 = hlfir\.declare .*uniq_name = "([^"]+)"\} : \(!fir\.ref<(!fir\.array<([\dx]+)xf32>|f32)>', l)
        if m: decl[m.group(1)] = (m.group(2), [int(x) for x in m.group(4).split('x')] if m.group(4) else None)
    calls = [i for i, l in enumerate(L) if re.search(r'fir\.call @' + re.escape(callee) + r'\(', l)]
    if not calls: return {'verdict': 'reject', 'reason': 'no call to ' + callee}
    n = calls[-1]
    start, depth = None, 0
    for i in range(n - 1, -1, -1):
        s = L[i].strip()
        if s == '}': depth += 1
        elif s.endswith('{'):
            if depth: depth -= 1
            else: start = i; break
    if start is None or 'fir.do_loop' not in L[start]: return {'verdict': 'reject', 'reason': 'call is not inside a loop'}
    m = re.search(r'fir\.do_loop (%\S+) = %c(-?\d+)\S* to %c(-?\d+)\S* step %c(-?\d+)', L[start])
    if not m: return {'verdict': 'reject', 'reason': 'loop bounds are not constant'}
    lo, hi, step = int(m.group(2)), int(m.group(3)), int(m.group(4))
    if step == 0 or (hi - lo) * step < 0: return {'verdict': 'reject', 'reason': 'empty loop'}
    count = (hi - lo) // step + 1
    minc = min(lo, lo + (count - 1) * step)
    # find the loop end
    end, depth = None, 0
    for i in range(start + 1, len(L)):
        s = L[i].strip()
        if s.endswith('{'): depth += 1
        elif s == '}':
            if depth: depth -= 1
            else: end = i; break
    body = L[start + 1:end]
    ivar = re.match(r'\s*fir\.store (%\S+) to (%\S+)', body[0]) if body else None
    if not ivar or ivar.group(1) != m.group(1): return {'verdict': 'reject', 'reason': 'loop body does not start with the index store'}
    ialloca = ivar.group(2)
    # ---- parse: defs (ssa -> op text), elementals (ssa -> block), statements in order
    defs, elem, stmts = {}, {}, []
    i = 1
    while i < len(body):
        s = body[i].strip()
        em = re.match(r'(%\w+) = hlfir\.elemental ', s)
        if em:
            blk, i = [], i + 1
            while not body[i].strip().startswith('}'): blk.append(body[i].strip()); i += 1
            elem[em.group(1)] = blk; defs[em.group(1)] = 'hlfir.elemental'
        elif s.startswith('%'):
            name, rest = s.split(' = ', 1); defs[name] = rest
        elif s.startswith('hlfir.assign') or s.startswith('fir.store') or s.startswith('fir.call'):
            stmts.append((i + start + 1, s))
        elif s.startswith('hlfir.destroy') or not s: pass
        else: return {'verdict': 'reject', 'reason': 'unsupported statement in loop body: ' + s.split()[0]}
        i += 1
    # ---- index classification: returns ('i', c) for loop index + c, ('k', v) for constant, None otherwise
    def index_of(ssa):
        if ssa.startswith('%c'):
            mm = re.match(r'%c(\d+)', ssa); return ('k', int(mm.group(1))) if mm else None
        d = defs.get(ssa, '')
        if d.startswith('fir.convert'):
            src = re.search(r'fir\.convert (%\S+)', d).group(1)
            if src in defs and defs[src].startswith('fir.load') and ialloca in defs[src]: return ('i', 0)
            return index_of(src)
        if d.startswith('fir.load') and ialloca in d: return ('i', 0)
        am = re.match(r'arith\.(addi|subi) (%\S+), (%\S+)', d)
        if am:
            a, b = index_of(am.group(2)), index_of(am.group(3))
            if a and b and a[0] == 'i' and b[0] == 'k': return ('i', a[1] + b[1] if am.group(1) == 'addi' else a[1] - b[1])
            if a and b and a[0] == 'k' and b[0] == 'i' and am.group(1) == 'addi': return ('i', b[1] + a[1])
        return None
    def access(ssa):    # designate -> (array name, shape, column index class) for a column slice or an element of a 2-D array
        ssa = ssa.split('#')[0]
        d = defs.get(ssa, '')
        if not d.startswith('hlfir.designate'): return None
        dm = re.match(r'hlfir\.designate (%\w+)(?:#0)? \(([^)]*)\)', d)
        if not dm or dm.group(1) not in decl: return None
        name, shape = decl[dm.group(1)]
        if not shape: return None
        parts = [p.strip() for p in dm.group(2).split(',')]
        if len(shape) == 2 and len(parts) == 2:
            col = index_of(parts[1].split(':')[0]) if ':' not in parts[1] else None
            return (name, shape, col, 'slice' if ':' in parts[0] else 'elem')
        return (name, shape, None, 'other')
    def reads_of(ssa, seen=None):   # arrays read in the def slice of a value
        seen = seen if seen is not None else set(); out = []
        if ssa in seen or ssa not in defs: return out
        seen.add(ssa); d = defs[ssa]
        if d == 'hlfir.elemental':
            for s in elem[ssa]:
                for v in re.findall(r'%[\w#]+', s.split(' = ', 1)[1] if ' = ' in s else s):
                    a = access(v)
                    if a: out.append(a)
                    out += reads_of(v.split('#')[0], seen)
            return out
        a = access(ssa)
        if a: out.append(a)
        for v in re.findall(r'%[\w#]+', d): out += reads_of(v.split('#')[0], seen)
        return out
    # ---- the call
    cl = L[n]; cargs = [a.split('#')[0] for a in re.findall(r'%[\w#]+', cl.split('(', 1)[1])[:2]]
    def base(ssa):
        while ssa in defs and defs[ssa].startswith('fir.convert'): ssa = re.search(r'fir\.convert (%\S+)', defs[ssa]).group(1).split('#')[0]
        return ssa
    cin, cout = base(cargs[0]), base(cargs[1])
    out_acc = access(cout)
    if not out_acc or out_acc[3] != 'slice' or out_acc[2] != ('i', 0): return {'verdict': 'reject', 'reason': 'call output is not the column slice y(:,i)'}
    in_acc = access(cin)
    temp_in = None
    if in_acc is None:
        if cin in decl and decl[cin][1] and len(decl[cin][1]) == 1: temp_in = cin
        else: return {'verdict': 'reject', 'reason': 'call input is neither a column slice nor a declared temporary'}
    elif in_acc[3] != 'slice' or in_acc[2] != ('i', 0): return {'verdict': 'reject', 'reason': 'call input is not the column slice x(:,i)'}
    yname = out_acc[0]
    # ---- classify the other statements
    verdicts, lift, post_download = [], None, False
    call_idx = [k for k, (ln, s) in enumerate(stmts) if s.startswith('fir.call')][0]
    for k, (ln, s) in enumerate(stmts):
        if k == call_idx: continue
        before = k < call_idx
        if s.startswith('hlfir.assign'):
            src, tgt = re.match(r'hlfir\.assign (%[\w#]+) to (%[\w#]+)', s).groups()
            tgt_acc = access(tgt); src_reads = reads_of(src.split('#')[0])
            tgt_name = tgt_acc[0] if tgt_acc else decl.get(tgt.split('#')[0], ('?',))[0]
        elif s.startswith('fir.store'):
            src, tgt = re.match(r'fir\.store (%\S+) to (%\S+)', s).groups()
            tgt_acc = access(tgt); src_reads = reads_of(src)
            tgt_name = tgt_acc[0] if tgt_acc else decl.get(tgt.split('#')[0], ('?',))[0]
        else: return {'verdict': 'reject', 'reason': 'unsupported statement: ' + s.split()[0]}
        # loop-carried through the call: a write to the call's input at another iteration, or a write
        # to the call's input from the call's output at another iteration
        writes_in = in_acc is not None and tgt_acc and tgt_acc[0] == in_acc[0]
        writes_out = tgt_acc and tgt_acc[0] == yname
        reads_out_other = any(r[0] == yname and r[2] and r[2] != ('i', 0) for r in src_reads)
        reads_in_any = any(in_acc is not None and r[0] == in_acc[0] for r in src_reads)
        if writes_in and tgt_acc[2] != ('i', 0):
            return {'verdict': 'block', 'reason': f'line {ln}: writes the call input at another iteration (loop-carried into the model)'}
        if writes_in and reads_out_other:
            return {'verdict': 'block', 'reason': f'line {ln}: writes the call input from the model output of another iteration (recurrence through the model)'}
        if before and temp_in and tgt.split('#')[0] == temp_in:
            # candidate Lift: elementwise expression assigned to the call's temporary
            from fortis_hostlift import analyze as lift_analyze
            la = lift_analyze(path, callee)
            if not la['ok']: return {'verdict': 'block', 'reason': 'pre-statement assigns the call temporary but is not liftable (' + la['reason'] + ')'}
            lift = la; verdicts.append((ln, 'lift', 'elementwise expression on the input slice, compiled into the step')); continue
        if before and writes_in and tgt_acc[2] == ('i', 0):
            return {'verdict': 'block', 'reason': f'line {ln}: writes the call input slice before the call and is not an elementwise expression'}
        if before and writes_out:
            post_download = True; verdicts.append((ln, 'stay', 'writes the output slice before the call; output is downloaded per iteration after it')); continue
        verdicts.append((ln, 'stay', 'loop-independent, runs on the host'))
    return {'verdict': 'batched', 'batch': count, 'lo': lo, 'step': step, 'minc': minc,
            'in': in_acc[0] if in_acc else (lift['in_sym'] if lift else None), 'in_shape': in_acc[1] if in_acc else (lift['in_shape'] if lift else None),
            'out': yname, 'out_shape': out_acc[1], 'post_download': post_download,
            'lift': lift, 'statements': verdicts,
            'reason': f'call is on no loop-carried cycle; {count} iterations over columns {minc}..{minc + (count - 1) * abs(step)} step {abs(step)}'}

if __name__ == '__main__':
    if sys.argv[1] == '--prologue':
        d = json.load(open(sys.argv[2])); print(emit_prologue(d['lift'], sys.argv[3]))
    else:
        print(json.dumps(analyze(sys.argv[1], sys.argv[2]), indent=1))
