#!/bin/sh

# This script is used from the executor/reload test and executed via the
# 'sdmadm exe -script' command. It ouputs the current user, the current
# directory and the (long) listing of the current working directory.
#
# Furthermore, it tests whether the user is allowed to create a file and a
# directory in the current dir.
#
# Exits with -1 if file or directory could not be created, otherwise 0.

id
pwd
ls -l

# check that we can create a directory
mkdir testdir
rc=$?
if [ "$rc" -ne 0 ] ; then
   echo "Could not create directory: rc=$rc"
   exit -1
fi

# check that we can create a file
touch testfile
rc=$?
if [ "$rc" -ne 0 ] ; then
   echo "Could not create file: rc=$rc"
   exit -1
fi

