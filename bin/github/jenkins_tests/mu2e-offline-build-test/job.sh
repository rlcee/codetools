#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk

cd "$WORKSPACE" || exit
rm -f *.log

echo "[$(date)] setup CMS-BOT/mu2e"
setup_cmsbot

echo "[$(date)] setup ${REPOSITORY}"
setup_offline "${REPOSITORY}"

cd "$WORKSPACE/$REPO" || exit 1
git rev-parse HEAD > master-commit-sha.txt

git checkout ${COMMIT_SHA} || exit 1

export MODIFIED_PR_FILES=$(git --no-pager diff --name-only FETCH_HEAD $(git merge-base FETCH_HEAD master))
CT_FILES="" # files to run in clang tidy


echo "[$(date)] FIXME, TODO check before merge"
FIXM_COUNT=0
TD_COUNT=0
BUILD_NECESSARY=0
FILES_SCANNED=0

TD_FIXM_STATUS=":wavy_dash:"
CE_STATUS=":wavy_dash:"
BUILD_STATUS=":wavy_dash:"
CT_STATUS=":wavy_dash:"

echo "" > $WORKSPACE/fixme_todo.log
for MOD_FILE in $MODIFIED_PR_FILES
do
    if [[ "$MOD_FILE" == *.cc ]] || [[ "$MOD_FILE" == *.hh ]]; then
        BUILD_NECESSARY=1
        FILES_SCANNED=$((FILES_SCANNED + 1))
        TD_temp=$(grep -c TODO "${MOD_FILE}")
        TD_COUNT=$((TD_temp + TD_COUNT))

        FIXM_temp=$(grep -c FIXME "${MOD_FILE}")
        FIXM_COUNT=$((FIXM_temp + FIXM_COUNT))

        echo "${MOD_FILE} has ${TD_temp} TODO, ${FIXM_temp} FIXME comments." >> "$WORKSPACE/fixme_todo.log"
        grep TODO ${MOD_FILE} >> $WORKSPACE/fixme_todo.log
        grep FIXME ${MOD_FILE} >> $WORKSPACE/fixme_todo.log
        echo "---" >> $WORKSPACE/fixme_todo.log
        echo "" >> $WORKSPACE/fixme_todo.log

        # we only wish to process .cc files in clang tidy
        if [[ "$MOD_FILE" == *.cc ]]; then
            CT_FILES="$MOD_FILE $CT_FILES"
        fi
    else
        echo "skipped $MOD_FILE since not a cpp file"
    fi
done

TD_FIXM_COUNT=$((FIXM_COUNT + TD_COUNT))

if [ $TD_FIXM_COUNT == 0 ]; then
    TD_FIXM_STATUS=":heavy_check_mark:"
fi

echo "[$(date)] setup ${REPOSITORY}: perform merge"

offline_domerge
OFFLINE_MERGESTATUS=$?

if [ $OFFLINE_MERGESTATUS -ne 0 ];
then
    cat > gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
