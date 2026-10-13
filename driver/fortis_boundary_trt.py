#!/usr/bin/env python3
# fortis_boundary_trt.py <lift2d.json> -> boundary.cu
# The boundary verdict for a second consumer of the contract: the lifted pre and post expressions and the
# layout pair become two CUDA kernels around an opaque engine call on (B, n_in) -> (B, n_out) fp32 buffers.
# The host arrays and vectors are the host's own globals, read in place; expressions run in the host's type.
import sys, json
d = json.load(open(sys.argv[1]))
lin, lout = d['layout']['in'], d['layout']['out']
NI, NK = lin['from_shape']; NO = lout['to_shape'][1]
assert lin['to_shape'] == [NK, NI] and lout['from_shape'] == [NO, NI] and lout['to_shape'] == [NI, NO], (lin, lout)
CT = {'f64': 'double', 'f32': 'float'}
def expr(e, aval):
    if isinstance(e, list) and e[0] == 'A': return aval
    if isinstance(e, list) and e[0] == 'V': return 'g_%s[k]' % e[1]
    if isinstance(e, list) and e[0] == 'C': return repr(float(e[1]))
    op = {'arith.addf': '+', 'arith.subf': '-', 'arith.mulf': '*', 'arith.divf': '/'}[e[0]]
    return '(%s %s %s)' % (expr(e[1], aval), op, expr(e[2], aval))
pre, post = d.get('pre'), d.get('post')
globs = []
for p in (pre, post):
    if p:
        for g in p['globals']: globs.append((g, p['sizes'][g], CT[p['elt']]))
o = ['#include <cuda_runtime.h>', '#include <cstdio>', 'extern "C" void fortis_trt_forward(const void*, void*, cudaStream_t);']
for g, n, t in globs: o.append('extern "C" %s %s[%d]; static %s* g_%s = 0;' % (t, g, n, t, g))
o.append('static float *x32 = 0, *y32 = 0;')
HT, OT = CT[lin['from_elt']], CT[lout['to_elt']]
o.append('__global__ void fortis_pre_k(const %s* A, float* x%s) {' % (HT, ''.join(', const %s* g_%s' % (t, g) for g, n, t in globs if pre and g in pre['globals'])))
o.append('  int t = blockIdx.x * blockDim.x + threadIdx.x; if (t >= %d) return; int i = t / %d, k = t %% %d;' % (NI * NK, NK, NK))
o.append('  %s a = A[i + %dL * k];' % (HT, NI))
if pre: o.append('  a = %s;' % expr(pre['expr'], 'a'))
o.append('  x[i * %d + k] = (float)a;' % NK)
o.append('}')
o.append('__global__ void fortis_post_k(const float* y, %s* B%s) {' % (OT, ''.join(', const %s* g_%s' % (t, g) for g, n, t in globs if post and g in post['globals'])))
o.append('  int t = blockIdx.x * blockDim.x + threadIdx.x; if (t >= %d) return; int i = t / %d, k = t %% %d;' % (NI * NO, NO, NO))
o.append('  %s b = (%s)y[i * %d + k];' % (OT, OT, NO))
if post: o.append('  b = %s;' % expr(post['expr'], 'b'))
o.append('  B[i + %dL * k] = b;' % NI)
o.append('}')
o.append('extern "C" void fortis_trt_boundary(const void* din, void* dout, cudaStream_t s) {')
o.append('  if (!x32) {')
o.append('    cudaMalloc(&x32, %dL * 4); cudaMalloc(&y32, %dL * 4);' % (NI * NK, NI * NO))
for g, n, t in globs: o.append('    cudaMalloc(&g_%s, %dL * sizeof(%s)); cudaMemcpy(g_%s, %s, %dL * sizeof(%s), cudaMemcpyHostToDevice);' % (g, n, t, g, g, n, t))
o.append('  }')
o.append('  fortis_pre_k<<<(%d + 255) / 256, 256, 0, s>>>((const %s*)din, x32%s);' % (NI * NK, HT, ''.join(', g_%s' % g for g, n, t in globs if pre and g in pre['globals'])))
o.append('  fortis_trt_forward(x32, y32, s);')
o.append('  fortis_post_k<<<(%d + 255) / 256, 256, 0, s>>>(y32, (%s*)dout%s);' % (NI * NO, OT, ''.join(', g_%s' % g for g, n, t in globs if post and g in post['globals'])))
o.append('  cudaStreamSynchronize(s);')
o.append('}')
print('\n'.join(o))
