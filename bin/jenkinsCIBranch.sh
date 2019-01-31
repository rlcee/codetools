#!/bin/bash
#
# expects in the environment:
# label=SLF6 or 7
# BUILDTYPE=prof or debug
# GIT_BRANCH=origin/master (or other branch)
#

initialize() {
  echo "[$(date)] GIT_BRANCH=$GIT_BRANCH"
  echo "[$(date)] printenv"
  printenv
  echo "[$(date)] df -h"
  df -h
  echo "[$(date)] quota"
  quota -v
  echo "[$(date)] PWD"
  pwd
  echo "[$(date)] ls of local dir"
  ls -al
  echo "[$(date)] cpuinfo"
  cat /proc/cpuinfo | head -30

  local ARCH=$( cat /proc/cpuinfo  | grep vendor_id | \
      tail -1 | awk '{print $NF}')
  local NPROC=$( cat /proc/cpuinfo  | grep processor | \
      tail -1 | awk '{print $NF}')
  echo "[$(date)] architecture $ARCH"
  echo "[$(date)] number of processors $NPROC"

  mkdir -p copyBack

  return 0
}

#
# checkout the main repo
#
getCode() {

    echo "[$(date)] clone"
  # pull the main repo
    if ! git clone ssh://p-mu2eofflinesoftwaremu2eoffline@cdcvs.fnal.gov/cvs/projects/mu2eofflinesoftwaremu2eoffline/Offline.git ; then
	echo "[$(date)] failed to clone"
	return 1
    fi
}

#
# buildBranch with BRANCH=brachName
# cleanup Offline, checkout this branch, see if this hash
# has already has been put on cvmfs, if not, build it and make a tarball
# defining this function with "()" causes it to run in a subshell
# to allow multiple setups in one job
#
buildBranch() (
    if ! cd Offline ; then 
	echo "[$(date)] could not cd Offline"
	cd $BUILDTOP
	return 1
    fi
    
  # define this potential build
    if ! git checkout $BRANCH ; then
	echo "[$(date)][$BRANCH] could not checkout branch $branch"
	cd $BUILDTOP
	return 2
    fi
    local HASH=$( git rev-parse HEAD | cut -c 1-8 )
    if [ -z "$HASH" ] ; then
	echo "[$(date)][$BRANCH] could not find hash"
	cd $BUILDTOP
	return 3
    fi
    local DATE=$( git show $HASH | grep Date: | head -1 | \
        awk '{print $2" "$3" "$4" "$5" "}' )
    local DATESTR=$( date -d "$DATE" +%Y_%m_%d_%H_%M)
    if [[ -z "$DATE" || -z "$DATESTR" ]] ; then
	echo "[$(date)][$BRANCH] could not parse branch date"
	cd $BUILDTOP
	return 4
    fi
    local BUILD=$DATESTR_$HASH
    
  # see if this hash is already built
    local TDIR=$BASECDIR/$BRANCH/$BUILD
    if [ -d $TDIR ]; then
	echo "[$(date)][$BRANCH] is up to date at build $BUILD"
	cd $BUILDTOP
	return 0
    fi
    
  # needs to be built
    echo "[$(date)][$BRANCH] start build for hash $HASH"
    rm -f *.log *.root *.txt
    if ! ./buildopts --build=$BUILDTYPE ; then
	echo "[$(date)][$BRANCH] buildopts failed with BUILDTYPE=$BUILDTYPE"
	cd $BUILDTOP
	return 5
    fi
    if ! source setup.sh ; then
	echo "[$(date)][$BRANCH] buildopts failed setup.sh"
	cd $BUILDTOP
	return 6
    fi

    if ! scons -c -j 16 >& clean.log ; then
	echo "[$(date)][$BRANCH] failed to run scons -c"
	cat clean.log
	cd $BUILDTOP
	return 7
    fi

    #local SHORT=lib/libmu2e_Validation_root.so
    local SHORT=
    if ! scons -j 16 $SHORT >& build.log ; then
	echo "[$(date)][$BRANCH] failed to run scons build"
	cat build.log
	cd $BUILDTOP
	return 8
    fi
    
    echo "[$(date)][$BRANCH] start deps"
  # create deps
    if [ ! -x bin/deps ]; then
	echo "[$(date)][$BRANCH] did not find deps"      
    else
	scons -Q --tree=prune | deps -i > deps.txt
	local N=$( cat deps.txt | grep HDR | \
	    awk 'BEGIN{N=0}{if (NF>2) N=N+1}END{print N}' )
	echo "[$(date)][$BRANCH] found $N deps"      
    fi
    
  # make sure .git is packed
    git repack -d -l

  # cleanup
    echo "[$(date)][$BRANCH] run cleanup"
    rm -rf tmp
    rm -f .sconsign.dblite
    find . -name "*.os" -delete
    find . -name "*.o"  -delete
    
  # now make a tarball
    cd $BUILDTOP
    local FDIR=$BRANCH/$BUILD/$LABEL/$BUILDTYPE
    local TBALL=copyBack/${BRANCH}+${BUILD}+${LABEL}+${BUILDTYPE}.tgz
    mkdir -p $FDIR
    ln -s ../../../../Offline $FDIR/Offline
    mv Offline/*.log $FDIR
    mv Offline/deps.txt $FDIR
    
    echo "[$(date)][$BRANCH] run tarball"  
    if ! tar -czhf $TBALL $BRANCH ; then
	echo "[$(date)][$BRANCH] failed to run tar"
	return 9
    fi

    [ -d "$BRANCH" ] && rm -rf $BRANCH
    
    cd $BUILDTOP
    return 0

)



export BUILDTOP=$PWD
export BASECDIR=/cvmfs/mu2e-development.opensciencegrid.org/CIBranches
export LABEL=$label

# print info, check dirs
initialize

# clone and set list of branches in BRANCHES
getCode
RC=$?
[ $RC -ne 0 ] && exit $RC

export BRANCH=$( echo $GIT_BRANCH | awk -F/ '{print $NF}' )
buildBranch
RC=$?

exit $RC
