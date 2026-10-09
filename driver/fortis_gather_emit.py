#!/usr/bin/env python3
# Emit the kernels of a stencil lift as CUDA.  Gather: one thread per row reads the host's arrays at the
# stencil of its cell, applies the lifted expressions, and writes the model's input buffer.  Scatter: one
# thread per row reads the model's output, applies the expressions, and writes device planes of the host
# arrays, from which the visited rectangle is copied back.
#   fortis_gather_emit.py <gather.json> <scatter.json> <loop.json> > gather.cu
import sys, json
G = json.load(open(sys.argv[1])); S = json.load(open(sys.argv[2])); Lp = json.load(open(sys.argv[3]))
K = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else {'ok': False}
nk, klo = (K['nk'], K['loop']['lo']) if K.get('ok') else (1, 0)
count, ilo, ni = Lp['batch'] // nk, Lp['inner']['lo'], Lp['inner']['n']
jlo, nj = (Lp['outer']['lo'], count // ni) if Lp['outer'] else (0, 1)
cty = {'f32': 'float', 'f64': 'double'}
o = ['#include <cuda_runtime.h>', '#include <stdio.h>', 'extern "C" void* mgpuStreamCreate(void);',
     'extern "C" void* fortis_model_input(void);', 'extern "C" void* fortis_model_output(void);']
def plan(J, uses):
    A = []
    for ai, a in enumerate(J['arrays']):
        shape = a['shape']; strides = [1]
        for nn in shape[:-1]: strides.append(strides[-1] * nn)
        vdims = sorted({di for (aj, idx) in uses if aj == ai for di, c in enumerate(idx) if c[0] == 'v'})
        assert vdims == list(range(len(shape) - len(vdims), len(shape))), 'plane dims must be the trailing dims'
        plane = 1
        for di in range(len(shape) - len(vdims)): plane *= shape[di]
        A.append({'c': cty[a['elt']], 'strides': strides, 'plane': plane, 'shape': shape,
                  'total': plane * eval('*'.join(str(shape[v]) for v in vdims) or '1'), 'idx': next(idx for (aj, idx) in uses if aj == ai)})
    return A
def elem(A, ai, idx):
    terms = []
    for di, c in enumerate(idx):
        if c[0] == 'v': continue
        st = A[ai]['strides'][di]
        terms.append('(%s%+d - 1) * %d' % (c[0], c[1], st) if st != 1 else '(%s%+d - 1)' % (c[0], c[1]))
    return ' + '.join(terms)
def plane_off(A, ai, idx):
    return ' + '.join('(long)(a%d - 1) * %dL' % (c[1], A[ai]['strides'][di]) for di, c in enumerate(idx) if c[0] == 'v') or '0'
def common(J, A, pfx, planes=1):
    o.append('static void *%s; static int %sinit = 0;' % (', *'.join('%sd%d' % (pfx, ai) for ai in range(len(A))), pfx))
    o.append('static void %ssetup(%s) {' % (pfx, ', '.join('const %s* H%d' % (A[ai]['c'], ai) for ai in range(len(A)))))
    for ai, a in enumerate(J['arrays']):
        o.append('  cudaMalloc(&%sd%d, %dL * sizeof(%s)); cudaHostRegister((void*)H%d, %dL * sizeof(%s), cudaHostRegisterDefault); cudaGetLastError();' % (pfx, ai, A[ai]['plane'] * planes, A[ai]['c'], ai, A[ai]['total'], A[ai]['c']))
    o.append('  %sinit = 1;\n}' % pfx)
if G.get('ok'):
    uses = [(s['array'], s['idx']) for s in G['slots']] + [(s['array'], s['idx']) for s in G['scalars']]
    A = plan(G, uses); nin = G['n']; common(G, A, 'g', nk)
    o.append('__global__ void fortis_gather_k(%s, float* X, int count, int ilo, int jlo, int ni) {' % ', '.join('const %s* A%d' % (A[ai]['c'], ai) for ai in range(len(A))))
    o.append('  int row = blockIdx.x * blockDim.x + threadIdx.x; if (row >= count * %d) return; int col = row %% count, kk = row / count;' % nk)
    o.append('  int i = ilo + col %% ni, j = jlo + col / ni; float* x = X + (size_t)row * %d; float tv;' % nin)
    if K.get('ok'):
        for ai in range(len(A)): o.append('  A%d += (size_t)kk * %dL;' % (ai, A[ai]['plane']))
    for s in G['scalars']: o.append('  const %s %s = A%d[%s];' % (A[s['array']]['c'], s['name'], s['array'], elem(A, s['array'], s['idx'])))
    for q, s in enumerate(G['slots']):
        line = '  tv = A%d[%s];' % (s['array'], elem(A, s['array'], s['idx']))
        for e in G['exprs']: line += ' tv = %s;' % e
        o.append(line + ' x[%d] = tv;' % q)
    o.append('}')
    gargs = [] if K.get('ok') else ['int a%d' % i for i in range(len(G['args']))]
    o.append('extern "C" void fortis_gather(%s) {' % ', '.join(gargs + ['const %s* H%d' % (A[ai]['c'], ai) for ai in range(len(A))]))
    o.append('  cudaStream_t s = (cudaStream_t)mgpuStreamCreate(); if (!ginit) gsetup(%s);' % ', '.join('H%d' % ai for ai in range(len(A))))
    for ai in range(len(A)):
        if K.get('ok'): o.append('  cudaMemcpyAsync(gd%d, H%d + (long)(%d - 1) * %dL, %dL * sizeof(%s), cudaMemcpyHostToDevice, s);' % (ai, ai, klo, A[ai]['plane'], A[ai]['plane'] * nk, A[ai]['c']))
        else: o.append('  cudaMemcpyAsync(gd%d, H%d + (%s), %dL * sizeof(%s), cudaMemcpyHostToDevice, s);' % (ai, ai, plane_off(A, ai, A[ai]['idx']), A[ai]['plane'], A[ai]['c']))
    o.append('  fortis_gather_k<<<(%d + 255) / 256, 256, 0, s>>>(%s, (float*)fortis_model_input(), %d, %d, %d, %d);' % (count * nk, ', '.join('(const %s*)gd%d' % (A[ai]['c'], ai) for ai in range(len(A))), count, ilo, jlo, ni))
    o.append('}')
if S.get('ok'):
    uses = [(s['array'], s['idx']) for s in S['stores']] + [(s['array'], s['idx']) for s in S['scalars']]
    A = plan(S, uses); nout = S['n']; common(S, A, 's')
    written = sorted({s['array'] for s in S['stores']})
    o.append('__global__ void fortis_scatter_k(const float* Yd, %s, int count, int ilo, int jlo, int ni) {' % ', '.join('%s* A%d' % (A[ai]['c'], ai) for ai in range(len(A))))
    o.append('  int col = blockIdx.x * blockDim.x + threadIdx.x; if (col >= count) return;')
    o.append('  int i = ilo + col %% ni, j = jlo + col / ni; const float* y = Yd + (size_t)col * %d; float tv; float yv[%d];' % (nout, nout))
    for q in range(nout): o.append('  yv[%d] = y[%d];' % (q, q))
    for s in S['scalars']: o.append('  const %s %s = A%d[%s];' % (A[s['array']]['c'], s['name'], s['array'], elem(A, s['array'], s['idx'])))
    for e in S['exprs']:
        for q in range(nout): o.append('  tv = yv[%d]; tv = %s; yv[%d] = tv;' % (q, e, q))
    for s in S['stores']: o.append('  A%d[%s] = yv[%d];' % (s['array'], elem(A, s['array'], s['idx']), s['slot']))
    o.append('}')
    o.append('extern "C" void fortis_scatter(%s) {' % ', '.join(['int a%d' % i for i in range(len(S['args']))] + ['%s* H%d' % (A[ai]['c'], ai) for ai in range(len(A))]))
    o.append('  cudaStream_t s = (cudaStream_t)mgpuStreamCreate(); if (!sinit) ssetup(%s);' % ', '.join('H%d' % ai for ai in range(len(A))))
    for ai in range(len(A)):
        if ai not in written:
            o.append('  cudaMemcpyAsync(sd%d, H%d + (%s), %dL * sizeof(%s), cudaMemcpyHostToDevice, s);' % (ai, ai, plane_off(A, ai, A[ai]['idx']), A[ai]['plane'], A[ai]['c']))
    yoff = '(size_t)(a0 - %d) * %dL' % (klo, count * nout) if K.get('ok') else '0'
    o.append('  fortis_scatter_k<<<(%d + 255) / 256, 256, 0, s>>>((const float*)fortis_model_output() + %s, %s, %d, %d, %d, %d);' % (count, yoff, ', '.join('(%s*)sd%d' % (A[ai]['c'], ai) for ai in range(len(A))), count, ilo, jlo, ni))
    for s in S['stores']:
        ai = s['array']; di = next(c[1] for c in s['idx'] if c[0] == 'i'); dj = next((c[1] for c in s['idx'] if c[0] == 'j'), 0)
        pitch = A[ai]['strides'][1] if len(A[ai]['shape']) > 1 else 1
        rect = '(%d + %d - 1) + (long)(%d + %d - 1) * %d' % (ilo, di, jlo, dj, pitch)
        o.append('  cudaMemcpy2DAsync(H%d + (%s) + (%s), %dL * sizeof(%s), (%s*)sd%d + (%s), %dL * sizeof(%s), %dL * sizeof(%s), %d, cudaMemcpyDeviceToHost, s);'
                 % (ai, plane_off(A, ai, s['idx']), rect, pitch, A[ai]['c'], A[ai]['c'], ai, rect, pitch, A[ai]['c'], ni, A[ai]['c'], nj))
    o.append('  cudaStreamSynchronize(s);\n}')
print('\n'.join(o))
