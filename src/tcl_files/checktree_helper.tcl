#!/vol2/TCL_TK/glinux/bin/expect
# expect script 
# test SGE/SGEEE System
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


#****** checktree_helper/exec_compile_hooks() **************************************************
#  NAME
#    exec_compile_hooks() -- execute a compile hooks
#
#  SYNOPSIS
#    exec_compile_hooks { compile_hosts report } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#    compile_hosts --  list of all compile hosts
#    a_report      --  the report object
#
#  RESULT
#     0   --  all compile hooks are executed
#     > 0 --  number of failed compile hooks
#     -1  --  a compile has not been found
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#
#*******************************************************************************
proc exec_compile_hooks { compile_hosts a_report } {
   global ts_checktree

   upvar $a_report report
   
   set error_count 0
   for {set i 0} { $i < $ts_checktree(act_nr)} {incr i 1 } {
      for {set ii 0} {[info exists ts_checktree($i,compile_hooks_${ii})]} {incr ii 1} {
         
         set compile_proc $ts_checktree($i,compile_hooks_${ii})
         
         if { [info procs $compile_proc ] != $compile_proc } {
            report_add_message report "Can not execute compile hook ${ii} of checktree $ts_checktree($i,dir_name), compile proc not found"
            return -1
         } else {
            set res [$compile_proc $compile_hosts report]
            if { $res != 0 } {
               report_add_message report "compile hook ${ii}  of checktree  $ts_checktree($i,dir_name) failed, $compile_proc returned $res\n"
               incr error_count
            }
         }
      }
   }
   return $error_count
}

#****** checktree_helper/exec_compile_clean_hooks() **************************************************
#  NAME
#    exec_compile_clean_hooks() -- execute a compile clean hook
#
#  SYNOPSIS
#    exec_compile_clean_hooks { compile_hosts report } 
#
#  FUNCTION
#     This method executes all registered compile_clean hooks of the
#     checktree
#
#  INPUTS
#    compile_hosts -- list of compile hosts
#    a_report      -- the report object
#
#  RESULT
#     0   -- all compile_clean hooks has been executed
#    >0   -- number of failed compile_clean hooks
#    <0   -- configuration error
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc exec_compile_clean_hooks { compile_hosts a_report } {
   global ts_checktree
   upvar $a_report report
   
   set error_count 0
   for {set i 0} { $i < $ts_checktree(act_nr)} {incr i 1 } {
      for {set ii 0} {[info exists ts_checktree($i,compile_clean_hooks_${ii})]} {incr ii 1} {
         
         set compile_clean_proc $ts_checktree($i,compile_clean_hooks_${ii})
         
         if { [info procs $compile_clean_proc ] != $compile_clean_proc } {
            report_add_message report "Can not execute compile_clean hook ${ii} of checktree $ts_checktree($i,dir_name), compile proc not found"
            return -1
         } else {
            set res [$compile_clean_proc $compile_hosts report]
            if { $res != 0 } {
               report_add_message report "compile_clean hook ${ii}  of checktree  $ts_checktree($i,dir_name) failed, $compile_clean_proc returned $res\n"
               incr error_count
            }
         }
      }
   }
   return $error_count
}

#****** checktree_helper/exec_checktree_clean_hooks() **************************
#  NAME
#     exec_checktree_clean_hooks() -- execute all cleanup hooks
#
#  SYNOPSIS
#     exec_checktree_clean_hooks { } 
#
#  FUNCTION
#
#     execute all cleanup hooks for additional checktrees
#     
#
#  INPUTS
#
#  RESULT
#    0   -- all cleanup hooks are successfully executed
#    >0  -- number of failed cleanup hooks
#    <0  -- a cleanup hook was not found
#
#*******************************************************************************
proc exec_checktree_clean_hooks { } {
   
   global ts_checktree

   set error_count 0
   for {set i 0} { $i < $ts_checktree(act_nr)} {incr i 1 } {
      for {set ii 0} {[info exists ts_checktree($i,checktree_clean_hooks_${ii})]} {incr ii 1} {
         
         set clean_proc $ts_checktree($i,checktree_clean_hooks_${ii})
         
         if { [info procs $clean_proc ] != $clean_proc } {
            ts_log_warning "Can not execute clean_proc hook ${ii} of checktree $ts_checktree($i,dir_name), clean proc not found"
            return -1
         } else {
            ts_log_fine "running cleanup hook: $clean_proc"
            set res [$clean_proc]
            if { $res != 0 } {
               ts_log_warning "checktree_clean hook ${ii}  of checktree  $ts_checktree($i,dir_name) failed, $clean_proc returned $res\n"
               incr error_count
            }
         }
      }
   }
   return $error_count
}



