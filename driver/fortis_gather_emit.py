#!/usr/bin/env python3
# Emit the gather kernel of a stencil lift as CUDA: one thread per row of the batch reads the host's
# arrays at the stencil of its cell, applies the lifted expressions, and writes the model's input buffer.
#   fortis_gather_emit.py <gather.json> <loop.json> > gather.cu
import sys, json
G = json.load(open(sys.argv[1])); Lp = json.load(open(sys.argv[2]))
nin, count, ilo, ni = G['nin'], Lp['batch'], Lp['inner']['lo'], Lp['inner']['n']
jlo = Lp['outer']['lo'] if Lp['outer'] else 0
cty = {'f32': 'float', 'f64': 'double'}
uses = [(s['array'], s['idx']) for s in G['slots']] + [(s['array'], s['idx']) for s in G['scalars']]
A = []
for ai, a in enumerate(G['arrays']):
    shape = a['shape']; strides = [1]
    for n in shape[:-1]: strides.append(strides[-1] * n)
    vdims = sorted({di for (aj, idx) in uses if aj == ai for di, c in enumerate(idx) if c[0] == 'v'})
    assert vdims == list(range(len(shape) - len(vdims), len(shape))), 'plane dims must be the trailing dims'
    plane = 1
    for di in range(len(shape) - len(vdims)): plane *= shape[di]
    A.append({'c': cty[a['elt']], 'strides': strides, 'plane': plane, 'vdims': vdims, 'total': plane * eval('*'.join(str(shape[v]) for v in vdims) or '1')})
def elem(ai, idx):
    terms = []
    for di, c in enumerate(idx):
        if c[0] == 'v': continue
        terms.append('(%s%+d - 1) * %d' % (c[0], c[1], A[ai]['strides'][di]) if A[ai]['strides'][di] != 1 else '(%s%+d - 1)' % (c[0], c[1]))
    return ' + '.join(terms)
def plane_off(ai, idx):
    return ' + '.join('(long)(a%d - 1) * %dL' % (c[1], A[ai]['strides'][di]) for di, c in enumerate(idx) if c[0] == 'v') or '0'
o = ['#include <cuda_runtime.h>', '#include <stdio.h>', 'extern "C" void* mgpuStreamCreate(void);', 'extern "C" void* fortis_model_input(void);']
o.append('static void *%s; static int ginit = 0;' % ', *'.join('dA%d' % ai for ai in range(len(A))))
o.append('static const void *%s;' % ', *'.join('pA%d' % ai for ai in range(len(A))))
sig = ', '.join('const %s* A%d' % (A[ai]['c'], ai) for ai in range(len(A)))
o.append('__global__ void fortis_gather_k(%s, float* X, int count, int ilo, int jlo, int ni) {' % sig)
o.append('  int col = blockIdx.x * blockDim.x + threadIdx.x; if (col >= count) return;')
o.append('  int i = ilo + col %% ni, j = jlo + col / ni; float* x = X + (size_t)col * %d; float xv;' % nin)
for s in G['scalars']: o.append('  const %s %s = A%d[%s];' % (A[s['array']]['c'], s['name'], s['array'], elem(s['array'], s['idx'])))
for q, s in enumerate(G['slots']):
    line = '  xv = A%d[%s];' % (s['array'], elem(s['array'], s['idx']))
    for e in G['exprs']: line += ' xv = %s;' % e
    o.append(line + ' x[%d] = xv;' % q)
o.append('}')
argl = ', '.join(['int a%d' % i for i in range(len(G['args']))] + ['const %s* H%d' % (A[ai]['c'], ai) for ai in range(len(A))])
o.append('extern "C" void fortis_gather(%s) {' % argl)
o.append('  cudaStream_t s = (cudaStream_t)mgpuStreamCreate();')
o.append('  if (!ginit) {')
for ai, a in enumerate(G['arrays']):
    # the host array is pinned once at its first address; an operand that moves is a temporary and is not pinned
    o.append('    cudaMalloc(&dA%d, %dL * sizeof(%s)); pA%d = H%d; cudaHostRegister((void*)H%d, %dL * sizeof(%s), cudaHostRegisterDefault); cudaGetLastError();' % (ai, A[ai]['plane'], A[ai]['c'], ai, ai, ai, A[ai]['total'], A[ai]['c']))
o.append('    ginit = 1;\n  }')
for ai, a in enumerate(G['arrays']):
    idx = next(idx for (aj, idx) in uses if aj == ai)
    o.append('  cudaMemcpyAsync(dA%d, H%d + (%s), %dL * sizeof(%s), cudaMemcpyHostToDevice, s);' % (ai, ai, plane_off(ai, idx), A[ai]['plane'], A[ai]['c']))
o.append('  float* X = (float*)fortis_model_input();')
o.append('  fortis_gather_k<<<(%d + 255) / 256, 256, 0, s>>>(%s, X, %d, %d, %d, %d);' % (count, ', '.join('(const %s*)dA%d' % (A[ai]['c'], ai) for ai in range(len(A))), count, ilo, jlo, ni))
o.append('}')
print('\n'.join(o))
