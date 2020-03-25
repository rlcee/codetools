#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk

echo "[`date`] clang-format"


CLANG_TIDY_ARGS="-extra-arg=-isystem$CLANG_FQ_DIR/include/c++/v1 -p . -j 24"
CLANG_TIDY_RUNNER="${CLANG_FQ_DIR}/share/clang/run-clang-tidy.py"
PATCH_FILE="$WORKSPACE/clang-format-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"
CT_FILES="" # files to run in clang tidy

for MOD_FILE in $MODIFIED_PR_FILES
do
    if [[ "$MOD_FILE" == *.cc ]] || [[ "$MOD_FILE" == *.hh ]]; then
        clang-format -i $MOD_FILE
        echo "clang-format on $MOD_FILE"

        if [[ "$MOD_FILE" == *.cc ]]; then
            CT_FILES="$MOD_FILE $CT_FILES"
        fi
    else
        echo "skipped $MOD_FILE since not a cpp .hh or .cc file"
    fi
done

${CLANG_TIDY_RUNNER} ${CLANG_TIDY_ARGS} ${CT_FILES} > $WORKSPACE/clang-tidy-log-${COMMIT_SHA}.log || exit 1

git checkout -- .clang-tidy
git checkout -- .clang-format # we do this so these configs do not show up in the diff.
git checkout -- SConstruct
git diff > $PATCH_FILE

if [ -s "$PATCH_FILE" ]; then
  PURL="${JOB_URL}/${BUILD_NUMBER}/artifact/clang-format-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"

  cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
success
Code checks have finished.
${JOB_URL}/${BUILD_NUMBER}/console
:cloud: clang-format generated a patch at ref ${COMMIT_SHA} on files you changed.
#### clang-format suggests re-formatting files:
Please review the patch [here]($PURL).

If it is convenient to do so, you can apply the patch like this:
\`\`\`
curl $PURL | git apply -v --index
git commit -am "Code formatting patch on ${COMMIT_SHA}" && git push
\`\`\`

#### clang-tidy results
The \`clang-tidy\` log file is [here](${JOB_URL}/${BUILD_NUMBER}/artifact/clang-tidy-log-${COMMIT_SHA}.log).

EOM

    exit 1;
fi


  cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
success
Code checks have finished.
${JOB_URL}/${BUILD_NUMBER}/console
:sunny: No re-formatting is required at ref ${COMMIT_SHA} on files you changed.

#### clang-tidy results
The \`clang-tidy\` log file is [here](${JOB_URL}/${BUILD_NUMBER}/artifact/clang-tidy-log-${COMMIT_SHA}.log).

EOM
exit 0;
