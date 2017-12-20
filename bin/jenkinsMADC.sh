#!/bin/bash
#
# build a tagged version of mu2e_artdaq_core in Jenkins system
# the following are defined by the project:
# export BUILDTYPE=prof
# export label=SLF6
# the following are defined as jenkins project parameters
# export PACKAGE_VERSION=v1_02_00a
# export COMPILER=e14
# export ART_VERSION=s58
# to run locally, define these in the environment first
#


OS=`echo $label | tr "[A-Z]" "[a-z]"`

echo "[`date`] start $PACKAGE_VERSION $COMPILER $ART_VERSION $BUILDTYPE $OS"
echo "[`date`] PWD"
pwd
echo "[`date`] directories"
rm -rf mu2e_artdaq-core build products
mkdir -p build
mkdir -p products
export LOCAL_DIR=$PWD

echo "[`date`] ls of local dir"
ls -al *

echo "[`date`] source products common"
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
echo "[`date`] setup mu2e"
setup mu2e

echo "[`date`] rsync"
# where to install new products
export CETPKG_INSTALL=$LOCAL_DIR/products
# .upsfiles needs to be there
rsync -aur /cvmfs/mu2e.opensciencegrid.org/artexternals/.upsfiles $CETPKG_INSTALL
# max parallelism in build
export CETPKG_J=10

echo "[`date`] git clone"
# Make top level working directory, clone source and checkout tag
git clone http://cdcvs.fnal.gov/projects/mu2e_artdaq-core
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] checkout"
cd mu2e_artdaq-core
git checkout -b work $PACKAGE_VERSION

cd $LOCAL_DIR/build

FLAG="-p"
[ "$BUILDTYPE" == "debug" ] && FLAG="-d"
echo "[`date`] setup_for_development FLAG=$FLAG"
source ../mu2e_artdaq-core/ups/setup_for_development $FLAG ${COMPILER}:$ART_VERSION
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] buildtool"
buildtool -i
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] buildtool RC=$RC"

PACKAGE_VERSION_DOT=`echo $PACKAGE_VERSION | sed -e 's/v//' -e 's/_/\./g' `

TBALL=mu2e_artdaq_core-${PACKAGE_VERSION_DOT}-${OS}-x86_64-${COMPILER}-${ART_VERSION}-${BUILDTYPE}.tar.bz2

cd $LOCAL_DIR

tar -cj -C products -f $TBALL mu2e_artdaq_core
RC=$?
[ $RC -ne 0 ] && exit $RC

mv $TBALL copyBack

echo "[`date`] ls"
ls -l *

echo "[`date`] normal exit"

exit

