#!/bin/bash
# Build SAM from sam_code_NN with RAD_CAM. Produces ./SAM.
set -e
module load OpenMPI/4.1.6 netcdf/4.9.3-gcc HDF5/1.14.6
SRC=$PWD/sam_code_NN; OBJ=$PWD/OBJ; mkdir -p $OBJ; cd $OBJ
printf "%s\n%s\n" $SRC $SRC/RAD_CAM > Filepath
perl $SRC/SCRIPT/mkSrcfiles
perl $SRC/SCRIPT/mkDepends Filepath Srcfiles > Depends
make -j 8 -f ../Makefile.sam 2>&1 | tee build.log | grep -i "error" | head -40
ls -la ../SAM
