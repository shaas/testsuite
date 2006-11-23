global $CHECK_OUTPUT

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
      add_proc_error "install_reporting" -1 "Can not get local spool dir for host $swc_host"
      return -1
   }

   # we have to change the ownership of the queries and results subdirectory, because
   # the installation script set it to noaccess
   set dirs { queries results }
   foreach dir $dirs {
      set output [start_remote_prog $arco_config(swc_host) root "chown" "-R $owner $spool_dir/$dir"]
      if { $prg_exit_state != 0 } {
         add_proc_error "arcorun_check_options" -3 "Can not change owner of directory $spool_dir/$dir: $output"
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
proc arcorun_exec { args output { timeout 60 } } {
   global ts_config arco_config
   global CHECK_USER
   
   upvar $output my_output
   
   set swc_host $arco_config(swc_host)
   set arco_run_cmd "$ts_config(product_root)/$ts_config(cell)/arco/reporting/arcorun"
   
   set my_output [start_remote_prog $swc_host $CHECK_USER $arco_run_cmd "$args" prg_exit_state $timeout]
   return $prg_exit_state
}

