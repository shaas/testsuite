#!/bin/sh
if [ -x $1 ]; then
  if [ -s $1 ]; then
     tail -1 $1 | grep _END_OF_FILE_ > /dev/null
     if [ $? = 0 ]; then
        echo "TS_OK"
        exit 0
     fi
  fi
fi
echo "file not found"
exit 1
