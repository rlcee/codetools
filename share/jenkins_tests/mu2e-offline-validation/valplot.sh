#!/bin/bash

# e.g. valplot.sh master ceSimReco
# Sets up the build in $WORKSPACE/$1/Offline and runs validation according to Validation/fcl/$2.fcl
# then makes validation plots, and moves the rootfile back to workspace.
# return code 0: success
# return code 1: error

WORKING_DIRECTORY="$WORKSPACE/$1/Offline"
BUILDVER=$1
VALIDATION_JOB=$2

(
    set --
    cd "$WORKING_DIRECTORY" || exit 1
    source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
    setup mu2e

    source setup.sh

    echo "[$(date)] ($WORKING_DIRECTORY) ${VALIDATION_JOB} (1000 events)"
    mu2e -n 1000 -c Validation/fcl/${VALIDATION_JOB}.fcl 2>&1 | tee "$WORKING_DIRECTORY/../ceSimReco.log"
    RC2=${PIPESTATUS[0]}
    echo "[$(date)] ($WORKING_DIRECTORY) ${VALIDATION_JOB} return code is $RC2"

    if [ "$RC2" -ne 0 ]; then
        echo "[$(date)] ($WORKING_DIRECTORY) error while running validation job - abort"
        exit 1;
    fi

    echo "[$(date)] ($WORKING_DIRECTORY) generate validation plots"
    mu2e -s mcs* -c Validation/fcl/val.fcl 2>&1 | tee "$WORKING_DIRECTORY/../val_pr.log"

    RC3=${PIPESTATUS[0]}
    echo "[$(date)] ($WORKING_DIRECTORY) validation plots return code is $RC3"
    if [ "$RC3" -ne 0 ]; then
        echo "[$(date)] ($WORKING_DIRECTORY) error while generating validation plots - abort"
        exit 1;
    fi

    echo "[$(date)] ($WORKING_DIRECTORY) move validation.root to $WORKSPACE"

    mv validation.root "$WORKSPACE/rev_${COMMIT_SHA}_${BUILDVER}_validation.root" || exit 1;

    exit 0;
)
exit $?