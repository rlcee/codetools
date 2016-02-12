#!/bin/bash
#
#
# Ray Culbertson
#

usage()
{
    echo "
 Pull an Offline validation histogram file from Jenkins build machine
 \$1 = git release tag, like v5_2_1

"
}


export TAG=$1
HTMLDIR="/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/val/files"

if [ "$TAG" == "" ]; then
  usage
  exit 1
fi

TMP=`mktemp`
FILE=val-genReco-5000-${TAG}.root
export URL="https://buildmaster.fnal.gov/view/mu2e/job/mu2e-offline-build/BUILDTYPE=prof,label=SLF6/lastSuccessfulBuild/artifact/copyBack/$FILE"
wget -O $TMP $URL
RC=$?
if [ $RC -ne 0 ];then
  echo "ERROR - wget failed on $FILE"
  exit 1
fi

mv $TMP $HTMLDIR/$FILE
RC=$?
if [ $RC -ne 0 ];then
  echo "ERROR - wget failed to move val file to $HTMLDIR"
  exit 1
fi

exit

