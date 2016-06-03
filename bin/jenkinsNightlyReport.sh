# /bin/bash
#
# pull the nightly offline build products from jenkins server
# and do validation comparisons and send a report
# run by a daily cron
#
cd ~/cron/val

NDIR=/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/nightlyBuild
FDIR=/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/val/files
PDIR=/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/val/plots
ARTIFACT=https://buildmaster.fnal.gov/job/mu2e-offline-nightly/label=SLF6/lastBuild/artifact/copyBack
DATE=`date +"%Y-%m-%d"`
FN=nightly-build-${DATE}.txt
echo "[`date`] wget $ARTIFACT/$FN"
wget -q "$ARTIFACT/$FN"
RC=$?
echo RC=$RC
echo "FN=$FN"
ls -l $FN
if [ ! -r "$FN" ]; then
  echo "[`date`] No build report found " > $FN
  echo "[`date`] ERROR - could not wget $ARTIFACT/$FN"
fi
TODAYTOTRC="`cat $FN | grep "Total" | awk -F= '{print $2}'`"
[ -z "$TODAYTOTRC" ] && TODAYTOTRC="-"

LOG=nightly-log-${DATE}.log
echo "[`date`] wget $LOG"
wget -q "$ARTIFACT/$LOG"
if [ ! -r "$LOG" ]; then
  echo "[`date`] No build log found " > $LOG
  echo "[`date`] ERROR - could not wget $ARTIFACT/$LOG"
fi
cp $LOG $NDIR
rm -f $LOG


# setup code for comparison
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
setup mu2e
OVER=`ls -1 /cvmfs/mu2e.opensciencegrid.org/Offline | tail -1`
echo "setting up offline $OVER"
source /cvmfs/mu2e.opensciencegrid.org/Offline/$OVER/SLF6/prof/Offline/setup.sh
VVER=`ups list -aK+ validation | awk '{print $2}' | tr '"' ' ' | sort | tail -1`
echo "setting up validation $VVER"
setup validation $VVER
#  setup validation v0_00_01

#
# set up for validation plots
#
VAL=val-genReco-5000-nightly_${DATE}-0.root
echo "[`date`] wget $ARTIFACT/$VAL"
wget -q "$ARTIFACT/$VAL"
RC=$?
if [ ! -r $VAL ]; then
  echo "[`date`] ERROR - could not wget $ARTIFACT/$VAL"
fi
VALRC="-"

#
# Process validation plots
#

rm -f summary.txt

if [ -r $VAL ]; then

  # find last version
  VAL0=`ls -tr $FDIR/val-genReco-5000-nightly* | grep -v $DATE | tail -1`
  VAL0=`basename $VAL0`
  cp $FDIR/$VAL0 .

  echo "" >> summary.txt
  echo "" >> summary.txt
  echo " >>>>>>>>>>>>>>>>>  validation plots <<<<<<<<<<<<<<< " >> summary.txt
  echo "" >> summary.txt
  echo "Will compare:"  | tee -a summary.txt
  echo $VAL | tee -a summary.txt
  echo $VAL0 | tee -a summary.txt

  # make text comparison
  # -s summary -r report -w filespec
  valCompare -s $VAL0 $VAL > temp.txt
  echo "" >> summary.txt
  cat temp.txt >> summary.txt
  echo "" >> summary.txt
  valCompare -r $VAL0 $VAL >> summary.txt

  NT=`cat temp.txt | grep "Compared" | awk '{print $1}'`
  [ -z "$NT" ] && NT=0
  NP=`cat temp.txt | grep "had perfect match" | awk '{print $1}'`
  [ -z "$NP" ] && NP=0
  NF=`cat temp.txt | grep "failed loose comparison" | awk '{print $1}'`
  [ $NT -eq 0 ] && NF=999
  echo "[`date`] $NF validation plots failed loose comparison to yesterday" >> $FN
  VALRC=1
  [ $NF -eq 0 ] && VALRC=0

  # make web page
  mkdir -p $PDIR/nightly-${DATE}
  valCompare -w $PDIR/nightly-${DATE}/val.html $VAL0 $VAL 2>&1 | grep -v Info

  # keep the validation files
  cp $VAL $FDIR

else
  echo "ERROR - validation file not found"
fi
rm -f $VAL0
mv $VAL val.root
echo "VALRC=$VALRC"


#
# set up for CutAndCount plots
#
CAC=candc-nightly_${DATE}-0.root
echo "[`date`] wget $ARTIFACT/$CAC"
wget -q "$ARTIFACT/$CAC"
RC=$?
if [ ! -r $CAC ]; then
  echo "[`date`] ERROR - could not wget $ARTIFACT/$CAC"
