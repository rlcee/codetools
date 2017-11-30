#!/bin/bash
#
# build a tagged version of BTrk in Jenkins system
# the following are defined by the project:
# export BUILDTYPE=prof
# export label=SLF6
# the following are defined as jenkins project parameters
# export PACKAGE_VERSION=v1_02_03
# export COMPILER=e14
# to run locally, define these in the environment first
#


OS=`echo $label | tr "[A-Z]" "[a-z]"`

echo "[`date`] start $PACKAGE_VERSION $COMPILER $BUILDTYPE $OS"
echo "[`date`] PWD"
pwd
echo "[`date`] directories"
rm -rf BTrk build prod
mkdir -p build
mkdir -p prod
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

