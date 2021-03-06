#! /bin/bash
#
# after setting up a offline release, run this to make a gdml file and
# run it through the root overlap checker
#


rm -f mu2e.gdml
mu2e -c Mu2eG4/fcl/gdmldump.fcl >& makeGdml.log
RC=$?
if [ $RC -ne 0  ]; then
    echo "ERROR rootOverlaps could not make gdml file"
    tail -30 makeGdml.log
    exit $RC
fi

if [ -r ${MU2E_SATELLITE_RELEASE}/bin/overlapCheck.sh ]; then
    ${MU2E_SATELLITE_RELEASE}/bin/overlapCheck.sh mu2e.gdml >& overlapCheck.log 
elif [ -r ${MU2E_BASE_RELEASE}/bin/overlapCheck.sh ]; then
    ${MU2E_BASE_RELEASE}/bin/overlapCheck.sh mu2e.gdml >& overlapCheck.log
else
    echo "ERROR rootOverlaps could not find bin/overlapCheck.sh"
    exit 1
fi

# a message on how many volumes checked
grep "in Geometry imported from GDML" overlapCheck.log

# check number of failures
RC=`grep "illegal" overlapCheck.log | awk '{print $NF}'`
[ "$RC" == "" ] && RC=0
# also print them
grep "illegal" overlapCheck.log
cat overlapCheck.log | awk 'BEGIN{flag=0;}{if(flag==1) print $0; if($1=="===") flag=1; }'

rm -f mu2e.gdml makeGdml.fcl makeGdml.log data_06.root transportOnly.root overlapCheck.log

exit $RC
