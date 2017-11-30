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
RCTOT=0

echo "[`date`] start $PACKAGE_VERSION $COMPILER $BUILDTYPE $OS"
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
RCTOT=$(($RCTOT+$RC))

echo "[`date`] checkout"
cd mu2e_artdaq-core
git checkout -b work $PACKAGE_VERSION

cat ups/product_deps | sed 's/e14:s50/e14:s58/g' > s.txt
cp s.txt ups/product_deps
rm s.txt

cd $LOCAL_DIR/build

FLAG="-p"
[ "$BUILDTYPE" == "debug" ] && FLAG="-d"
echo "[`date`] setup_for_development FLAG=$FLAG"
source ../mu2e_artdaq-core/ups/setup_for_development $FLAG
ups list -a artdaq_core

RC=$?
RCTOT=$(($RCTOT+$RC))

echo "[`date`] buildtool"
buildtool -i
RC=$?
RCTOT=$(($RCTOT+$RC))

echo "[`date`] buildtool RC=$RC"

PACKAGE_VERSION_DOT=`echo $PACKAGE_VERSION | sed -e 's/v//' -e 's/_/\./g' `

TBALL=mu2e_artdaq_core-${PACKAGE_VERSION_DOT}-${OS}-x86_64-${COMPILER}-${ART_VERSION}-${BUILDTYPE}.tar.bz2

tar -cj -C products -f $TBALL mu2e_artdaq_core
RC=$?
RCTOT=$(($RCTOT+$RC))
mv $TBALL copyBack

echo "[`date`] ls"
ls -l *

exit $RCTOT

************************************************************




# Environment
setup mu2e
export CETPKG_INSTALL=~/products  # where to install new products .upsfiles needs to be there
export CETPKG_J=60                           # max parallelism in build


# Make top level working directory, clone source and checkout tag
mkdir mu2e_artdaq_core
cd mu2e_artdaq_core
git clone http://cdcvs.fnal.gov/projects/mu2e-artdaq-core
cd mu2e_artdaq_core
git checkout -b v1_07_08_build v1_07_08


# Make working area and setup environment
cd ..
mkdir build_prof
cd build_prof
source ../mu2e-artdaq-core/ups/setup_for_development -p   # -p is for prof

#
buildtool -i

1) After setup_for_development there is a ton of output. There should be
    no errors between the lines:
----------- check this block for errors -----------------------
————————————————————————————————

2) A successful buildtool ends in:
------------------------------------
INFO: Stage install / package successful.
------------------------------------

3) To make the debug build, log out, log in, follow the above but replace prof
     with debug in 3 places

mkdir build_debug
cd build_debug
source ../mu2e-artdaq-core/ups/setup_for_development -d   # -d is for debug
************************************************************

export LOCAL_DIR=$PWD

echo "[`date`] ls of local dir"
ls -al
echo "[`date`] source products common"
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
echo "[`date`] setup mu2e"
setup mu2e
echo "[`date`] setup experimentla mu2e setup script "
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh 

echo "[`date`] printenv after setup"
printenv

echo "[`date`] clone BTrk"
git clone https://github.com/KFTrack/BTrk.git
cd BTrk
echo "[`date`] checkout BTrk $PACKAGE_VERSION"
git checkout -b work $PACKAGE_VERSION
cd $LOCAL_DIR/build
echo "[`date`] newBuild $BUILDTYPE"
source $LOCAL_DIR/BTrk/scripts/newBuild.sh $BUILDTYPE
echo "[`date`] setup"
source setup.sh
echo "[`date`] scons"
scons -j 10
RC=$?
echo "[`date`] scons RC=$RC"

export PRODUCTS_INSTALL=$LOCAL_DIR/prod
source $LOCAL_DIR/BTrk/scripts/install.sh

cd $LOCAL_DIR

PACKAGE_VERSION_DOT=`echo $PACKAGE_VERSION | sed -e 's/v//' -e 's/_/\./g' `

TBALL=BTrk-${PACKAGE_VERSION_DOT}-${OS}-x86_64-${COMPILER}-${BUILDTYPE}.tar.bz2

tar -cj -C prod -f $TBALL BTrk
mv $TBALL copyBack

echo "[`date`] ls"
ls -l *

exit $RC

