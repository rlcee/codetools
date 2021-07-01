#!/bin/bash
# Ryunosuke O'Neil, 2020
# Contact: @ryuwd on GitHub

# the table
MU2E_POSTBUILDTEST_STATUSES=""

function append_report_row() {
    MU2E_POSTBUILDTEST_STATUSES="${MU2E_POSTBUILDTEST_STATUSES}
| $1 | $2 | $3 |"
}

function prepare_repositories() {
    cd ${WORKSPACE}/${REPO}
    if [ $? -ne 0 ]; then 
        return 1
    fi
    if [ "${NO_MERGE}" = "1" ]; then
        echo "[$(date)] Mu2e/$REPO - Checking out PR HEAD directly"
        git checkout ${COMMIT_SHA} #"pr${PULL_REQUEST}"
        git log -1
        append_report_row "checkout" ":white_check_mark:" "Checked out ${COMMIT_SHA}"
    else
        echo "[$(date)] Mu2e/$REPO - Checking out latest commit on base branch"
        git checkout ${MASTER_COMMIT_SHA}
        git log -1
    fi

    if [ "${TEST_WITH_PR}" != "" ]; then
        # comma separated list

        for pr in $(echo ${TEST_WITH_PR} | sed "s/,/ /g")
        do
            # if it starts with "#" then it is a PR in $REPO.
            if [[ $pr = \#* ]]; then
                REPO_NAME="$REPO"
                THE_PR=$( echo $pr | awk -F\# '{print $2}' )
                cd $WORKSPACE/$REPO
            elif [[ $pr = *\#* ]]; then
                # get the repository name
                REPO_NAME=$( echo $pr | awk -F\# '{print $1}' )
                THE_PR=$( echo $pr | awk -F\# '{print $2}' )

                # check it exists, and clone it into the workspace if it does not.
                if [ ! -d "$WORKSPACE/$REPO_NAME" ]; then
                    (
                        cd $WORKSPACE
                        git clone git@github.com:Mu2e/${REPO_NAME}.git ${REPO_NAME} || exit 1
                    )
                    if [ $? -ne 0 ]; then 
                        append_report_row "test with" ":x:" "Mu2e/${REPO_NAME} git clone failed"
                        return 1
                    fi
                fi
                # change directory to it
                cd $WORKSPACE/$REPO_NAME || exit 1
            else
                # ???
                return 1
            fi

            git config user.email "you@example.com"
            git config user.name "Your Name"
            git fetch origin pull/${THE_PR}/head:pr${THE_PR}

            echo "[$(date)] Merging PR ${REPO_NAME}#${THE_PR} into ${REPO_NAME} as part of this test."

            THE_COMMIT_SHA=$(git rev-parse pr${THE_PR})

            # Merge it in
            git merge --no-ff pr${THE_PR} -m "merged #${THE_PR} as part of this test"
            if [ "$?" -gt 0 ]; then
                echo "[$(date)] Merge failure!"
                append_report_row "test with" ":x:" "Mu2e/${REPO_NAME}#${THE_PR} @ ${THE_COMMIT_SHA} merge failed"
                return 1
            fi
            CONFLICTS=$(git ls-files -u | wc -l)
            if [ "$CONFLICTS" -gt 0 ] ; then
                echo "[$(date)] Merge conflicts!"
                append_report_row "test with" ":x:" "Mu2e/${REPO_NAME}#${THE_PR} @ ${THE_COMMIT_SHA} has conflicts with this PR"
                return 1
            fi

            append_report_row "test with" ":white_check_mark:" "Included Mu2e/${REPO_NAME}#${THE_PR} @ ${THE_COMMIT_SHA} by merge"

        done
    fi
    
    cd ${WORKSPACE}/${REPO}

    if [ "${NO_MERGE}" != "1" ]; then 
        echo "[$(date)] Merging PR#${PULL_REQUEST} at ${COMMIT_SHA}."
        git merge --no-ff ${COMMIT_SHA} -m "merged ${REPOSITORY} PR#${PULL_REQUEST} ${COMMIT_SHA}."
        if [ "$?" -gt 0 ]; then
            append_report_row "merge" ":x:" "${COMMIT_SHA} into ${MASTER_COMMIT_SHA} merge failed"
            return 1
        fi
        append_report_row "merge" ":white_check_mark:" "Merged ${COMMIT_SHA} at ${MASTER_COMMIT_SHA}"


        CONFLICTS=$(git ls-files -u | wc -l)
        if [ "$CONFLICTS" -gt 0 ] ; then
            append_report_row "merge" ":x:" "${COMMIT_SHA} has merge conflicts with ${MASTER_COMMIT_SHA} "
            return 1
        fi
    fi

    return 0
}


# Configuration of test jobs to run directly after a successful build
if [ -f ".build-tests.sh" ]; then
    source .build-tests.sh
else
    # these arrays should have the same length
    # name of the job
    declare -a JOBNAMES=("ceSimReco" "g4test_03MT" "transportOnly" "POT" "g4study" "cosmicSimReco" "cosmicOffSpill" )
    # the fcl file to run the job
    declare -a FCLFILES=("Production/Validation/ceSimReco.fcl" "Offline/Mu2eG4/fcl/g4test_03MT.fcl" "Offline/Mu2eG4/fcl/transportOnly.fcl" "Production/JobConfig/beam/POT_validation.fcl" "Offline/Mu2eG4/g4study/g4study.fcl" "Production/Validation/cosmicSimReco.fcl" "Production/Validation/cosmicOffSpill.fcl")
    # how many events?
    declare -a NEVTS_TJ=("10" "10" "1" "1" "1" "1" "10")

    # manually defined test names (see build.sh)
    declare -a ADDITIONAL_JOBNAMES=("ceSteps" "ceDigi" "muDauSteps" "ceMix" "rootOverlaps" "g4surfaceCheck")

    # tests that are known to be bad
    declare -a FAIL_OK=()

    # how many of these tests to run in parallel at once
    export MAX_TEST_PROCESSES=8
    
    export JOBNAMES
    export FCLFILES
    export NEVTS_TJ
fi

cd "$WORKSPACE" || exit
rm -f *.log

echo "[$(date)] setup Mu2e/CI"
setup_cmsbot

echo "[$(date)] setup ${REPOSITORY}"
setup_offline "${REPOSITORY}"

cd "$WORKSPACE/$REPO" || exit 1
echo ${MASTER_COMMIT_SHA} > master-commit-sha.txt

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
    TD_FIXM_STATUS=":white_check_mark:"
fi


echo "[$(date)] setup ${REPOSITORY}: perform merge"
cd $WORKSPACE || exit 1
prepare_repositories
OFFLINE_MERGESTATUS=$?

if [ $OFFLINE_MERGESTATUS -ne 0 ];
then
    cat > gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
error
The PR branch may have conflicts.
http://github.com/${REPOSITORY}/pull/${PULL_REQUEST}
:bangbang: It was not possible to prepare the workspace for this test. This is often caused by merge conflicts - please check and try again.
\`\`\`
> git diff --check | grep -i conflict
$(git diff --check | grep -i conflict)
\`\`\`

| Test          | Result        | Details |
| ------------- |:-------------:| ------- |${MU2E_POSTBUILDTEST_STATUSES}


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
The build is running...
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
    CT_STATUS=":white_check_mark:"
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
        run-clang-tidy ${CLANG_TIDY_ARGS} ${CT_FILES} > $WORKSPACE/clang-tidy.log || exit 1
    )

    if [ $? -ne 1 ]; then
        CT_STATUS=":white_check_mark:"
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

function build_test_report() {
    i=$1
    EXTRAINFO=""
    STATUS_temp=":wavy_dash:"
    ALLOWED_TO_FAIL=0
    # Check if this test is "allowed to fail"
    for j in "${FAIL_OK[@]}"; do
        if [ "$i" = "$j" ]; then
            # This test is allowed to fail.
            ALLOWED_TO_FAIL=1
            STATUS_temp=":heavy_exclamation_mark:"
            break;
        fi
    done
    if [ -f "$WORKSPACE/$i.log.SUCCESS" ]; then
        STATUS_temp=":white_check_mark:"
    elif [ -f "$WORKSPACE/$i.log.TIMEOUT" ]; then
        STATUS_temp=":stopwatch: :x:"
        EXTRAINFO="Timed out."
        if [ ${ALLOWED_TO_FAIL} -ne 1 ]; then
            TESTS_FAILED=1
        fi
    elif [ -f "$WORKSPACE/$i.log.FAILED" ]; then
        STATUS_temp=":x:"
        EXTRAINFO="Return Code $(cat $WORKSPACE/$i.log.FAILED)."

        if [ ${ALLOWED_TO_FAIL} -ne 1 ]; then
            TESTS_FAILED=1
        fi
    fi
    append_report_row "$i" "${STATUS_temp}" "[Log file.](${JOB_URL}/${BUILD_NUMBER}/artifact/$i.log) ${EXTRAINFO}"
}

BUILDTIME_STR=""

if [ "$BUILDTEST_OUTCOME" == 1 ]; then
    BUILD_STATUS=":x:"

    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
failure
The build is failing (${BUILDTYPE})
${JOB_URL}/${BUILD_NUMBER}/console
:umbrella: The build is failing at ${COMMIT_SHA}.

\`\`\`
${ERROR_OUTPUT}
\`\`\`

EOM

else
    BUILD_STATUS=":white_check_mark:"

    TIME_BUILD_OUTPUT=$(grep "Total build time: " scons.log)
    TIME_BUILD_OUTPUT=$(echo "$TIME_BUILD_OUTPUT" | grep -o -E '[0-9\.]+')

    BUILDTIME_STR="Build time: $(date -d@$TIME_BUILD_OUTPUT -u '+%M min %S sec')"

    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
success
The tests passed.
${JOB_URL}/${BUILD_NUMBER}/console
:sunny: The tests passed at ${COMMIT_SHA}.

EOM

fi

append_report_row "build ($BUILDTYPE)" "${BUILD_STATUS}" "[Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/scons.log). ${BUILDTIME_STR}"

for i in "${JOBNAMES[@]}"
do
    build_test_report $i
done
for i in "${ADDITIONAL_JOBNAMES[@]}"
do 
    build_test_report $i
done

if [ "$TESTS_FAILED" == 1 ] && [ "$BUILDTEST_OUTCOME" == 1 ]; then
    BUILDTEST_OUTCOME=1

    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
failure
The build succeeded, but other tests are failing.
${JOB_URL}/${BUILD_NUMBER}/console
:umbrella: The tests failed for ${COMMIT_SHA}.

EOM
fi

append_report_row "FIXME, TODO" "${TD_FIXM_STATUS}" "[TODO (${TD_COUNT}) FIXME (${FIXM_COUNT}) in ${FILES_SCANNED} files](${JOB_URL}/${BUILD_NUMBER}/artifact/fixme_todo.log)"
append_report_row "clang-tidy" "${CT_STATUS}" "[${CT_STAT_STRING}](${JOB_URL}/${BUILD_NUMBER}/artifact/clang-tidy.log)"


cat >> "$WORKSPACE"/gh-report.md <<- EOM

| Test          | Result        | Details |
| ------------- |:-------------:| ------- |${MU2E_POSTBUILDTEST_STATUSES}

EOM

if [ "$TRIGGER_VALIDATION" = "1" ]; then

cat >> "$WORKSPACE"/gh-report.md <<- EOM
:hourglass: The validation job has been queued.

EOM

fi

if [ "${NO_MERGE}" = "0" ]; then
    cat >> "$WORKSPACE"/gh-report.md <<- EOM

N.B. These results were obtained from a build of this Pull Request at ${COMMIT_SHA} after being merged into the base branch at ${MASTER_COMMIT_SHA}.

EOM
else
    cat >> "$WORKSPACE"/gh-report.md <<- EOM

N.B. These results were obtained from a build of this pull request branch at ${COMMIT_SHA}.

EOM
fi

cat >> "$WORKSPACE"/gh-report.md <<- EOM

For more information, please check the job page [here](${JOB_URL}/${BUILD_NUMBER}/console).
Build artifacts are deleted after 5 days. If this is not desired, select \`Keep this build forever\` on the job page.

EOM

# truncate scons logfile in place, removing time debug info
sed -i '/Command execution time:/d' scons.log
sed -i '/SConscript:/d' scons.log

${CMS_BOT_DIR}/upload-job-logfiles gh-report.md ${WORKSPACE}/*.log > gist-link.txt 2> upload_logfile_error_response.txt

if [ $? -ne 0 ]; then
    # do nothing for now, but maybe add an error message in future
    echo "Couldn't upload logfiles..."

else
    GIST_LINK=$( cat gist-link.txt )
    cat >> "$WORKSPACE"/gh-report.md <<- EOM

Log files have been uploaded [here.](${GIST_LINK})

EOM

fi


cmsbot_report "$WORKSPACE/gh-report.md"

echo "[$(date)] cleaning up old gists"
${CMS_BOT_DIR}/cleanup-old-gists

wait;
exit $BUILDTEST_OUTCOME;

