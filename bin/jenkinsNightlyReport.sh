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
wget -q "$ARTIFACT/$FN"
if [ ! -r "$FN" ]; then
  echo "[`date`] No build report found " > $FN
fi
TODAYTOTRC="`cat $FN | grep "Total" | awk -F= '{print $2}'`"
[ -z "$TODAYTOTRC" ] && TODAYTOTRC="-"

LOG=nightly-log-${DATE}.log
wget -q "$ARTIFACT/$LOG"
if [ ! -r "$LOG" ]; then
  echo "[`date`] No build log found " > $LOG
fi
cp $LOG $NDIR
rm -f $LOG

VAL=val-genReco-5000-nightly_${DATE}-0.root
wget -q "$ARTIFACT/$VAL"

VALRC="-"
rm -f summary.txt

if [ -r $VAL ]; then

  # setup code for comparison
  source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
  setup mu2e
  OVER=`ls -1 /cvmfs/mu2e.opensciencegrid.org/Offline | tail -1`
  echo "setting up offline $OVER"
  source /cvmfs/mu2e.opensciencegrid.org/Offline/$OVER/SLF6/prof/Offline/setup.sh
  VVER=`ups list -aK+ validation | awk '{print $2}' | tr '"' ' ' | sort | tail -1`
  echo "setting up validation $VVER"
#  setup validation $VVER
  setup validation v0_00_01

  # find last version
  CFILE=`ls -tr $FDIR/val-genReco-5000-nightly* | grep -v $DATE | tail -1`
  CFILE=`basename $CFILE`
  cp $FDIR/$CFILE .

  echo "Will compare:"
  echo $VAL
  echo $CFILE

  # make text comparison
  # -s summary -r report -w filespec
  valCompare -s $CFILE $VAL >> summary.txt
  echo "" >> summary.txt
  echo "" >> summary.txt
  valCompare -r $CFILE $VAL >> summary.txt

  NT=`cat summary.txt | grep "Compared" | awk '{print $1}'`
  [ -z "$NT" ] && NT=0
  NP=`cat summary.txt | grep "had perfect match" | awk '{print $1}'`
  [ -z "$NP" ] && NP=0
  NF=`cat summary.txt | grep "failed loose comparison" | awk '{print $1}'`
  [ $NT -eq 0 ] && NF=999
  echo "[`date`] $NF validation plots failed loose comparison to yesterday" >> $FN
  VALRC=1
  [ $NF -eq 0 ] && VALRC=0

  echo "" >> $FN
  echo "" >> $FN
  cat summary.txt >> $FN

  # make web page
  mkdir -p $PDIR/nightly-${DATE}
  valCompare -w $PDIR/nightly-${DATE}/val.html $CFILE $VAL 2>&1 | grep -v Info

#TValCompare Status Summary:
#   87 Compared
#    0 had unknown status
#    0 could not be compared
#   16 had at least one histogram empty
#   55 failed loose comparison
#    5 passed loose comparison, failed tight
#    6 passed tight comparison, not perfect match
#    5 had perfect match
#   16 passed loose or better
#   11 passed tight or better

  # keep the validation files
  cp $VAL $FDIR

else
  echo "ERROR - validation file not found"
fi
rm -f $CFILE
mv $VAL val.root

echo "VALRC=$VALRC"

cp $FN $NDIR
mv $FN nightly.txt

cat nightly.txt | mail -s "Nightly build, status=$TODAYTOTRC/$VALRC" \
rlc@fnal.gov
#rlc@fnal.gov,genser@fnal.gov,kutschke@fnal.gov,david.brown@louisville.edu


# construct the summary web page

cd $NDIR
TL=`mktemp`
ls -r nightly*.txt > $TL
TT=`mktemp`
cat head.shtml > $TT
while read FF
do
  DD=`echo $FF | cut -c 15-24`
  VD="../val/plots/nightly-$DD"

  if [ -d $VD ]; then
    VT="<a href=\"$VD/val.html\">plots</a>"
  else
    VT="-"
  fi

  LT="<a href=\"$LOG\">log</a>"
  [ ! -r $LOG ] && LT="-"

  ST="<a href=\"$FF\">summary</a>"
  TOTRC="`cat $FF | grep "Total" | awk -F= '{print $2}'`"
  [ -z "$TOTRC" ] && TOTRC="-"
  VALRC="`cat $FF | grep "validation plots failed" | awk '{print $7}'`"
  [ -z "$VALRC" ] && VALRC="-"

  echo "<TR> <TD> $DD </TD> <TD> $TOTRC </TD> <TD> $LT </TD> <TD> $ST </TD> <TD> $VALRC </TD> <TD> $VT </TD> </TR>" >> $TT
done < $TL
rm -f $TL

cat tail.shtml >> $TT
cp $TT nightly.shtml

rm -f $TT

exit 0
