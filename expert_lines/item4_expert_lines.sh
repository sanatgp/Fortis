#!/bin/bash
# Item 4: what the expert must edit when the application changes, against FORTIS on unchanged source.
# Three changes to the E3SM host: chunk 384 -> 768, hidden width 128 -> 512, and a second post nest (out_gain).
# Run on the V100 node in $F/cam_run:  bash item4_expert_lines.sh
set -e
F=/scratch/taghipouranvari.s/FTORCH; cd $F/cam_run
CUDA=/shared/EL9/explorer/nvidia-hpc-sdk/24.7/Linux_x86_64/24.7/cuda/12.5
TRT=$F/venv-trt/lib/python3.12/site-packages/tensorrt_libs; TRTI=$F/trt_run/trt-oss/include
mkdir -p item4

if [ ! -f $F/climsim_run/climsim_b768.plan ]; then
echo "== batch-768 engine (same weights as climsim_b384.onnx, batch dimension rewritten)"
(source $F/venv-trt/bin/activate && cd $F/climsim_run && python - <<'PY'
import onnx, tensorrt as trt
m = onnx.load("climsim_b384.onnx")
for t in list(m.graph.input) + list(m.graph.output):
    d = t.type.tensor_type.shape.dim[0]
    if d.dim_value == 384: d.dim_value = 768
onnx.save(m, "climsim_b768.onnx")
logger = trt.Logger(trt.Logger.WARNING); b = trt.Builder(logger)
net = b.create_network(1 << int(trt.NetworkDefinitionCreationFlag.EXPLICIT_BATCH)); p = trt.OnnxParser(net, logger)
assert p.parse(open("climsim_b768.onnx", "rb").read()), [p.get_error(i) for i in range(p.num_errors)]
cfg = b.create_builder_config(); cfg.set_memory_pool_limit(trt.MemoryPoolType.WORKSPACE, 1 << 30)
plan = b.build_serialized_network(net, cfg); open("climsim_b768.plan", "wb").write(plan); print("built climsim_b768.plan", plan.nbytes)
PY
deactivate)
fi

if [ ! -f item4/cam_host_expert_gain.f90 ]; then
echo "== the three changed expert programs, by minimal edits of the originals"
python3 - <<'PY'
cu = open("fwd_trt_bnd.cu").read(); f90 = open("cam_host_expert.f90").read()
a = cu.replace("#define NC 384", "#define NC 768").replace("climsim_b384.plan", "climsim_b768.plan")
open("item4/fwd_trt_bnd_768.cu", "w").write(a)
h = f90.replace("pcols = 384", "pcols = 768").replace('"cam_state.bin"', '"cam_state_768.bin"').replace('"cam_ref.bin"', '"cam_ref_768.bin"')
open("item4/cam_host_expert_768.f90", "w").write(h)
open("item4/fwd_trt_bnd_w512.cu", "w").write(open("fwd_trt_bnd_w512.cu").read())
open("item4/cam_host_expert_w512.f90", "w").write(f90)
c = cu.replace("static double *din, *dout, *dmean, *dmax, *dmin, *dscale;", "static double *din, *dout, *dmean, *dmax, *dmin, *dscale, *dgain;")
c = c.replace("__global__ void post_k(const float* y, const double* scale, double* out) {", "__global__ void post_k(const float* y, const double* scale, const double* gain, double* out) {")
c = c.replace("out[i + (long)k * NC] = (double)y[idx] / scale[k];", "out[i + (long)k * NC] = (double)y[idx] / scale[k] * gain[k];")
c = c.replace('extern "C" void mlp_forward_bnd(double* in, double* mean, double* mx, double* mn, double* scale, double* out) {',
              'extern "C" void mlp_forward_bnd(double* in, double* mean, double* mx, double* mn, double* scale, double* gain, double* out) {')
