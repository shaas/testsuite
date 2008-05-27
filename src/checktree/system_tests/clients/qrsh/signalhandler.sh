#!/bin/sh 
# expample: ./signal.sh SIGUSR1 or ./signal.sh SIGUSR2 

wait=1

trap 'echo Signal; sleep 1; echo exit; exit' $1 

echo running

while [ $wait -eq 1 ] 
do
   sleep 1 
done 

