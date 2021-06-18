#!/bin/bash
# Ryunosuke O'Neil, 2020
# @ryuwd on GitHub
# 

echo "[`date`] find trailing whitespace"
PATCH_FILE="$WORKSPACE/codechecks-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"
for MOD_FILE in $MODIFIED_PR_FILES
do
    if [[ "$MOD_FILE" == *.cc ]] || [[ "$MOD_FILE" == *.hh ]] || [[ "$MOD_FILE" == *.fcl ]]; then
        sed -Ei 's/[ \t]+$//' "$MOD_FILE"
    else
        echo "skipped $MOD_FILE since not a cpp or fcl file"
    fi
done
git diff > $PATCH_FILE

if [ -s "$PATCH_FILE" ]; then
  PURL="${JOB_URL}/${BUILD_NUMBER}/artifact/codechecks-pr${PULL_REQUEST}-${COMMIT_SHA}.patch"

  cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
failure
Trailing whitespace was found in one or more header, source, or fcl files.
${JOB_URL}/${BUILD_NUMBER}/console
:x: Trailing whitespace characters were found at ${COMMIT_SHA} on files you changed.

You can review the generated patch [here]($PURL).

If it is convenient, you may remove the trailing whitespace like this:
\`\`\`
curl $PURL | git apply -v --index
git commit -am "Remove trailing whitespace" && git push
\`\`\`

EOM

    exit 1;
fi

echo "[`date`] find hard tabs"
HARD_TABS=0
for MOD_FILE in $MODIFIED_PR_FILES
do
    if [[ "$MOD_FILE" == *.cc ]] || [[ "$MOD_FILE" == *.hh ]] || [[ "$MOD_FILE" == *.fcl ]]; then
        detect-tab-indent "$MOD_FILE" >> ${WORKSPACE}/detect-tab-indent-${COMMIT_SHA}.log
        
        if [ $? -ne 0 ]; then
            HARD_TABS=1
        fi
    else
        echo "skipped $MOD_FILE since not a cpp file"
    fi
done

if [ $HARD_TABS -ne 0 ]; then
  PURL="${JOB_URL}/${BUILD_NUMBER}/artifact/detect-tab-indent-${COMMIT_SHA}.log"
  cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
failure
Hard tabs were found in one or more header, source, or fcl files.
${JOB_URL}/${BUILD_NUMBER}/console
:x: Hard tab indentations were found at ${COMMIT_SHA} on files you changed.

Please remove any tab characters from code indentations, and re-indent with spaces where appropriate. 

See the [log file]($PURL) for more details.

EOM

    exit 1;
fi



  cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/codechecks
success
Code checks were successful.
${JOB_URL}/${BUILD_NUMBER}/console
NOCOMMENT

EOM
exit 0;
