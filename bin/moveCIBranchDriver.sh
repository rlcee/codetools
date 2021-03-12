#!/bin/bash
cd /mu2e/app/home/mu2epro/cron/git
if [ -f lock ]; then
   DT=$(( $(date +%s) - $(stat --printf="%Y" lock) ))
   if [ $DT -lt 3000 ]; then
       echo "[$(date)] exit on lock, DT=$DT" 
       exit 0
   else
       echo "[$(date)] force remove lock DT=$DT" 
       rm -f lock
       echo " removed git branch lock, dt=$DT" | \
	   mail -r pgit -s "pgit cron removed lock" rlc@fnal.gov
   fi
fi

echo "[$(date)] running pgit" 

touch lock

# pgit
./moveCIBranch.sh >& moveCIBranch.log

echo "[$(date)] running mgit" 

# muse mgit
./museCIBuild.sh >& museCIBuild.log

rm lock

exit 0
