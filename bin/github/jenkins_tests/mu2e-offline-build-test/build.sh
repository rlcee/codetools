#!/bin/bash
# Ryunosuke O'Neil, 2020
# Contact: @ryuwd on GitHub

function do_setupstep() {
    source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
    setup mu2e
    setup muse
    setup codetools

    # building prof or debug
    muse setup -q $BUILDTYPE

    return 0
}

function do_buildstep() {
   muse build --debug=time -k --max-drift=1 --implicit-deps-unchanged -j 24 2>&1 | tee "${WORKSPACE}/scons.log"
    return "${PIPESTATUS[0]}"
}

TEST_TIMEOUT=1200 # half an hour

function babysit_test() {
  # use:
  # babysit_test "Test Name" $Test_PID
  TEST_NAME=$1
  THE_PID=$2
  CHECK_INTERVAL=120 # how long to wait between checking
  (
    NCHECK=0
    while [ ! -f "${WORKSPACE}/${TEST_NAME}.SUCCESS" ] | [ ! -f "${WORKSPACE}/${TEST_NAME}.FAILED" ]; do
      sleep $CHECK_INTERVAL

      NCHECK=$((NCHECK + 1))

      if ps -p $THE_PID > /dev/null
      then
        ELAPSEDTIME=$((CHECK_INTERVAL * NCHECK))
        echo "[$(date)] Monitoring: ${TEST_NAME} is still running after $ELAPSEDTIME seconds."
        if [ "$ELAPSEDTIME" -gt "$TESTTIMEOUT" ]; then # Exit condition
          echo "[$(date)] Monitoring: Killed ${TEST_NAME} for running too long."
          touch "${WORKSPACE}/${TEST_NAME}.log.TIMEOUT"
          kill -9 $THE_PID
          break;
        fi
      fi
    done
  ) &
}

