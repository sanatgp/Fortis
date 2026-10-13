#!/bin/bash
# Two more timed runs of each in-situ build; per-run logs in $F/mom6/insitu/runs, summary in runs/summary.txt
F=/scratch/taghipouranvari.s/FTORCH; D=$F/mom6/insitu/runs; mkdir -p $D
for v in shipped fortis expert_trt; do cp $F/mom6/run_$v/run.log $D/${v}_1.log 2>/dev/null; done
for i in 2 3; do for v in shipped fortis expert_trt; do
  $F/mom6/insitu/run_mom6.sh $v > /dev/null 2>&1; cp $F/mom6/run_$v/run.log $D/${v}_$i.log
done; done
for f in $D/*_[123].log; do
  m=$(grep "Main loop" $f | awk '{print $5}'); z=$(grep "ZB2020 compute stress ANN" $f | awk '{print $7}')
  echo "$(basename $f .log) step_ms $(echo "$m*1000/288" | bc -l | cut -c1-7) zb_ms $(echo "$z*1000/288" | bc -l | cut -c1-6)"
done | tee $D/summary.txt
