#!/bin/sh

if [ $# -ne 1 ]; then
   echo "usage: $0 <sge_root>"
fi

SGE_ROOT=$1
export SGE_ROOT

. $SGE_ROOT/util/arch_variables
echo "qlogin_command    $QLOGIN_COMMAND"
echo "qlogin_daemon     $QLOGIN_DAEMON"
echo "rlogin_command    $RLOGIN_COMMAND"
echo "rlogin_daemon     $RLOGIN_DAEMON"
echo "rsh_command       $RSH_COMMAND"
echo "rsh_daemon        $RSH_DAEMON"

