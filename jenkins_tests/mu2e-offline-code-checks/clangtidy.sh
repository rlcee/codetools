#!/bin/bash
function gen_compdb() {
    python "$WORKSPACE/clangtools_utilities/gen_compdb.py"
}

gen_compdb

CLANG_TIDY_ARGS="-extra-arg=-isystem$CLANG_FQ_DIR/include/c++/v1 -p . -fix -format"
CLANG_TIDY_RUNNER="${CLANG_FQ_DIR}/share/clang/run-clang-tidy.py"

touch $WORKSPACE/clang-tidy-log-*.log
${CLANG_TIDY_RUNNER} ${CLANG_TIDY_ARGS} ${MODIFIED_PR_FILES} > $WORKSPACE/clang-tidy-log-${COMMIT_SHA}.log
clang-format -i ${MODIFIED_PR_FILES}

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