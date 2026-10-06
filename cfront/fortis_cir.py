#!/usr/bin/env python3
# FORTIS C front end over ClangIR. Reads the CIR of the translation unit that calls the model entry, writes the same
# hostinfo.json and loop.json the Flang front end writes, and performs loop fission at CIR for a batched verdict.
#   python3 fortis_cir.py analyze host.cir mlp_forward <workdir>
#   python3 fortis_cir.py fission host.cir loop.json mlp_forward > host_fissioned.cir
import sys, re, json

def parse(path):
    lines = open(path).read().split('\n')
    # block tree over brace structure; a line with net '{' opens a node, a line starting with '}' closes it
    root = {'start': -1, 'end': len(lines), 'kids': [], 'parent': None}; cur = root
    for i, l in enumerate(lines):
        s = l.strip()
        if s.startswith('}') and '{' in s:            # "} body {" closes one region and opens a sibling
            cur['end'] = i; sib = {'start': i, 'end': None, 'kids': [], 'parent': cur['parent']}
            cur['parent']['kids'].append(sib); cur = sib
        elif s.endswith('{'):
            n = {'start': i, 'end': None, 'kids': [], 'parent': cur}; cur['kids'].append(n); cur = n
        elif s.startswith('}'):
            cur['end'] = i; cur = cur['parent']
    return lines, root

def globals_of(lines):
    g = {}
    for l in lines:
        m = re.match(r'\s*cir\.global\b.*@(\w+)\s*:\s*(\S.*?)\s*(\{|loc)', l)
        if m: g[m.group(1)] = [int(d) for d in re.findall(r'x (\d+)>', m.group(2))]   # inner-to-outer, Fortran order
    return g

def defs_in(lines, a, b):
    d = {}
    for i in range(a, b + 1):
        m = re.match(r'\s*(%[\w]+)\s*=', lines[i])
        if m: d[m.group(1)] = i
    return d

def operands(line):
    rhs = line.split('=', 1)[1] if re.match(r'\s*%[\w]+\s*=', line) else line
    return re.findall(r'%[\w]+', rhs)

def closure(lines, defs, idx):
    seen, todo = set(), [idx]
    while todo:
        i = todo.pop()
        if i in seen: continue
        seen.add(i)
        for o in operands(lines[i]):
            if o in defs and defs[o] not in seen: todo.append(defs[o])
    return seen

def find(node, pred, out):
    for k in node['kids']:
        if pred(k): out.append(k)
        find(k, pred, out)
    return out

def trace_ptr(lines, defs, v, iv_alloca):
    """Follow a pointer operand back to (global, index-kind). index-kind: 'this' (loop variable), 'other', 'unknown', 'const'."""
    g, kind = None, 'const'
    while v in defs:
        l = lines[defs[v]]
        if 'cir.get_global' in l:
            g = re.search(r'@(\w+)', l).group(1); break
        m = re.search(r'cir\.get_element\s+(%[\w]+)\[(%[\w]+)', l)
        if m:
            kind = index_kind(lines, defs, m.group(2), iv_alloca) if kind == 'const' else 'unknown'; v = m.group(1); continue
        m = re.search(r'cir\.cast\s+\w+\s+(%[\w]+)', l)
        if m: v = m.group(1); continue
        break
    return g, kind

def index_kind(lines, defs, v, iv_alloca):
    while v in defs:
        l = lines[defs[v]]
        m = re.search(r'cir\.cast\s+\w+\s+(%[\w]+)', l)
        if m: v = m.group(1); continue
        m = re.search(r'cir\.load\b.*?(%[\w]+)\s*:', l)
        if m: return 'this' if m.group(1) == iv_alloca else 'unknown'
        if 'cir.binop' in l: return 'other'
        if 'cir.const' in l: return 'const'
        break
    return 'unknown'

