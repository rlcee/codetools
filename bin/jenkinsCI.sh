#!/bin/bash

echo "[`date`] printenv"
printenv
echo "[`date`] df -h"
df -h
echo "[`date`] quota"
quota -v
echo "[`date`] PWD"
pwd
export LOCAL_DIR=$PWD
echo "[`date`] ls of local dir"
ls -al
echo "[`date`] cpuinfo"
cat /proc/cpuinfo | head -30


echo "["`date`"] setups"
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
setup mu2e

# pull the main repo
git clone http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline/Offline.git
cd Offline

# dump the rev
git show
git rev-parse HEAD

# building prof and debug
./buildopts --build=$BUILDTYPE
source setup.sh

echo "["`date`"] ups"
ups active

echo "["`date`"] build"

scons -j 16
RC=$?

echo "["`date`"] scons return code is $RC"

exit $RC
