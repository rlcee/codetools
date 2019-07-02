# /bin/bash
#
# pull the nightly offline build products from jenkins server
# and do validation comparisons and send a report
# run by a daily cron
#
cd ~/cron/val

# make sure we have kerberos for writing to web
source $HOME/bin/authentication.sh

NDIR=/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/nightlyBuild
FDIR=/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/val/files
PDIR=/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/val/plots
#ARTIFACT=https://buildmaster.fnal.gov/job/mu2e-offline-nightly/label=SLF6/lastBuild/artifact/copyBack
ARTIFACT=https://buildmaster.fnal.gov/buildmaster/view/mu2e/job/mu2e-offline-nightly/label=SLF6/lastBuild/artifact/copyBack
DATE=`date +"%Y-%m-%d"`
FN=nightly-build-${DATE}.txt

# wait up to 6 hours for the log file to appear
I=0
DONE=false
while [[ $I -lt 30 && "$DONE" == "false" ]];
do
  echo "[`date`] wget $FN"
  wget -q "$ARTIFACT/$FN"
  RC=$?
  if [ -r "$FN" ]; then
    DONE=true
  else
    echo "[`date`] sleeping"
    sleep 900
    I=$(($I+1))
  fi
done

if ! ls $NDIR ; then 
  echo "ERROR could not read web area "
  /usr/krb5/bin/klist
  echo "ERROR cron/val/jenkinsNightlyReport could not read web area " \
    | mail -r valJenkinsReportError \
    -s "error mu2epro accessing web area" \
    rlc@fnal.gov
fi

if [ ! -r "$FN" ]; then
  echo "[`date`] No build report found " > $FN
  echo "[`date`] ERROR - could not wget $ARTIFACT/$FN"
fi
TODAYTOTRC="`cat $FN | grep "before validation" | awk '{print $5}'`"
VALEXERC="`cat $FN | grep "validation exe return code" | awk '{print $11}'`"
CACEXERC="`cat $FN | grep "CutAndCount exe return code" | awk '{print $11}'`"


LOG=nightly-log-${DATE}.log
echo "[`date`] wget $LOG"
wget -q "$ARTIFACT/$LOG"

if [ ! -r "$LOG" ]; then
  echo "[`date`] No build log found " > $LOG
  echo "[`date`] ERROR - could not wget $ARTIFACT/$LOG"
fi
cp $LOG $NDIR
mv $LOG build.log

# setup code for comparison
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
setup mu2e
OVER=`ls -1 /cvmfs/mu2e.opensciencegrid.org/Offline | tail -1`
echo "setting up offline $OVER"
source /cvmfs/mu2e.opensciencegrid.org/Offline/${OVER}/SLF6/prof/Offline/setup.sh
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
  NC=`cat temp.txt | grep "could not be compared" | awk '{print $1}'`
  if [[ $NT -eq 0 || -z "$NF" || -z "$NC" ]]; then
    NF=999
  else
    NF=$(($NF+$NC))
  fi

  echo "[`date`] $NF validation plots failed loose comparison to yesterday" >> $FN
  VALRC=1
  [ $NF -eq 0 ] && VALRC=0
  [ "$VALEXERC" != "0" ] && VALRC=$VALEXERC

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

cat nightly.txt | mail -r valJenkins \
 -s "Nightly build, status=$TODAYTOTRC/$VALRC" \
rlc@fnal.gov
#rlc@fnal.gov,genser@fnal.gov,kutschke@fnal.gov,dave_brown@lbl.gov,david.brown@louisville.edu,gandr@fnal.gov,murat@fnal.gov,gianipez@fnal.gov,echenard@fnal.gov,ehrlich@virginia.edu



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

  # two tests due to schema evolution
  TOTRC="`cat $FF | grep "Return code before validation" | awk '{print $5}'`"
  [ -z "$TOTRC" ] && TOTRC="`cat $FF | grep "Total" | awk -F= '{print $2}'`"
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
