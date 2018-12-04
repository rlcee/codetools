#! /bin/bash
#
# build the code for nightly validation and run quick checks
# $1= the work directory
# $2= tarball full path
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

T0=$(date +%s)
echo_date "clone offline"
git clone -q http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline/Offline.git
RC=$?
T1=$(date +%s)
DT_CLONE=$(($T1-$T0))
echo_date "clone return code $RC time $DT_CLONE s"
echo "REPORT TIME clone $DT_CLONE"

if [ $RC -ne 0 ]; then
  echo "REPORT STATUS FAIL build"
  exit $RC
fi

echo_date "cd Offline"
cd Offline

echo_date "print commit"
git show -q
git rev-parse HEAD

echo_date "source setup"
source setup.sh

echo_date "start scons"
T0=$(date +%s)
scons -j 20
RC=$?
T1=$(date +%s)
DT_BUILD=$(($T1-$T0))
echo_date "scons return code $RC time $DT_BUILD s"
echo "REPORT TIME build $DT_BUILD"

if [ $RC -ne 0 ]; then
  echo "REPORT STATUS FAIL build"
  exit $RC
fi

echo_date "starting tarball"
T0=$(date +%s)
cp /mu2e/app/home/mu2epro/cron/val/seeds.txt .
cp /mu2e/app/home/mu2epro/cron/val/recoInputFiles.txt .
cd ..

tar --exclude="*.cc" --exclude="*.os" --exclude="Offline/tmp/*" \
   -czf code.tgz Offline

RC=$?
T1=$(date +%s)
DT_TAR=$(($T1-$T0))
ls -l code.tgz
echo_date "tar return code $RC time $DT_TAR s"
echo "REPORT TIME tar $DT_TAR"

if [ $RC -ne 0 ]; then
  echo "REPORT STATUS FAIL build"
  exit $RC
fi

[ -f $TBALL ] && mv $TBALL ${TBALL}_$(date +%s)
cp code.tgz $TBALL
RC=$?
ls -l $TBALL
echo_date "copy tarball $RC"

if [ $RC -ne 0 ]; then
  echo "REPORT FAIL build"
  exit $RC
fi

#
# remove older tarballs
#
DD=$(dirname $TBALL)
N=$(ls -1 $DD/* | wc -l)
if [ $N -gt 5 ]; then
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