def analyze(cir, entry, outdir):
    lines, root = parse(cir); G = globals_of(lines)
    call = next((i for i, l in enumerate(lines) if re.search(r'cir\.call\s+@%s\b' % re.escape(entry), l)), None)
    if call is None: sys.exit("no call to %s" % entry)
    # innermost loop around the call: the "} body {" node containing it whose previous sibling is "cir.for : cond {"
    bodies = find(root, lambda n: lines[n['start']].strip().startswith('} body {') and n['start'] < call < n['end'], [])
    body = bodies[-1]; par = body['parent']; j = par['kids'].index(body); cond = par['kids'][j - 1]; step = par['kids'][j + 1]
    loop_scope = par                                        # the cir.scope holding the alloca of the loop variable
    iv = re.search(r'(%[\w]+)\s*=\s*cir\.alloca\s+"(\w+)"', '\n'.join(lines[loop_scope['start']:cond['start']]))
    iv_alloca, iv_name = iv.group(1), iv.group(2)
    defs_scope = defs_in(lines, loop_scope['start'], loop_scope['end'])
    init = next((int(re.search(r'#cir\.int<(-?\d+)>', lines[defs_scope[o]]).group(1)) for i in range(loop_scope['start'], cond['start'])
                 for o in operands(lines[i]) if 'cir.store' in lines[i] and o in defs_scope and 'cir.const' in lines[defs_scope[o]]), 0)
    cmp = next(l for l in lines[cond['start']:cond['end']] if 'cir.cmp' in l)
    bound = int(re.search(r'#cir\.int<(-?\d+)>', lines[defs_in(lines, cond['start'], cond['end'])[operands(cmp)[-1]]]).group(1))
    inc = 1 if any('cir.inc' in l for l in lines[step['start']:step['end']]) else None
    if inc is None or ' lt ' not in cmp: sys.exit("loop form not recognized")
    trip = (bound - init + inc - 1) // inc
    # statements in the body: the call and every store; classify each
    inner = body['kids'][0] if body['kids'] and lines[body['kids'][0]['start']].strip().startswith('cir.scope') else body
    a, b = inner['start'], inner['end']; defs = defs_in(lines, a, b)
    args = operands(lines[call]); ins, outs = [trace_ptr(lines, defs, v, iv_alloca) for v in args]
    stmts, verdict, reason = [], 'batched', None
    for (gname, kind) in (ins, outs):
        if gname not in G or kind != 'this': verdict, reason = 'reject', 'call operand is not a row of a global array indexed by the loop variable'
    for i in range(a, b + 1):
        if i == call or 'cir.store' not in lines[i]: continue
        ops = operands(lines[i]); tgt, kind = trace_ptr(lines, defs, ops[-1], iv_alloca)
        reads = [trace_ptr(lines, defs, operands(lines[k])[0], iv_alloca) for k in closure(lines, defs, i) if 'cir.load' in lines[k] and operands(lines[k])[0] in defs]
        if tgt is None:                                     # a local scalar
            stmts.append([i + 1, 'stay', 'scalar on the host']); continue
        if tgt in (ins[0], outs[0]) and kind != 'this':
            verdict, reason = 'block', 'store to %s at another column' % tgt
        if any(r[0] == outs[0] and r[1] != 'this' for r in reads):
            verdict, reason = 'block', 'reads the call output at another column, a recurrence through the model'
        if kind == 'unknown': verdict, reason = 'reject', 'store to %s at an index the analysis cannot classify' % tgt
        stmts.append([i + 1, 'stay', 'loop-independent, runs on the host'])
    if verdict == 'batched':
        reason = 'call is on no loop-carried cycle; %d iterations over columns 1..%d step %d' % (trip, trip, inc)
    xi, yo = G.get(ins[0], []), G.get(outs[0], [])
    hostinfo = {'calls': [{'line': call + 1, 'in_shape': xi[:-1], 'out_shape': yo[:-1], 'in_loop': True, 'trip': trip,
                           'loop_batch': {'trip': trip, 'in_full': xi, 'out_full': yo}}],
                'in_shape': xi[:-1], 'out_shape': yo[:-1], 'in_loop': True, 'trip': trip, 'batch': 1,
                'loop_batch': {'trip': trip, 'in_full': xi, 'out_full': yo}, 'loop_batch_reject': None}
    loop = {'verdict': verdict, 'batch': trip, 'lo': 1, 'step': inc, 'minc': 1, 'in': ins[0], 'in_shape': xi, 'out': outs[0], 'out_shape': yo,
            'post_download': False, 'lift': None, 'statements': stmts, 'reason': reason,
            'cir': {'loop_scope': [loop_scope['start'], loop_scope['end']], 'inner': [a, b], 'call': call, 'iv': iv_alloca, 'iv_name': iv_name}}
    json.dump(hostinfo, open(outdir + '/hostinfo.json', 'w'), indent=1); json.dump(loop, open(outdir + '/loop.json', 'w'), indent=1)
    print(json.dumps({'verdict': verdict, 'reason': reason, 'batch': trip, 'in': ins[0], 'out': outs[0], 'statements': stmts}))

