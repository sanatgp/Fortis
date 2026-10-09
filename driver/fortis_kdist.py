#!/usr/bin/env python3
# Distribution of the loop that encloses a lifted nest.  When the gather reads only arrays that the
# enclosing loop's body never writes, the gather and the model call move in front of that loop and run
# once per step over every iteration's rows; the scatter and the rest of the body stay per iteration.
#   fortis_kdist.py <host.hlfir> <loop.json> <gather.json> <scatter.json> -> kdist.json
import re, sys, json
L = open(sys.argv[1]).read().split('\n'); d = json.load(open(sys.argv[2])); G = json.load(open(sys.argv[3])); S = json.load(open(sys.argv[4]))
def out(o): print(json.dumps(o, indent=1)); sys.exit(0)
def rej(r): out({'ok': False, 'reason': r})
if not (G.get('ok') and S.get('ok')): rej('both sides of the nest must be lifted')
if len(G['args']) != 1 or [a['alloca'] for a in S['args']] not in ([], [G['args'][0]['alloca']]): rej('the lifted reads must be indexed by one enclosing loop')
outer = d['outer'] or d['inner']
nlo, nhi = outer['start'], outer['end']
# the enclosing loop: scan upward from the nest at depth 0
depth, k0 = 0, None
for i in range(nlo - 1, -1, -1):
    s = L[i].strip()
    if s.startswith('}') and not s.endswith('{'): depth += 1
    elif s.endswith('{'):
        if depth: depth -= 1
        else: k0 = i; break
if k0 is None: rej('no enclosing loop')
m = re.search(r'fir\.do_loop (%\w+) = %c(-?\d+)\S* to %c(-?\d+)\S* step %c1\S* : i32 \{', L[k0])
if not m: rej('enclosing loop is not a unit-step loop with constant bounds')
st = re.match(r'\s*fir\.store (%\w+) to (%\w+)#0', L[k0 + 1])
if not st or st.group(1) != m.group(1): rej('enclosing loop body does not start with the index store')
if st.group(2) != G['args'][0]['alloca']: rej('the lifted reads are not indexed by the enclosing loop')
depth = 0; k1 = None
for i in range(k0 + 1, len(L)):
    s = L[i].strip()
    if s.endswith('{') and not s.startswith('}'): depth += 1
    elif s.startswith('}'):
        if depth: depth -= 1
        else: k1 = i; break
# arrays written anywhere in the enclosing loop's body, outside the nest, and by the scatter stores
decl = {}
for l in L:
    mm = re.search(r'(%\w+):2 = hlfir\.declare .*uniq_name = "([^"]+)"\}', l)
    if mm: decl[mm.group(1)] = mm.group(2)
defs = {}
for i, l in enumerate(L):
    mm = re.match(r'\s*(%\w+)(?::\d+)? = (.*)', l)
    if mm: defs.setdefault(mm.group(1), []).append((i, mm.group(2)))
def base_of(ssa, k):
    ssa = ssa.split('#')[0]
    for _ in range(8):
        if ssa in decl: return ssa
        best = None
        for dd, txt in defs.get(ssa, []):
            if dd < k: best = txt
        if not best: return None
        mm = re.match(r'hlfir\.designate (%[\w#]+)', best) or re.match(r'fir\.load (%[\w#]+)', best)
        if not mm: return None
        ssa = mm.group(1).split('#')[0]
    return None
written = set()
for i in range(k0 + 1, k1):
    if nlo <= i <= nhi: continue
    mm = re.match(r'\s*(?:hlfir\.assign|fir\.store) (%[\w#]+) to (%[\w#]+)', L[i])
    if mm:
        b = base_of(mm.group(2), i)
        if b: written.add(b)
for s in S['stores']: written.add(S['arrays'][s['array']]['ssa'])
clash = [decl[a['ssa']] for a in G['arrays'] if a['ssa'] in written]
if clash: rej('the gather reads %s, which the enclosing loop writes' % ', '.join(clash))
out({'ok': True, 'loop': {'start': k0, 'end': k1, 'alloca': st.group(2), 'lo': int(m.group(2)), 'hi': int(m.group(3)), 'arg': m.group(1)},
     'nk': int(m.group(3)) - int(m.group(2)) + 1,
     'reason': 'enclosing loop %s..%s distributed: gather and model once per step over %d x %d rows, scatter per iteration' % (m.group(2), m.group(3), int(m.group(3)) - int(m.group(2)) + 1, d['batch'])})