function do_runstep() {
    arraylength=${#JOBNAMES[@]}
    started=0
    for (( i=1; i<arraylength+1; i++ ));
    do
      started=$((started+1))
      (
        JOBNAME=${JOBNAMES[$i-1]}
        FCLFILE=${FCLFILES[$i-1]}
        NEVTS=${NEVTS_TJ[$i-1]}
        TEST_URL_GS="${JOB_URL}/${BUILD_NUMBER}/console"
        (
          source $HOME/mu2e-gh-bot-venv/bin/activate
          cmsbot_report_test_status "mu2e/${JOBNAME}" "pending" "The test has started." "${TEST_URL_GS}"
        ) &

        echo "[$(date)] ${JOBNAME} step. Output is being written to ${WORKSPACE}/${JOBNAME}.log"
        echo "Test: mu2e -n ${NEVTS_TJ[$i-1]} -c ${FCLFILE}" > "${WORKSPACE}/${JOBNAME}.log" 2>&1
        echo "Please see the EOF for job results." >> "${WORKSPACE}/${JOBNAME}.log" 2>&1
        echo "-----------------------------------" >> "${WORKSPACE}/${JOBNAME}.log" 2>&1
        mu2e -n "${NEVTS}" -c "${FCLFILE}" >> "${WORKSPACE}/${JOBNAME}.log" 2>&1 &
        TESTPID=$!
        babysit_test "${JOBNAME}" "${TESTPID}" # Kills the test after TEST_TIMEOUT seconds

        wait $TESTPID; # Wait for process to finish
        RC=$? # grab the return code from the process

        TEST_STAT_GS="pending"

        if [ ${RC} -eq 0 ]; then
          echo "Job completed successfully." >> "${WORKSPACE}/${JOBNAME}.log"
          echo "${RC}" > ${WORKSPACE}/${JOBNAME}.log.SUCCESS
          TEST_STAT_GS="success"
        else
          echo "${RC}" > ${WORKSPACE}/${JOBNAME}.log.FAILED
          TEST_STAT_GS="failure"
        fi

        TEST_URL_GS="${JOB_URL}/${BUILD_NUMBER}/artifact/${JOBNAME}.log"
        TEST_MSG_GS="mu2e -c ${FCLFILE} -n ${NEVTS} finished with return code ${RC}"

        echo "Return Code: $RC" >> "${WORKSPACE}/${JOBNAME}.log"

        echo "[$(date)] ${JOBNAME} return code is ${RC}"
        
        (
          source $HOME/mu2e-gh-bot-venv/bin/activate
          cmsbot_report_test_status "mu2e/${JOBNAME}" "${TEST_STAT_GS}" "${TEST_MSG_GS}" "${TEST_URL_GS}"
        ) &
      ) &

      failed=$(ls -1 ${WORKSPACE} | { grep log.FAILED || true; } | wc -l)
      finished=$(ls -1 ${WORKSPACE} | { grep log.SUCCESS || true; } | wc -l)
      running=$((started - finished - failed))
      while (( running >= MAX_TEST_PROCESSES )); do
        sleep 30
        failed=$(ls -1 ${WORKSPACE} | { grep log.FAILED || true; } | wc -l)
        finished=$(ls -1 ${WORKSPACE} | { grep log.SUCCESS || true; } | wc -l)
        running=$((started - finished - failed))

        echo "[$(date)] ${running} tests still running. ${finished} have finished. ${failed} have errors."
      done
    done

    #wait;


    # check the MDC2020 production sequence
    (
	for STAGE in ceSteps:100 ceDigi:100 muDauSteps:10000 ceMix:100
	do
	    FCL=$( echo $STAGE | awk -F: '{print $1}' )
	    NEV=$( echo $STAGE | awk -F: '{print $2}' )
      TEST_URL_GS="${JOB_URL}/${BUILD_NUMBER}/console"
      (
        source $HOME/mu2e-gh-bot-venv/bin/activate
        cmsbot_report_test_status "mu2e/${FCL}" "pending" "The test has started." "${TEST_URL_GS}"
      ) &

      echo "[$(date)] Running MDC2020 production sequence, $FCL stage"
      mu2e -n $NEV -c Validation/${FCL}.fcl > ${WORKSPACE}/${FCL}.log 2>&1 &
      TESTPID=$!
      babysit_test "${FCL}" "${TESTPID}" # Kills the test after TEST_TIMEOUT seconds

      wait $TESTPID; # Wait for process to finish
      RC=$? # grab the return code from the process

      if [ ${RC} -eq 0 ]; then
        echo "Job completed successfully." >> "${WORKSPACE}/${FCL}.log"
        echo "${RC}" > ${WORKSPACE}/${FCL}.log.SUCCESS
        TEST_STAT_GS="success"
      else
        TEST_STAT_GS="failure"
        echo "${RC}" > ${WORKSPACE}/${FCL}.log.FAILED
      fi
      
      TEST_MSG_GS="mu2e -n ${NEV} -c Validation/${FCL}.fcl finished with return code ${RC}"
      TEST_URL_GS="${JOB_URL}/${BUILD_NUMBER}/artifact/${JOBNAME}.log"

      echo "Return Code: $RC" >> "${WORKSPACE}/${FCL}.log"

      echo "[$(date)] MDC2020 production sequence, $FCL stage, return code is ${RC}"

      (
        source $HOME/mu2e-gh-bot-venv/bin/activate
        cmsbot_report_test_status "mu2e/${FCL}" "${TEST_STAT_GS}" "${TEST_MSG_GS}" "${TEST_URL_GS}"
      ) &

	done
    ) &


    # check for overlaps with root
    (
        echo "[$(date)] checking for overlaps using ROOT (output going to rootOverlaps.log)"
        ${WORKSPACE}/codetools/bin/rootOverlaps.sh > ${WORKSPACE}/rootOverlaps.log &
        TESTPID=$!
        babysit_test "rootOverlaps" "${TESTPID}" # Kills the test after TEST_TIMEOUT seconds
        wait $TESTPID; # Wait for process to finish
        RC=$? # grab the return code from the process

        if [ ${RC} -eq 0 ]; then
          echo "Job completed successfully." >> "${WORKSPACE}/rootOverlaps.log"
          echo "${RC}" > ${WORKSPACE}/rootOverlaps.log.SUCCESS
        else
          echo "${RC}" > ${WORKSPACE}/rootOverlaps.log.FAILED
        fi

        echo "Return Code: $RC" >> "${WORKSPACE}/rootOverlaps.log"

        echo "[$(date)] rootOverlaps return code is ${RC}"
    ) &
    
    # check for overlaps with geant4
    (
        echo "[$(date) check for overlaps with geant4 surfaceCheck.fcl"
        mu2e -c Mu2eG4/fcl/surfaceCheck.fcl > "${WORKSPACE}/g4surfaceCheck.log" 2>&1 &
        TESTPID=$!
        babysit_test "g4surfaceCheck" "${TESTPID}" # Kills the test after TEST_TIMEOUT seconds
        wait $TESTPID; # Wait for process to finish
        RC=$? # grab the return code from the process
        
        LEGAL=$( grep 'Checking overlaps for volume' ${WORKSPACE}/g4surfaceCheck.log | grep -c OK )
        ILLEGAL=$( grep 'Checking overlaps for volume' ${WORKSPACE}/g4surfaceCheck.log | grep -v OK | wc -l )
        
        echo "geant surfaceCheck $ILLEGAL overlaps in $LEGAL"  >> "${WORKSPACE}/g4surfaceCheck.log"
        
        # print overlaps into the log
        echo "Overlaps:" >> "${WORKSPACE}/rootOverlaps.log"
        grep 'Checking overlaps for volume' ${WORKSPACE}/g4surfaceCheck.log | grep -v OK  >> "${WORKSPACE}/rootOverlaps.log"
        echo "--------"  >> "${WORKSPACE}/rootOverlaps.log"
        
        if [[ $RC -eq 0 && $LEGAL -gt 0 && $ILLEGAL -eq 0 ]]; then
            echo "geant surfaceCheck OK"  >> "${WORKSPACE}/g4surfaceCheck.log"
            echo "Job completed successfully." >> "${WORKSPACE}/g4surfaceCheck.log"
            echo "${RC}" > ${WORKSPACE}/g4surfaceCheck.log.SUCCESS
        else
            echo "geant surfaceCheck FAILURE" >> "${WORKSPACE}/g4surfaceCheck.log"
            echo "${RC}" > ${WORKSPACE}/g4surfaceCheck.log.FAILED
            RC=1
        fi
       
        echo "Return Code: $RC" >> "${WORKSPACE}/g4surfaceCheck.log"
        echo "[$(date)] g4surfaceCheck return code is ${RC}"
    ) &
    
    wait;

}



cd "$WORKSPACE" || exit
cd "$REPO" || exit

# dump the rev
git show
git rev-parse HEAD

cd "$WORKSPACE" || exit

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
  tar -zcvf rev_"${COMMIT_SHA}"_pr_lib.tar.gz $REPO build > /dev/null
) &

echo "[$(date)] run tests"
do_runstep

wait;

exit 0
