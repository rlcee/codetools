#!/bin/bash
# Ryunosuke O'Neil, 2020
# Contact: @ryuwd on GitHub

function do_setupstep() {
    source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
    setup mu2e
    setup muse
    setup codetools

    # building prof or debug
    setup muse -q $BUILDTYPE

    return 0
}

function do_buildstep() {
   muse build --debug=time -k --max-drift=1 --implicit-deps-unchanged -j 24 2>&1 | tee "${WORKSPACE}/scons.log"
    return "${PIPESTATUS[0]}"
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

        echo "[$(date)] ${JOBNAME} step. Output is being written to ${WORKSPACE}/${JOBNAME}.log"
        echo "Test: mu2e -n ${NEVTS_TJ[$i-1]} -c ${FCLFILE}" > "${WORKSPACE}/${JOBNAME}.log" 2>&1
        echo "Please see the EOF for job results." >> "${WORKSPACE}/${JOBNAME}.log" 2>&1
        echo "-----------------------------------" >> "${WORKSPACE}/${JOBNAME}.log" 2>&1
        mu2e -n "${NEVTS}" -c "${FCLFILE}" >> "${WORKSPACE}/${JOBNAME}.log" 2>&1
        RC=$?

        if [ ${RC} -eq 0 ]; then
          echo "++REPORT_STATUS_OK++" >> "${WORKSPACE}/${JOBNAME}.log"
          touch ${WORKSPACE}/${JOBNAME}.log.SUCCESS
          cat > gh-report-${JOBNAME}.md <<- EOM
${COMMIT_SHA}
mu2e/${JOBNAME}
success
mu2e -c ${FCLFILE} -n ${NEVTS} finished with return code ${RC}
${JOB_URL}/${BUILD_NUMBER}/artifact/${JOBNAME}.log
NOCOMMENT

EOM
        else
          touch ${WORKSPACE}/${JOBNAME}.log.FAILED

          cat > gh-report-${JOBNAME}.md <<- EOM
${COMMIT_SHA}
mu2e/${JOBNAME}
failure
mu2e -c ${FCLFILE} -n ${NEVTS_TJ[$i-1]} failed with return code ${RC}
${JOB_URL}/${BUILD_NUMBER}/artifact/${JOBNAME}.log
NOCOMMENT

EOM
        fi

        echo "++RETURN CODE++ $RC" >> "${WORKSPACE}/${JOBNAME}.log"

        echo "[$(date)] ${JOBNAME} return code is ${RC}"
        
        source $HOME/mu2e-gh-bot-venv/bin/activate
        cmsbot_report gh-report-${JOBNAME}.md
      ) &

      failed=$(ls -1 ${WORKSPACE} | { grep log.FAILED || true; } | wc -l)
      finished=$(ls -1 ${WORKSPACE} | { grep log.SUCCESS || true; } | wc -l)
      running=$((started - finished - failed))
      while (( running >= MAX_TEST_PROCESSES )); do
        sleep 90
        failed=$(ls -1 ${WORKSPACE} | { grep log.FAILED || true; } | wc -l)
        finished=$(ls -1 ${WORKSPACE} | { grep log.SUCCESS || true; } | wc -l)
        running=$((started - finished - failed))
      done
    done

    #wait;


    # check the MDC2020 production sequence
    (
	for STAGE in ceSteps:100 ceDigi:100 muDauSteps:10000 ceMix:100
	do
	    FCL=$( echo $STAGE | awk -F: '{print $1}' )
	    NEV=$( echo $STAGE | awk -F: '{print $2}' )
            echo "[$(date)] Running MDC2020 production sequence, $FCL stage"
	    mu2e -n $NEV -c Validation/test/${FCL}.fcl > ${WORKSPACE}/${FCL}.log 2>&1
            RC=$?
            if [ ${RC} -eq 0 ]; then
		echo "++REPORT_STATUS_OK++" >> "${WORKSPACE}/${FCL}.log"
            fi

            echo "++RETURN CODE++ $RC" >> "${WORKSPACE}/${FCL}.log"

            echo "[$(date)] MDC2020 production sequence, $FCL stage, return code is ${RC}"
	done
    ) &


    # check for overlaps with root
    (
        echo "[$(date)] checking for overlaps using ROOT (output going to rootOverlaps.log)"
        ${WORKSPACE}/codetools/bin/rootOverlaps.sh > ${WORKSPACE}/rootOverlaps.log
        RC=$?
        if [ ${RC} -eq 0 ]; then
          echo "++REPORT_STATUS_OK++" >> "${WORKSPACE}/rootOverlaps.log"
        fi

        echo "++RETURN CODE++ $RC" >> "${WORKSPACE}/rootOverlaps.log"

        echo "[$(date)] rootOverlaps return code is ${RC}"
    ) &
    
    # check for overlaps with geant4
    (
        echo "[$(date) check for overlaps with geant4 surfaceCheck.fcl"
        mu2e -c Mu2eG4/fcl/surfaceCheck.fcl > "${WORKSPACE}/g4surfaceCheck.log" 2>&1
        RC=$?
        
        LEGAL=$( grep 'Checking overlaps for volume' ${WORKSPACE}/g4surfaceCheck.log | grep -c OK )
        ILLEGAL=$( grep 'Checking overlaps for volume' ${WORKSPACE}/g4surfaceCheck.log | grep -v OK | wc -l )
        
        echo "geant surfaceCheck $ILLEGAL overlaps in $LEGAL"  >> "${WORKSPACE}/g4surfaceCheck.log"
        
        # print overlaps into the log
        echo "Overlaps:" >> "${WORKSPACE}/rootOverlaps.log"
        grep 'Checking overlaps for volume' ${WORKSPACE}/g4surfaceCheck.log | grep -v OK  >> "${WORKSPACE}/rootOverlaps.log"
        echo "--------"  >> "${WORKSPACE}/rootOverlaps.log"
        
        if [[ $RC -eq 0 && $LEGAL -gt 0 && $ILLEGAL -eq 0 ]]; then
            echo "geant surfaceCheck OK"  >> "${WORKSPACE}/rootOverlaps.log"
            echo "++REPORT_STATUS_OK++" >> "${WORKSPACE}/g4surfaceCheck.log"
        else
            echo "geant surfaceCheck FAILURE" >> "${WORKSPACE}/rootOverlaps.log"
            RC=1
        fi
       
        echo "++RETURN CODE++ $RC" >> "${WORKSPACE}/g4surfaceCheck.log"
        echo "[$(date)] g4surfaceCheck return code is ${RC}"
    ) &
    
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