def fission(cir, loopjson, entry):
    lines, root = parse(cir); L = json.load(open(loopjson)); c = L['cir']; G = globals_of(lines)
    s, e = c['loop_scope']; a, b = c['inner']; call = c['call']; defs = defs_in(lines, a, b)
    stmts = [i for i in range(a, b + 1) if i != call and 'cir.store' in lines[i]]
    pre = set().union(*[closure(lines, defs, i) for i in stmts if i < call]) if any(i < call for i in stmts) else set()
    post = set().union(*[closure(lines, defs, i) for i in stmts if i > call]) if any(i > call for i in stmts) else set()
    def copy_loop(keep):
        out = []
        for i in range(s, e + 1):
            if a <= i <= b and (re.match(r'\s*%[\w]+\s*=', lines[i]) or 'cir.store' in lines[i] or 'cir.call' in lines[i]) and i not in keep: continue
            out.append(lines[i])
        return out
    ind = re.match(r'\s*', lines[s]).group(0)
    def ptr(tag, g):
        dims = G[g]; inner = '!cir.array<!cir.float x %d>' % dims[0]; full = '!cir.array<%s x %d>' % (inner, dims[1])
        return ['%s%%fb_%s_g = cir.get_global @%s : !cir.ptr<%s>' % (ind, tag, g, full),
                '%s%%fb_%s_e = cir.get_element %%fb_%s_g[%%fb_c0 : !s64i] : !cir.ptr<%s> -> !cir.ptr<%s>' % (ind, tag, tag, full, inner),
                '%s%%fb_%s = cir.cast array_to_ptrdecay %%fb_%s_e : !cir.ptr<%s> -> !cir.ptr<!cir.float>' % (ind, tag, tag, inner)]
    new = (copy_loop(pre) if pre else []) + ['%s%%fb_c0 = cir.const #cir.int<0> : !s64i' % ind] + ptr('in', L['in']) + ptr('out', L['out']) + \
          ['%scir.call @%s_batched(%%fb_in, %%fb_out) : (!cir.ptr<!cir.float>, !cir.ptr<!cir.float>) -> ()' % (ind, entry)] + (copy_loop(post) if post else [])
    out = lines[:s] + new + lines[e + 1:]
    decl = next(i for i, l in enumerate(out) if re.search(r'cir\.func\s+private\s+@%s\b' % re.escape(entry), l))
    out.insert(decl + 1, '  cir.func private @%s_batched(!cir.ptr<!cir.float>, !cir.ptr<!cir.float>)' % entry)
    print('\n'.join(out))

if __name__ == '__main__':
    if sys.argv[1] == 'analyze': analyze(sys.argv[2], sys.argv[3], sys.argv[4])
    elif sys.argv[1] == 'fission': fission(sys.argv[2], sys.argv[3], sys.argv[4])
