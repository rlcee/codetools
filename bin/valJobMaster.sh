#! /bin/bash
#
# run from cron, submit validation grid jobs, wait for them to finish,
#   collect output, do comparisons, write report
#

echo_date() {
echo "[$(date)] $*" 
}

define_surfaceCheck() {
    LABEL[$NPROJ]=surfaceCheck
    TARBALL[$NPROJ]=$TBALL
    FCL[$NPROJ]=Mu2eG4/fcl/surfaceCheck.fcl
    INPUT[$NPROJ]=NULL
    NINPUT[$NPROJ]=0
    NEV[$NPROJ]=1
    NJOB[$NPROJ]=1
    MEM[$NPROJ]=1900MB
    JOBID[$NPROJ]=none
    JID[$NPROJ]=0
    SEEDS[$NPROJ]=no
    WATCHDOG[$NPROJ]=no
    CHECK[$NPROJ]=overLaps
    STATUS[$NPROJ]="defined"
    CSTATUS[$NPROJ]="undefined"
    PLOTS[$I]="undefined"
    NPROJ=$(($NPROJ+1))
    return 0
}


define_potSim() {
    LABEL[$NPROJ]=potSim
    TARBALL[$NPROJ]=$TBALL
    FCL[$NPROJ]=Validation/fcl/potSim.fcl
    INPUT[$NPROJ]=NULL
    NINPUT[$NPROJ]=0
    NEV[$NPROJ]=500
    NJOB[$NPROJ]=20
    MEM[$NPROJ]=2500MB
    JOBID[$NPROJ]=none
    JID[$NPROJ]=0
    SEEDS[$NPROJ]=yes
    WATCHDOG[$NPROJ]=no
    CHECK[$NPROJ]=statPlots
    STATUS[$NPROJ]="defined"
    CSTATUS[$NPROJ]="undefined"
    PLOTS[$I]="undefined"
    NPROJ=$(($NPROJ+1))
    return 0
}

define_ceSimReco() {
    LABEL[$NPROJ]=ceSimReco
    TARBALL[$NPROJ]=$TBALL
    FCL[$NPROJ]=Validation/fcl/ceSimReco.fcl
    INPUT[$NPROJ]=NULL
    NINPUT[$NPROJ]=0
    NEV[$NPROJ]=5000
    NJOB[$NPROJ]=20
    MEM[$NPROJ]=3000MB
    JOBID[$NPROJ]=none
    JID[$NPROJ]=0
    SEEDS[$NPROJ]=yes
    WATCHDOG[$NPROJ]=no
    CHECK[$NPROJ]=statPlots
    CSTATUS[$NPROJ]="undefined"
    STATUS[$NPROJ]="defined"
    PLOTS[$I]="undefined"
    NPROJ=$(($NPROJ+1))
    return 0
}

define_cosmicSimReco() {
    LABEL[$NPROJ]=cosmicSimReco
    TARBALL[$NPROJ]=$TBALL
    FCL[$NPROJ]=Validation/fcl/cosmicSimReco.fcl
    INPUT[$NPROJ]=NULL
    NINPUT[$NPROJ]=0
    NEV[$NPROJ]=50000
    NJOB[$NPROJ]=20
    MEM[$NPROJ]=4GB
    JOBID[$NPROJ]=none
    JID[$NPROJ]=0
    SEEDS[$NPROJ]=yes
    WATCHDOG[$NPROJ]=no
    CHECK[$NPROJ]=statPlots
    STATUS[$NPROJ]="defined"
    CSTATUS[$NPROJ]="undefined"
    PLOTS[$I]="undefined"
    NPROJ=$(($NPROJ+1))
    return 0
}

