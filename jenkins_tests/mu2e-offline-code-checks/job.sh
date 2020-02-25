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
    python "$WORKSPACE/clangtools_utilities/gen_compdb.py"
}

echo "[$(date)] setup job environment"
. setup.sh

echo "[$(date)] setup python env + CMS-BOT/mu2e"
setup_cmsbot

echo "[$(date)] setup ${REPOSITORY}"
setup_offline "${REPOSITORY}"

cd $REPO || exit 1
git checkout ${COMMIT_SHA}


echo "[$(date)] setups"
do_setupstep

export MODIFIED_PR_FILES=`git diff --name-status master | grep "^M" | sed -e 's/^\w*\ *//' | awk '{$1=$1;print}'`

echo "[$(date)] check formatting"
(
    source jenkins_tests/mu2e-offline-code-checks/formatting.sh
)
if [ $? -ne 0 ]; then
    cmsbot_report $WORKSPACE/gh-report.md
    exit 1;
fi
git reset --hard ${COMMIT_SHA}

echo "[$(date)] setup compile_commands.json"
gen_compdb

echo "[$(date)] clang-tidy"
(
    source jenkins_tests/mu2e-offline-code-checks/clangtidy.sh
)
if [ $? -ne 0 ]; then
    cmsbot_report $WORKSPACE/gh-report.md
    exit 1;
fi
echo "[$(date)] include-what-you-use"

(
    source jenkins_tests/mu2e-offline-code-checks/iwyu.sh
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