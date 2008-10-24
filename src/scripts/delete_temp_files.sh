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

# we move it away - to prevent conflicts
temp=${orig}.tmp
mv $orig $temp

# the last entry is the open_remote_spawn_process calling us - do not delete it!
last_entry=`tail -1 $temp`
echo $last_entry >> $orig

# delete the files
for file in `cat $temp | grep -v -- "$last_entry"`; do
   rm -f $file
done

# cleanup
rm $temp

exit 0
