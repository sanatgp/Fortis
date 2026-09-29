#!/usr/bin/env python3
# fortis_boundary.py <host.hlfir> <lift2d.json> -> host HLFIR with the boundary nests removed and the call
# taking the host's own arrays (pointer-cast to the callee's declared element type; the shim knows the contract)
import re, sys, json
L = open(sys.argv[1]).read().split('\n'); d = json.load(open(sys.argv[2]))
if not d.get('ok'): sys.exit('boundary rejected: ' + str(d.get('reject')))
decl = {}
for l in L:
    m = re.search(r'(%\w+):2 = hlfir\.declare .*uniq_name = "([^"]+)"\} : \((!fir\.ref<!fir\.array<[\dx]+xf\d+>>)', l)
    if m: decl[m.group(2)] = (m.group(1), m.group(3))
n = d['call_line']
ops = [o.strip() for o in re.search(r'fir\.call @' + re.escape(d['callee']) + r'\((.*?)\)', L[n]).group(1).split(',')]
for op, new in zip(ops, d['new_args']):
    j = [i for i in range(n - 1, max(n - 400, 0), -1) if re.match(r'\s*' + re.escape(op) + r' = fir\.convert ', L[i])]
    if not j: sys.exit('call operand ' + op + ' is not a fir.convert of a host array')
    j = j[0]; m = re.match(r'(\s*)' + re.escape(op) + r' = fir\.convert (%\w+)#\d : \((.*?)\) -> (.*)$', L[j])
    ssa, ty = decl[new]
    L[j] = m.group(1) + op + ' = fir.convert ' + ssa + '#0 : (' + ty + ') -> ' + m.group(4)
kill = set()
for a, b in d['drop']: kill.update(range(a, b + 1))
print('\n'.join(l for i, l in enumerate(L) if i not in kill))
