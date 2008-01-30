#!/vol2/TCL_TK/glinux/bin/tclsh
# expect script 
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


#****** check/arcorun_change_spooldir_owner() **************************************************
#  NAME
#    arcorun_change_spooldir_owner() -- change the owner of the arco spool directory
#
#  SYNOPSIS
#    arcorun_change_spooldir_owner { owner { a_spool_dir "" } } 
#
#  FUNCTION
#    change the owner of the arco spool directory
#
#  INPUTS
#    owner --  the new owner of the arco spool directory
#    a_spool_dir -- the spool directory is written into this variable
#
#  RESULT
#     0  -- owner changed
#     else -- error
#
#  SEE ALSO
#     file_procedures/get_local_spool_dir
#*******************************************************************************
proc arcorun_change_spooldir_owner { owner { a_spool_dir "" } } {
   global arco_config
   
   set spool_dir [get_local_spool_dir $arco_config(swc_host) arco 0]
   
   if { $spool_dir == "" } {
      ts_log_severe "Can not get local spool dir for host $swc_host"
      return -1
   }

   # we have to change the ownership of the queries and results subdirectory, because
   # the installation script set it to noaccess
   set dirs { queries results }
   foreach dir $dirs {
      set output [start_remote_prog $arco_config(swc_host) root "chown" "-R $owner $spool_dir/$dir"]
      if { $prg_exit_state != 0 } {
         ts_log_config "Can not change owner of directory $spool_dir/$dir: $output"
         return -1
      }
   }
   
   if { $a_spool_dir != "" } {
      upvar $a_spool_dir ret_spool_dir
      set ret_spool_dir $spool_dir
   }
   return 0
}

#****** check/arcorun_exec() **************************************************
#  NAME
#    arcorun_exec() -- execute the arcorun util 
#
#  SYNOPSIS
#    arcorun_exec { args output { timeout 60 } } 
#
#  FUNCTION
#     Execute the arcorun util on the host where the arco web application
#     is installed
#
#  INPUTS
#    args    --  Arguments for the arcorun util
#    output  --  output of the arcorun util is stored in this variable
#    timeout --  timeout in seconds (default 60)
#
#  RESULT
#     exit state of the arcorun util
#
#  EXAMPLE
#
#*******************************************************************************
proc arcorun_exec {args output {timeout 60}} {
   global ts_config arco_config CHECK_USER
   
   upvar $output my_output
   
   set swc_host $arco_config(swc_host)
   set arco_run_cmd "$ts_config(product_root)/$ts_config(cell)/arco/reporting/arcorun"
   if {$ts_config(gridengine_version) < 62} {
      set my_env(JAVA_HOME) [get_java_home_for_host $swc_host "1.4"]  
   } else {
      set my_env(JAVA_HOME) [get_java_home_for_host $swc_host "1.5"]
   }
   set my_env(SGE_ROOT) "$ts_config(product_root)"
   set my_env(SGE_CELL) "$ts_config(cell)"
   ts_log_fine "---> executing on $swc_host as $CHECK_USER:"
   ts_log_fine "$arco_run_cmd $args"
   set my_output [start_remote_prog $swc_host $CHECK_USER $arco_run_cmd $args prg_exit_state $timeout 0 "" my_env]
   return $prg_exit_state
}

