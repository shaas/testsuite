#!/bin/sh
#
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
#  Copyright: 2009 by Sun Microsystems, Inc.
#
#  All Rights Reserved.
#
##########################################################################
#___INFO__MARK_END__

#workaround script for getting some attributes from hedeby specific xml files: global.xml for example
# $1 - path to file which should be processed
# $2 - full path to temporary file 
# $3 - key for value which should be returned
# $4 - condition for a string in the line
# example (search for owner of cs_vm)
# ./hedeby_config_parser.sh global.xml /tmp/mytestfile user "name=\"cs_vm\""
# This script using basic sed and grep functionality serches for specific attributes.
# Example xml:
#  <common:jvm port="44123"
#               user="rm199614"
#               name="cs_vm">
#       <common:component xsi:type="common:MultiComponent"
#                         classname="com.sun.grid.grm.executor.impl.ExecutorImpl"
#                         name="executor"
#                         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#  </common:jvm>
# This helper script will create intermediate line like below:
# <common:jvm port="44123" user="me" name="cs_vm"> (1)
# <common:component xsi:type="common:MultiComponent" classname="com.sun.grid.grm.executor.impl.ExecutorImpl" name="executor" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"> (2)
# Next step is to return all lines that fulfill condition string. For example: name="cs_vm".
# Finally script will obtain value of the key if found. 

if [ ! $# -eq 3 -a ! $# -eq 4 ]; then 
   echo 'Wrong usage of script: script <filename> <tmp_file> <key> <condition>'
   exit 2
fi 
t="$2"
if [ "$t" = "" ]; then
   echo "Temporary file not specified"
   exit 2
fi
rm -f $t
rm -f $t.tmp
touch $t 
while read line; do
  tmp=""
  echo $line | grep \>$ > /dev/null
  if [ $? -eq 0 ]; then
     tmp="1"
  fi;
  result="$result $line"
  if [ "$tmp" = "1" ]; then
     echo $result >> $t
     result=""
  fi;
done < "$1";
key="$3"
if [ $# -eq 4 ]; then
   cat $t | grep $4 > $t.tmp
fi;
if [ ! -f $t.tmp ]; then
   cat $t > $t.tmp
fi;
cat $t.tmp  | grep $key | sed 's/^.*'"$key"'=\"//g' | sed 's/".*$//g'
rm -f $t
rm -f $t.tmp 
