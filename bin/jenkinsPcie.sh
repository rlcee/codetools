#!/bin/bash
#
# build a tagged version of mu2e_artdaq_core in Jenkins system
# the following are defined by the project:
# export BUILDTYPE=prof
# export label=SLF7
# the following are defined as jenkins project parameters
# export PACKAGE_VERSION=v2_02_02
# export COMPILER=e17
# to run locally, define these in the environment first
#


OS=`echo $label | tr "[A-Z]" "[a-z]"`

echo "[`date`] start $PACKAGE_VERSION $COMPILER $BUILDTYPE $OS "
echo "[`date`] PWD"
pwd
echo "[`date`] directories"
rm -rf pcie_linux_kernel_module build products
mkdir -p build
mkdir -p products
mkdir -p copyBack
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
git clone http://cdcvs.fnal.gov/projects/pcie_linux_kernel_module
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] checkout"
cd pcie_linux_kernel_module
git checkout -b work $PACKAGE_VERSION

cd $LOCAL_DIR/build

FLAG="-p"
[ "$BUILDTYPE" == "debug" ] && FLAG="-d"
echo "[`date`] setup_for_development FLAG=$FLAG"
source ../pcie_linux_kernel_module/ups/setup_for_development $FLAG ${COMPILER}
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] buildtool"
buildtool -i
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] buildtool RC=$RC"

PACKAGE_VERSION_DOT=`echo $PACKAGE_VERSION | sed -e 's/v//' -e 's/_/\./g' `

TBALL=pcie_linux_kernel_module-${PACKAGE_VERSION_DOT}-${OS}-x86_64-${COMPILER}-${BUILDTYPE}.tar.bz2

cd $LOCAL_DIR

tar -cj -C products -f $TBALL pcie_linux_kernel_module
RC=$?
[ $RC -ne 0 ] && exit $RC

mv $TBALL copyBack

echo "[`date`] ls"
ls -l *

echo "[`date`] normal exit"

exit

