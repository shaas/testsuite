#!/bin/sh
#
#$ -S /bin/sh
#$ -cwd
#set -x

script=$1
instances=$2
duration=$3
sleep_after=$4

trap "echo master task received SIGUSR1" USR1
trap "echo master task received SIGUSR2" USR2

# convert pe_hostfile to a list of hosts
prepare_host_slots() 
{
   HOSTSLOTS=""
   while read host nproc rest; do
      hosttask=0
      while [ $hosttask -lt $nproc ]; do
         HOSTSLOTS="$HOSTSLOTS $host"
         hosttask=`expr $hosttask + 1`
      done
   done
   echo $HOSTSLOTS
}

unset SGE_DEBUG_LEVEL
printf "master task started with job id %6d and pid %8d\n" $JOB_ID $$

# get a list of host names taking one slot each
HOSTSLOTS=`cat $PE_HOSTFILE | prepare_host_slots`

# start a sleeper process on each granted processor
task=0
for host in $HOSTSLOTS; do
   $SGE_ROOT/bin/$ARC/qrsh -inherit -noshell -nostdin -cwd $host $script $task $duration &
   task=`expr $task + 1`
done
echo "master task submitted all sub tasks"

# wait for the pe tasks (qrsh -inherit) to terminate
# we do multiple wait calls, as wait gets interrupted
# when signals are received, even when they are trapped
# see tight_integration check, tight_integration_notify
# We do a double wait for each started pe task to be sure
# not to finish master task before all tasks have finished
for host in $HOSTSLOTS; do
   wait
   wait
done

if [ "$sleep_after" != "" ]; then
   echo "sleeping $sleep_after seconds ..."
   sleep $sleep_after
   echo "sleeping $sleep_after seconds finished"
fi
echo "master task exiting"
exit 0
