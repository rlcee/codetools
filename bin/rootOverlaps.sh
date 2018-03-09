#! /bin/bash
#
# after setting up a offline release, run this to make a gdml file and
# run it through the root overlap checker
#

if [ ! -r  Mu2eG4/fcl/transportOnly.fcl ]; then
    echo "ERROR rootOverlaps needs to be run in an Offline directory"
    exit 1
fi

cp Mu2eG4/fcl/transportOnly.fcl makeGdml.fcl
echo "physics.producers.g4run.debug.writeGDML : true" >> makeGdml.fcl
rm -f mu2e.gdml
mu2e -n 1 -c makeGdml.fcl >& makeGdml.log
RC=$?
if [ $RC -ne 0  ]; then
    echo "ERROR rootOverlaps could not make gdml file"
    tail -30 makeGdml.log
    exit $RC
fi
bin/overlapCheck.sh mu2e.gdml >& overlapCheck.log

RC=`grep "illegal" overlapCheck.log | awk '{print $NF}'`
grep "illegal" overlapCheck.log
cat overlapCheck.log | awk 'BEGIN{flag=0;}{if(flag==1) print $0; if($1=="===") flag=1; }'

rm -f mu2e.gdml makeGdml.fcl makeGdml.log

exit $RC
