#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk


cd "$WORKSPACE" || exit

function do_setupstep() {
    source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
    setup mu2e
    setup codetools
    setup clang v5_0_1
    setup iwyu

    return 0
}

function gen_compdb() {
    python "${CLANGTOOLS_UTIL_DIR}/gen_compdb.py"
}

echo "[$(date)] setup CMS-BOT/mu2e"
setup_cmsbot

echo "[$(date)] setup ${REPOSITORY}"
setup_offline "${REPOSITORY}"

cd $WORKSPACE/$REPO || exit 1;
git checkout ${COMMIT_SHA}

#offline_domerge
OFFLINE_MERGESTATUS=0

if [ $OFFLINE_MERGESTATUS -ne 0 ];
then
    cat > gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
error
The PR branch could not be merged.
http://github.com/${REPOSITORY}/pull/${PULL_REQUEST}
:x: The build test could not run due to merge conflicts, or otherwise. Please resolve this first and try again.

EOM
    cmsbot_report gh-report.md
    exit 1;
fi



#export MODIFIED_PR_FILES=`git diff --name-only ${MASTER_COMMIT_SHA} HEAD | grep "^M" | grep -E '(.*\.cc$|\.hh$)' | sed -e 's/^\w*\ *//' | awk '{$1=$1;print}'`
export MODIFIED_PR_FILES=$(git --no-pager diff --name-only FETCH_HEAD $(git merge-base FETCH_HEAD master))

echo "[$(date)] check formatting"
(
    source ${TESTSCRIPT_DIR}/simple-formatting.sh
)
if [ $? -ne 0 ]; then
    cmsbot_report $WORKSPACE/gh-report.md
    exit 1;
fi
git reset --hard ${COMMIT_SHA}

echo "[$(date)] setups"
do_setupstep

echo "[$(date)] setup compile_commands.json"
(
    exit 0;
    set --
    source setup.sh
    scons -Q compiledb
)

echo "[$(date)] clang-tidy"
(
    exit 0;
    source ${TESTSCRIPT_DIR}/clangtidy.sh
)
if [ $? -ne 0 ]; then
    cat > gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
error
clang-tidy failed to run.
http://github.com/${REPOSITORY}/pull/${PULL_REQUEST}
:x: Clang-tidy failed to run. Please check the job output.
http://github.com/${REPOSITORY}/pull/${PULL_REQUEST}

EOM

    cmsbot_report $WORKSPACE/gh-report.md
    exit 1;
fi

echo "[$(date)] include-what-you-use"
(
    echo "IWYU step has been switched off."
    exit 0;
    #source ${TESTSCRIPT_DIR}/iwyu.sh
)
if [ $? -ne 0 ]; then
    cmsbot_report $WORKSPACE/gh-report.md
    exit 0;
fi

cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
success
The code checks passed.
${JOB_URL}/${BUILD_NUMBER}/console
NOCOMMENT

EOM

cmsbot_report $WORKSPACE/gh-report.md
exit 0;
