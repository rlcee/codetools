#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk

echo "[`date`] clang-format"

PATCH_FILE="$WORKSPACE/clang-format-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"

clang-format -i $MODIFIED_PR_FILES
git diff > $PATCH_FILE

if [ -s "$PATCH_FILE" ]; then
  PURL="${JOB_URL}/${BUILD_NUMBER}/artifact/clang-format-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"

  cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
failure
The code checks failed.
${JOB_URL}/${BUILD_NUMBER}/console
:-1: Code formatting checks have failed at ref ${COMMIT_SHA}.
#### `clang-format` changed these files:
\`\`\`
git diff --compact-summary
$(git diff --compact-summary)
\`\`\`

Please review and \`git apply\` [this patch]($PURL) on your PR branch:
\`\`\`
curl $PURL | git apply -v --index
git commit -am "Code formatting patch on ${COMMIT_SHA}"
git push
\`\`\`

To avoid this in future please \`clang-format -i\` modified files before opening a PR.

EOM
    exit 1;
fi

exit 0;