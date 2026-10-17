#!/usr/bin/env python3
# Differential testing of loop batching. Usage: python3 gen_difftest.py N SEED
# Each program is the ClimSim column loop with random extra statements. Expected verdicts come from the
# construction; negatives make a previous iteration's model output reach an observable value or a later
# input, or alias the call operands, and must be refused or blocked.
import os, random, subprocess, sys, json, re
import numpy as np
F = '/scratch/taghipouranvari.s/FTORCH'; ROOT = F + '/torch-mlir'; RUN = F + '/climsim_run'; OUT = F + '/difftest'
N = int(sys.argv[1]); SEED = int(sys.argv[2]); random.seed(SEED)
FORTISC = os.environ.get('FORTISC', ROOT + '/fortisc.sh')

POS_PRE = [
    ('x(1, c) = x(1, c) + f(c)', 'f'),
    ('s = s + x(1, c)', 's'),
    ('y(1, c) = 0.0', ''),
    ('x(2, c) = x(2, c) * 0.5', ''),
    ('z(c) = x(3, c) + x(4, c)', 'z'),
]
POS_POST = [
    ('s = s + y(1, c)', 's'),
    ('y(2, c) = y(2, c) * g(c)', 'g'),
    ('w(c) = y(5, c) - y(6, c)', 'w'),
    ('y(:, c) = y(:, c) * 2.0', ''),
]
NEG = [
    ('x(1, c) = y(1, c - 1)', 'recur'),
    ('z(c) = y(1, c - 1) + x(1, c)', 'recur'),
    ('s = s + y(1, c - 1); x(1, c) = x(1, c) + s', 'recur'),
]
NEG_POST = [
    ('x(1, c + 1) = y(1, c)', 'fwd'),
]
LOOPS = ['do c = 1, ncol', 'do c = 1, 200', 'do c = 1, ncol, 2', 'do c = ncol, 1, -1']

def program(k):
    pre = random.sample(POS_PRE, random.randint(0, 2)); post = random.sample(POS_POST, random.randint(0, 2))
    loop = random.choice(LOOPS)
    neg = None; negpost = None; alias = False
    r = random.random()
    if r < 0.25: neg = random.choice(NEG); loop = 'do c = 2, ncol'
    elif r < 0.35: negpost = random.choice(NEG_POST); loop = 'do c = 1, ncol - 1'
    elif r < 0.45: alias = True
    decl = ['  real :: x(nin, ncol), y(nout, ncol)', '  real :: s, z(ncol), w(ncol), f(ncol), g(ncol)']
    if alias: decl[0] = '  real, target :: x(nin, ncol)\n  real :: y(nout, ncol)\n  real, pointer :: xp(:, :)'
    body = [f'     {t}' for t, _ in pre]
    if neg: body.append(f'     {neg[0]}')
    body.append('     call mlp_forward(x(:, c), y(:, c))')
    body += [f'     {t}' for t, _ in post]
    if negpost: body.append(f'     {negpost[0]}')
    src = f'''program difftest_{k}
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  integer, parameter :: nin = 124, nout = 128, ncol = 384, nsteps = 1
  integer :: c, step, u
{chr(10).join(decl)}
  open(newunit=u, file="columns.bin", access="stream", form="unformatted", status="old"); read(u) x; close(u)
  y = 0.0; s = 0.0; z = 0.0; w = 0.0
  do c = 1, ncol
     f(c) = 0.001 * c; g(c) = 1.0 + 0.0001 * c
  end do
{"  xp => x" if alias else ""}
  do step = 1, nsteps
  {loop}
{chr(10).join(body)}
  end do
  end do
  open(newunit=u, file="{OUT}/out_{k}_RUNTAG.bin", access="stream", form="unformatted", status="replace")
  write(u) x, y, s, z, w; close(u)
  print *, "done", sum(y)
end program difftest_{k}'''
    expect = 'refused' if (neg or negpost or alias) else 'batched'
    kind = neg[1] if neg else (negpost[1] if negpost else ('alias' if alias else 'none'))
    return src, expect, kind

def build(k, src, tag, env):
    f = f'{OUT}/t_{k}_{tag}.f90'; open(f, 'w').write(src.replace('RUNTAG', tag))
    w = f'{OUT}/work_{k}_{tag}'; e = dict(os.environ, FORTIS_WORK=w, **env); e.pop('LD_LIBRARY_PATH', None)
    binp = f'{OUT}/bin_{k}_{tag}'
    if os.path.exists(binp): os.remove(binp)
    r = subprocess.run([FORTISC, 'export_climsim.py linalg', f, binp], cwd=RUN, env=e, capture_output=True, text=True)
    log = '\n'.join(l for l in (r.stdout + r.stderr).splitlines() if 'arning' not in l and 'warn' not in l and 'generated' not in l)
    m = re.search(r'fortisc: loop verdict (\w+)', log); verdict = m.group(1) if m else None
    return os.path.exists(binp), verdict, log[-800:]

def run(k, tag):
    binp = f'{OUT}/bin_{k}_{tag}'; p = f'{OUT}/out_{k}_{tag}.bin'
    if os.path.exists(p): os.remove(p)
    e = {k2: v for k2, v in os.environ.items() if k2 != 'LD_LIBRARY_PATH'}
    r = subprocess.run([binp], cwd=RUN, capture_output=True, text=True, env=e)
    return (np.fromfile(p, dtype=np.float32) if os.path.exists(p) else None), (r.stdout + r.stderr)[-300:]

rows = []; fa = fr = 0; nb = nr = 0; mism = 0; fails = 0
for k in range(N):
    src, expect, kind = program(k)
    okr, vr, logr = build(k, src, 'ref', {'FORTIS_NO_DIST': '1'})
    okb, vb, logb = build(k, src, 'bat', {})
    got = 'batched' if vb == 'batched' else 'refused'
    status = 'ok'; maxrel = ''
    if expect == 'refused' and got == 'batched': fa += 1; status = 'FALSE_ACCEPT'
    if expect == 'batched' and got == 'refused': fr += 1; status = 'false_reject'
    if got == 'batched':
        nb += 1
        if not (okr and okb): status = 'BUILD_FAIL'; fails += 1
        else:
            (a, la), (b, lb) = run(k, 'ref'), run(k, 'bat')
            if a is None or b is None: status = 'RUN_FAIL'; fails += 1; logb = la + lb
            else:
                maxrel = float(np.max(np.abs(a - b)) / max(np.max(np.abs(a)), 1e-30))
                if maxrel > 5e-6: mism += 1; status = 'MISMATCH'
    else: nr += 1
    rows.append((k, kind, expect, got, vb, status, maxrel))
    print(f'{k:4d} {kind:6s} expect={expect:8s} got={got:8s} verdict={vb} {status} {maxrel}', flush=True)
    if status in ('FALSE_ACCEPT', 'MISMATCH', 'RUN_FAIL', 'BUILD_FAIL'): print('    ' + logb.replace('\n', '\n    '), flush=True)
open(f'{OUT}/difftest_{SEED}.csv', 'w').write('\n'.join(','.join(str(c) for c in r) for r in rows))
print(f'\nprograms {N}  batched {nb}  refused {nr}  false_accept {fa}  false_reject {fr}  mismatch {mism}  build_or_run_fail {fails}')
