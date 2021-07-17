#! /bin/bash
#
# build the Offline code from a commit specification
# $1= the build work directory
# $2= output tarball full path
#

echo_date() {
echo "[$(date)] $*" 
}

echo_date "start build WORKDIR=$1 TBALL=$2"
echo_date "cd $1"
WORKDIR=$1
shift
if [ -z "$WORKDIR" ]; then
  echo "ERROR - no work dir provided - exit" 
  exit 1
fi
TBALL=$1
shift
if [ -z "$TBALL" ]; then
  echo "ERROR - no tarball file name provided - exit" 
  exit 2
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
setup muse

T0=$(date +%s)
echo_date "clone offline"
git clone -q https://github.com/mu2e/Offline
RC=$?
T1=$(date +%s)
DT_CLONE=$(($T1-$T0))
echo_date "clone return code $RC time $DT_CLONE s"
echo "REPORT TIME clone $DT_CLONE"
git clone -q https://github.com/mu2e/Production
RCP=$?
RC=$(($RC+$RCP))

if [ $RC -ne 0 ]; then
  echo "REPORT STATUS FAIL build"
  exit $RC
fi

echo_date "print commit"
git -C Offline show -q
git -C Offline rev-parse HEAD

echo_date "muse setup"
muse setup -1
muse status

echo_date "start build"
T0=$(date +%s)
muse build -j 20 --mu2eCompactPrint
RC=$?
T1=$(date +%s)
DT_BUILD=$(($T1-$T0))
echo_date "build return code $RC time $DT_BUILD s"
echo "REPORT TIME build $DT_BUILD"

if [ $RC -ne 0 ]; then
  echo "REPORT STATUS FAIL build"
  exit $RC
fi

echo_date "starting tarball"
T0=$(date +%s)
cp /mu2e/app/home/mu2epro/cron/val/seeds.txt .
cp /mu2e/app/home/mu2epro/cron/val/recoInputFiles.txt .

#tar --exclude="*.cc" --exclude="*.os" --exclude="$MUSE_BUILD_BASE/Offline/tmp/*" \
#   -czf code.tgz Offline build *.txt
TEMPBALL=$( muse tarball recoInputFiles.txt seeds.txt | grep "Tarball:" | awk '{print $2}' )

RC=$?
T1=$(date +%s)
DT_TAR=$(($T1-$T0))

echo_date "ls -l $TEMPBALL"
echo_date ls -l $TEMPBALL
ls -l $TEMPBALL
echo_date "tar return code $RC time $DT_TAR s"
echo "REPORT TIME tar $DT_TAR"

if [ $RC -ne 0 ]; then
  echo "REPORT STATUS FAIL build"
  exit $RC
fi

[ -f $TBALL ] && mv $TBALL ${TBALL}_$(date +%s)
echo_date "cp $TEMPBALL $TBALL"
echo_date cp $TEMPBALL $TBALL
cp $TEMPBALL $TBALL
RC=$?
ls -l $TBALL
echo_date "copy tarball $RC"

if [ $RC -ne 0 ]; then
  echo "REPORT FAIL build"
  exit $RC
fi

# keep from building up tarballs in muse temp area
rm -rf $(dirname $TEMPBALL)

#
# remove older tarballs
#
DD=$(dirname $TBALL)
N=$(ls -1 $DD/* | wc -l)
if [ $N -gt 10 ]; then
  NRM=$(($N-5))
  FILES=$( ls -1 $DD/* | head -$NRM )
  for FF in $FILES
  do
    echo_date "removing code tarball $FF"
    rm -f $FF
  done
fi

echo "REPORT STATUS OK build"

exit 0
