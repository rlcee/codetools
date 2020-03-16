#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk


CLANG_TIDY_ARGS="-extra-arg=-isystem$CLANG_FQ_DIR/include/c++/v1 -p ."
CLANG_TIDY_RUNNER="${CLANG_FQ_DIR}/share/clang/run-clang-tidy.py"

touch $WORKSPACE/clang-tidy-log-*.log
${CLANG_TIDY_RUNNER} ${CLANG_TIDY_ARGS} ${MODIFIED_PR_FILES} > $WORKSPACE/clang-tidy-log-${COMMIT_SHA}.log || exit 1


exit 0;

# is the diff now nonempty?
git diff HEAD $MODIFIED_FILES > $WORKSPACE/clang-tidy-pr${PULL_REQUEST}-${COMMIT_SHA}.patch

if [ -s "$WORKSPACE/clang-tidy-pr${PULL_REQUEST}-${COMMIT_SHA}.patch" ]; then
    PURL="${JOB_URL}/${BUILD_NUMBER}/artifact/clang-tidy-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"

    cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
failure
The code checks failed (clang-tidy).
${JOB_URL}/${BUILD_NUMBER}/console
:-1: Clang tidy checks produced warnings at ref ${COMMIT_SHA}.

\`\`\`diff
$(git diff HEAD ${MODIFIED_FILES})
\`\`\`


Please \`git apply\` [this patch]($PURL) on your PR branch:

\`\`\`
curl $PURL | git apply -v --index
git commit -am "Clang tidy patch on ${COMMIT_SHA}"
git push

\`\`\`

The clang-tidy log can be [viewed here.](${JOB_URL}/${BUILD_NUMBER}/artifact/clang-tidy-log-${COMMIT_SHA}.log)

EOM
    exit 1;
fi
