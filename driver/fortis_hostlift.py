#!/usr/bin/env python3
# Lift pure per-column Fortran arithmetic around the model call into the compiled step.
#   analyze:  fortis_hostlift.py <host.hlfir> <callee>                 -> JSON verdict on stdout
#   prologue: fortis_hostlift.py --prologue <lift.json> <model_linalg.mlir> -> merged module on stdout
# Legal loop body: index bookkeeping, one column slice of a static 2-D array, elementals over that
# slice with program-level 1-D arrays and constants, one assign into a temp, the call on the temp
# and a column slice of a static 2-D output array. Everything else is rejected with the reason.
import re, sys, json

def analyze(path, callee):
    L = open(path).read().split('\n')
    decl = {}   # ssa -> (uniq_name, shape)
    for l in L:
        m = re.search(r'(%\w+):2 = hlfir\.declare .*uniq_name = "([^"]+)"\} : \(!fir\.ref<!fir\.array<([\dx]+)xf32>>', l)
        if m: decl[m.group(1)] = (m.group(2), [int(x) for x in m.group(3).split('x')])
    calls = [i for i, l in enumerate(L) if re.search(r'fir\.call @' + re.escape(callee) + r'\(', l)]
    if not calls: return {'ok': False, 'reason': 'no call to ' + callee}
    n = calls[-1]
    # enclosing loop
    start, depth = None, 0
    for i in range(n - 1, -1, -1):
        s = L[i].strip()
        if s == '}': depth += 1
        elif s.endswith('{'):
            if depth: depth -= 1
            else: start = i; break
    if start is None or 'fir.do_loop' not in L[start]: return {'ok': False, 'reason': 'call is not inside a loop'}
    m = re.search(r'fir\.do_loop (%\S+) = %c(-?\d+)\S* to %c(-?\d+)\S* step %c(-?\d+)', L[start])
    if not m: return {'ok': False, 'reason': 'loop bounds are not constant'}
    if m.group(4) != '1' or m.group(2) != '1': return {'ok': False, 'reason': f'loop must run from 1 with step 1, has start {m.group(2)} step {m.group(4)}'}
    trip = int(m.group(3))
    body = L[start + 1:n]
    ivar = re.match(r'\s*fir\.store (%\S+) to (%\S+)', body[0]) if body else None
    if not ivar or ivar.group(1) != m.group(1): return {'ok': False, 'reason': 'loop body does not start with the index store'}
    ialloca = ivar.group(2)
    # parse elementals (blocks) and top-level ops
    elem, top, i = {}, [], 1
    while i < len(body):
        s = body[i].strip()
        em = re.match(r'(%\w+) = hlfir\.elemental ', s)
        if em:
            blk, i = [], i + 1
            while not body[i].strip().startswith('}'): blk.append(body[i].strip()); i += 1
            elem[em.group(1)] = blk
        else: top.append(s)
        i += 1
    allowed = ('arith.constant', 'fir.load', 'fir.convert', 'fir.shape', 'hlfir.designate', 'hlfir.assign', 'hlfir.destroy')
    defs = {}
    assign = None
    for s in top:
        if s.startswith('%'):
            name, rest = s.split(' = ', 1); op = rest.split()[0]; defs[name] = rest
        else:
            op = s.split()[0]
            if op == 'hlfir.assign':
                if assign: return {'ok': False, 'reason': 'more than one assignment in loop body'}
                assign = re.match(r'hlfir\.assign (%[\w#]+) to (%[\w#]+)', s).groups()
                continue
            if op == 'hlfir.destroy' or op == 'fir.call': continue
            return {'ok': False, 'reason': 'side effect in loop body: ' + op}
        if op not in allowed: return {'ok': False, 'reason': 'non-elementwise operation in loop body: ' + op}
        if op == 'fir.load' and ialloca not in rest and not re.search(r'!fir\.ref<f32>', rest): return {'ok': False, 'reason': 'load of a value other than the loop index'}
    # call operands
    cargs = re.findall(r'%\w+', L[n].split('(', 1)[1])[:2]
    def base_of(ssa):   # follow fir.convert chains
        while ssa in defs and defs[ssa].startswith('fir.convert'): ssa = re.search(r'fir\.convert (%\S+)', defs[ssa]).group(1)
        return ssa
    def col_slice(ssa):  # hlfir.designate DECL (%c1:%cN:%c1, %idx) shape -> (uniq_name, shape) or None
        if ssa not in defs: return None
        d = re.match(r'hlfir\.designate (%\w+)#0 \(%c1[\w_]*:%c(\d+)[\w_]*:%c1[\w_]*, (%\w+)\)\s+shape', defs[ssa])
        if not d or d.group(1) not in decl: return None
        idx = d.group(3)
        if idx not in defs or not defs[idx].startswith('fir.convert'): return None
        ld = re.search(r'fir\.convert (%\w+)', defs[idx]).group(1)
        if ld not in defs or ialloca not in defs[ld]: return None
        return decl[d.group(1)]
    tmp = base_of(cargs[0]); out = col_slice(base_of(cargs[1]))
    if not out: return {'ok': False, 'reason': 'second call argument is not a column slice of a static 2-D array'}
    if not assign or assign[1] != tmp: return {'ok': False, 'reason': 'first call argument is not the temp assigned in the loop body'}
    # expression tree from the assigned elemental
    globals_, in_arr, ops = [], [None], []
    def gsym(ssa):
        if ssa in decl and len(decl[ssa][1]) == 1:
            nm = decl[ssa][0]
            if nm not in globals_: globals_.append(nm)
            return ('G', nm)
        return None
    def eval_elem(e, env=None):
        blk = elem[e]; env = {}
        for s in blk:
            if s.startswith('^bb0'): continue
            if s.startswith('hlfir.yield_element'): return env[re.search(r'yield_element (%\w+)', s).group(1)]
            name, rest = s.split(' = ', 1); op = rest.split()[0]
            if op == 'hlfir.designate':
                src = re.search(r'hlfir\.designate (%\w+)(#0)? \(', rest).group(1)
                sl = col_slice(src)
                if sl:
                    if len(sl[1]) != 2 or sl[1][1] != trip: return ('ERR', f'slice trailing extent {sl[1]} does not match trip {trip}')
                    in_arr[0] = sl; env[name] = ('X',)
                else:
                    g = gsym(src)
                    if not g: return ('ERR', 'operand is not the column slice or a program-level 1-D array')
                    env[name] = g
            elif op == 'fir.load': env[name] = env[re.search(r'fir\.load (%\w+)', rest).group(1)]
            elif op == 'hlfir.apply': env[name] = eval_elem(re.search(r'hlfir\.apply (%\w+)', rest).group(1))
            elif op == 'hlfir.no_reassoc': env[name] = env[re.search(r'no_reassoc (%\w+)', rest).group(1)]
            elif op == 'arith.constant': env[name] = ('C', re.search(r'arith\.constant ([-\d.eE+]+)', rest).group(1))
            elif op in ('arith.addf', 'arith.subf', 'arith.mulf', 'arith.divf'):
                a, b = re.search(r'arith\.\w+ (%\w+), (%\w+)', rest).groups(); env[name] = (op, env[a], env[b])
            else: return ('ERR', 'unsupported operation in elementwise expression: ' + op)
        return ('ERR', 'elemental without yield')
    tree = eval_elem(assign[0])
    def has_err(t): return t[0] == 'ERR' or any(has_err(c) for c in t[1:] if isinstance(c, tuple))
    if has_err(tree):
        def first_err(t):
            if t[0] == 'ERR': return t[1]
            for c in t[1:]:
                if isinstance(c, tuple):
                    r = first_err(c)
                    if r: return r
        return {'ok': False, 'reason': first_err(tree)}
    if not in_arr[0]: return {'ok': False, 'reason': 'expression does not read the column slice'}
    return {'ok': True, 'trip': trip, 'in_sym': in_arr[0][0], 'in_shape': in_arr[0][1], 'out_sym': out[0], 'out_shape': out[1],
            'globals': [{'sym': g, 'n': decl[[k for k, v in decl.items() if v[0] == g][0]][1][0]} for g in globals_], 'expr': tree}