define_reco() {
    LABEL[$NPROJ]=reco
    TARBALL[$NPROJ]=$TBALL
    FCL[$NPROJ]=Validation/fcl/reco.fcl
    INPUT[$NPROJ]=recoInputFiles.txt
    NINPUT[$NPROJ]=4
    NEV[$NPROJ]=999999
    NJOB[$NPROJ]=40
    MEM[$NPROJ]=1980MB
    JOBID[$NPROJ]=none
    JID[$NPROJ]=0
    SEEDS[$NPROJ]=no
    WATCHDOG[$NPROJ]=yes
    CHECK[$NPROJ]=statPlots
    STATUS[$NPROJ]="defined"
    CSTATUS[$NPROJ]="undefined"
    PLOTS[$I]="undefined"
    NPROJ=$(($NPROJ+1))
    return 0
}


#
# clone the repo and build on mu2ebuild01
#
build_code() {
    echo_date "Start build"
    if [ -z "$BUILD_DIR"  ]; then
	echo_date "build_code called but $BUILD_DIR not defined"
	return 1
    fi
    DD=$(dirname $BUILD_DIR)
    rm -rf $DD/05
    mv $DD/04 $DD/05
    mv $DD/03 $DD/04
    mv $DD/02 $DD/03
    mv $DD/01 $DD/02
    mv $DD/current $DD/01
    mkdir -p $BUILD_DIR

    ssh -n mu2ebuild01 "$HOME/cron/val/valJobBuild.sh $BUILD_DIR $TBALL >& $BUILD_DIR/build"
    RC=$? # this includes the tar command
    if [ $RC -ne 0 ]; then
      echo_date "ERROR in build $RC"
      tail -20 $BUILD_DIR/build
      echo "FAIL build" >> $REPORT
    else
      echo_date "Done build"
      echo "OK build" >> $REPORT
    fi
    grep REPORT $BUILD_DIR/build | sed 's/REPORT //' >> $WEBREPORT
    return $RC
}

#
# run several quick checks on the build
#
check_code() {
    echo_date "Start check"
    ssh -n mu2ebuild01 "/mu2e/app/home/mu2epro/cron/val/valJobCheck.sh $BUILD_DIR >& $BUILD_DIR/check"
    RC=$?
    if [ $RC -ne 0 ]; then
      echo_date "ERROR in check $RC"
      echo "FAIL check" >> $REPORT
    else
      echo_date "Check OK"
      echo "OK check" >> $REPORT
    fi

    grep "REPORT" $BUILD_DIR/check | grep STATUS | grep -v check | \
	sed 's/REPORT//' | sed 's/STATUS//' | \
	    awk '{print "  " $0}' | tee -a $REPORT

    grep REPORT $BUILD_DIR/check | sed 's/REPORT //' >> $WEBREPORT

    return $RC
}

