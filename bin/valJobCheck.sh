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

if ! cd $WORKDIR ; then
  echo "ERROR - could not cd to work dir - exit"
  exit 2
fi

RC=0

echo_date "general setups"
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
setup muse
setup codetools
muse setup -1

echo_date "start root overlaps"
rootOverlaps.sh
RCT=${PIPESTATUS[0]}
echo_date "root overlaps return code $RCT"
LEGAL=$( grep CloseGeometry check | awk '{print $4 " " $5 " " $6 " " $7 " " $8}' )
ILLEGAL=$( grep illegal check | awk '{print $NF}' )
if [[ $RCT -eq 0 && $ILLEGAL -eq 0 ]]; then
  STATUS=OK
else
  STATUS=FAILED
  RCT=1
fi
echo "REPORT STATUS $STATUS root overlaps   $ILLEGAL overlaps in $LEGAL"
RC=$(($RC+$RCT))


echo_date "start transportOnly"
mu2e -n 5 -c Offline/Mu2eG4/fcl/transportOnly.fcl
RCT=$?
echo_date "transportOnly return code $RCT"
if [ $RCT -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS transportOnly"
RC=$(($RC+$RCT))


echo_date "start g4study2"
mu2e -n 5 -c Offline/Mu2eG4/g4study/g4study.fcl
RCT=$?
echo_date "g4study2 return code $RCT"
if [ $RCT -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS g4study2"
RC=$(($RC+$RCT))


echo_date "start g4test_03MT"
mu2e -n 20 -c Offline/Mu2eG4/fcl/g4test_03MT.fcl
RCT=$?
echo_date "g4test_03MT return code $RCT"
if [ $RCT -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS g4test_03MT"
RC=$(($RC+$RCT))


# 4/2021 MDC2020 production sequence

echo_date "start ceSteps"
mu2e -n 50 -c Production/Validation/ceSteps.fcl
RCT=$?
echo_date "ceSteps return code $RCT"
if [ $RCT -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS ceSteps"
RC=$(($RC+$RCT))


echo_date "start ceDigi"
# takes ceSteps as input
mu2e -c Production/Validation/ceDigi.fcl
RCT=$?
echo_date "ceDigi return code $RCT"
if [ $RCT -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS ceDigi"
RC=$(($RC+$RCT))

echo_date "start muDauSteps"
mu2e -n 6000 -c Production/Validation/muDauSteps.fcl
RCT=$?
echo_date "muDauSteps return code $RCT"
if [ $RCT -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS muDauSteps"
RC=$(($RC+$RCT))

echo_date "start ceMix"
# takes ceSteps and muDauSteps as input
mu2e -c Production/Validation/ceMix.fcl
RCT=$?
echo_date "ceMix return code $RCT"
if [ $RCT -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS ceMix"
RC=$(($RC+$RCT))

echo_date "start cosmicOffSpill"
# takes an explicit input file, in fcl
mu2e -n 20 -c Production/Validation/cosmicOffSpill.fcl
RCT=$?
echo_date "cosmicOffSpill return code $RCT"
if [ $RCT -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo "REPORT STATUS $STATUS cosmicOffSpill"
RC=$(($RC+$RCT))


echo_date "start geant surfaceCheck"
mu2e -c Offline/Mu2eG4/fcl/surfaceCheck.fcl
RCT=$?
echo_date "geant surfaceCheck return code $RCT"
LEGAL=$( grep 'Checking overlaps for volume' check | grep -c OK )
ILLEGAL=$( grep 'Checking overlaps for volume' check | grep -v OK | wc -l )
# print overlaps into the log
grep 'Checking overlaps for volume' check | grep -v OK
if [[ $RCT -eq 0 && $LEGAL -gt 0 && $ILLEGAL -eq 0 ]]; then
  STATUS=OK
else
  STATUS=FAILED
  RCT=1
fi
echo "REPORT STATUS $STATUS geant surfaceCheck   $ILLEGAL overlaps in $LEGAL"
RC=$(($RC+$RCT))


if [ $RC -eq 0 ]; then
  STATUS=OK
else
  STATUS=FAILED
fi
echo_date "check total return code $RC"
echo "REPORT STATUS $STATUS check"

exit $RC
