#!/bin/bash
#
#


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

echo "[`date`] source setupmu2e-art.sh"
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
setup codetools

echo "[`date`] printenv after setup"
printenv


echo "[$(date)] starting with MU2E_TAG=$MU2E_TAG BUILDTYPE=$BUILDTYPE label=$label"

source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
setup muse

echo "[$(date)] clone"
git clone -q https://github.com/Mu2e/Offline
[ $? -ne 0 ] && exit 1


echo "[$(date)] checkout $MU2E_TAG"
git -C Offline checkout -b temp_work $MU2E_TAG
[ $? -ne 0 ] && exit 1

echo "[`date`] show what is checked out"
git -C Offline show -1
git -c Offline status

echo "[$(date)] muse setup"
muse -v setup -1 -q $BUILDTYPE
[ $? -ne 0 ] && exit 1

LOG=copyBack/build-${MU2E_TAG}-${MUSE_STUB}.log

echo "[$(date)] muse build"
muse build -j 20 >& $LOG
if [ $? -eq 0 ]; then
  echo "[$(date)] build success"
else
  echo "[$(date)] build failed - tail of log:"
  tail -100 $LOG
  exit 1
fi

RLOG=copyBack/build-release-${MU2E_TAG}-${MUSE_STUB}.log

echo "[$(date)] muse build RELEASE"
muse build RELEASE >& $RLOG
[ $? -ne 0 ] && exit 1

cp $LOG $MUSE_BUILD_BASE/Offline/gen/txt
cp $RLOG $MUSE_BUILD_BASE/Offline/gen/txt

mkdir tar

echo "[$(date)] muse tarball"
muse tarball -e copyBack -t ./tar -r Offline/$MU2E_TAG
[ $? -ne 0 ] && exit 1

exit 0


