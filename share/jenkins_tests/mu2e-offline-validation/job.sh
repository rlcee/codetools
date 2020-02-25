#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk

cd "$WORKSPACE" || exit

echo "[$(date)] setup CMS-BOT/mu2e"
setup_cmsbot

if [ -f "$WORKSPACE/master_commit_sha.txt" ]; then
  BUILDTEST_MASTER_SHA=`cat $WORKSPACE/master_commit_sha.txt`

  if [ "$BUILDTEST_MASTER_SHA" != "$MASTER_COMMIT_SHA" ]; then
      echo "[`date`] WARNING: MASTER REV MISMATCH WITH BUILD TEST MASTER REV"
      echo "[`date`] This means that commits in master that were not built in a build test"
      echo "[`date`] may affect the comparison results. Review these results with caution."
  fi
else
	echo "[`date`] WARNING: could not find master_commit_sha.txt..."
fi

if [ ! -f "$WORKSPACE/rev_${COMMIT_SHA}_pr_lib.tar.gz" ]; then
	cat > gh-run-report.md <<- EOM
${COMMIT_SHA}
mu2e/validation
error
Validation cannot be run before a build test.
${JOB_URL}/${BUILD_NUMBER}/console
The archived shared libraries from build test at ${COMMIT_SHA} cannot be found. Archived builds are deleted after 5 days.

If this is the case, please try re-running the build test.

EOM
    cmsbot_report gh-run-report.md

	cat > gh-run-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
pending
The test has not been triggered yet.
http://github.com/$REPOSITORY/pull/${PULL_REQUEST}
NOCOMMENT

EOM
	sleep 2;
    cmsbot_report gh-run-report.md

    exit 1;
fi

cd "$WORKSPACE" || exit 1

# report that the job script is now running

cat > gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
pending
Validation is running in Jenkins.
${JOB_URL}/${BUILD_NUMBER}/console
NOCOMMENT

EOM
cmsbot_report gh-report.md

# parallelise for speed.
(
    echo "[$(date)] set up master"
    (
        source "${TESTSCRIPT_DIR}/setup_master_build.sh"
    ) &
    MASTER_BUILD_PID=$!

    echo "[$(date)] set up PR version"
    (
        source "${TESTSCRIPT_DIR}/setup_pr_build.sh"
    ) &
    PR_BUILD_PID=$!

    wait $PR_BUILD_PID;
    PR_RESTORE_OUTCOME=$?

    wait $MASTER_BUILD_PID;
    MASTER_BUILD_OUTCOME=$?

    if [ $PR_BUILD_PID -ne 0 ]; then
        echo "[$(date)] PR build could not be restored - abort."
        exit 1;
    fi

    if [ $MASTER_BUILD_PID -ne 0 ]; then
        echo "[$(date)] master build could not be restored or built - abort."
        exit 1;
    fi

    exit 0;
)

if [ $? -ne 0 ]; then
    echo "[$(date)] Failure while setting up master and PR build versions - abort."

    cat > gh-run-report.md <<- EOM
${COMMIT_SHA}
mu2e/validation
error
An error occured during the setup of master and PR build versions.
${JOB_URL}/${BUILD_NUMBER}/console
NOCOMMENT

EOM
    cmsbot_report gh-run-report.md
    exit 1;
fi

echo "[$(date)] PR and master builds are ready"

# parallelise validation jobs for each build version.



echo "[$(date)] report outcome"

cmsbot_report "$WORKSPACE/gh-report.md"
exit 0;