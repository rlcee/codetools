#!/bin/bash

echo "[`date`] start"
echo "[`date`] printenv"
printenv
echo "[`date`] df -h"
df -h
echo "[`date`] PWD"
pwd
echo "[`date`] ls of local dir"
ls -al

REPORT=nightly-build-`date +"%Y-%m-%d.txt"`
VALFILE=val-genReco-5000-nightly_`date +"%Y-%m-%d"`-0.root
CACFILE=candc-nightly_`date +"%Y-%m-%d"`-0.root

echo "[`date`] source products common"
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
echo "[`date`] setup mu2e"
setup mu2e

echo "[`date`] printenv after setup"
printenv

echo "[`date`] clone offline"
git clone http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline/Offline.git
echo "[`date`] cd Offline"
cd Offline
echo "[`date`] print commit"
git show
git rev-parse HEAD
#echo "[`date`] clone validation"
#git clone http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline-validation/validation.git
echo "[`date`] source setup"
source setup.sh

echo "Nightly build " > $REPORT

echo "[`date`] start scons" | tee -a $REPORT
scons -j 16
RC1=$?
echo "[`date`] scons return code $RC1" | tee -a $REPORT

mu2e -c Mu2eG4/fcl/g4test_03.fcl
RC2=$?
echo "[`date`] g4test_03 return code $RC2" | tee -a $REPORT

mu2e -c Mu2eG4/fcl/surfaceCheck.fcl >& surfaceCheck.log
RC3=$?
echo "[`date`] surfaceCheck exe return code $RC3" | tee -a $REPORT

VOLCHECKG=`egrep 'Checking overlaps for volume' surfaceCheck.log | grep OK | wc -l`
VOLCHECKB=`egrep 'Checking overlaps for volume' surfaceCheck.log | grep -v OK | wc -l`
echo "Volume checks:  OK=${VOLCHECKG},  not OK=$VOLCHECKB" | tee -a $REPORT
egrep 'Checking overlaps for volume' surfaceCheck.log | grep -v OK | tee -a $REPORT

mu2e -n 5 -c Mu2eG4/fcl/g4study.fcl
RC4=$?
echo "[`date`] g4study exe return code $RC4" | tee -a $REPORT

mu2e -n 5 -c Mu2eG4/fcl/transportOnly.fcl
RC5=$?
echo "[`date`] transportOnly exe return code $RC5" | tee -a $REPORT

mu2e -c JobConfig/cd3/beam/beam_g4s1.fcl -n 100
RC6=$?
echo "[`date`] beam_g4s1 return code $RC6" | tee -a $REPORT

# needs data from /cvmfs/mu2e
mu2e -n 5000 -c Analyses/test/genReco.fcl
RC7=$?
echo "[`date`] genReco exe return code $RC7" | tee -a $REPORT

# run gstudy2
mu2e -n 5 -c Mu2eG4/fcl/g4study2.fcl
RC8=$?
echo "[`date`] g4study2 exe return code $RC8" | tee -a $REPORT

#
# validation hists
#

#mu2e -s genReco.art -c validation/fcl/validation1.fcl 
mu2e -s genReco.art -c Validation/fcl/val.fcl 
RC9=$?
echo "[`date`] validation exe return code $RC9" | tee -a $REPORT

cp validation.root ../copyBack/$VALFILE

# run CutAndCount on its standard input
mu2e -c JobConfig/cd3/beam/dra_pure_baseline.fcl \
 -s /cvmfs/mu2e.opensciencegrid.org/DataFiles/ExampleDataFiles/StoppedMuons/sim.mu2e.cd3-beam-g4s4-detconversion.v566.004001_00000000.art
RC10=$?
echo "[`date`] CutAndCount return code $RC10" | tee -a $REPORT
cp nts.owner.cd3-dra-pure-baseline.ver.seq.root ../copyBack/$CACFILE

# validation exes RC9 and 10 not included since it
# will be implicitly included in the validation report
RC=$(($RC1+$RC2+$RC3+$VOLCHECKB+$RC4+$RC5+$RC6+$RC7+$RC8))
echo "Total return code=$RC" | tee -a $REPORT

echo "[`date`] ls of Offline dir"
ls -al

#echo "[`date`] mail report"
#cat $REPORT | mail -s "Nightly build, status=$RC" \
#rlc@fnal.gov
#rlc@fnal.gov,genser@fnal.gov,kutschke@fnal.gov,david.brown@louisville.edu

cp $REPORT ../copyBack
cd ..
echo "[`date`] ls of local dir"
ls -al
echo "[`date`] ls of copyBack"
ls -al copyBack


exit $RC
