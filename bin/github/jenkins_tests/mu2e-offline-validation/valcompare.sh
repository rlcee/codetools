#!/bin/bash

# runs TValCompare with only access to the Validation shared library
# return code 0: success
# return code 1: error
set --

setup mu2e

# choose a version of Offline with a 'good' Validation shared lib available.
# We do it this way since we know tagged releases should have a stable TValCompare
# and, sometimes master doesn't get built if i.e. we have a cached rootfile
# and, we don't want to rely on the PR version (since that came from elsewhere)

IMPARTIAL_OFFLINE_LOC="/cvmfs/mu2e.opensciencegrid.org/Offline/v8_0_3/SLF7/prof/Offline"
source "$IMPARTIAL_OFFLINE_LOC/setup.sh"

rm -rf $WORKSPACE/validation_web
mkdir -p $WORKSPACE/validation_web


cat > $WORKSPACE/validation-script <<- EOM

.L ${IMPARTIAL_OFFLINE_LOC}/lib/libmu2e_Validation_root.so

TValCompare c;
c.SetFile1("${WORKSPACE}/rev_${MASTER_COMMIT_SHA}_master_validation.root");
c.SetFile2("${WORKSPACE}/rev_${COMMIT_SHA}_pr_validation.root");
c.Analyze();
c.Summary();
c.Report();
c.SaveAs("${WORKSPACE}/validation_web/result.html");

.q

EOM

root -b < ${WORKSPACE}/validation-script 2>&1 | tee ${WORKSPACE}/valCompare.log
VRC=${PIPESTATUS[0]}

if [ ! -f "${WORKSPACE}/validation_web/result.html" ]; then
	exit 1;
fi

cd "$WORKSPACE"
tar -zcvf valOutput_PR${PULL_REQUEST}_${COMMIT_SHA}_master_${MASTER_COMMIT_SHA}.tar.gz validation_web/ || exit 1;

mkdir -p valOutput/pr${PULL_REQUEST}/;
mv validation_web valOutput/pr${PULL_REQUEST}/rev${COMMIT_SHA} || exit 1;

cat $WORKSPACE/valCompare.log | awk 'BEGIN{ found=0} /TValCompare/{found=1}  {if (found) print }' > temp.log
grep -vwE "TCanvas::Print" temp.log > $WORKSPACE/valCompareSummary.log

if [ ! -f "${WORKSPACE}/valCompareSummary.log" ]; then
	exit 1;
fi

exit 0;