#!/bin/sh
#$ -S /bin/sh

if [ $# -ne 2 ]; then
   echo "usage: $0 <id> <sleeptime>"
   exit 1
fi

ID=$1 ; export ID
SLEEP=$2

trap 'echo $ID got signal SIGUSR1' USR1
trap 'echo $ID got signal SIGTSTP' TSTP

if [ $ID -eq 0 ]; then
   echo ""
   echo "job started with job_id $JOB_ID"
   echo "$ID starting sub processes"
   $0 1 $SLEEP </dev/null &
   $0 2 $SLEEP </dev/null &
   wait
   wait
   wait
   wait
   echo "$ID sub processes ended"
else
   echo "$ID sleeping $SLEEP seconds"
   now=`$SGE_ROOT/utilbin/$ARC/now`
   time_end=`expr $now + $SLEEP`
   while [ $now -lt $time_end ]; do
      sleep 1
      now=`$SGE_ROOT/utilbin/$ARC/now`
   done
   echo "$ID done"
fi

exit 0
