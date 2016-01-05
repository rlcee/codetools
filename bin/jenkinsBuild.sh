#!/bin/bash
#
# build a tagged version of Offline in Jenkins system
# $MU2E_RELEASE_TAG should be set
#


echo "[`date`] start for MU2E_RELEASE_TAG=$MU2E_RELEASE_TAG"

if [ "$MU2E_RELEASE_TAG" == "" ]; then
   echo "MU2E_RELEASE_TAG is not set - exiting"
   exit 1
fi

echo "[`date`] printenv"
printenv
echo "[`date`] df -h"
df -h
echo "[`date`] PWD"
pwd
export LOCAL_DIR=$PWD
echo "[`date`] ls of local dir"
ls -al

echo "[`date`] source products common"
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
echo "[`date`] setup mu2e"
setup mu2e

echo "[`date`] printenv after setup"
printenv

echo "[`date`] clone offline"
git clone -b $MU2E_RELEASE_TAG http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline/Offline.git

echo "[`date`] cd Offline"
cd Offline

echo "[`date`] clone validation"
git clone http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline-validation/validation.git

echo "[`date`] source setup"
./buildopts --build=$BUILDTYPE
source setup.sh

echo "[`date`] start scons"
scons -j 16
RC=$?
echo "["`date`"] scons return code=$RC"

echo "[`date`] run genReco"
mu2e -n 5000 Analyses/test/genReco.fcl

echo "[`date`] run validation"
mu2e -n 1000 -s genReco.art validation/fcl/validation1.fcl
mv validation.root ../copyBack/val-genReco-1000-${$MU2E_RELEASE_TAG}.root
mu2e -n 5000 -s genReco.art validation/fcl/validation1.fcl
mv validation.root ../copyBack/val-genReco-5000-${$MU2E_RELEASE_TAG}.root

echo "[`date`] remove genReco"
rm -f genReco*

echo "[`date`] build validation product"
OLDVER=`find /cvmfs/mu2e.opensciencegrid.org/artexternals/validation -name "v*_*_*" | tail -1 | awk -F/ '{print $NF}'`
P1=`echo $OLDVER | awk -F_ '{print $1}'`
P2=`echo $OLDVER | awk -F_ '{print $2}'`
P3=`echo $OLDVER | awk -F_ '{print $3}'`
NEWP2=`printf "%02d" $(($P2+1))`
NEWVALVER="${P1}_${NEWP2}_${P3}"
./validation/prd/build.sh -i -v $NEWVALVER -d ..

echo "["`date`"] removing validation"
./validation/prd/build.sh -c
rm -rf validation

echo "["`date`"] making tarballs"
# back to the top of the working directory
cd $LOCAL_DIR
echo "["`date`"] pwd"
pwd
echo "["`date`"] ls of local dir"
ls -al

echo "["`date`"] tar of Offline"
tar -czf copyBack/Offline_${MU2E_RELEASE_TAG}_${label}_${BUILDTYPE}.tgz Offline
echo "["`date`"] tar of validation"
tar -czf copyBack/validation_${NEWVALVER}_${label}_${BUILDTYPE}.tgz validation
echo "["`date`"] done tarballs"

ls -1 copyBack > copyBack/listing.txt

exit $RC
