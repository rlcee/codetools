#!/bin/bash
# Ryunosuke O'Neil, 2020
# @ryuwd on GitHub
# 

echo "[`date`] find trailing whitespace"
CT_FILES="" # files to run in clang tidy
PATCH_FILE="$WORKSPACE/codechecks-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"
for MOD_FILE in $MODIFIED_PR_FILES
do
    if [[ "$MOD_FILE" == *.cc ]] || [[ "$MOD_FILE" == *.hh ]]; then
        sed -Ei 's/[ \t]+$//' "$MOD_FILE"
    else
        echo "skipped $MOD_FILE since not a cpp file"
    fi
done
git diff > $PATCH_FILE

if [ -s "$PATCH_FILE" ]; then
  PURL="${JOB_URL}/${BUILD_NUMBER}/artifact/codechecks-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"

  cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
failure
Trailing whitespace was found in one or more header or source files.
${JOB_URL}/${BUILD_NUMBER}/console
:cloud: Trailing whitespace characters were found at ${COMMIT_SHA} on files you changed.

You can review the generated patch [here]($PURL).

If it is convenient, you may remove the trailing whitespace like this:
\`\`\`
curl $PURL | git apply -v --index
git commit -am "Remove trailing whitespace found at ${COMMIT_SHA}" && git push
\`\`\`

EOM

    exit 1;
fi


  cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
success
Code checks have finished.
${JOB_URL}/${BUILD_NUMBER}/console
NOCOMMENT

EOM
exit 0;
