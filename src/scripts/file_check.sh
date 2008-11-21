#!/bin/sh
if [ -s $1 ]; then
   echo "TS_OK"
   exit 0
fi
echo "file not found"
exit 1
