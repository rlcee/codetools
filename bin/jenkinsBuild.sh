#!/bin/bash
#
# build a tagged version of Offline in Jenkins system
# $MU2E_RELEASE_TAG should be set
#


echo "[`date`] start for MU2E_RELEASE_TAG=$MU2E_RELEASE_TAG MU2E_BRANCH=$MU2E_BRANCH"

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

echo "[`date`] clone offline"
git clone http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline/Offline.git

echo "[`date`] cd Offline"
cd Offline

if [ "$MU2E_TAG" == "" ]; then
  echo "Error - MU2E_TAG not set - exiting"
  exit 1
fi

echo "[`date`]checkout command: $CHECKOUT_COM"
$CHECKOUT_COM
git checkout $MU2E_TAG

echo "[`date`] show what is checked out"
git show-ref $MU2E_TAG
git status

echo "[`date`] source setup"
./buildopts --build=$BUILDTYPE
source setup.sh

echo "[`date`] start scons"
scons -j 16
RC=$?
echo "["`date`"] scons return code=$RC"

if [ $RC -ne 0  ]; then
    echo "["`date`"] exiting after scons with return code=$RC"
    exit $RC
fi

# make deps.txt, gdml, validation files, etc
scons RELEASE
RC=$?
echo "["`date`"] scons RELEASE return code=$RC"

if [ $RC -ne 0  ]; then
    echo "["`date`"] exiting after scons RELEASE with return code=$RC"
    exit $RC
fi

echo "["`date`"] making tarballs"
# back to the top of the working directory
cd $LOCAL_DIR
echo "["`date`"] pwd"
pwd
echo "["`date`"] ls of local dir"
ls -al

mkdir -p Offline/gen/log
cp build.log Offline/gen/log/build.log

echo "["`date`"] tar of Offline"
tar -czf copyBack/Offline_${MU2E_TAG}_${label}_${BUILDTYPE}.tgz Offline
RC=$?

echo "["`date`"] done tarball, RC=$RC"
if [ $RC -ne 0  ]; then
    echo "["`date`"] exiting after tarball with return code=$RC"
    exit $RC
fi

echo "["`date`"] exiting success"

exit 0
