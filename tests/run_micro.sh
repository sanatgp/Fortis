#!/bin/bash
# micro-suite: torch REF checksum must match the fortis checksum (run inside the torch-mlir venv)
cd "$(dirname "$0")"
for t in maxpool upsample convT convT_s1 bn concat two_convs; do
  NOUT=$(python optest_$t.py 2>&1 >/dev/null | grep -o "nout=[0-9]*" | cut -d= -f2)
  sed "s/nin = 3\*16\*16\*16, nout = 8\*16\*16\*16/nin = 256, nout = $NOUT/" conv_host.f90 > optest_host.f90
  fortisc optest_$t.py optest_host.f90 optest_bin 2>&1 | grep -E "REF" | cut -c1-60; ./optest_bin | tr '\n' ' ' | cut -c1-70; echo
done
