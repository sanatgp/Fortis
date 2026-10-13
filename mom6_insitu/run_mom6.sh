#!/bin/bash
# run_mom6.sh shipped|percell|fortis|expert_trt : 2 model days of the 0.25-degree NeverWorld2 case on 4 ranks, from a fresh copy of run_ann
V=$1; F=/scratch/taghipouranvari.s/FTORCH
case $V in shipped) EXE=$F/mom6/nw2/build/MOM6;; *) EXE=$F/mom6/nw2/build_$V/MOM6;; esac
R=$F/mom6/run_$V; rm -rf $R; cp -r $F/mom6/run_ann $R; cd $R; rm -f run.log ocean.stats* RESTART/* *.nc.0*
cp $F/zb_run/zb_nn.bin . 2>/dev/null
module load OpenMPI/4.1.6 netcdf/4.9.3-gcc HDF5/1.14.6 2>/dev/null || true
export OMP_NUM_THREADS=1
export ZB_TRT_PLAN=$F/zb_run/zb_b35216.plan
X=""
if [ "$V" = fortis ] || [ "$V" = expert_trt ]; then
  export CUDA_MPS_PIPE_DIRECTORY=$HOME/mps/pipe CUDA_MPS_LOG_DIRECTORY=$HOME/mps/log
  mkdir -p $HOME/mps/pipe $HOME/mps/log
  pgrep -x nvidia-cuda-mps-control > /dev/null || nvidia-cuda-mps-control -d
  sleep 2
  X="-x CUDA_MPS_PIPE_DIRECTORY -x ZB_TRT_PLAN"
fi
/usr/bin/time -f "wall %e s" mpirun --oversubscribe -np 4 $X $EXE > run.log 2> time.log; echo "exit $?" >> time.log
echo "== $V"; tail -2 time.log
grep "MOM Day" run.log | tail -1
grep -n "ZB2020 compute stress ANN\|^ *Ocean *[0-9]\|Main loop\|Total runtime" run.log | head -6
