#!/bin/bash
#
# BASE_BUILD is of form github_repo:ref, like Mu2e/Offline:master or 
#      Mu2e/Offline:v7_0_0 or rlc/Offline:dev_branch
# TEST_BUILD same format
# BUILD_NAME is a string to name the web output directory
# NEV is the number of ceSimReco events to run
#
# output
# LOG=copyBack/log_${BASE_BUILD}_${TEST_BUILD}.log

build() {
    local CWD=$PWD
    local DIR="$1"
    local BUILD="$2"
    shift 2
    echo "[`date`] starting build $DIR $BUILD"
    mkdir $DIR
    cd $DIR
    local REPO=`echo $BUILD | awk -F: '{print $1}'`
    local REF=`echo $BUILD | awk -F: '{print $2}'`

    git clone https://github.com/$REPO/Offline
    RC=$?
    echo "[`date`] clone $REPO return code $RC"
    [ $RC -ne 0 ] && return 1

    cd Offline
    git checkout --no-progress -b temp $REF
    RC=$?
    echo "[`date`] checkout $REF return code $RC"
    [ $RC -ne 0 ] && return $RC

    source setup.sh

    scons -j 16 
    RC=$?

    echo "[`date`] scons return code $RC"
    [ $RC -ne 0 ] && return 1

    cd $CWD
    return 0
}


launch() {
    local CWD=$PWD
    local DIR="$1"
    local N="$2"
    local NEV="$3"
    shift 3
    echo "[`date`] starting launch $DIR, $N jobs, $NE total events"
    local NEJ=$(($NEV/$N))
    cd $DIR

    source Offline/setup.sh
    I=1
    while [ $I -le $N ]; 
    do
	cp Offline/Validation/fcl/ceSimReco.fcl ./${I}.fcl
	echo "services.SeedService.baseSeed: $I" >> ${I}.fcl
	mu2e -n $NEJ -o ${I}.art -T ${I}.root -c ${I}.fcl >& ${I}.log &
	I=$(($I+1))
    done

    echo "[`date`] launch ls"
    ls -l
    echo "[`date`] launch ps"
    ps -fwww f
    echo "[`date`] launch ps"
    ps -fwww fT

    cd $CWD
    return 0
}

#
# after jobs run in the background, collect all the art files
# and run validation on them
#
collect() {
    local CWD=$PWD
    local DIR="$1"
    local BUILD="$2"
    shift 2
    echo "[`date`] starting collect $DIR $BUILD"
    cd $DIR

    source Offline/setup.sh
    ls -l
    echo "[`date`] collect $DIR first fcl file"
    cat 1.fcl
    echo "[`date`] collect $DIR first log file"
    cat 1.log
    echo "[`date`] collect $DIR attempt validation exe"
    ls *.art > input.txt
    mu2e -S input.txt -c Validation/fcl/val.fcl
    RC=$?
    echo "[`date`] collect $DIR validation RC=$RC"

    VF=`echo ${BUILD}.root | tr ":" "-"`
    cp validation.root ../copyBack/$VF

    cd $CWD
    return 0
}

#
# run valcompare and make a tarball of the results
#
compare() {
    echo "[`date`] starting compare"
    local CWD=$PWD
    local BN="$1"
    local BB="$2"
    local TB="$3"
    shift 3
    cd copyBack
    mkdir $BN
    source $CWD/base/Offline/setup.sh
    VB=`echo ${BUILD}.root | tr ":" "-"`
    VT=`echo ${BUILD}.root | tr ":" "-"`
    valcompare -s $VB $VT
    valcompare -w $BN/result.html $VB $VT
    RC=$?

    tar -czf result.tgz $BN

    cd $CWD
    return 0
}



#
# start of main
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
NPROC=$( cat /proc/cpuinfo | grep -c processor )
echo "[`date`] processors: $NPROC"

echo "["`date`"] setups"
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
setup mu2e


# build code

(build base $BASE_BUILD )
RC=$?
[ $RC -ne 0 ] && exit 1

(build test $TEST_BUILD )
RC=$?
[ $RC -ne 0 ] && exit 2


# start validation jobs

NJOB=5

(launch base $NJOB $NEV )
RC=$?
[ $RC -ne 0 ] && exit 11

(launch test $NJOB $NEV )
RC=$?
[ $RC -ne 0 ] && exit 12


# wait for results

NTJOB=$((2*$NJOB))
N=0
I=0
while [[ $N -lt $NTJOB && $I -lt 50 ]];
do
  sleep 60
  N=`grep "Art has completed" base/*.log test/*.log | wc -l`
  M=$( jobs | wc -l )
  echo "waiting: min $I logs $N, jobs=$M"
  I=$(($I+1))
done


# make val files

(collect base $BASE_BUILD )
RC=$?
[ $RC -ne 0 ] && exit 21

(collect test $TEST_BUILD )
RC=$?
[ $RC -ne 0 ] && exit 22

# make comparison tarball

(compare $BUILD_NAME $BASE_BUILD $TEST_BUILD)
RC=$?
[ $RC -ne 0 ] && exit 30

echo "[`date`] ls one level down"

ls -l *

echo "[`date`] exit"


exit 0