#****** checktree_helper/exec_install_binaries_hooks() **************************************************
#  NAME
#    exec_install_binaries_hooks() -- ???
#
#  SYNOPSIS
#    exec_install_binaries_hooks { } 
#
#  FUNCTION
#     Execute all registered install_binaries_hooks 
#
#  INPUTS
#    arch_list   -- list of architectures
#    a_report    -- the report object
#
#  RESULT
#     0  - on success
#     >1 - nuber of failed install_binaries_hooks
#     <0 - failure
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc exec_install_binaries_hooks { arch_list a_report } {
   global ts_checktree

   upvar $a_report report
   set error_count 0
   for {set i 0} { $i < $ts_checktree(act_nr)} {incr i 1 } {
      for {set ii 0} {[info exists ts_checktree($i,install_binary_hooks_${ii})]} {incr ii 1} {
         
         set prog $ts_checktree($i,install_binary_hooks_${ii})
         
         if { [info procs $prog ] != $prog } {
            ts_log_severe "Can not execute compile hook $ts_checktree($i,install_binary_hooks_${ii}), compile prog not found"
            return -1
         } else {
            set res [$prog $arch_list report]
            if { $res != 0 } {
               report_add_message report "install hook ${ii} of checktree  $ts_checktree($i,dir_name), $prog returned $res\n"
               incr error_count
            }
         }
      }
   }
   return $error_count
}


#****** checktree_helper/exec_shutdown_hooks() **************************************************
#  NAME
#    exec_shutdown_hooks() -- execute all shutdown hooks
#
#  SYNOPSIS
#    exec_shutdown_hooks { } 
#
#  FUNCTION
#     Executes all registered shutdown hooks
#
#  INPUTS
#
#  RESULT
#
#  EXAMPLE
#     ??? 
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc exec_shutdown_hooks {} {
   global ts_checktree

   set error_count 0
   for {set i 0} { $i < $ts_checktree(act_nr)} {incr i 1 } {
      for {set ii 0} {[info exists ts_checktree($i,shutdown_hooks_${ii})]} {incr ii 1} {
         
         set shutdown_hook $ts_checktree($i,shutdown_hooks_${ii})
         
         if { [info procs $shutdown_hook ] != $shutdown_hook } {
            ts_log_fine "Can not execute shutdown hook ${ii} of checktree $ts_checktree($i,dir_name), shutdown proc not found"
            return -1
         } else {
            set res [$shutdown_hook]
            if { $res != 0 } {
               ts_log_fine "shutdown hook ${ii}  of checktree  $ts_checktree($i,dir_name) failed, $shutdown_hook returned $res\n"
               incr error_count
            }
         }
      }
   }
   return $error_count
}


#****** checktree_helper/exec_startup_hooks() **************************************************
#  NAME
#    exec_startup_hooks() -- execute all startup hooks
#
#  SYNOPSIS
#    exec_startup_hooks { } 
#
#  FUNCTION
#     Executes all registered startup hooks
#     Additional checktree will be informed that the cluster starts up
#
#  INPUTS
#
#  RESULT
#
#  EXAMPLE
#     ??? 
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc exec_startup_hooks {} {
   global ts_checktree

   set error_count 0
   for {set i 0} { $i < $ts_checktree(act_nr)} {incr i 1 } {
      for {set ii 0} {[info exists ts_checktree($i,startup_hooks_${ii})]} {incr ii 1} {
         
         set startup_hook $ts_checktree($i,startup_hooks_${ii})
         
         if { [info procs $startup_hook ] != $startup_hook } {
            ts_log_severe "Can not execute startup hook ${ii} of checktree $ts_checktree($i,dir_name), startup proc not found"
            return -1
         } else {
            set res [$startup_hook]
            if { $res != 0 } {
               ts_log_severe "startup hook ${ii}  of checktree  $ts_checktree($i,dir_name) failed, $startup_hook returned $res\n"
               incr error_count
            }
         }
      }
   }
   return $error_count
}

#****** checktree_helper/checktree_get_required_hosts() **************************************************
#  NAME
#    checktree_get_required_hosts() -- get a list of required hosts of all checktrees
#
#  SYNOPSIS
#    checktree_get_required_hosts { } 
#
#  FUNCTION
#     get a list of required hosts of all checktrees
#
#  INPUTS
#
#  RESULT
#     list with the required hosts
#
#  EXAMPLE
#     set required_hosts [checktree_get_required_hosts]
#
#*******************************************************************************
proc checktree_get_required_hosts {} {
   global ts_checktree

   set required_hosts {}
   for {set i 0} {$i < $ts_checktree(act_nr)} {incr i 1 } {
      if { [info exists ts_checktree($i,required_hosts_hook) ] } {
         set required_hosts_hook $ts_checktree($i,required_hosts_hook)
         if { [info procs $required_hosts_hook ] != $required_hosts_hook } {
            ts_log_severe "Can not execute required_hosts_hook of checktree $ts_checktree($i,dir_name), proc not found"
         } else {
            set required_host_list [$required_hosts_hook]
            if { $required_host_list == -1 } {
               ts_log_severe "required_hosts_hook of checktree  $ts_checktree($i,dir_name) failed"
            } else {
               foreach host $required_host_list {
                  if { [lsearch $required_hosts $host] < 0 } {
                     lappend required_hosts $host
                  }
               }
            }
         }
      }
   }
   return $required_hosts
}

