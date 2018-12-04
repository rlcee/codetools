#! /bin/bash
#
#
# expects:
# VALJOB_RELEASE=/pnfs/mu2e/resilient/users/mu2epro/nightly/date.tgz
# VALJOB_FCL=Validation/fcl/potSim.fcl
# VALJOB_NEV=500
# VALJOB_LABEL=potSim
# VALJOB_OUTDIR=/pnfs/mu2e/persistent/users/mu2epro/valjob/2017/10/06/potSim
# VALJOB_SEEDS=yes/no
# VALJOB_WATCHDOG=yes/no
# -f seeds.txt

tee_date() {
echo "[$(date)] $*" 
echo "[$(date)] $*" 1>&2
}

# $1 =time limit in s
# outdir assumed: $VALJOB_OUTDIR/dog
# ifdh assumed setup
watchdog() {
  local DD=$VALJOB_OUTDIR/dog 
  local TL=$1
  if [ -z "$DD"  ]; then
    TL=$((8*3600))
  fi

  local T0=$( date +%s )
  local DT=0
  local FN="watchdog"
  local PP=$( printf "%04d" $PROCESS )
  while [ $DT -lt $TL ];
  do
    sleep 600

    FN=watchdog.${PP}_$(date +%Y_%m_%d-%H_%M)

    echo "************************************************* ps" >> $FN
    ps -fwww f >> $FN
    echo "************************************************* top" >> $FN
    top -n 1 -b >> $FN
    echo "************************************************* ls" >> $FN
    ls -l >> $FN
    echo "************************************************* OUT log" >> $FN
    cat jsb_tmp/JOBSUB_LOG_FILE >> $FN
    echo "************************************************* ERR log" >> $FN
    cat jsb_tmp/JOBSUB_ERR_FILE >> $FN

    ifdh cp $FN $DD/$FN
   
    DT=$(( $( date +%s ) - $T0 ))
  done
  echo "watchdog exiting on time limit $TL"
  

}


initialize() {
  ## move input files to cwd
  #find $CONDOR_DIR_INPUT -type f -exec mv {} . \;
  
  tee_date "setup"
  source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
  source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
  setup ifdhc
  # if a local recovery job, need to add voms proxy
  [ -r $HOME/bin/authentication.sh ] && source $HOME/bin/authentication.sh
 
  if [ -n "$VALJOB_TARBALL" ]; then
    tee_date "copy in tarball $VALJOB_TARBALL"
    ifdh cp $VALJOB_TARBALL ./tball.tgz
    RC=$?
    tee_date "tarball copy return code $RC"
    if [ $RC -ne 0 ]; then
      tee_date "ERROR exit copy tarball $RC"
      return $RC
    fi
    
    tee_date "unwind tarball"
    tar -xzf tball.tgz
    RC=$?
    tee_date "tarball unwind return code $RC"
    if [ $RC -ne 0 ]; then
      tee_date "ERROR exit unwind tarball $RC"
      return $RC
    fi
  else
    tee_date "no tarball, assuming Offline exists"
    if [ ! -d Offline ]; then
      tee_date "ERROR no tarball or Offline directory"
      return 1
    fi
  fi

  tee_date "setup"
  source Offline/setup.sh
  
  tee_date "printenv"
  printenv
  
  tee_date "model name"
  cat /proc/cpuinfo | grep "model name" | head -1

  tee_date "ls start"
  ls -l
  
  NUMBER=$(printf "%02d" $PROCESS )
  LABEL=$(printf "%s_%02d" $VALJOB_LABEL $PROCESS )

  return 0
}