error
The PR branch could not be merged.
http://github.com/${REPOSITORY}/pull/${PULL_REQUEST}
:bangbang: The build test could not run due to merge conflicts. Please resolve these first and try again.
\`\`\`
> git diff --check | grep -i conflict
$(git diff --check | grep -i conflict)
\`\`\`
EOM
    cmsbot_report gh-report.md
    exit 1;
fi

cd "$WORKSPACE" || exit
# report that the job script is now running

cat > gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
pending
The build is running in Jenkins...
${JOB_URL}/${BUILD_NUMBER}/console
NOCOMMENT

EOM
cmsbot_report gh-report.md

echo "[$(date)] run build test"
(
    source "${TESTSCRIPT_DIR}/build.sh"
)
BUILDTEST_OUTCOME=$?
ERROR_OUTPUT=$(grep "scons: \*\*\*" scons.log)

if [[ -z $CT_FILES ]]; then
    echo "[$(date)] skip clang tidy step - no CPP files modified."
    echo "No CPP files modified." > $WORKSPACE/clang-tidy.log
    CT_STATUS=":heavy_check_mark:"
else

    echo "[$(date)] run clang tidy"
    (
        cd $WORKSPACE/$REPO || exit 1;
        set --

        # make sure clang tools can find the compdb
        # in an obvious location
        mv gen/compile_commands.json .

        source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
        setup mu2e
        setup clang v5_0_1

        # run clang-tidy
        CLANG_TIDY_ARGS="-extra-arg=-isystem$CLANG_FQ_DIR/include/c++/v1 -p . -j 24"
        CLANG_TIDY_RUNNER="${CLANG_FQ_DIR}/share/clang/run-clang-tidy.py"

        ${CLANG_TIDY_RUNNER} ${CLANG_TIDY_ARGS} ${CT_FILES} > $WORKSPACE/clang-tidy.log || exit 1
    )

    if [ $? -ne 1 ]; then
        CT_STATUS=":heavy_check_mark:"
    fi
fi

if grep -q warning: "$WORKSPACE/clang-tidy.log"; then
    CT_STATUS=":wavy_dash:"
fi

if grep -q error: "$WORKSPACE/clang-tidy.log"; then
    CT_STATUS=":wavy_dash:"
fi

CT_ERROR_COUNT=$(grep -c error: "$WORKSPACE/clang-tidy.log")
CT_WARN_COUNT=$(grep -c warning: "$WORKSPACE/clang-tidy.log")

CT_STAT_STRING="$CT_ERROR_COUNT errors $CT_WARN_COUNT warnings"
echo $CT_STAT_STRING

echo "[$(date)] report outcome"

TESTS_FAILED=0
MU2E_POSTBUILDTEST_STATUSES=""
declare -a ART_TESTJOBS=("ceSimReco" "g4test_03MT" "transportOnly" "PS" "g4study" "cosmicSimReco")
for i in "${ART_TESTJOBS[@]}"
do
    STATUS_temp=":wavy_dash:"


    # as a crude way to see if we have completed a check, we grep
    # this string on the corresp. logfile!
    if grep -q "++REPORT_STATUS_OK++" "$WORKSPACE/$i.log"; then
        STATUS_temp=":heavy_check_mark:"
    elif [ -f "$WORKSPACE/$i.log" ]; then
        STATUS_temp=":x:"
        TESTS_FAILED=1
    fi
    MU2E_POSTBUILDTEST_STATUSES="${MU2E_POSTBUILDTEST_STATUSES}
| $i | ${STATUS_temp} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/$i.log) |"
done

# | ceSimReco (-n 1) | ${CE_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/ceSimReco.log) |
# | g4test_03 (-n 1) | ${G4TEST3_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/g4test_03.log) |
# | surfaceCheck | ${SURFACECHECK_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/surfaceCheck.log) |
# | transportOnly (-n 1) | ${TRANSP_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/transportOnly.log) |
# | PS (-n 1) | ${PS_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/PS.log) |
# | g4study (-n 1) | ${G4S_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/g4study.log) |

BUILDTIME_STR=""

if [ "$BUILDTEST_OUTCOME" == 1 ]; then
    BUILD_STATUS=":x:"

    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
failure
The build is failing (${BUILDTYPE})
${JOB_URL}/${BUILD_NUMBER}/console
:umbrella: The build is failing at ref ${COMMIT_SHA}.

\`\`\`
${ERROR_OUTPUT}
\`\`\`

EOM

elif [ "$TESTS_FAILED" == 1 ]; then
    BUILD_STATUS=":heavy_check_mark:"

    TIME_BUILD_OUTPUT=$(grep "Total build time: " scons.log)
    TIME_BUILD_OUTPUT=$(echo "$TIME_BUILD_OUTPUT" | grep -o -E '[0-9\.]+')
    BUILDTIME_STR="Build time: $(date -d@$TIME_BUILD_OUTPUT -u '+%M min %S sec')"

    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
failure
The build succeeded, but other tests are failing.
${JOB_URL}/${BUILD_NUMBER}/console
:umbrella: The tests failed for ref ${COMMIT_SHA}.

EOM

else
    BUILD_STATUS=":heavy_check_mark:"

    TIME_BUILD_OUTPUT=$(grep "Total build time: " scons.log)
    TIME_BUILD_OUTPUT=$(echo "$TIME_BUILD_OUTPUT" | grep -o -E '[0-9\.]+')

    BUILDTIME_STR="Build time: $(date -d@$TIME_BUILD_OUTPUT -u '+%M min %S sec')"

    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
success
The tests passed.
${JOB_URL}/${BUILD_NUMBER}/console
:sunny: The tests passed at ref ${COMMIT_SHA}.

EOM

fi

cat >> "$WORKSPACE"/gh-report.md <<- EOM

| Test          | Result        | Details |
| ------------- |:-------------:| ------- |
| scons build (prof) | ${BUILD_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/scons.log). ${BUILDTIME_STR} |${MU2E_POSTBUILDTEST_STATUSES}
| FIXME, TODO count | ${TD_FIXM_STATUS} | [TODO (${TD_COUNT}) FIXME (${FIXM_COUNT}) in ${FILES_SCANNED} files](${JOB_URL}/${BUILD_NUMBER}/artifact/fixme_todo.log) |
| clang-tidy | ${CT_STATUS} | [${CT_STAT_STRING}](${JOB_URL}/${BUILD_NUMBER}/artifact/clang-tidy.log) |

For more information, please check the job page [here](${JOB_URL}/${BUILD_NUMBER}/console).

EOM

if [ $TRIGGER_VALIDATION -ne 0 ]; then

cat >> "$WORKSPACE"/gh-report.md <<- EOM
:hourglass: The validation job has been queued.

EOM

fi

cmsbot_report "$WORKSPACE/gh-report.md"
wait;
exit $BUILDTEST_OUTCOME;