c = c.replace("cudaMalloc(&dscale, NO * 8);", "cudaMalloc(&dscale, NO * 8); cudaMalloc(&dgain, NO * 8);")
c = c.replace("cudaMemcpy(dscale, scale, NO * 8, cudaMemcpyHostToDevice);", "cudaMemcpy(dscale, scale, NO * 8, cudaMemcpyHostToDevice); cudaMemcpy(dgain, gain, NO * 8, cudaMemcpyHostToDevice);")
c = c.replace("post_k<<<(NC * NO + 255) / 256, 256, 0, s>>>(dy, dscale, dout);", "post_k<<<(NC * NO + 255) / 256, 256, 0, s>>>(dy, dscale, dgain, dout);")
assert c.count("dgain") == 4 and c.count("gain[k]") == 1, (c.count("dgain"), c.count("gain[k]"))
open("item4/fwd_trt_bnd_gain.cu", "w").write(c)
g = f90.replace("subroutine mlp_forward_bnd(a, m, mx, mn, sc, b)", "subroutine mlp_forward_bnd(a, m, mx, mn, sc, g, b)")
g = g.replace("real(kind(1.0d0)) :: a(*), m(*), mx(*), mn(*), sc(*), b(*)", "real(kind(1.0d0)) :: a(*), m(*), mx(*), mn(*), sc(*), g(*), b(*)")
g = g.replace("out_scale(outputlength)\n", "out_scale(outputlength), out_gain(outputlength)\n", 1)
g = g.replace("  ncol = pcols\n", "  ncol = pcols\n  out_gain = 2.0d0\n", 1)
g = g.replace("call mlp_forward_bnd(input, in_mean, in_max, in_min, out_scale, output)", "call mlp_forward_bnd(input, in_mean, in_max, in_min, out_scale, out_gain, output)")
assert g.count("out_gain") == 3, g.count("out_gain")
open("item4/cam_host_expert_gain.f90", "w").write(g)
print("wrote item4/*")
PY
fi

count() { diff "$1" "$2" | grep -c '^[<>]' || true; }
echo "== lines touched (diff lines, both sides of each hunk)"
printf "%-28s %10s %11s %11s\n" change expert_cu expert_f90 fortis_f90
printf "%-28s %10s %11s %11s\n" "chunk 384->768"     $(count fwd_trt_bnd.cu item4/fwd_trt_bnd_768.cu)  $(count cam_host_expert.f90 item4/cam_host_expert_768.f90)  $(count cam_host.f90 cam_host_768.f90)
printf "%-28s %10s %11s %11s\n" "hidden 128->512"    $(count fwd_trt_bnd.cu item4/fwd_trt_bnd_w512.cu) $(count cam_host_expert.f90 item4/cam_host_expert_w512.f90) 0
printf "%-28s %10s %11s %11s\n" "post nest out_gain" $(count fwd_trt_bnd.cu item4/fwd_trt_bnd_gain.cu) $(count cam_host_expert.f90 item4/cam_host_expert_gain.f90) $(count cam_host.f90 bv_compose.f90)
echo "   (expert also rebuilds a TensorRT engine for the first two changes; FORTIS re-runs fortisc on the same command line)"

echo "== build and run the changed expert programs"
build() { $CUDA/bin/nvcc -O2 -w -arch=sm_70 -I$TRTI -I$CUDA/include -c item4/$2.cu -o item4/$2.o 2>/dev/null
          gfortran -O2 -ffree-line-length-none item4/$1.f90 item4/$2.o -o item4/$3 $TRT/libnvinfer.so.10 -L$CUDA/lib64 -lcudart -lstdc++ -Wl,-rpath,$TRT -Wl,-rpath,$CUDA/lib64; }
build cam_host_expert_768  fwd_trt_bnd_768  expert_768
build cam_host_expert_w512 fwd_trt_bnd_w512 expert_w512
build cam_host_expert_gain fwd_trt_bnd_gain expert_gain
run5() { for i in 1 2 3 4 5; do "$1" 2>/dev/null | tr '\n' ' '; echo; done | awk -v n="$1" -F'per-step ms:' '{split($2,a," "); s+=a[1]; c++; last=$0} END{print n ": " last; printf "   mean per-step ms %.3f over %d runs\n", s/c, c}'; }
for e in expert_768 expert_w512 expert_gain; do run5 ./item4/$e; done
echo "== the FORTIS builds for the same three changes, unchanged source through the same fortisc command"
for e in cam_bnd_768 cam_fortis_bnd_w512 bv_compose_bnd; do run5 ./$e; done
