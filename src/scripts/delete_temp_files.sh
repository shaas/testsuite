#!/bin/sh
#
# script to be called on the file server to delete all the temp files
# created by testsuite
# first argument is the file listing the temp filenames
if [ $# -ne 1 ]; then
   echo "Usage: $0 filename"
   exit 1
fi

# if the file doesn't exist - nothing to do
orig=$1
if [ ! -f $orig ]; then
   exit 0
fi

# delete the files
for file in `cat $orig`; do
   if [ -f "$file" ]; then
      rm -f $file
   fi
done

# cleanup
rm $orig

exit 0
