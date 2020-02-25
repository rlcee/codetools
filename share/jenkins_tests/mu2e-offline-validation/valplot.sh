#!/bin/bash

# Sets up the build in $WORKSPACE/$1/Offline and produces validation plots.
# return code 0: success
# return code 1: error

NJOBS=16
export REPO=$(echo $REPOSITORY | sed 's|^.*/||')
export WORKING_DIRECTORY="$WORKSPACE/$1/Offline"

cd $WORKING_DIRECTORY || exit 1
(
    source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
    setup mu2e
    source setup.sh

    echo "["`date`"] ($WORKING_DIRECTORY) ceSimReco (1000 events)"
    mu2e -n 1000 -c Validation/fcl/ceSimReco.fcl 2>&1 | tee $WORKING_DIRECTORY/../ceSimReco.log
    RC2=${PIPESTATUS[0]}
    echo "["`date`"] ($WORKING_DIRECTORY) ceSimReco return code is $RC2"

    if [ $RC2 -ne 0 ]; then
        echo "["`date`"] ($WORKING_DIRECTORY) error while generating validation plots - abort"
        exit 1;
    fi

    echo "["`date`"] ($WORKING_DIRECTORY) generate validation plots"
    mu2e -s mcs* -c Validation/fcl/val.fcl 2>&1 | tee $WORKSPACE/val_pr.log

    RC3=${PIPESTATUS[0]}
    echo "["`date`"] ($WORKING_DIRECTORY) validation plots return code is $RC3"
    echo "$RC3" > $WORKSPACE/pr_valplot_rc

    echo "["`date`"] move PR validation.root to $WORKSPACE"
    mv validation.root $WORKSPACE/rev_${COMMIT_SHA}_pr_validation.root

)

