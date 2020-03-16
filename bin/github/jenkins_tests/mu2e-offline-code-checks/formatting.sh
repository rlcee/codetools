#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk

echo "[`date`] clang-format"

PATCH_FILE="$WORKSPACE/clang-format-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"

for MOD_FILE in $MODIFIED_PR_FILES
do
    if [[ "$MOD_FILE" == *.cc ] || [ "$MOD_FILE" == *.hh ]]; then
        clang-format -i $MOD_FILE
        echo "clang-format on $MOD_FILE"
    else
        echo "skipped $MOD_FILE since not a cpp .hh or .cc file"    
    fi
done

git diff > $PATCH_FILE

if [ -s "$PATCH_FILE" ]; then
  PURL="${JOB_URL}/${BUILD_NUMBER}/artifact/clang-format-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"

  cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
success
clang-format made suggestions...
${JOB_URL}/${BUILD_NUMBER}/console
:cloudy: clang-format generated a patch at ref ${COMMIT_SHA} on files you changed.
#### `clang-format` suggests re-formatting these files:
\`\`\`
git diff --compact-summary
$(git diff --compact-summary)
\`\`\`

Please review the patch [here]($PURL).

You can apply the proposed changes like this:
\`\`\`
curl $PURL | git apply -v --index
git commit -am "Code formatting patch on ${COMMIT_SHA}"
git push
\`\`\`

EOM
    exit 1;
fi

exit 0;
