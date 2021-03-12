#! /bin/bash
#
# pull partial checkout branch builds
# 12/2018 Ray Culbertson
#

abort() {
  echo "[$(date)] aborting"
  cvmfs_server abort -f mu2e-development.opensciencegrid.org
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "[$(date)] abort failed with $RC"
  fi
  exit 1
}

cleanRepos() {
  local BRANCHES=$( ls -1 $CDIR )
  local NOW=$( date +%s )
  for BRANCH in $BRANCHES
  do
    # exempt Pasha's base build for now
    #local TAGS=$( ls -t $CDIR/$BRANCH | grep -v c1e34abc )
    local TAGS=$( ls -t $CDIR/$BRANCH | grep -v 9ab5447e )
    local POSITION=1
    for TAG in $TAGS
    do
	local CTIME=$( stat -c "%Z" $CDIR/$BRANCH/$TAG )
	local DAYSOLD=$(( ($NOW-$CTIME)/86400  ))
        #echo "checking $BRANCH/$TAG POSITION=$POSITION DAYSOLD=$DAYSOLD"
	if [[ $POSITION -gt 10 || ( $POSITION -gt 3 && $DAYSOLD -gt 14 ) ]]; then
          echo "cleanup $BRANCH/$TAG POSITION=$POSITION DAYSOLD=$DAYSOLD"
	  rm -rf $CDIR/$BRANCH/$TAG
        #else
        #  echo "save $BRANCH/$TAG"
        fi
	POSITION=$(( $POSITION + 1 ))
    done
  done
}


TDIR=/mu2e/data/users/mu2epro/git/stage
CDIR=/cvmfs/mu2e-development.opensciencegrid.org/branches
FN="$1"
echo "[$(date)] Start $FN"


echo "[$(date)] cvmfs transaction"
cvmfs_server transaction mu2e-development.opensciencegrid.org
RC=$?
sleep 1
if [ $RC -ne 0 ]; then
   echo "[$(date)] scp failed $RC"
   abort
fi

echo "[$(date)] tar"
cd $CDIR
sleep 1

scp mu2epro@mu2egpvm01:$TDIR/$FN ./$FN
RC=$?
if [ $RC -ne 0 ]; then
   echo "[$(date)] scp failed $RC"
   abort
fi

tar -xzf ./$FN
RC=$?
rm -f ./$FN
if [ $RC -ne 0 ]; then
   echo "[$(date)] tar failed $RC"
   abort
fi

# must get out of the partition
cd 

echo "[$(date)] clean"
cleanRepos

echo "[$(date)] publish"
cvmfs_server publish mu2e-development.opensciencegrid.org
RC=$?
sleep 1
if [ $RC -ne 0 ]; then
   echo "[$(date)] publish failed $RC"
   abort
fi

echo "[$(date)] garbage collect"
cvmfs_server gc -f mu2e-development.opensciencegrid.org
RC=$?
if [ $RC -ne 0 ]; then
   echo "[$(date)] garbage collect failed $RC"
   exit 3
fi

exit 0