#****** checktree_helper/append_check_only_in_jgdi() ***************************
#  NAME
#    append_check_only_in_jgdi() -- adds check_name to check_functions only in 
#                                   only_jgdi mode
#
#  SYNOPSIS
#    append_check_only_in_jgdi { check_name } 
#
#  FUNCTION
#     Adds check_name to check_functions only in  only_jgdi mode
#
#  INPUTS
#    check_name -- name of the check
#
#  RESULT
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc append_check_only_in_jgdi { check_name } {
   global check_functions CHECK_JGDI_ENABLED

   if { $CHECK_JGDI_ENABLED == 1 } { #only_jgdi
      lappend check_functions $check_name
#ts_log_fine "Added only to JGDI: $check_name"
   }
}

#****** checktree_helper/exclude_check() ***************************************
#  NAME
#    exclude_check() -- Excludes the check from check_functions due to 
#                       description
#
#  SYNOPSIS
#    exclude_check { mode_key check_name {description "Reason not specified" } }
#
#  FUNCTION
#     Excludes the check from check_functions due to description
#
#  INPUTS
#    mode        -- any string, usually now only "JGDI"
#    check_name  -- name of the check to be exluded
#    description -- resone why the check is to be excluded
#
#  RESULT
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc exclude_check { mode_key check_name {description "Reason not specified" } } {
   global check_category exclude_array CHECK_JGDI_ENABLED

   #We uniquely add a check
   if { ![info exists exclude_array($mode_key,$description)] || 
        [lsearch -exact $exclude_array($mode_key,$description) $check_name] == -1 } {
      lappend exclude_array($mode_key,$description) $check_name
#ts_log_fine "Excluded: $check_name mode:$mode_key"
   }
}

#****** checktree_helper/append_check_and_exclude_in_jgdi() ********************
#  NAME
#    append_check_and_exclude_in_jgdi() -- Appends the check to check_functions
#                                          only in no_jgdi mode.
#
#  SYNOPSIS
#    append_check_and_exclude_in_jgdi {check_name {description "DOES NOT WORK in JGDI" } }
#
#  FUNCTION
#     Appends the check to check_functions only in no_jgdi mode.
#
#  INPUTS
#    check_name  -- name of the check to be exluded
#    description -- resone why the check is to be excluded in JGDI
#
#  RESULT
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc append_check_and_exclude_in_jgdi { check_name {description "DOES NOT WORK in JGDI" } } {
    global CHECK_ACT_LEVEL check_description check_functions check_highest_level CHECK_JGDI_ENABLED
    #We need to go over all the levels
    if { $CHECK_JGDI_ENABLED == 1 } { #If JGDI enabled
       exclude_check JGDI $check_name $description
    } else {
       lappend check_functions $check_name
    }
}

#****** checktree_helper/create_excluded_check_email_content() *****************
#  NAME
#    create_excluded_check_email_content() -- Creates email with excluded checks
#
#  SYNOPSIS
#    create_excluded_check_email_content {}
#
#  FUNCTION
#     Creates email with excluded checks
#
#  INPUTS
#
#  RESULT
#     result -- body of the email
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc create_excluded_check_email_content {} {
    global exclude_array

    if { ![info exists exclude_array] } {
       return ""
    }

    set out ""
    set last_mode ""
    set last_desc ""
    #Get keys (level_description - CLIENT, JGDI, custom)
    foreach key [lsort [array names exclude_array]] {
       set mode [string range $key 0 [expr [string length [lindex [split $key ","] 0]] - 1]]
       set description [string range $key [expr [string length $mode] + 1] end]
#ts_log_fine "mode: $mode desc: $description"
       if { [string compare $mode $last_mode] != 0 } {
          append out "\n=============================================\n"
          append out "FOLLOWING CHECKS ARE MARKED TO BE SKIPPED FOR\n"
          append out " $mode mode\n"
          append out "============================================="
          set last_mode $mode
       }
       if { [string compare $description $last_desc] != 0 } {
          append out "\nREASON: $description\n"
       }
       #Print each item
       foreach check_name [lsort $exclude_array($key)] {
          append out "   $check_name\n"
       }
    }
    #We delete the array for next run
    array unset exclude_array
    return $out
}

#****** checktree_helper/send_skipped_tests_mail() ********************
#  NAME
#    send_skipped_tests_mail() -- Sends an email with excluded checks
#
#  SYNOPSIS
#    send_skipped_tests_mail { { subject "SKIPPED TEST REPORT"} }
#
#  FUNCTION
#     Sends an email with excluded checks
#
#  INPUTS
#     Subject -- subject of the email
#
#  RESULT
#     
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc send_skipped_tests_mail { { subject "SKIPPED TEST REPORT"} } {
   set out [create_excluded_check_email_content]
   #Send the email if there is something to report
   if { [string length $out] > 0 } {
      mail_report $subject $out
   }
}
