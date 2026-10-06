#!/usr/bin/env python3
# Loop fission at HLFIR for the expanded-temporary case of fortis_units.py.
#   fortis_fission_hlfir.py <host.hlfir> <loop.json> -> host HLFIR with the nest split
# The nest is copied twice.  The first copy keeps the pre units and ends each iteration by packing the
# call's input temporary into row col of a batch buffer; one batched call runs between the copies; the
# second copy starts each iteration by unpacking row col of the output buffer and keeps the post units.
# Values are region-scoped in MLIR, so the copies need no renaming; deleted units leave their pure
# value definitions behind, which are dead.
import re, sys, json
L = open(sys.argv[1]).read().split('\n'); d = json.load(open(sys.argv[2]))
if d.get('verdict') != 'batched' or d.get('mode') != 'expanded': sys.exit('not an expanded batched loop')
inner, outer, n = d['inner'], d['outer'], d['call_line']
nlo, nhi = (outer['start'], outer['end']) if outer else (inner['start'], inner['end'])
# a unit needed by both loops ('both') stays in both copies; each copy drops only the other side's units
pre_ranges = [(s['lo'], s['hi']) for s in d['statements'] if s['side'] == 'pre']
post_ranges = [(s['lo'], s['hi']) for s in d['statements'] if s['side'] == 'post']
def ref_ty(shape, elt): return '!fir.ref<!fir.array<%dx%s>>' % (shape[0], elt)
tin_ty, tout_ty = ref_ty(d['in_shape'], d['in_elt']), ref_ty(d['out_shape'], d['out_elt'])
ind = re.match(r'(\s*)', L[inner['start'] + 1]).group(1)
def col_lines():
    ls = [ind + '%%fx_ilo = arith.constant %d : i32' % inner['lo'], ind + '%fx_i = arith.subi ' + inner['arg'] + ', %fx_ilo : i32']
    if outer:
        ls += [ind + '%%fx_jlo = arith.constant %d : i32' % outer['lo'], ind + '%%fx_ni = arith.constant %d : i32' % inner['n'],
               ind + '%fx_j = arith.subi ' + outer['arg'] + ', %fx_jlo : i32', ind + '%fx_m = arith.muli %fx_j, %fx_ni : i32',
               ind + '%fx_col = arith.addi %fx_m, %fx_i : i32']
    else:
        ls += [ind + '%fx_zero = arith.constant 0 : i32', ind + '%fx_col = arith.addi %fx_i, %fx_zero : i32']
    return ls
def copy(keep_side):
    drop = post_ranges if keep_side == 'pre' else pre_ranges
    out = []
    for i in range(nlo, nhi + 1):
        if i == n or any(a <= i <= b for a, b in drop): continue
        if keep_side == 'pre' and i == inner['end']:      # before the inner loop's closing brace
            out.append(ind + 'fir.call @fortis_pack(' + d['in_ssa'] + '#1, %fx_col) : (' + tin_ty + ', i32) -> ()')
        out.append(L[i])
        if i == inner['start'] + 1:      # right after the inner index store
            out += col_lines()
            if keep_side == 'post':
                out.append(ind + 'fir.call @fortis_unpack(' + d['out_ssa'] + '#1, %fx_col) : (' + tout_ty + ', i32) -> ()')
    return out
nest_ind = re.match(r'(\s*)', L[nlo]).group(1)
new = L[:nlo] + copy('pre') + [nest_ind + 'fir.call @mlp_forward_batched() : () -> ()'] + copy('post') + L[nhi + 1:]
decls = ['  func.func private @fortis_pack(' + tin_ty + ', i32) attributes {fir.bindc_name = "fortis_pack", fir.proc_attrs = #fir.proc_attrs<bind_c>}',
         '  func.func private @fortis_unpack(' + tout_ty + ', i32) attributes {fir.bindc_name = "fortis_unpack", fir.proc_attrs = #fir.proc_attrs<bind_c>}',
         '  func.func private @mlp_forward_batched() attributes {fir.bindc_name = "mlp_forward_batched", fir.proc_attrs = #fir.proc_attrs<bind_c>}']
k = max(i for i, l in enumerate(new) if l.startswith('  func.func private @'))
new = new[:k + 1] + decls + new[k + 1:]
print('\n'.join(new))
