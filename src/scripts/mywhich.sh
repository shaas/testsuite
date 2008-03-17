#!/bin/sh

# simulate the which command in sh

if [ $# -lt 1 ]; then
   echo which: Too few arguments.
   exit 1
fi

for i in `echo $PATH |tr -s : ' '` ; do
   if [ ! -d $i/$1 -a -x $i/$1 ]; then
      echo $i/$1
      exit 0
   fi
done
# it is not available in the current PATH
echo $1: Command not found.
exit 1