def emit_prologue(lift, model_path):
    src = open(model_path).read()
    head = re.search(r'func\.func @(\w+)\((%\w+): (tensor<[^>]+>)\) -> (tensor<[^>]+>) \{', src)
    fname, _, intype, outtype = head.groups()
    B, K = lift['trip'], lift['in_shape'][0]
    assert intype == f'tensor<{B}x{K}xf32>', f'model input {intype} vs host {B}x{K}'
    gl = lift['globals']; gi = {g['sym']: i for i, g in enumerate(gl)}
    cnt = [0]; lines = []
    def emit(t):
        if t[0] == 'X': return '%a'
        if t[0] == 'G': return f'%g{gi[t[1]]}'
        if t[0] == 'C':
            cnt[0] += 1; lines.append(f'    %c{cnt[0]} = arith.constant {t[1]} : f32'); return f'%c{cnt[0]}'
        a, b = emit(t[1]), emit(t[2]); cnt[0] += 1
        lines.append(f'    %v{cnt[0]} = {t[0]} {a}, {b} : f32'); return f'%v{cnt[0]}'
    res = emit(lift['expr'])
    gargs = ', '.join(f'%G{i}: tensor<{g["n"]}xf32>' for i, g in enumerate(gl))
    gins = ', '.join(f'%G{i}' for i in range(len(gl))); gtys = ', '.join(f'tensor<{g["n"]}xf32>' for g in gl)
    maps = ', '.join(['affine_map<(b, k) -> (b, k)>'] + ['affine_map<(b, k) -> (k)>'] * len(gl) + ['affine_map<(b, k) -> (b, k)>'])
    bargs = ', '.join(['%a: f32'] + [f'%g{i}: f32' for i in range(len(gl))] + ['%o: f32'])
    pro = f'''
  func.func @fortis_main(%x: {intype}, {gargs}) -> {outtype} {{
    %e = tensor.empty() : {intype}
    %xn = linalg.generic {{indexing_maps = [{maps}], iterator_types = ["parallel", "parallel"]}} ins(%x, {gins} : {intype}, {gtys}) outs(%e : {intype}) {{
    ^bb0({bargs}):
{chr(10).join(lines)}
      linalg.yield {res} : f32
    }} -> {intype}
    %y = call @{fname}(%xn) : ({intype}) -> {outtype}
    return %y : {outtype}
  }}
'''
    src = src.replace(head.group(0), head.group(0).replace(f'func.func @{fname}', f'func.func private @{fname}'), 1)
    cut = src.index('{-#') if '{-#' in src else src.rindex('}')
    return src[:cut].rstrip()[:-1] + pro + '}\n' + (src[cut:] if '{-#' in src else '')

if __name__ == '__main__':
    if sys.argv[1] == '--prologue':
        print(emit_prologue(json.load(open(sys.argv[2])), sys.argv[3]))
    else:
        print(json.dumps(analyze(sys.argv[1], sys.argv[2]), indent=1))
