#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk


function do_setupstep() {
    source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
    setup mu2e
    setup codetools

    # building prof or debug
    ./buildopts --build="$BUILDTYPE"
    source setup.sh

    return 0
}

function do_buildstep() {
    scons --debug=time -k --max-drift=1 --implicit-deps-unchanged -j 24 2>&1 | tee "${WORKSPACE}/scons.log"
    return "${PIPESTATUS[0]}"
}

function do_runstep() {
    declare -a JOBNAMES=("ceSimReco" "g4test_03MT" "transportOnly" "PS" "g4study2" "cosmicSimReco")
    declare -a FCLFILES=("Validation/fcl/ceSimReco.fcl" "Mu2eG4/fcl/g4test_03MT.fcl" "Mu2eG4/fcl/transportOnly.fcl" "JobConfig/beam/PS.fcl" "Mu2eG4/fcl/g4study2.fcl" "Validation/fcl/cosmicSimReco.fcl")

    arraylength=${#JOBNAMES[@]}

    for (( i=1; i<arraylength+1; i++ ));
    do
      (
        mu2e -n 1 -c ${FCLFILES[$i-1]} 2>&1 | tee "${WORKSPACE}/${JOBNAMES[$i-1]}.log"

        if [ ${PIPESTATUS[0]} -eq 0 ]; then
          echo "++REPORT_STATUS_OK++" >> "${WORKSPACE}/${JOBNAMES[$i-1]}.log"
        fi

        echo "[$(date)] ${JOBNAMES[$i-1]} return code is ${PIPESTATUS[0]}"

      ) &
    done

    wait;
}



cd "$WORKSPACE" || exit
cd "$REPO" || exit

# dump the rev
git show
git rev-parse HEAD

echo "[$(date)] setup"

do_setupstep

echo "[$(date)] ups"
ups active

echo "[$(date)] build"
do_buildstep

SCONS_RC=$?
echo "[$(date)] scons return code is $SCONS_RC"

if [ $SCONS_RC -ne 0 ]; then
  exit 1
fi

echo "[$(date)] Now gzip the compiled build, saving this for validation if needed."
(
  cd "$WORKSPACE" || exit
  tar -zcvf rev_"${COMMIT_SHA}"_pr_lib.tar.gz Offline/lib > /dev/null
) &

echo "[$(date)] run tests"
do_runstep

wait;

exit 0