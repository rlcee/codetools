#! /bin/bash
#
# run quick checks for nightly validation
# $1= the work directory
#

echo_date() {
echo "[$(date)] $*" 
}

echo_date "cd"
WORKDIR="$1"
shift
if [ -z "$WORKDIR" ]; then
  echo "ERROR - no work dir provided - exit" 
  exit 1
fi
cd $WORKDIR
RC=$?
if [ $RC -ne 0 ]; then
  echo "ERROR - could not cd to work dir - exit"
  exit 2
fi

echo_date "general setups"
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
setup codetools

echo_date "cd Offline"
cd Offline

echo_date "source setup"
source setup.sh

echo_date "start root overlaps"
rootOverlaps.sh
RC2=${PIPESTATUS[0]}
echo_date "root overlaps return code $RC2"
LEGAL=$( grep CloseGeometry ../check | awk '{print $4 " " $5 " " $6 " " $7 " " $8}' )
ILLEGAL=$( grep illegal ../check | awk '{print $NF}' )
if [[ $RC2 -eq 0 && $ILLEGAL -eq 0 ]]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS root overlaps   $ILLEGAL overlaps in $LEGAL"

echo_date "start transportOnly"
mu2e -n 5 -c Mu2eG4/fcl/transportOnly.fcl
RC3=$?
echo_date "transportOnly return code $RC4"
if [ $RC3 -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS transportOnly"

echo_date "start g4study2"
mu2e -n 5 -c Mu2eG4/fcl/g4study.fcl
RC4=$?
echo_date "g4study2 return code $RC5"
if [ $RC4 -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS g4study2"

echo_date "start ceMixDigi"
mu2e -n 10 -c Validation/fcl/ceMixDigi.fcl >& ceMixDigi.log
RC5=$?
cat ceMixDigi.log
echo_date "ceMixDigi return code $RC6"
if [ $RC5 -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS ceMixDigi"
MIXCPU=$( grep "TimeReport CPU" ceMixDigi.log | awk '{print int($4)}')
MIXMEM=$( grep "VmPeak" ceMixDigi.log | awk '{print int($4)}')
MIXSIZ=$( ls -l dig.owner.val-ceMixDigi.dsconf.seq.art | awk '{print $5}')
echo "REPORT EXE ceMixDigi $MIXCPU $MIXMEM $MIXSIZ"

RC=$(($RC2+$RC3+$RC4+$RC5))

if [ $RC -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo_date "check total return code $RC"
echo "REPORT STATUS $STATUS check"

exit $RC
