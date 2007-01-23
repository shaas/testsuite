#!/bin/sh
#___INFO__MARK_BEGIN__
##########################################################################
#
#  The Contents of this file are made available subject to the terms of
#  the Sun Industry Standards Source License Version 1.2
#
#  Sun Microsystems Inc., March, 2001
#
#
#  Sun Industry Standards Source License Version 1.2
#  =================================================
#  The contents of this file are subject to the Sun Industry Standards
#  Source License Version 1.2 (the "License"); You may not use this file
#  except in compliance with the License. You may obtain a copy of the
#  License at http://gridengine.sunsource.net/Gridengine_SISSL_license.html
#
#  Software provided under this License is provided on an "AS IS" basis,
#  WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING,
#  WITHOUT LIMITATION, WARRANTIES THAT THE SOFTWARE IS FREE OF DEFECTS,
#  MERCHANTABLE, FIT FOR A PARTICULAR PURPOSE, OR NON-INFRINGING.
#  See the License for the specific provisions governing your rights and
#  obligations concerning the Software.
#
#  The Initial Developer of the Original Code is: Sun Microsystems, Inc.
#
#  Copyright: 2001 by Sun Microsystems, Inc.
#
#  All Rights Reserved.
#
##########################################################################
#___INFO__MARK_END__

#
#

# -------------------------------------------
# --          use Bourne shell             --
#$ -S /bin/sh
# --             our name                  --
#$ -N PMiniWorm
# -------------------------------------------
# -- send mail if the job exits abnormally --
#$ -m a
# -------------------------------------------
# --     What to redirect to where         --
#$ -e /dev/null
#$ -o /dev/null

usage() {
   echo "pminiworm.sh [-s <sleep time>] [-i <job index>] [-m <max job index] [-e <sub script>] [-- <qsub options>]"
   echo "  -s <sleep time>     sleep <sleep time> seconds before submitting a new job"
   echo "  -i <job index>      current job index"
   echo "  -m <max job index>  max job index"
   echo "  <job index>         index for the job names (default 1)"
   echo "  -- <qsub options>   All options after -- are treaded as qsub options"
   echo ""
}

if [ "$ARC" = "" ]; then
   ARC=$ARCH
fi

QSUB=$SGE_ROOT/bin/$ARC/qsub
QSUB_OPTIONS=""
SLEEP=120

basedir=`dirname $0`
basedir=`cd $basedir; pwd`
basename=`basename $0`

job_index=1
max_job_index=0
script=$basedir/$basename

while [ $# -gt 0 ]; do
   if [ "$1" = "-s" ]; then
     if [ $# -lt 2 ]; then
        echo "Missing <sleep time>"
        exit 1
     fi
     shift
     SLEEP=$1
   elif [ "$1" = "-i" ]; then
     if [ $# -lt 2 ]; then
        echo "Missing <job index>"
        exit 1
     fi
     shift
     job_index=$1
   elif [ "$1" = "-m" ]; then
     if [ $# -lt 2 ]; then
        echo "Missing <max job index>"
        exit 1
     fi
     shift
     max_job_index=$1
   elif [ "$1" = "-e" ]; then
     if [ $# -lt 2 ]; then
        echo "Missing <script>"
        exit 1
     fi
     shift
     script=$1
   elif [ "$1" = "--" ]; then
     shift
     QSUB_OPTIONS=$@
     break
   else 
     echo "unknown option $1"
     exit 1
   fi
   shift
done

NAME=W$job_index

# started by SGE or manually 
if [ "$JOB_ID" = "" ]; then
   echo "submitting $NAME"
else
   sleep $SLEEP
   if [ $max_job_index -gt 0 ]; then
     if [ $job_index -gt $max_job_index  ]; then
        echo "reached max job index $max_job_index ($job_index), exit worm"
        exit 0
     fi
   fi
fi

job_index=`expr $job_index + 1`

cmd="$QSUB -N $NAME $QSUB_OPTIONS $script -s $SLEEP -i $job_index -m $max_job_index -e $script -- $QSUB_OPTIONS"
echo "execute $cmd"
$cmd
while [ "x$?" != "x0" ]; do
   echo "pminiworm.sh: qsub failed - retrying .." >&2
   sleep $SLEEP
   $cmd
done







