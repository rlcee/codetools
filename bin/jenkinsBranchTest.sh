#!/bin/bash
# LOG=copyBack/log_${BASE_BUILD}_${TEST_BUILD}.log

build() {
    local CWD=$PWD
    local DIR="$1"
    local BUILD="$2"
    echo "[`date`] starting build $DIR $BUILD"
    mkdir $DIR
    cd $DIR
    local TYPE=`echo $BUILD | awk -F: '{print $1}'`
    local TEXT=`echo $BUILD | awk -F: '{print $2}'`

    git clone http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline/Offline.git
    RC=$?
    echo "[`date`] clone return code $RC"
    [ $RC -ne 0 ] && return 1
    cd Offline
    if [ "$TYPE" == "commit" ]; then
	git checkout -b work $TEXT
	RC=$?
    elif [ "$TYPE" == "tag" ]; then
	git checkout tags/$TEXT
	RC=$?
    elif [ "$TYPE" == "branch" ]; then
	git checkout $TEXT
	RC=$?
    else
	RC=2
    fi

    echo "[`date`] check return code $RC"
    [ $RC -ne 0 ] && return $RC

    source setup.sh

    scons -j 16 
    RC=$?
    echo "[`date`] scons return code $RC"
    [ $RC -ne 0 ] && return 1

    cd $CWD
    return 0
}

genreco() {
}


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

(build base $BASE_BUILD )
RC=$?
[ $RC -ne 0 ] && exit 1

(build test $TEST_BUILD )
RC=$?
[ $RC -ne 0 ] && exit 2




## pull the main repo
#git clone http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline/Offline.git
#cd Offline
#
## dump the rev
#git show
#git rev-parse HEAD
#
## building prof and debug
#./buildopts --build=$BUILDTYPE
#source setup.sh
#
#echo "["`date`"] ups"
#ups active
#
#echo "["`date`"] build"
#
#scons -j 16
#RC=$?
#
#echo "["`date`"] scons return code is $RC"

exit $RC
