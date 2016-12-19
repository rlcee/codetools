#!/bin/bash

echo "["`date`"] environment"

printenv
df -h
pwd

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
