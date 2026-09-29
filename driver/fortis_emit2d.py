#!/usr/bin/env python3
# fortis_emit2d.py <lift2d.json> <model.mlir> -> model.mlir with @fortis_main that takes the host's own arrays
# The host array A(ni,nk) is column-major, so its memory is the row-major tensor <nk x ni>.  The pre region
# reads it transposed, applies the lifted pre expression in the host's element type and casts to the model's
# type; the post region casts the model output back, applies the lifted post expression and writes the
# host's <nk x ni> memory order.  One linalg.generic before the model, one after.
import re, sys, json
d = json.load(open(sys.argv[1])); src = open(sys.argv[2]).read()
head = re.search(r'func\.func @(\w+)\((%\w+): (tensor<[^>]+>)\) -> (tensor<[^>]+>) \{', src)
fname, _, intype, outtype = head.groups()
lin, lout = d['layout']['in'], d['layout']['out']
def ten(shape, elt): return 'tensor<' + 'x'.join(map(str, shape)) + 'x' + elt + '>'
xin = ten(lin['from_shape'][::-1], lin['from_elt'])
xout = ten(lout['to_shape'][::-1], lout['to_elt'])
if ten(lin['to_shape'][::-1], lin['to_elt']) != intype or ten(lout['from_shape'][::-1], lout['from_elt']) != outtype:
    sys.exit('model signature %s -> %s does not match the call temporaries' % (intype, outtype))
def castline(name, v, a, b):
    op = 'arith.truncf' if int(a[1:]) > int(b[1:]) else 'arith.extf'
    return '      ' + name + ' = ' + op + ' ' + v + ' : ' + a + ' to ' + b
def region(tag, expr, syms, sizes, src_val, a_ty, a_elt, host_elt, out_ty, out_elt, g_map, cast_first):
    cnt = [0]; lines = []; a_name = '%a'
    if cast_first and a_elt != host_elt:
        a_name = '%' + tag + 'in'; lines.append(castline(a_name, '%a', a_elt, host_elt))
    def emit(t):
        if t[0] == 'A': return a_name
        if t[0] == 'V': return '%g' + str(syms.index(t[1]))
        if t[0] == 'C':
            cnt[0] += 1; lines.append('      %' + tag + 'c' + str(cnt[0]) + ' = arith.constant ' + t[1] + ' : ' + host_elt); return '%' + tag + 'c' + str(cnt[0])
        x, y = emit(t[1]), emit(t[2]); cnt[0] += 1
        lines.append('      %' + tag + 'v' + str(cnt[0]) + ' = ' + t[0] + ' ' + x + ', ' + y + ' : ' + host_elt); return '%' + tag + 'v' + str(cnt[0])
    r = emit(expr) if expr else a_name
    if not cast_first and host_elt != out_elt:
        lines.append(castline('%' + tag + 'out', r, host_elt, out_elt)); r = '%' + tag + 'out'
    gtys = ''.join(', tensor<' + str(sizes[g]) + 'x' + host_elt + '>' for g in syms)
    gins = ''.join(', %' + tag + 'G' + str(i) for i in range(len(syms)))
    maps = ', '.join(['affine_map<(d0, d1) -> (d1, d0)>'] + ['affine_map<(d0, d1) -> (' + g_map + ')>'] * len(syms) + ['affine_map<(d0, d1) -> (d0, d1)>'])
    bargs = ', '.join(['%a: ' + a_elt] + ['%g' + str(i) + ': ' + host_elt for i in range(len(syms))] + ['%o: ' + out_elt])
    out = '    %' + tag + 'e = tensor.empty() : ' + out_ty + '\n'
    out += '    %' + tag + 'r = linalg.generic {indexing_maps = [' + maps + '], iterator_types = ["parallel", "parallel"]} ins(' + src_val + gins + ' : ' + a_ty + gtys + ') outs(%' + tag + 'e : ' + out_ty + ') {\n'
    out += '    ^bb0(' + bargs + '):\n' + ''.join(l + '\n' for l in lines) + '      linalg.yield ' + r + ' : ' + out_elt + '\n    } -> ' + out_ty + '\n'
    return out
pre, post = d.get('pre'), d.get('post')
pre_syms = pre['globals'] if pre else []; pre_sizes = pre['sizes'] if pre else {}
post_syms = post['globals'] if post else []; post_sizes = post['sizes'] if post else {}
args = ['%x: ' + xin] + ['%preG' + str(i) + ': tensor<' + str(pre_sizes[g]) + 'x' + lin['from_elt'] + '>' for i, g in enumerate(pre_syms)]
args += ['%postG' + str(i) + ': tensor<' + str(post_sizes[g]) + 'x' + lout['to_elt'] + '>' for i, g in enumerate(post_syms)]
# pre: domain (b,k) over the model input; host tensor is (k,b); vectors are indexed by k = d1
body = region('pre', pre['expr'] if pre else None, pre_syms, pre_sizes, '%x', xin, lin['from_elt'], lin['from_elt'], intype, lin['to_elt'], 'd1', False)
body += '    %y0 = call @' + fname + '(%prer) : (' + intype + ') -> ' + outtype + '\n'
# post: domain (k,b) over the host output memory; model output is (b,k); vectors are indexed by k = d0
body += region('post', post['expr'] if post else None, post_syms, post_sizes, '%y0', outtype, lout['from_elt'], lout['to_elt'], xout, lout['to_elt'], 'd0', True)
pro = '\n  func.func @fortis_main(' + ', '.join(args) + ') -> ' + xout + ' {\n' + body + '    return %postr : ' + xout + '\n  }\n'
src = src.replace(head.group(0), head.group(0).replace('func.func @' + fname, 'func.func private @' + fname), 1)
cut = src.index('{-#') if '{-#' in src else src.rindex('}')
print(src[:cut].rstrip()[:-1] + pro + '}\n' + (src[cut:] if '{-#' in src else ''))
