#!/usr/bin/env python3
# Purity check on the exported model (linalg on tensors). Refuses a graph that is stochastic,
# stateful, or opaque, and names the first offending construct. Exit 0 accepted, 1 refused.
import re, sys
src = open(sys.argv[1]).read()
BAD = [
    (r'\btorch\.aten\.(rand|randn|rand_like|randn_like|normal|bernoulli|multinomial|dropout|native_dropout|uniform|exponential|poisson)\b', 'random operation'),
    (r'\bml_program\.global\b[^\n]*\bmutable\b', 'mutable module state'),
    (r'\bml_program\.global_store\b', 'store to module state'),
    (r'\btorch\.overwrite\.tensor\.contents\b', 'in-place overwrite'),
    (r'\bmemref\.(store|global)\b', 'memref side effect'),
    (r'\bscf\.while\b', 'data-dependent loop'),
    (r'\bfunc\.func\s+private\s+@', 'opaque external call'),
    (r'\bllvm\.call\b', 'opaque external call'),
]
for pat, why in BAD:
    m = re.search(pat, src)
    if m:
        line = src.count('\n', 0, m.start()) + 1
        print(f'fortis: model refused, {why} at line {line}: {m.group(0)}'); sys.exit(1)
funcs = re.findall(r'func\.func\s+@(\w+)\((.*?)\)\s*->\s*\(?([^{]*?)\)?\s*(?:attributes[^{]*)?\{', src, re.S)
entries = [f for f in funcs if not f[0].startswith('_')]
if len(entries) != 1:
    print(f'fortis: model refused, expected one entry function, found {len(entries)}'); sys.exit(1)
name, args, rets = entries[0]
nargs = len(re.findall(r'%\w+\s*:', args)); nrets = len(re.findall(r'tensor<', rets))
if nargs != 1 or nrets != 1:
    print(f'fortis: model refused, entry @{name} takes {nargs} tensors and returns {nrets}, need one in and one out'); sys.exit(1)
print(f'fortis: model accepted as pure, entry @{name}, one tensor in, one tensor out, no random, stateful, or opaque operation')
