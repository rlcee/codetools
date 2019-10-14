#!/bin/bash
# LOG=copyBack/log_${BASE_BUILD}_${TEST_BUILD}.log

build() {
    local CWD=$PWD
    local DIR="$1"
    local BUILD="$2"
    shift 2
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


launch() {
    local CWD=$PWD
    local DIR="$1"
    local BUILD="$2"
    shift 2
    N=`cat seeds.txt | wc -l`
    echo "[`date`] starting launch $DIR $BUILD $N seeds"
    cd $DIR
    local TYPE=`echo $BUILD | awk -F: '{print $1}'`
    local TEXT=`echo $BUILD | awk -F: '{print $2}'`

    source Offline/setup.sh
    I=1
    while [ $I -le $N ]; 
    do
	cp Offline/Validation/fcl/ceSimReco.fcl ./${I}.fcl
	SEED=`sed "${I}q;d" ../seeds.txt`
	echo "services.SeedService.baseSeed: $SEED" >> ${I}.fcl
	mu2e -n 1000 -o ${I}.art -T ${I}.root -c ${I}.fcl >& ${I}.log &
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

collect() {
    local CWD=$PWD
    local DIR="$1"
    local BUILD="$2"
    shift 2
    echo "[`date`] starting collect $DIR $BUILD"
    cd $DIR
    local TYPE=`echo $BUILD | awk -F: '{print $1}'`
    local TEXT=`echo $BUILD | awk -F: '{print $2}'`

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

    VF=`echo val_${BUILD}_${BUILD_NAME}.root | tr ":" "-"`
    cp validation.root ../copyBack/$VF

    cd $CWD
    return 0
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

NJOB=5
echo -e "3112\n4438\n7204\n7864\n9578" > seeds.txt

(launch base $BASE_BUILD )
RC=$?
[ $RC -ne 0 ] && exit 11

(launch test $TEST_BUILD )
RC=$?
[ $RC -ne 0 ] && exit 12

#
# wait for results
#
NTJOB=$((2*$NJOB))
N=0
I=0
while [[ $N -lt $NTJOB && $I -lt 50 ]];
do
  sleep 60
  N=`grep "Art has completed" base/*.log test/*.log | wc -l`
  echo "waiting: min $I logs $N"
  I=$(($I+1))
done

#
# make val files
#

(collect base $BASE_BUILD )
RC=$?
[ $RC -ne 0 ] && exit 21

(collect test $TEST_BUILD )
RC=$?
[ $RC -ne 0 ] && exit 22

echo "[`date`] done collect"

ls -l *

echo "[`date`] exit"


exit $RC
