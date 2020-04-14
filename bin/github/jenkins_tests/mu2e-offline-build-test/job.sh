#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk

cd "$WORKSPACE" || exit

echo "[$(date)] setup CMS-BOT/mu2e"
setup_cmsbot

echo "[$(date)] setup ${REPOSITORY} and merge"
setup_offline "${REPOSITORY}"

cd "$WORKSPACE/$REPO" || exit 1
git rev-parse HEAD > master-commit-sha.txt

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
echo "[$(date)] report outcome"
if [ "$BUILDTEST_OUTCOME" == 1 ]; then
    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
failure
The build failed (${BUILDTYPE})
${JOB_URL}/${BUILD_NUMBER}/console
:umbrella: The build failed at ref ${COMMIT_SHA}.
| Test          | Result        |
| ------------- |:-------------:|
| scons build (prof) | :heavy_check_mark: |
| ceSimReco (-n 10) | :wavy_dash: |

\`\`\`
${ERROR_OUTPUT}
\`\`\`
For more information, please check [here](${JOB_URL}/${BUILD_NUMBER}/console).

EOM

elif [ "$BUILDTEST_OUTCOME" == 2 ]; then
    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
failure
The build succeeded, but other tests failed.
${JOB_URL}/${BUILD_NUMBER}/console
:umbrella: The tests failed for ref ${COMMIT_SHA}.

| Test          | Result        |
| ------------- |:-------------:|
| scons build (prof) | :heavy_check_mark: |
| ceSimReco (-n 10) | :x: |

For more information, please check [here](${JOB_URL}/${BUILD_NUMBER}/console).

EOM

else

    TIME_BUILD_OUTPUT=$(grep "Total build time: " scons.log)
    TIME_BUILD_OUTPUT=$(echo "$TIME_BUILD_OUTPUT" | grep -o -E '[0-9\.]+')

    cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/buildtest
success
The tests passed.
${JOB_URL}/${BUILD_NUMBER}/console
:sunny: The tests passed at ref ${COMMIT_SHA}. Total build time: $(date -d@$TIME_BUILD_OUTPUT -u '+%M min %S sec').

| Test          | Result        |
| ------------- |:-------------:|
| scons build (prof) | :heavy_check_mark: |
| ceSimReco (-n 10) | :heavy_check_mark: |

For more information, please check [here](${JOB_URL}/${BUILD_NUMBER}/console).

EOM

fi

cmsbot_report "$WORKSPACE/gh-report.md"
wait;
exit $BUILDTEST_OUTCOME;

