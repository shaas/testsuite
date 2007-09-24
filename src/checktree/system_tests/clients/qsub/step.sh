#!/bin/sh

#$ -S /bin/sh

echo first $SGE_TASK_FIRST last $SGE_TASK_LAST step $SGE_TASK_STEPSIZE 

echo start is $SGE_TASK_ID

end=`expr $SGE_TASK_ID + $SGE_TASK_STEPSIZE - 1`

echo first is $start
echo last is $end