#
#
#
submit_jobs() {

  local I=0
  while [ $I -lt $NPROJ ]
  do
    echo_date "start submit_job for ${LABEL[$I]}"
    rm -f jobsub.txt
    local VALJOB_OUTDIR=$OUTDIR/${LABEL[$I]}
    mkdir -p $VALJOB_OUTDIR/log
    mkdir -p $VALJOB_OUTDIR/art
    mkdir -p $VALJOB_OUTDIR/val
    if [ "${WATCHDOG[$I]}" == "yes" ]; then
      mkdir -p $VALJOB_OUTDIR/dog
    fi
    # change the name of the script so that monitoring is easier
    local SCRIPT="valJob_${LABEL[$I]}"
    cp valJobNode.sh $SCRIPT
  #  local SEED_STANZA=""
  #  if [ "${SEEDS[$I]}" != "no" ]; then
  #      SEED_STANZA=" -f $PWD/seeds.txt -e VALJOB_SEEDS=seeds.txt "
  #  fi
# 8/5/2020 removed OS=sl7, added two singularity lines
    CMD="jobsub_submit -Q "
    CMD="$CMD -N ${NJOB[$I]}  "
    CMD="$CMD --role=Production --subgroup=monitor "
    CMD="$CMD --resource-provides=usage_model=DEDICATED,OPPORTUNISTIC "
    CMD="$CMD  --memory=${MEM[$I]} --disk=30GB --expected-lifetime=4h "
    CMD="$CMD --append_condor_requirements='(TARGET.CpuFamily==6)' "
    CMD="$CMD --append_condor_requirements='(TARGET.HAS_SINGULARITY=?=true)' "
    CMD="$CMD --lines  '+SingularityImage=\"/cvmfs/singularity.opensciencegrid.org/fermilab/fnal-wn-sl7:latest\"' "
    CMD="$CMD -e VALJOB_TARBALL=${TARBALL[$I]} "
    CMD="$CMD -e VALJOB_FCL=${FCL[$I]} "
    CMD="$CMD -e VALJOB_INPUT=${INPUT[$I]} "
    CMD="$CMD -e VALJOB_NINPUT=${NINPUT[$I]} "
    CMD="$CMD -e VALJOB_LABEL=${LABEL[$I]} "
    CMD="$CMD -e VALJOB_SEEDS=${SEEDS[$I]} "
    CMD="$CMD -e VALJOB_WATCHDOG=${WATCHDOG[$I]} "
    CMD="$CMD -e VALJOB_OUTDIR=$VALJOB_OUTDIR "
    CMD="$CMD -e VALJOB_NEV=${NEV[$I]} "
    CMD="$CMD file://$PWD/$SCRIPT"
    echo $CMD
    $CMD >& jobsub.txt
    RC=$?
    rm -f $SCRIPT
    JOBID[$I]=`grep retrieve jobsub.txt | awk '{print $4}'`
    if [[ $RC -ne 0 || -z "${JOBID[$I]}" ]]; then
        echo "ERROR failed to submit ${LABEL[$I]}"
        cat jobsub.txt
        STATUS[$I]="ERRORSubmit"
        JID[$I]="0"
        return 1
    fi
    echo_date "Submitted ${LABEL[$I]} with ${JOBID[$I]}"
    # just the number
    JID[$I]=`echo ${JOBID[$I]} | awk -F. '{print $1}'`
    STATUS[$I]="submitted"
    I=$(($I+1))
  done
  return 0
}

