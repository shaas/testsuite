#!/bin/sh

#$ -S /bin/sh

echo first $SGE_TASK_FIRST last $SGE_TASK_LAST step $SGE_TASK_STEPSIZE 

sleep 11
echo start is $SGE_TASK_ID

start=$SGE_TASK_ID
end=`expr $start + $SGE_TASK_STEPSIZE - 1`

echo first is $start
echo last is $end
