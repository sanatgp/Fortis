#!/usr/bin/env python3
# Loop fission at HLFIR for the expanded-temporary case of fortis_units.py.
#   fortis_fission_hlfir.py <host.hlfir> <loop.json> -> host HLFIR with the nest split
# The nest is copied twice.  The first copy keeps the pre units and ends each iteration by packing the
# call's input temporary into row col of a batch buffer; one batched call runs between the copies; the
# second copy starts each iteration by unpacking row col of the output buffer and keeps the post units.
# A unit needed by both loops ('both') stays in both copies.  When the loop bounds are run-time values
# the bound definitions are cloned in front of the nest, the count is computed there, and
# fortis_begin(count) specializes the model side at first call.
import re, sys, json
L = open(sys.argv[1]).read().split('\n'); d = json.load(open(sys.argv[2]))
if d.get('verdict') != 'batched' or d.get('mode') != 'expanded': sys.exit('not an expanded batched loop')
inner, outer, n = d['inner'], d['outer'], d['call_line']
nlo, nhi = (outer['start'], outer['end']) if outer else (inner['start'], inner['end'])
pre_ranges = [(s['lo'], s['hi']) for s in d['statements'] if s['side'] == 'pre']
post_ranges = [(s['lo'], s['hi']) for s in d['statements'] if s['side'] == 'post']
def ref_ty(shape, elt): return '!fir.ref<!fir.array<%dx%s>>' % (shape[0], elt)
tin_ty, tout_ty = ref_ty(d['in_shape'], d['in_elt']), ref_ty(d['out_shape'], d['out_elt'])
ind = re.match(r'(\s*)', L[inner['start'] + 1]).group(1)
nest_ind = re.match(r'(\s*)', L[nlo]).group(1)
runtime = d.get('batch') is None
# ---- bound tokens: an int becomes a constant in front of the nest, an SSA value is cloned there if it is
# defined between the loops, and used as is if it is defined before the nest
ren = {}
pre_nest = []
def clone_between():
    if not outer: return
    for i in range(outer['start'] + 1, inner['start']):
        m = re.match(r'\s*(%[\w]+) = (.*)', L[i])
        if not m or re.match(r'\s*fir\.store', L[i]): continue
        new = '%fxb_' + m.group(1)[1:]; ren[m.group(1)] = new
        body = re.sub(r'%[\w]+', lambda mm: ren.get(mm.group(0), mm.group(0)), m.group(2))
        pre_nest.append(nest_ind + new + ' = ' + body)
def tok(name, v):
    if isinstance(v, int):
        pre_nest.append(nest_ind + '%%%s = arith.constant %d : i32' % (name, v)); return '%' + name
    return ren.get(v, v)
clone_between()
ilo, ihi = tok('fx_ilo', inner['lo']), tok('fx_ihi', inner['hi'])
pre_nest.append(nest_ind + '%fx_one = arith.constant 1 : i32')
pre_nest.append(nest_ind + '%fx_ispan = arith.subi ' + ihi + ', ' + ilo + ' : i32')
pre_nest.append(nest_ind + '%fx_ni = arith.addi %fx_ispan, %fx_one : i32')
if outer:
    jlo, jhi = tok('fx_jlo', outer['lo']), tok('fx_jhi', outer['hi'])
    pre_nest.append(nest_ind + '%fx_jspan = arith.subi ' + jhi + ', ' + jlo + ' : i32')
    pre_nest.append(nest_ind + '%fx_nj = arith.addi %fx_jspan, %fx_one : i32')
    pre_nest.append(nest_ind + '%fx_count = arith.muli %fx_ni, %fx_nj : i32')
else:
    pre_nest.append(nest_ind + '%fx_count = arith.addi %fx_ni, %c0_i32_fx : i32')
    pre_nest.insert(0, nest_ind + '%c0_i32_fx = arith.constant 0 : i32')
if runtime: pre_nest.append(nest_ind + 'fir.call @fortis_begin(%fx_count) : (i32) -> ()')
def col_lines():
    ls = [ind + '%fx_i = arith.subi ' + inner['arg'] + ', ' + ilo + ' : i32']
    if outer:
        ls += [ind + '%fx_j = arith.subi ' + outer['arg'] + ', ' + jlo + ' : i32', ind + '%fx_m = arith.muli %fx_j, %fx_ni : i32',
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
new = L[:nlo] + pre_nest + copy('pre') + [nest_ind + 'fir.call @mlp_forward_batched() : () -> ()'] + copy('post') + L[nhi + 1:]
decls = ['  func.func private @fortis_pack(' + tin_ty + ', i32) attributes {fir.bindc_name = "fortis_pack", fir.proc_attrs = #fir.proc_attrs<bind_c>}',
         '  func.func private @fortis_unpack(' + tout_ty + ', i32) attributes {fir.bindc_name = "fortis_unpack", fir.proc_attrs = #fir.proc_attrs<bind_c>}',
         '  func.func private @fortis_begin(i32) attributes {fir.bindc_name = "fortis_begin", fir.proc_attrs = #fir.proc_attrs<bind_c>}',
         '  func.func private @mlp_forward_batched() attributes {fir.bindc_name = "mlp_forward_batched", fir.proc_attrs = #fir.proc_attrs<bind_c>}']
k = max(i for i, l in enumerate(new) if l.startswith('  func.func private @'))
new = new[:k + 1] + decls + new[k + 1:]
print('\n'.join(new))
