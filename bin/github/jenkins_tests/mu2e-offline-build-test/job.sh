#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk

cd "$WORKSPACE" || exit

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

TD_FIXM_STATUS=":heavy_check_mark:"
CE_STATUS=":wavy_dash:"
BUILD_STATUS=":wavy_dash:"
CT_STATUS=":wavy_dash:"

echo "" > $WORKSPACE/fixme_todo.log
for MOD_FILE in $MODIFIED_PR_FILES
do
    if [[ "$MOD_FILE" == *.cc ]] || [[ "$MOD_FILE" == *.hh ]]; then
        BUILD_NECESSARY=1
        TD_FIXM_STATUS=":wavy_dash:"
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


echo "[$(date)] setup compile_commands.json and run clang tidy"
CT_STATUS=":heavy_check_mark:"

(
    cd $WORKSPACE/$REPO || exit 1;
    set --

    source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
    setup mu2e
    setup clang v5_0_1
    source setup.sh

    scons -Q compiledb
    # make sure clang tools can find this file
    # in an obvious location
    mv gen/compile_commands.json .

    # run clang-tidy
    CLANG_TIDY_ARGS="-extra-arg=-isystem$CLANG_FQ_DIR/include/c++/v1 -p . -j 24"
    CLANG_TIDY_RUNNER="${CLANG_FQ_DIR}/share/clang/run-clang-tidy.py"

    ${CLANG_TIDY_RUNNER} ${CLANG_TIDY_ARGS} ${CT_FILES} > $WORKSPACE/clang-tidy.log || exit 1
)

if grep -q warning: "$WORKSPACE/clang-tidy.log"; then
    CT_STATUS=":wavy_dash:"
fi

if grep -q error: "$WORKSPACE/clang-tidy.log"; then
    CT_STATUS=":x:"
fi


echo "[$(date)] report outcome"
if [ "$BUILDTEST_OUTCOME" == 1 ]; then
    BUILD_STATUS=":x:"

    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
failure
The build failed (${BUILDTYPE})
${JOB_URL}/${BUILD_NUMBER}/console
:umbrella: The build failed at ref ${COMMIT_SHA}.

| Test          | Result        | Details |
| ------------- |:-------------:| ------- |
| scons build (prof) | ${BUILD_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/scons.log) |
| ceSimReco (-n 10) | ${CE_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/ceSimReco.log) |
| FIXME, TODO count | ${TD_FIXM_STATUS} | [TODO (${TD_COUNT}) FIXME (${FIXM_COUNT}) in ${FILES_SCANNED} files.](${JOB_URL}/${BUILD_NUMBER}/artifact/fixme_todo.log) |
| clang-tidy | ${CT_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/clang-tidy.log) |

\`\`\`
${ERROR_OUTPUT}
\`\`\`
For more information, please check the job page [here](${JOB_URL}/${BUILD_NUMBER}/console).

EOM

elif [ "$BUILDTEST_OUTCOME" == 2 ]; then
    BUILD_STATUS=":heavy_check_mark:"
    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
failure
The build succeeded, but other tests failed.
${JOB_URL}/${BUILD_NUMBER}/console
:umbrella: The tests failed for ref ${COMMIT_SHA}.

| Test          | Result        | Details |
| ------------- |:-------------:| ------- |
| scons build (prof) | ${BUILD_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/scons.log) |
| ceSimReco (-n 10) | ${CE_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/ceSimReco.log) |
| FIXME, TODO count | ${TD_FIXM_STATUS} | [TODO (${TD_COUNT}) FIXME (${FIXM_COUNT}) in ${FILES_SCANNED} files.](${JOB_URL}/${BUILD_NUMBER}/artifact/fixme_todo.log) |
| clang-tidy | ${CT_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/clang-tidy.log) |

For more information, please check the job page [here](${JOB_URL}/${BUILD_NUMBER}/console).

EOM

else
    BUILD_STATUS=":heavy_check_mark:"
    CE_STATUS=":heavy_check_mark:"

    TIME_BUILD_OUTPUT=$(grep "Total build time: " scons.log)
    TIME_BUILD_OUTPUT=$(echo "$TIME_BUILD_OUTPUT" | grep -o -E '[0-9\.]+')

    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
success
The tests passed.
${JOB_URL}/${BUILD_NUMBER}/console
:sunny: The tests passed at ref ${COMMIT_SHA}. Total build time: $(date -d@$TIME_BUILD_OUTPUT -u '+%M min %S sec').

| Test          | Result        | Details |
| ------------- |:-------------:| ------- |
| scons build (prof) | ${BUILD_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/scons.log) |
| ceSimReco (-n 10) | ${CE_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/ceSimReco.log) |
| FIXME, TODO count | ${TD_FIXM_STATUS} | [TODO (${TD_COUNT}) FIXME (${FIXM_COUNT}) in ${FILES_SCANNED} files.](${JOB_URL}/${BUILD_NUMBER}/artifact/fixme_todo.log) |
| clang-tidy | ${CT_STATUS} | [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/clang-tidy.log) |

For more information, please check the job page [here](${JOB_URL}/${BUILD_NUMBER}/console).

EOM

fi

cmsbot_report "$WORKSPACE/gh-report.md"
wait;
exit $BUILDTEST_OUTCOME;

