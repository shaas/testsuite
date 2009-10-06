#!/bin/sh

usage()
{
   echo "usage: $0 <arch> <spooling_method>"
   echo "where <spooling_method> = bdb|classic"
   exit 1
}

if [ $# -ne 2 ]; then
   usage
fi

arch=$1

if [ ! -d bin/$arch ]; then
   echo "bin/$arch doesn't exist"
   usage
fi

spooling=$2

if [ "$spooling" != "bdb" -a "$spooling" != "classic" ]; then
   usage
fi


BINFILES="sge_qmaster"
UTILBINFILES="spooldefaults spoolinit"
BASE=`pwd`

cd bin/$arch
for i in $BINFILES; do
   if [ -f $i.spool_$spooling ]; then
      rm $i
      ln -s $i.spool_$spooling $i
   fi
done
cd $BASE

cd utilbin/$arch
for i in $UTILBINFILES; do
   if [ -f $i.spool_$spooling ]; then
      rm $i
      ln -s $i.spool_$spooling $i
   fi
done
cd $BASE

