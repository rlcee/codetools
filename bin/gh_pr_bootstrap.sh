#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk
# sets up job environment and calls the job.sh script in the relevant directory

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export JENKINS_TESTS_DIR="$DIR/github/jenkins_tests"
export CLANGTOOLS_UTIL_DIR="$DIR/../clangtools_utilities"
export TESTSCRIPT_DIR="$JENKINS_TESTS_DIR/$1"


cd "$WORKSPACE" || exit 1;


function check_set() {
    if [ -z "$1" ]; then
        return 1; # not set!
    fi

    return 0;
}

echo "Checking we're in the expected Jenkins environment...";

check_set $REPOSITORY || exit 1;
check_set $PULL_REQUEST || exit 1;
check_set $COMMIT_SHA || exit 1;
check_set $MASTER_COMMIT_SHA || exit 1;

echo "OK!"

echo "Bootstrapping job $1..."


JOB_SCRIPT="${TESTSCRIPT_DIR}/job.sh"

if [ ! -f "$JOB_SCRIPT" ]; then
    echo "Fatal error running job type $1 - could not find $JOB_SCRIPT."
    exit 1;
fi

echo "Setting up job environment..."


rm -rf *.log *.md *.patch > /dev/null 2>&1

function print_jobinfo() {
    echo "[`date`] printenv"
    printenv

    echo "[`date`] df -h"
    df -h

    echo "[`date`] quota"
    quota -v

    echo "[`date`] PWD"
    pwd
    export LOCAL_DIR=$PWD

    echo "[`date`] ls of local dir"
    ls -al

    echo "[`date`] cpuinfo"
    cat /proc/cpuinfo | head -30

}

function setup_cmsbot() {
    source $HOME/PyGithub/bin/activate
    export CMS_BOT_DIR="$WORKSPACE/CI"

    if [ ! -d ${CMS_BOT_DIR} ]; then
        (
            cd "$WORKSPACE"
            git clone -b master git@github.com:Mu2e/CI
        )
    else
        (
            cd ${CMS_BOT_DIR}
            git fetch; git pull
            cd -
        )
    fi
}

function cmsbot_report() {
    ${CMS_BOT_DIR}/comment-github-pullrequest -r ${REPOSITORY} -p ${PULL_REQUEST} --report-file $1

    if grep -Fxq "NOCOMMENT" $1
    then
        ${CMS_BOT_DIR}/process-pull-request ${PULL_REQUEST} --repository ${REPOSITORY}
    fi

}

function setup_offline() {
    # setup_offline Mu2e/Offline
    # clone Mu2e/Offline

    export REPO=$(echo $1 | sed 's|^.*/||')
    export REPO_FULLNAME=$1
    (

        if [ -d ${REPO} ]; then
            rm -rf $REPO
        fi

        git clone "https://github.com/$REPO_FULLNAME"

        cd $REPO

        git config user.email "you@example.com"
        git config user.name "Your Name"

        git fetch origin pull/${PULL_REQUEST}/head:pr${PULL_REQUEST}
    )
}


function offline_domerge() {
    git checkout ${MASTER_COMMIT_SHA}

    git merge --no-ff ${COMMIT_SHA} -m "merged ${REPOSITORY} PR#${PULL_REQUEST} ${COMMIT_SHA} at ${MASTER_COMMIT_SHA}."

    if [ "$?" -gt 0 ]; then
        return 1;
    fi

    CONFLICTS=$(git ls-files -u | wc -l)
    if [ "$CONFLICTS" -gt 0 ] ; then
        return 1
    fi

    return 0

}

echo "Running job now."
(
    source $JOB_SCRIPT
)
JOB_STATUS=$?

echo "Job finished with status $JOB_STATUS."
exit $JOB_STATUS