#
# exe
#
exe() {
  TIME=`date +%s`
  cp Offline/$VALJOB_FCL ./local.fcl
  
  if [ "$VALJOB_SEEDS" != "no" ]; then
    export VALJOB_SEED=`cat Offline/seeds.txt | awk -v n=$PROCESS '{if(NR==(n+1)) print $1}'`
    echo "services.SeedService.baseSeed: $VALJOB_SEED" >> local.fcl
  fi

  if [ "$VALJOB_INPUT" != "NULL" ]; then
    echo "source.fileNames : [ " >> local.fcl
    if [ "$LOCALJOB" ]; then
	cat Offline/$VALJOB_INPUT | \
	    awk -v n=$VALJOB_NINPUT -v i=$PROCESS 'BEGIN{is=i*n;ie=(i+1)*n}{xend=",";if(NR==ie-1) xend="";if(NR>=is && NR<ie) print "\"" $0 "\"" xend}' >> local.fcl
	echo "                   ]" >> local.fcl
    else
	cat Offline/$VALJOB_INPUT | \
	    awk -v n=$VALJOB_NINPUT -v i=$PROCESS 'BEGIN{is=i*n;ie=(i+1)*n}{xend=",";if(NR==ie-1) xend="";if(NR>=is && NR<ie) print "\"" $0 "\"" xend}' | \
	    sed 's|/pnfs|xroot://fndca1.fnal.gov/pnfs/fnal.gov/usr|' >> local.fcl
	echo "                   ]" >> local.fcl
    fi
  fi

  NEV=""
  [ $VALJOB_NEV -gt 0 ] && NEV=" -n $VALJOB_NEV "
  
  /cvmfs/mu2e.opensciencegrid.org/bin/SLF6/mu2e_time \
    mu2e $NEV -c ./local.fcl \
    -o ${LABEL}.art -T ${LABEL}.root
  RC=$?
  tee_date "exe $RC"
  
  DT=$((`date +%s`-$TIME))
  tee_date "time exe $DT"

  if [ $RC -ne 0 ]; then
    tee_date "ERROR exit exe $RC"
    return $RC
  fi

  return 0
}

#
# validation exe
#
validation() {
  TIME=`date +%s`
  
  if [ ! -f ${LABEL}.art ]; then
    tee_date "no art file for validation"
    return 1
  fi

  /cvmfs/mu2e.opensciencegrid.org/bin/SLF6/mu2e_time \
    mu2e -s ${LABEL}.art -c Validation/fcl/val.fcl -T val_${LABEL}.root

  RC=$?
  tee_date "val $RC"
  
  DT=$((`date +%s`-$TIME))
  tee_date "time val $DT"

  if [ $RC -ne 0 ]; then
    tee_date "ERROR exit val $RC"
    return $RC
  fi
  
  return 0
}
#
# output
#

mkoutdir() {
  if [ "$LOCALJOB" ]; then
    mkdir -p $OUTDIR
    RC=$?
  else
    ifdh mkdir $OUTDIR
    RC=$?
  fi
  tee_date "mkoutdir $OUTDIR $RC"
  if [ $RC -ne 0 ]; then
    tee_date "ERROR mkoutdir $RC"
    return $RC
  fi
  return 0
}

transfer() {
  
  RC_TOT=0
  for FILE in $*
  do

    if [ -r "$FILE" ]; then

      if [ "$LOCALJOB" ]; then
	  cp ./$FILE $OUTDIR/$FILE
	  RC=$?
      else
	  ifdh cp ./$FILE $OUTDIR/$FILE
	  RC=$?
      fi
      
      RC=$?
      tee_date "cp ./$FILE $OUTDIR/$FILE $RC"
      
      if [ $RC -ne 0 ]; then
	  tee_date "ERROR ifdh cp $RC"
	  RC_TOT=$RC
      fi

    else

      tee_date "transfer failed: $FILE not found"

    fi

  done
  return $RC_TOT
}

output() {
  local RC_JOB=$1
  tee_date "output starting with RC_JOB $RC_JOB"

  TIME=`date +%s`
  tee_date "ls end"
  ls -l

  OUTDIR=${VALJOB_OUTDIR}/val
  #mkoutdir
  transfer  val_${LABEL}.root

  OUTDIR=${VALJOB_OUTDIR}/art
  #mkoutdir
  transfer  ${LABEL}.art  ${LABEL}.root

  tee_date "finished data transfer"
  DT=$((`date +%s`-$TIME))
  tee_date "time transfer $DT"
  
  if [ "$LOCALJOB" ]; then
    cp log ${LABEL}.log
  else
    cat jsb_tmp/JOBSUB_LOG_FILE > ${LABEL}.log
    echo "************************************************* ERR log" >> ${LABEL}.log
    cat jsb_tmp/JOBSUB_ERR_FILE >> ${LABEL}.log
  fi
  
  OUTDIR=${VALJOB_OUTDIR}/log
  #mkoutdir
  transfer  ${LABEL}.log

  if [ "$LOCALJOB" ]; then
      rm *.art
  fi

  tee_date "exit final"
  exit $RC
}


#
# main
#
LOCALJOB=""
[ -z "$GRID_USER" ] && LOCALJOB="YES"
tee_date "LOCALJOB=$LOCALJOB"

initialize
RC=$?
[ $RC -ne 0 ] && output $RC

if [[ "$VALJOB_WATCHDOG" == "yes" && "$LOCALJOB" == "" ]]; then
  # run watchdog for 4h
  watchdog 28800 &
fi

exe
RC=$?
[ $RC -ne 0 ] && output $RC

validation
RC=$?
[ $RC -ne 0 ] && output $RC

output 0
