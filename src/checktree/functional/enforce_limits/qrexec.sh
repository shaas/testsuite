#!/bin/sh
#$ -S /bin/sh
#$ -j y

echo "starting $NSLOTS at host `hostname`"

I=1
while [ $I -le $NSLOTS ]; do
   host=`sed -n "${I}p" $TMPDIR/machines`
   cmd="$SGE_ROOT/bin/$ARC/qrsh -nostdin -inherit $host $SGE_ROOT/examples/jobs/worker.sh $1"
   env
   ls -la $TMPDIR
   echo $cmd
   $cmd &
   I=`expr $I + 1`
done
wait

exit 0

