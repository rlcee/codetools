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
setup codetools

# pull the main repo
#git clone http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline/Offline.git
git clone https://github.com/mu2e/Offline
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
RC1=$?
echo "["`date`"] scons return code is $RC1"

mu2e -n 10 -c Validation/fcl/ceSimReco.fcl
RC2=$?
echo "["`date`"] ceSimReco return code is $RC2"

#rootOverlaps.sh
#RC3=$?
#echo "["`date`"] rootOverlaps return code is $RC3"

#RC=$(($RC1+$RC2+$RC3))
RC=$(($RC1+$RC2))
exit $RC
