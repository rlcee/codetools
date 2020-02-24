#!/bin/bash
cd "$WORKSPACE" || exit

echo "[$(date)] setup job environment"
. setup.sh

echo "[$(date)] setup CMS-BOT/mu2e"
setup_cmsbot

echo "[$(date)] setup ${REPOSITORY} and merge"
setup_offline "${REPOSITORY}"

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
:x: The build test could not run due to merge conflicts, or otherwise. Please resolve this first and try again.

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
The build test is running in Jenkins.
${JOB_URL}/${BUILD_NUMBER}/console
NOCOMMENT

EOM
cmsbot_report gh-report.md


echo "[$(date)] run build test"
(
    source "${WORKSPACE}/jenkins_tests/mu2e-offline-build-test/build.sh"
)
BUILDTEST_OUTCOME=$?

echo "[$(date)] report outcome"
if [ "$BUILDTEST_OUTCOME" == 1 ]; then
    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
failure
SCons failed to build ${BUILDTYPE}.
${JOB_URL}/${BUILD_NUMBER}/console
:-1: The build test failed at ref ${COMMIT_SHA}.
### Test Report
- The build (${BUILDTYPE}) was unsuccessful.
- ceSimReco (run test) was skipped.

For more information, please check [here](${JOB_URL}/${BUILD_NUMBER}/console).

EOM

elif [ "$BUILDTEST_OUTCOME" == 2 ]; then
    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
failure
The build succeeded, but ceSimReco failed.
${JOB_URL}/${BUILD_NUMBER}/console
:-1:
The build test failed for ref ${COMMIT_SHA}.
### Test Report
- The build (${BUILDTYPE}) was successful.
- ceSimReco completed unsuccessfully.

For more information, please check [here](${JOB_URL}/${BUILD_NUMBER}/console).

EOM

else
    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
success
The build test succeeded.
${JOB_URL}/${BUILD_NUMBER}/console
:+1:
The build test passed at ref ${COMMIT_SHA}. The build has been cached for validation, if required.

For more details, please check [here](${JOB_URL}/${BUILD_NUMBER}/console).

EOM
    echo "[$(date)] Now gzip the compiled build, saving this for validation if needed."
    cd "$WORKSPACE" || exit
    tar -zcvf rev_"${COMMIT_SHA}"_pr_lib.tar.gz Offline/lib

fi

cmsbot_report "$WORKSPACE/gh-report.md"
exit 0;