#
# count how many of the jobs of a project are done
#
count_done() {
  local I=$1
  local DD=$OUTDIR/${LABEL[$I]}
  #NL=$( ls -1 $DD/log/*.log | wc -l )
  local NTEST=$( find $DD/val -name "*.root" | wc -l )
  local NV=0
  if [ $NTEST -gt 0 ]; then
    local NV=$( ls -l $DD/val/*.root | awk 'BEGIN{n=0}{if($5>10000) n=n+1}END{print n}' )
  fi
  echo $NV
  return
}

#
# run failed jobs locally
#
recover_jobs() {
  local I=$1
  echo_date "starting recovery for ${LABEL[$I]}"
  # kill the job, rely on watchdog for any info
  echo_date "removing JOBID ${JOBID[$I]}"
  TMPID=$( echo ${JOBID[$I]} | sed 's/\.0/\./' )
  echo_date "Trying jobsub_q --jobid=$TMPID --role=Production"
  jobsub_q --jobid=$TMPID --role=Production
  echo_date "Trying jobsub_rm --jobid=$TMPID --role=Production"
  jobsub_rm --jobid=$TMPID --role=Production

  local DD=$OUTDIR/${LABEL[$I]}
  local NMAX=${NJOB[$I]}
  local J=0
  local NREC=0
  echo_date "Starting recovery loop ${LABEL[$I]} NMAX=$NMAX"
  while [ $J -lt $NMAX ]
  do
    local TT=$( printf "%02d" $J )
    local TS=$( ls -1 $DD/val | grep $TT  ) 
    #BUG local SS=$( ls -1l $DD/val | grep $TT  | awk '{print $5}' ) 
    local SS=$( ls -1l $DD/val/$TS  | awk '{print $5}' ) 
    [ -z "$SS" ] && SS=0
    echo_date "    loop $J TT=$TT   TS=$TS  SS=$SS"
    if [[ -z "$TS" || $SS -lt 1000 ]]; then
      echo_date "recovery job ${LABEL[$I]} $TT"

      # remove any partial output files
      local OUTTMP=$DD/art/${LABEL[$I]}_${TT}.art
      if [ -f $OUTTMP ]; then
	  echo_date "rm failed job output file $OUTTMP"
	  rm -f $DD/art/${LABEL[$I]}_${TT}.art
	  rm -f $DD/art/${LABEL[$I]}_${TT}.root
	  rm -f $DD/val/val_${LABEL[$I]}_${TT}.root
      fi
      # if it crashed, there may be a useful log file
      if [ -f $DD/log/${LABEL[$I]}_${TT}.log ]; then
	  mv  $DD/log/${LABEL[$I]}_${TT}.log \
	      $DD/log/${LABEL[$I]}_${TT}.log_crashed
      fi

      NREC=$(( $NREC + 1 ))
      local RDIR=$BUILD_DIR/rec_${LABEL[$I]}_${TT}
      mkdir $RDIR
      local CMDF=$RDIR/rec.sh
      touch $CMDF
      chmod a+x $CMDF
      echo "#! /bin/bash " > $CMDF
      echo "export VALJOB_LABEL=${LABEL[$I]} " >> $CMDF
      echo "export PROCESS=$J " >> $CMDF
      echo "export VALJOB_FCL=${FCL[$I]} " >> $CMDF
      echo "export VALJOB_INPUT=${INPUT[$I]} " >> $CMDF
      echo "export VALJOB_NINPUT=${NINPUT[$I]} " >> $CMDF
      echo "export VALJOB_SEEDS=${SEEDS[$I]} " >> $CMDF
      echo "export VALJOB_WATCHDOG=no " >> $CMDF
      echo "export VALJOB_OUTDIR=$OUTDIR/${LABEL[$I]} " >> $CMDF
      echo "export VALJOB_NEV=${NEV[$I]} " >> $CMDF
      echo "cd $RDIR " >> $CMDF
      echo "ln -s ../Offline " >> $CMDF
      echo "/mu2e/app/home/mu2epro/cron/val/valJobNode.sh >& log" >> $CMDF
      ssh -n -f mu2ebuild01 "$CMDF"
    fi

    J=$(($J+1))
  done

  
  return
}

#
#
#
wait_jobs() {

  echo_date "waiting for jobs"

  TWAIT0=$( date +%s )
  # first, just wait until done, or up to 4h
  local MORE=yes
  while [[ $TWAIT -lt 14400 && "$MORE" == "yes" ]]
  do
    sleep 600
    echo_date "checking.."
    TWAIT=$(( $( date +%s ) -  $TWAIT0 ))
    MORE=no
    I=0
    while [ $I -lt $NPROJ ]
    do
      NDONE=$( count_done $I )
      NMISS=$((${NJOB[$I]} - $NDONE ))
      echo_date "check ${LABEL[$I]} $NMISS jobs missing"
      [ $NMISS -gt 0 ] && MORE=yes
      I=$(($I+1))
    done
  done


  echo_date "done waiting, check for needed recovery"  
  I=0
  REC=0
  while [ $I -lt $NPROJ ]
  do
    NDONE=$( count_done $I )
    NMISS=$(( ${NJOB[$I]} - $NDONE ))
    if [ $NMISS -eq 0 ]; then
      echo_date "grid ${LABEL[$I]} jobs completed"
    elif [ $NMISS -le 5 ]; then
      echo_date "grid ${LABEL[$I]} $NMISS jobs missing, try to recover"
      recover_jobs $I
      REC=1
    else
      echo_date "ERROR grid ${LABEL[$I]} $NMISS jobs missing - too many to recover"
    fi
    I=$(($I+1))
  done

  # if recoveries are running, wait for them
  if [ $REC -gt 0 ]; then
    sleep 6000
  fi

  I=0
  while [ $I -lt $NPROJ ]
  do
    NDONE=$( count_done $I )
    NMISS=$(( ${NJOB[$I]} - $NDONE ))
    if [ $NMISS -eq 0 ]; then
      echo_date "final ${LABEL[$I]} jobs completed"
      STATUS[$I]="complete"
    else
      echo_date "ERROR final ${LABEL[$I]} $NMISS jobs missing - failed"
      STATUS[$I]="failed"
    fi
    I=$(($I+1))
  done

  return 0
}

#
# analyze logs and return
# average median lowest highest
ana_numbers() {
  local TMP=$1
  local TMP2=$( mktemp )
  cat $TMP | sort -rn > $TMP2
  local XL=$( cat $TMP2 | head -1 | awk '{print int($1)}' )
  local XH=$( cat $TMP2 | tail -1 | awk '{print int($1)}' )
  local N=$( cat $TMP2 | wc -l )
  if [ $N -le 2 ]; then
    NN=1
  else
    NN=$(($N/2))
  fi
  local XM=$( cat $TMP2 | head -$NN | tail -1 | awk '{print int($1)}' )
  local XA=$( cat $TMP2 | awk 'BEGIN{n=0;x=0.0;}{x=x+$1;n=n+1}END{if(n==0) print 0; else print int(x/n);}' )
  rm -f $TMP2
  echo "$XA $XM $XL $XH"
}

#
#
#
ana_logs() {
  local I=$1
  local DD=$OUTDIR/${LABEL[$I]}/log
  local TMP=$( mktemp )
  for FF in $(ls -1 $DD/*)
  do
    grep "TimeReport CPU" $FF | head -1 | awk '{print $4}' >> $TMP
  done
  local CPU=$( ana_numbers $TMP ) 

  rm -f $TMP
  for FF in $(ls -1 $DD/*)
  do
    grep "TimeReport CPU" $FF | head -1 | awk '{print $7}' >> $TMP
  done
  local REAL=$( ana_numbers $TMP )

  rm -f $TMP
  for FF in $(ls -1 $DD/*)
  do
    grep "VmHWM" $FF | head -1 | awk '{print $7}' >> $TMP
  done
  local MEM=$( ana_numbers $TMP )
  echo "$CPU    $REAL    $MEM"
}

#
#
#
collect_summaries() {
  I=0
  while [ $I -lt $NPROJ ]
  do
    echo_date "checking ${LABEL[$I]} has status ${STATUS[$I]}"
    if [ "${STATUS[$I]}" == "complete" ]; then
      if [ "${CHECK[$I]}" == "overLaps" ]; then
        VOLCHECKG=`egrep 'Checking overlaps for volume' $OUTDIR/${LABEL[$I]}/log/*.log | grep OK | wc -l`
        VOLCHECKB=`egrep 'Checking overlaps for volume' $OUTDIR/${LABEL[$I]}/log/*.log  | grep -v OK | wc -l`
        echo "Volume checks:  OK=${VOLCHECKG},  not OK=$VOLCHECKB" | tee -a $REPORT
        egrep 'Checking overlaps for volume' $OUTDIR/${LABEL[$I]}/log/*.log | grep -v OK 
      elif [ "${CHECK[$I]}" == "statPlots" ]; then
        local OUTROOT=$OUTDIR/summary/${LABEL[$I]}.root
        [ -f "$OUTROOT" ] && mv $OUTROOT ${OUTROOT}_$(date +%s)
        hadd $OUTROOT $OUTDIR/${LABEL[$I]}/val/val*.root > /dev/null
        RC=$?
        if [ $RC -ne 0 ]; then
          STATUS[$I]="hadd_failed"
        fi
      fi
      local NUMBERS=$( ana_logs $I )
      echo "LOGTIME ${LABEL[$I]} $NUMBERS" >> $WEBREPORT
    else 
      echo_date "******* skipping check on ${LABEL[$I]}"
      echo "LOGTIME ${LABEL[$I]} " >> $WEBREPORT
    fi
    I=$(($I+1))
  done
  return 0
}

#
#
#
valcompare() {

  local I=0
  while [ $I -lt $NPROJ ]
  do
    if [ "${CHECK[$I]}" == "statPlots" ]; then
      if [ "${STATUS[$I]}" != "complete" ]; then
        echo_date "valcompare ${LABEL[$I]} had status ${STATUS[$I]}, skipping"
	# CSTATUS[$I] will remain undefined
	echo "MISSING ${LABEL[$I]}" >> $REPORT
	echo "GRIDS MISSING ${LABEL[$I]}" >> $WEBREPORT
      else
	echo_date "valcompare ${LABEL[$I]} had status ${STATUS[$I]}, comparing"
        local NVAL=$OUTDIR/summary/${LABEL[$I]}.root
        local OVAL=""
        local DAYS=0
        while [[ -z "$OVAL" && $DAYS -lt 20 ]]; do 
	  DAYS=$(($DAYS+1))
	  DTEST=$(date -d "- $DAYS day" +%Y/%m/%d)
	  OVAL=$BASE_DIR/$DTEST/summary/${LABEL[$I]}.root
          [ ! -f $OVAL ] && OVAL=""
        done
	if [ $DAYS -ge 20 ]; then
	  echo_date "valcompare did not find compariosn after checking $DAYS days"
	  echo "FAIL ${LABEL[$I]} did not find comparison" >> $REPORT
	  echo "GRIDS FAIL ${LABEL[$I]}" >> $WEBREPORT
	else
          echo_date "valcompare finds old val on $DTEST, $DAYS day(s) ago"
          local TMP=$( mktemp )
          valCompare -s $OVAL $NVAL > $TMP
          cat $TMP
          local NBAD=$(grep "failed loose comparison" $TMP | awk '{print $1}')
          [ -z "$NBAD" ] && NBAD=999
          local NSOSO1=$(grep "passed loose comparison, failed tight" $TMP | awk '{print $1}')
          [ -z "$NSOSO1" ] && NSOSO1=999
          local NSOSO2=$(grep "passed tight comparison, not perfect match" $TMP | awk '{print $1}')
          [ -z "$NSOSO2" ] && NSOSO2=999
	  local NSOSO=$(($NSOSO1+$NSOSO2))

          echo "valcompare results ${LABEL[$I]} NBAD $NBAD  NSOSO $NSOSO"
          rm -f $TMP
          CSTATUS[$I]=$NBAD
          if [ $NBAD -eq 0 ]; then
            echo "OK ${LABEL[$I]} plots matched from $DAYS day(s) ago" >> $REPORT
	    if [ $NSOSO -eq 0 ]; then
		echo "GRIDS PERFECT ${LABEL[$I]}" >> $WEBREPORT
	    else
		echo "GRIDS OK ${LABEL[$I]}" >> $WEBREPORT
	    fi
          else
            echo "FAIL ${LABEL[$I]} $NBAD plots failed match from $DAYS day(s) ago" >> $REPORT
            echo "GRIDS FAIL ${LABEL[$I]}" >> $WEBREPORT
          
            local PLOT_DIR=$WEB_DIR_DAY/${LABEL[$I]}
            mkdir -p $PLOT_DIR
            local PLOT_URI=$PLOT_DIR/result.html
            echo_date "making web pages"
            valCompare -w $PLOT_URI $OVAL $NVAL >& valJobTemp.log
            PLOTS[$I]=$PLOT_URI

          fi # NBAD
	fi # comparison found
      fi # COMPLETE
    fi # statPlot

    I=$(($I+1))
  done

}

#
#
#
colorByStat() {
    # no result
    COLOR=#deeaee
    if [ "$1" == "PERFECT" ]; then
	COLOR=#588c7e
    elif [ "$1" == "OK" ]; then
	COLOR=#79a397
    elif [ "$1" == "MISSING" ]; then
	COLOR=#fbefcc
    elif [ "$1" == "FAIL" ]; then
	COLOR=#c83349
    fi
}


#
#
#
nightlyweb() {

  echo_date "starting nightly web page"
  # at this point done with the web report, copy it to the web area
  cp $WEBREPORT $WEB_DIR_DAY
  local RC=$?
  if [ $RC -ne 0  ]; then
    echo "ERROR - could not write to web area "
    echo "WEBREPORT=$WEBREPORT WEB_DIR_DAY=$WEB_DIR_DAY"
    echo "ls of parent dir:"
    ls -l $WEB_DIR_DAY/..
    echo "df "
    df -h
  fi
  cp $REPORT $WEB_DIR_DAY
  cp $BUILD_DIR/build $WEB_DIR_DAY
  cp $BUILD_DIR/check $WEB_DIR_DAY

  local CPWD=$PWD
  cd $WEB_DIR
  local TF=temp.html
  cp head.html $TF
  # make a list of grid tests with results
  # this approach allows the list to evolve
  local LIST=$( cat 20??_??/??/valJobWeb.txt | grep GRIDS | \
         awk '{print $3}'  | sort | uniq )
  #echo_date "found tests $LIST"

  # make the column headings
  echo -n "<TR align=""center""><TD width=100>Date</TD><TD width=80>build</TD><TD width=80>tests</TD>" >> $TF
  for LL in $LIST
  do
	echo -n "<TD  width=120>$LL</TD>" >> $TF
  done
  echo "</TR>" >> $TF

  # process each day into a line in the table
  local DDS=$(find 2* -mindepth 1 -maxdepth 1 | sed -e 's|/||' -e 's|_||' | sort -r -n)
  for DD in $DDS
  do
    local DDF=$(echo $DD | cut -c 1-4)-$(echo $DD | cut -c 5-6)-$(echo $DD | cut -c 7-8)
    local DDR=$(echo $DD | cut -c 1-4)_$(echo $DD | cut -c 5-6)/$(echo $DD | cut -c 7-8)
    # date
    echo -n "<TR align=""center""><TD>$DDF</TD>" >> $TF
    
    # build
    STAT=$( grep build $DDR/valJobWeb.txt | grep STATUS | awk '{print $2}')
    [ -z "$STAT" ] && STAT="-"
    colorByStat "$STAT"
    if [ -r $DDR/build ]; then
        echo "<TD bgcolor=$COLOR><a href=$DDR/build>log</a></TD>" >> $TF
    else
        echo "<TD bgcolor=$COLOR>log</TD>" >> $TF
    fi
    
    # tests
    STAT=$( grep check $DDR/valJobWeb.txt | grep STATUS | awk '{print $2}')
    [ -z "$STAT" ] && STAT="-"
    colorByStat "$STAT"
    if [ -r $DDR/valJobReport.txt ]; then
        echo "<TD bgcolor=$COLOR><a href=$DDR/check>text</a></TD>" >> $TF
    else
        echo "<TD bgcolor=$COLOR> - </TD>" >> $TF
    fi
    
    # now loop over the list of grid job tests
    for LL in $LIST
    do
      STAT=$( grep $LL $DDR/valJobWeb.txt | grep GRIDS | awk '{print $2}')
      [ -z "$STAT" ] && STAT="-"
      colorByStat "$STAT"
      if [ -r $DDR/$LL/result.html ]; then
        echo "<TD bgcolor=$COLOR><a href=$DDR/$LL/result.html>plots</a></TD>" >> $TF
      else
        echo "<TD bgcolor=$COLOR> - </TD>" >> $TF
      fi
    done # loop over grid job tests
    
    # finish the row for this day
    echo "</TR>" >> $TF
	
  done # loop over days

  cat tail.html >> $TF
  mv nightly_3.html nightly_4.html
  mv nightly_2.html nightly_3.html
  mv nightly_1.html nightly_2.html
  mv nightly.html nightly_1.html
  mv $TF nightly.html
  cd $CPWD

  return 0
}

#
#
#
exit_proc() {
  local RC=$1
  local MESS="$2"
  echo_date "exit $RC $MESS"
  local OLOG=valJobMaster_$(date +%Y-%m-%d)
  [ -f $OLOG ] && OLOG=${OLOG}_$(date +%s)
  cp valJobMaster.log $OLOG
  cp valJobMaster.log $REPORT $WEBREPORT $OUTDIR/summary

  # cleanup daily log files
  find . -name "valJobMaster_20??-??-*" -ctime +10 -delete
  # remove older art files in dCache
  local JJ=30
  while [ $JJ -lt 35 ]; do
    local CLDD=$BASE_DIR/`date -d "-$JJ day" +%Y`/`date -d "-$JJ day" +%m`/`date -d "-$JJ day" +%d`
    if ls $CLDD/*/art > /dev/null 2>&1 ; then
      echo_date "cleanup art files for $CLDD"
      rm -f $CLDD/*/art/*.art
      rm -f $CLDD/*/art/*.root
      rmdir $CLDD/*/art
    fi
    JJ=$(($JJ+1))
  done

  # report
  echo "" >> $REPORT
  echo "http://mu2e.fnal.gov/atwork/computing/ops/val/valJob/nightly/nightly.html" >> $REPORT
  echo "" >> $REPORT
  local COMPLETE=COMPLETE
  [ -n "`grep MISSING $REPORT`" ] && COMPLETE="INCOMPLETE"
  local RESULT="SUCCESS"
  [ -n "`grep FAIL $REPORT`" ] && RESULT=FAIL
  cat $REPORT | mail -r valJob -s "valJob $COMPLETE and $RESULT" \
rlc@fnal.gov,genser@fnal.gov,kutschke@fnal.gov,dave_brown@lbl.gov,david.brown@louisville.edu,gandr@fnal.gov,murat@fnal.gov,gianipez@fnal.gov,echenard@fnal.gov,ehrlich@virginia.edu
#    rlc@fnal.gov
  exit $RC
}


#
#
#  Main
#
#

echo_date "start setups"
cd $HOME/cron/val
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
source $HOME/bin/authentication.sh
setup jobsub_client

# this will contain the mail report
REPORT=valJobReport.txt
rm -f $REPORT
# this will contain the web report
WEBREPORT=valJobWeb.txt
rm -f $WEBREPORT
# all output will be written here
BASE_DIR=/pnfs/mu2e/persistent/users/mu2epro/valjob
OUTDIR=$BASE_DIR/`date +%Y`/`date +%m`/`date +%d`
# the collected plots
mkdir -p $OUTDIR/summary
# the build location
BUILD_DIR=/mu2e/app/users/mu2epro/nightly/current
# tarball for submission to the grid
TBALL=/pnfs/mu2e/resilient/users/mu2epro/nightly/$(date +%Y-%m-%d).tgz
# the val comparison
WEB_DIR=/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/val/valJob/nightly
WEB_DIR_DAY=/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/val/valJob/nightly/$(date +%Y_%m/%d)
mkdir -p $WEB_DIR_DAY
RC=$?
if [ $RC -ne 0 ]; then
    echo "ERROR - could not make web dir WEB_DIR_DAY=$WEB_DIR_DAY RC=$RC"
    echo "ls of parent dir"
    ls -l $WEB_DIR_DAY/..
fi

# build the code from the head
build_code
RC=$?
# can't continue if the build fails
if [ $RC -ne 0 ]; then
  nightlyweb
  exit_proc 1 "build failed"
fi

# run quick tests
check_code
# don't stop on failure..

# setup the grid jobs
echo_date "define jobs"
NPROJ=0
define_ceSimReco
define_reco
define_cosmicSimReco
define_potSim
#define_surfaceCheck

echo_date "$NPROJ projects defined: ${LABEL[*]}"

# submit
klist
voms-proxy-info
submit_jobs

# wait for grid jobs
# and run recovery locally if needed
wait_jobs
RC=$?

# collect plots and check overlaps
# will need root to do concatenation

# temproraily setup explicity on 01 until it is also sl7
#source $BUILD_DIR/Offline/setup.sh
source /cvmfs/mu2e.opensciencegrid.org/Offline/v7_4_1/SLF6/prof/Offline/setup.sh

collect_summaries
RC=$?
valcompare
RC=$?
nightlyweb
RC=$?

# send summary
exit_proc 0 success

