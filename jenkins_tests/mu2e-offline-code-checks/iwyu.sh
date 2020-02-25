#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk


PATH=$WORKSPACE/clangtools_utilities:$PATH

touch $WORKSPACE/iwyu-log-*.log
run_iwyu.sh ${MODIFIED_PR_FILES} > $WORKSPACE/iwyu-log-${COMMIT_SHA}.log
fix_includes.py < $WORKSPACE/iwyu-log-${COMMIT_SHA}.log
clang-format -i ${MODIFIED_PR_FILES}

# is the diff now nonempty?
git diff HEAD $MODIFIED_PR_FILES > $WORKSPACE/iwyu-pr${PULL_REQUEST}-${COMMIT_SHA}.patch

if [ -s "$WORKSPACE/clang-tidy-pr${PULL_REQUEST}-${COMMIT_SHA}.patch" ]; then
    PURL="${JOB_URL}/${BUILD_NUMBER}/artifact/iwyu-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"

    cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
success
The code checks succeeded with messages (IWYU).
${JOB_URL}/${BUILD_NUMBER}/console
:+1: Code checks succeeded with suggestions at ref ${COMMIT_SHA}.

IWYU made suggestions for $(git diff --name-status master | grep "^M" | wc -l) files. These are not required, but recommended.

Please review and \`git apply\` [this patch]($PURL) on your PR branch:

\`\`\`
curl $PURL | git apply -v --index
# < review changes first! >
git commit -am "IWYU patch on ${COMMIT_SHA}"
git push
\`\`\`

The IWYU log file can be [viewed here.](${JOB_URL}/${BUILD_NUMBER}/artifact/iwyu-log-${COMMIT_SHA}.log)

EOM

    exit 1;
fi

exit 0;