fi
CACRC="-"

#
# Process CutAndCount plots
#


if [ -r $CAC ]; then

  # find last version
  CAC0=`ls -tr $FDIR/candc-nightly_* | grep -v $DATE | tail -1`
  CAC0=`basename $CAC0`
  cp $FDIR/$CAC0 .

  echo "" >> summary.txt
  echo "" >> summary.txt
  echo " >>>>>>>>>>>>>>>>>  CutAndCount plots <<<<<<<<<<<<<<< " >> summary.txt
  echo "" >> summary.txt
  echo "Will compare:"  | tee -a summary.txt
  echo $CAC | tee -a summary.txt
  echo $CAC0 | tee -a summary.txt

  # make text comparison
  valCompare -s $CAC0 $CAC > temp.txt
  echo "" >> summary.txt
  cat temp.txt >> summary.txt
  echo "" >> summary.txt
  valCompare -r $CAC0 $CAC >> summary.txt

  NT=`cat temp.txt | grep "Compared" | awk '{print $1}'`
  [ -z "$NT" ] && NT=0
  NP=`cat temp.txt | grep "had perfect match" | awk '{print $1}'`
  [ -z "$NP" ] && NP=0
  NF=`cat temp.txt | grep "failed loose comparison" | awk '{print $1}'`
  [ $NT -eq 0 ] && NF=999
  echo "[`date`] $NF CutAndCount plots failed loose comparison to yesterday" >> $FN
  CACRC=1
  [ $NF -eq 0 ] && CACRC=0


  # make web page
  mkdir -p $PDIR/candc-${DATE}
  valCompare -w $PDIR/candc-${DATE}/cac.html $CAC0 $CAC 2>&1 | grep -v Info

  # keep the validation files
  cp $CAC $FDIR

else
  echo "ERROR - CutAndCount file not found"
fi
rm -f $CAC0
mv $CAC cac.root
echo "CACRC=$CACRC"

# add detailed summaries ot tail of report
cat summary.txt >> $FN


#
#  finish up the summary report, send mail
#

cp $FN $NDIR
mv $FN nightly.txt

echo >> nightly.txt
echo "All logs and validation plots can be found at:" >> nightly.txt
echo "http://mu2e.fnal.gov/atwork/computing/ops/nightlyBuild/nightly.shtml" >> nightly.txt
echo >> nightly.txt


cat nightly.txt | mail -s "Nightly build, status=$TODAYTOTRC/$VALRC/$CACRC" \
rlc@fnal.gov,genser@fnal.gov,kutschke@fnal.gov,david.brown@louisville.edu,gandr@fnal.gov
#rlc@fnal.gov


#
# construct the summary web page
#

cd $NDIR
# the earliest record available
STOPDATE=`ls -r nightly*.txt | tail -1 | cut -c 15-24`
TT=`mktemp`
cat head.shtml > $TT
N=0
DD=$DATE
echo "start loop $DD $STOPDATE"
while [ "$DD" != "$STOPDATE" ]
do

   echo "Starting date $DD"

  LT="-"
  VT="-"
  CT="-"
  
  FF="nightly-build-${DD}.txt"

  LF=nightly-log-${DD}.log
  if [ -r $LF ]; then
    LT="<a href=\"$LF\">log</a>"
  fi

  VF="../val/plots/nightly-$DD/val.html"
  if [ -r $VF ]; then
    VT="<a href=\"$VF\">plots</a>"
  fi

  CF="../val/plots/candc-$DD/cac.html"
  if [ -r $CF ]; then
    CT="<a href=\"$CF\">plots</a>"
  fi

  ST="<a href=\"$FF\">summary</a>"
  TOTRC="`cat $FF | grep "Total" | awk -F= '{print $2}'`"
  [ -z "$TOTRC" ] && TOTRC="-"
  VALRC="`cat $FF | grep "validation plots failed" | awk '{print $7}'`"
  [ -z "$VALRC" ] && VALRC="-"
  CACRC="`cat $FF | grep "CutAndCount plots failed" | awk '{print $7}'`"
  [ -z "$CACRC" ] && CACRC="-"

  echo "<TR> <TD> $DD </TD> <TD> $TOTRC </TD> <TD> $LT </TD> <TD> $ST </TD> <TD> $VALRC </TD> <TD> $VT </TD> <TD> $CACRC </TD> <TD> $CT </TD> </TR>" >> $TT
  N=$(($N + 1))
  DD=`date -d "-$N days" +"%Y-%m-%d"`

done


cat tail.shtml >> $TT
cp $TT nightly.shtml

rm -f $TT

exit 0
