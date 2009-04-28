#!/usr/local/bin/tclsh
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

# JG: TODO: Change the assign/unassign procedures.
# The current implemtation using aattr/dattr is destroying the default 
# settings in all.q

proc get_complex { change_array } {
  get_current_cluster_config_array ts_config
  upvar $change_array chgar

  set result [start_sge_bin "qconf" "-sc"]
  if {$prg_exit_state != 0} {
     ts_log_severe "qconf -sc failed:\n$result"
     return
  } 

  # split each line as listelement
  set help [split $result "\n"]
  foreach elem $help {
     set id [lindex $elem 0]
     if { [ string first "#" $id ]  != 0 } {
        set value [lrange $elem 1 end]
        if { [string compare $value ""] != 0 } {
           set chgar($id) $value
        }
     }
  }
}

#****** sge_procedures.60/set_complex() **********************************
#  NAME
#     set_complex() -- set complexes with the qconf -mc commaned
#
#  SYNOPSIS
#     set_complex { change_array {raise_error 1}} 
#
#  FUNCTION
#     Modifies, adds or deletes complexes
#
#     If an complex in change_array already exits the complex will be changed
#     If it not exists in will be added
#     If the complex definition in the change_array is a empty string the
#     complex will be deleted
#
#  INPUTS
#     change_array - array with the complex definitions
#     raise_error  - if unset the error is expected
#     fast_add     - add from file
#
#  RETURN:
#
#     >=0 - success  complex definition has been modified
#      <0 - error
#
#  EXAMPLE:
#
#  1. add or modify a complexes
#
#      set tmp_complex(slots) "s   INT <= YES YES 1 1000"
#      set tmp_complex(dummy) "du1 INT <= YES YES 0 500"
#     
#      set_complex tmp_complex
#
#   2. delete a complex
#
#      set tmp_complex(dummy) ""
#      set_complex tmp_complex
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc set_complex {change_array {raise_error 1} {fast_add 1}} {
   global CHECK_USER
   global env
   get_current_cluster_config_array ts_config
   upvar $change_array chgar
   set values [array names chgar]

   get_complex old_values

   if {$fast_add} {
      foreach elem $values {
         set old_values($elem) "$chgar($elem)"
      }

      set tmpfile [dump_array_to_tmpfile old_values]
      set result [start_sge_bin "qconf" "-Mc $tmpfile"]

      # parse output or raise error
      add_message_to_container messages 4 [translate_macro MSG_CENTRY_NOTCHANGED]
      add_message_to_container messages 3 [translate_macro MSG_SGETEXT_MODIFIEDINLIST_SSSS $CHECK_USER "*" "*" "*"]
      add_message_to_container messages 2 [translate_macro MSG_SGETEXT_REMOVEDFROMLIST_SSSS $CHECK_USER "*" "*" "*"]
      add_message_to_container messages 1 [translate_macro MSG_SGETEXT_ADDEDTOLIST_SSSS $CHECK_USER "*" "*" "*"]
      add_message_to_container messages -1 [translate_macro MSG_CENTRYREFINQUEUE_SS "*" "*"]
      add_message_to_container messages -2 [translate_macro MSG_CENTRYREFINHOST_SS "*" "*"]
      if {$ts_config(gridengine_version) >= 61} {
         add_message_to_container messages -6 [translate_macro MSG_CENTRY_NULL_URGENCY "*" "*"]
      }
      set result [handle_sge_errors "set_complex" "qconf -Mc" $result messages $raise_error]
      if {$result < 0 && $prg_exit_state == 0} {
         ts_log_severe "prg_exit_state was 0 but qconf returned an error" $raise_error
      }
   } else {
      set vi_commands {}
      foreach elem $values {
         # this will quote any / to \/  (for vi - search and replace)
         set newVal $chgar($elem)
         if {[info exists old_values($elem)]} {
            # if old and new config have the same value, create no vi command,
            # if they differ, add vi command to ...
            if { [compare_complex $old_values($elem) $newVal] != 0 } {
               if {$newVal == ""} {
                  # ... delete config entry (replace by comment)
                  lappend vi_commands ":%s/^$elem .*$/#/\n"
               } else {
                  # ... change config entry
                  set newVal1 [split $newVal {/}]
                  set newVal [join $newVal1 {\/}]
                  lappend vi_commands ":%s/^$elem .*$/$elem  $newVal/\n"
               }
            }
         } else {
            # if the config entry didn't exist in old config: append a new line
            lappend vi_commands "1Gi$elem  $newVal\n[format "%c" 27]"
         }
      }

      set MODIFIED [translate_macro MSG_SGETEXT_MODIFIEDINLIST_SSSS $CHECK_USER "*" "*" "*"]
      set ADDED    [translate_macro MSG_SGETEXT_ADDEDTOLIST_SSSS $CHECK_USER "*" "*" "*"]
      set REMOVED  [translate_macro MSG_SGETEXT_REMOVEDFROMLIST_SSSS $CHECK_USER "*" "*" "*"]
      set STILLREF [translate_macro MSG_CENTRYREFINQUEUE_SS "*" "*"]
      set NOT_MODIFIED [translate_macro MSG_CENTRY_NOTCHANGED]

      if {$ts_config(gridengine_version) >= 61} {
         set NULL_URGENCY [translate_macro MSG_CENTRY_NULL_URGENCY]
      } else {
         set NULL_URGENCY "NULL_URGENCY fix only available in SGE 6.1 or higher"
      }
    
      set master_arch [resolve_arch $ts_config(master_host)] 

      set result [handle_vi_edit "$ts_config(product_root)/bin/$master_arch/qconf" "-mc" $vi_commands $MODIFIED $REMOVED $ADDED $NOT_MODIFIED $STILLREF $NULL_URGENCY "___ABCDEFG___" $raise_error]
      if {$result != 0 && $result != -2 && $result != -3 && $result != -4} {
         ts_log_severe "could not modify complex: ($result)" $raise_error
      } 
      if {$result == -4} {
         ts_log_fine "INFO: could not modify complex: ($result) (unchanged settings)" $raise_error
      }
   }

   return $result
}



#****** sge_procedures.60/switch_to_admin_user_system() ************************
#  NAME
#     switch_to_admin_user_system() -- switch to a admin user system
#
#  SYNOPSIS
#     switch_to_admin_user_system { } 
#
#  FUNCTION
#     run install core system and install admin user system
#
#  INPUTS
#
#  RESULT
#     0 - on success
#
#  NOTES
#     not implemented
#
#  SEE ALSO
#     sge_procedures.60/switch_to_admin_user_system()
#     sge_procedures.60/switch_to_normal_user_system()
#     sge_procedures.60/switch_to_root_user_system()
#*******************************************************************************
proc switch_to_admin_user_system {} {
   global actual_user_system

   if { $actual_user_system != "admin user system" } {
      ts_log_fine "switching from $actual_user_system to admin user system ..."
      ts_log_info "Function not implemented"
      set actual_user_system "admin user system"
   }

   return 0
}

#****** sge_procedures.60/switch_to_root_user_system() *************************
#  NAME
#     switch_to_root_user_system() -- switch to a root user system
#
#  SYNOPSIS
#     switch_to_root_user_system { } 
#
#  FUNCTION
#     run install core system and install root user system
#
#  INPUTS
#
#  RESULT
#     0 - on success
#
#  NOTES
#     not implemented
#
#  SEE ALSO
#     sge_procedures.60/switch_to_admin_user_system()
#     sge_procedures.60/switch_to_normal_user_system()
#     sge_procedures.60/switch_to_root_user_system()
#*******************************************************************************
proc switch_to_root_user_system {} {
   global actual_user_system
    
   ts_log_info "Function not implemented"
   return 1

   if { $actual_user_system != "root user system" } {
      ts_log_fine "switching from $actual_user_system to root user system ..."
      set actual_user_system "root user system"
   }
}

#****** sge_procedures.60/switch_to_normal_user_system() ***********************
#  NAME
#     switch_to_normal_user_system() -- switch to a standard user system
#
#  SYNOPSIS
#     switch_to_normal_user_system { } 
#
#  FUNCTION
#      run install core system and install standard user system
#
#  INPUTS
#
#  RESULT
#     0 - on success
#
#  NOTES
#     not implemented
#
#  SEE ALSO
#     sge_procedures.60/switch_to_admin_user_system()
#     sge_procedures.60/switch_to_normal_user_system()
#     sge_procedures.60/switch_to_root_user_system()
#*******************************************************************************
proc switch_to_normal_user_system {} {
   global actual_user_system

   ts_log_info "Function not implemented"
   return 1

   if { $actual_user_system != "normal user system" } {
      ts_log_fine "switching from $actual_user_system to normal user system ..."
      set actual_user_system "normal user system"
   }
}

#****** sge_procedures.60/switch_execd_spool_dir() *****************************
#  NAME
#     switch_execd_spool_dir() -- switch execd spool directory
#
#  SYNOPSIS
#     switch_execd_spool_dir { host spool_type { force_restart 0 } } 
#
#  FUNCTION
#     This function will shutdown the execd running on $host, switch the
#     spool type depending on $spool_type if the spool directory doesn't
#     match. The optional parameter force_restart can be used to 
#     shutdown/restart the execd even when the spool directory is already
#     set to the correct value.
#
#  INPUTS
#     host                - host of execd
#     spool_type          - "cell", "local", "NFS-ROOT2NOBODY" or "NFS-ROOT2ROOT"
#     { force_restart 0 } - optional if 1: do shutdown/restart even when
#                           spool directory is already matching
#
#  RESULT
#     0 - on success
#
#  SEE ALSO
#     file_procedures/get_execd_spooldir()
#*******************************************************************************
proc switch_execd_spool_dir { host spool_type { force_restart 0 } } {
   global ts_config CHECK_USER

   set spool_dir [get_execd_spooldir $host $spool_type]
   set base_spool_dir [get_execd_spooldir $host $spool_type 1]

   if { [info exists execd_config] } {
      unset execd_config
   }
   if { [get_config execd_config $host] != 0 } {
      ts_log_severe "can't get configuration for host $host"
      return -1
   }

   if { $execd_config(execd_spool_dir) == $spool_dir && $force_restart == 0 } {
      ts_log_finest "spool dir is already set to $spool_dir"
      return 0
   }
   
   ts_log_fine "$host: actual spool dir: $execd_config(execd_spool_dir)"
   ts_log_fine "$host: new spool dir   : $spool_dir"
 
   delete_all_jobs
   wait_for_end_of_all_jobs 60

   shutdown_system_daemon $host execd

   ts_log_fine "changing execd_spool_dir for host $host ..."
   set execd_config(execd_spool_dir) $spool_dir
   set_config execd_config $host
   ts_log_fine "configuration changed for host $host!"

   ts_log_fine "checking base spool dir: $base_spool_dir"
   if { [ remote_file_isdirectory $host $base_spool_dir ] != 1 } {
      ts_log_fine "creating not existing base spool directory:\n\"$base_spool_dir\""
      remote_file_mkdir $host $base_spool_dir
      wait_for_remote_dir $ts_config(master_host) $CHECK_USER $base_spool_dir
   }

   ts_log_fine "cleaning up spool dir $spool_dir ..."
   cleanup_spool_dir_for_host $host $base_spool_dir "execd"
   

   startup_execd $host

   wait_for_load_from_all_queues 100

   return 0
}


#                                                             max. column:     |
#****** sge_procedures/startup_shadowd() ******
# 
#  NAME
#     startup_shadowd -- ??? 
#
#  SYNOPSIS
#     startup_shadowd { hostname } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     hostname - ??? 
#
#  RESULT
#     ??? 
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
#     sge_procedures/shutdown_core_system()
#     sge_procedures/shutdown_master_and_scheduler()
#     sge_procedures/shutdown_all_shadowd()
#     sge_procedures/shutdown_system_daemon()
#     sge_procedures/startup_qmaster()
#     sge_procedures/startup_execd()
#*******************************
proc startup_shadowd { hostname {env_list ""} } {
   global CHECK_ADMIN_USER_SYSTEM CHECK_USER
   get_current_cluster_config_array ts_config

   if {$env_list != ""} {
      upvar $env_list envlist
   }

   if { $CHECK_ADMIN_USER_SYSTEM == 0 } {  
      if { [have_root_passwd] != 0  } {
         ts_log_warning "no root password set or ssh not available"
         return -1
      }
      set startup_user "root"
   } else {
      set startup_user $CHECK_USER
   }

   ts_log_fine "starting up shadowd on host \"$hostname\" as user \"$startup_user\""

   set output [start_remote_prog "$hostname" "$startup_user" "$ts_config(product_root)/$ts_config(cell)/common/sgemaster" "-shadowd start" prg_exit_state 60 0 "" envlist]
   ts_log_fine $output
   if { [string first "starting sge_shadowd" $output] >= 0 } {
       if { [is_daemon_running $hostname "sge_shadowd"] == 1 } {
          return 0
       }
   }
   ts_log_severe "could not start shadowd on host $hostname:\noutput:\"$output\""
   return -1
}


#****** sge_procedures.60/check_shadowd_settings() *****************************
#  NAME
#     check_shadowd_settings() -- check if shadowd installation is supported
#
#  SYNOPSIS
#     check_shadowd_settings { shadowd_host } 
#
#  FUNCTION
#     This function is used to find out if the specified shadowd can be installed
#     with the current testsuite/host settings 
#
#  INPUTS
#     shadowd_host - name of shadowd host
#
#  RESULT
#     "" (empty string) if there are no problems
#     "some error text" - if there are problems
#*******************************************************************************
proc check_shadowd_settings { shadowd_host } {
   global CHECK_USER
   get_current_cluster_config_array ts_config
   set nr_shadowds [llength $ts_config(shadowd_hosts)]
   ts_log_fine "$nr_shadowds shadowd host configured ..." 

   set fine 0
   set test_host [resolve_host $shadowd_host]
   foreach sd_host $ts_config(shadowd_hosts) {
      set sd_res_host [resolve_host $sd_host]
      if { $sd_res_host == $test_host } {
         set fine 1
         break
      }
   }

   if { $fine != 1 } {
      return "shadowd host $shadowd_host not defined in shadowd_hosts list of testsuite"
   }

   # one shadow is ok on master host
   if { $nr_shadowds == 1 } {
      set shadowd_host [resolve_host $ts_config(shadowd_hosts)]
      set master_host [resolve_host $ts_config(master_host)]
      ts_log_fine "shadowd: $shadowd_host"
      ts_log_fine "master:  $master_host"
      if { $master_host == $shadowd_host } {
         return ""
      } else {
         return "shadowd_host is not master_host! Please alter your testsuite configuration!"
      }
   }

   # we have more than one shadow host
   if { $nr_shadowds >= 2 } {
      set heartbeat_file [get_qmaster_spool_dir]/heartbeat
      set qmaster_lock_file [get_qmaster_spool_dir]/lock
      set qmaster_messages_file [get_qmaster_spool_dir]/messages
      set act_qmaster_file "$ts_config(product_root)/$ts_config(cell)/common/act_qmaster"
      set sgemaster_file $ts_config(product_root)/$ts_config(cell)/common/sgemaster

      # read act qmaster file
      wait_for_remote_file $ts_config(master_host) $CHECK_USER $act_qmaster_file
      get_file_content $ts_config(master_host) $CHECK_USER $act_qmaster_file file_array
      set act_qmaster [string trim $file_array(1)]
      ts_log_fine "act_qmaster: \"$act_qmaster\""
      

      # read heartbeat file on qmaster host
      wait_for_remote_file $ts_config(master_host) $CHECK_USER $heartbeat_file
      get_file_content $ts_config(master_host) $CHECK_USER $heartbeat_file file_array
      set heartbeat1 [string trim $file_array(1)]
      set heartbeat1 [string trimleft $heartbeat1 "0"]
      ts_log_fine "heartbeat file read on host \"$ts_config(master_host)\": \"$heartbeat1\""

      # read heartbeat file on shadowd host
      wait_for_remote_file $test_host $CHECK_USER $heartbeat_file
      get_file_content $test_host $CHECK_USER $heartbeat_file file_array
      set heartbeat2 [string trim $file_array(1)]
      set heartbeat2 [string trimleft $heartbeat2 "0"]
      ts_log_fine "heartbeat file read on host \"$test_host\": \"$heartbeat2\""

      # diff the contents (allow max + 1)
      set heart_diff [expr ( $heartbeat2 - $heartbeat1 ) ]
      if { $heart_diff > 1 || $heart_diff < -1 } {
         return "heartbeat file diff error: heart_diff=$heart_diff - no nfs shared qmaster spool directory found"
      }

      # We need access to spooling data from shadow hosts, by
      # - classic spooling to a shared filesystem (to qmaster spooldir - if it was not shared,
      #   we would have failed earlier.
      # - bdb spooling with rpc server
      # - bdb spooling to nfsv4
      set spooling_ok 0
      if { $ts_config(spooling_method) == "classic" } {
         ts_log_fine "We have \"classic\" spooling to a shared qmaster spool dir."
         set spooling_ok 1
      } else {
         if {$ts_config(spooling_method) == "berkeleydb"} {
            if {$ts_config(bdb_server) != "none"} {
               ts_log_fine "We have \"berkeleydb\" spooling with RPC server." 
               set spooling_ok 1
            } else {
               set bdb_spooldir [get_bdb_spooldir]
               set fstype [fs_config_get_filesystem_type $bdb_spooldir $ts_config(master_host) 0]
               if {$fstype == "nfs4"} {
                  ts_log_fine "We have \"berkeleydb\" spooling on NFS v4" 
                  set spooling_ok 1

               }
            }
         }
      }

      if {!$spooling_ok} {
         return "Spooling database is not shared between master and shadow hosts"
      }
      return ""
   } 
   return "some magic error"
}


#                                                             max. column:     |
#****** sge_procedures/startup_execd() ******
# 
#  NAME
#     startup_execd -- ??? 
#
#  SYNOPSIS
#     startup_execd { hostname } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     hostname - ??? 
#
#  RESULT
#     ??? 
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
#     sge_procedures/shutdown_core_system()
#     sge_procedures/shutdown_master_and_scheduler()
#     sge_procedures/shutdown_all_shadowd()
#     sge_procedures/shutdown_system_daemon()
#     sge_procedures/startup_qmaster()
#     sge_procedures/startup_execd()
#     sge_procedures/startup_shadowd()
#*******************************
proc startup_execd { hostname {envlist ""}} {
   global CHECK_ADMIN_USER_SYSTEM CHECK_USER
   get_current_cluster_config_array ts_config

   upvar $envlist my_envlist

   if { $CHECK_ADMIN_USER_SYSTEM == 0 } { 
 
      if { [have_root_passwd] != 0  } {
         ts_log_warning "no root password set or ssh not available"
         return -1
      }
      set startup_user "root"
   } else {
      set startup_user $CHECK_USER
   }

   ts_log_fine "starting up execd on host \"$hostname\" as user \"$startup_user\""
   set output [start_remote_prog "$hostname" "$startup_user" "$ts_config(product_root)/$ts_config(cell)/common/sgeexecd" "start" prg_exit_state 60 0 "" my_envlist ]

   return 0
}

#****** sge_procedures/startup_execd_with_fd_limit() ************************
#  NAME
#     startup_execd_with_fd_limit() -- startup execution daemon
#
#  SYNOPSIS
#     startup_execd_with_fd_limit { host fd_limit {envlist ""} } 
#
#  FUNCTION
#     This procedure is used to startup an execution daemon of grid engine 
#     with special file descriptor limit settings.
#
#  INPUTS
#     host         - host where to start an execd
#     fd_limit     - file descriptor limit value
#     {envlist ""} - additional user environment variables to set
#
#  RESULT
#     The parsed output value of ulimit -Sn call which is the used
#     soft file descriptor limit setting before starting the execd.
#
#  SEE ALSO
#     sge_host/get_FD_SETSIZE_for_host()
#     sge_host/get_shell_fd_limit_for_host()
#     sge_procedures/startup_execd_with_fd_limit()
#*******************************************************************************
proc startup_execd_with_fd_limit { host fd_limit {envlist ""}} {
   global CHECK_ADMIN_USER_SYSTEM
   global CHECK_USER
   get_current_cluster_config_array ts_config
   upvar $envlist my_envlist

   set used_fd_limit -1
   set arch [resolve_arch $host]
   set execd_bin "$ts_config(product_root)/bin/$arch/sge_execd"


   if {$CHECK_ADMIN_USER_SYSTEM == 0} { 
      if {[have_root_passwd] != 0} {
         ts_log_warning "no root password set or ssh not available"
         return -1
      }
      set startup_user "root"
   } else {
      set startup_user $CHECK_USER
   }

   ts_log_fine "starting up execd on host \"$host\" as user \"$startup_user\" with file descriptor limit set to \"$fd_limit\" ..."
   
   set startup_arguments "-Hn $fd_limit ; ulimit -Sn $fd_limit ; echo \"--ulimit-output--\" ; ulimit -Sn ; $execd_bin ; sleep 2"
   set output [start_remote_prog "$host" "$startup_user" "ulimit" $startup_arguments prg_exit_state 60 0 $ts_config(product_root) my_envlist]

   if {$prg_exit_state != 0} {
      ts_log_severe "starting execd on host $host as user $startup_user returned $prg_exit_state\noutput:\n$output"
   }

   set found 0
   foreach line [split $output "\n"] {
      if {$found == 1} {
         set used_fd_limit [string trim $line]
         break
      }
      if {[string match "*--ulimit-output--*" $line]} {
         set found 1
      }
   }
   ts_log_fine "execd started with fd soft limit set to \"$used_fd_limit\""

   return $used_fd_limit
}

#                                                             max. column:     |
#****** sge_procedures/startup_bdb_rpc() ******
# 
#  NAME
#     startup_bdb_rpc -- ??? 
#
#  SYNOPSIS
#     startup_bdb_rpc { hostname } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     hostname - ??? 
#
#  RESULT
#     ??? 
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
#     sge_procedures/shutdown_core_system()
#     sge_procedures/shutdown_master_and_scheduler()
#     sge_procedures/shutdown_all_shadowd()
#     sge_procedures/shutdown_system_daemon()
#     sge_procedures/startup_qmaster()
#     sge_procedures/startup_execd()
#     sge_procedures/startup_shadowd()
#     sge_procedures/startup_bdb_rpc()
#*******************************
proc startup_bdb_rpc { hostname } {
   global CHECK_ADMIN_USER_SYSTEM CHECK_USER
   get_current_cluster_config_array ts_config

   if { $hostname == "none" } {
      return -1
   }

   if { $CHECK_ADMIN_USER_SYSTEM == 0 } {  
      if { [have_root_passwd] != 0  } {
         ts_log_warning "no root password set or ssh not available"
         return -1
      }
      set startup_user "root"
   } else {
      set startup_user $CHECK_USER
   }
 

   ts_log_fine "starting up BDB RPC Server on host \"$hostname\" as user \"$startup_user\""

   set output [start_remote_prog "$hostname" "$startup_user" "$ts_config(product_root)/$ts_config(cell)/common/sgebdb" "start"]
   ts_log_fine $output
   # give the bdb server a few seconds to fully initialize
   # starting sge_qmaster immediately after the bdb server can fail otherwise
   after 5000

   if { [string length $output] < 15  && $prg_exit_state == 0 } {
       return 0
   }
   ts_log_severe "could not start berkeley_db_svc on host $hostname:\noutput:\"$output\""
   return -1
}

#                                                             max. column:     |
#****** sge_procedures/get_urgency_job_info() ******
# 
#  NAME
#     get_urgency_job_info -- get urgency job information (qstat -urg)
#
#  SYNOPSIS
#     get_urgency_job_info { jobid {variable job_info} } 
#
#  FUNCTION
#     This procedure is calling the qstat (qstat -urg if sgeee) and returns
#     the output of the qstat in array form.
#
#  INPUTS
#     jobid               - job identifaction number
#     {variable job_info} - name of variable array to store the output
#     {do_replace_NA}     - 1 : if not set, don't replace NA settings
#
#  RESULT
#     0, if job was not found
#     1, if job was found
#     
#     fills array $variable with info found in qstat output with the following symbolic names:
#
#     job-ID prior nurg urg rrcontr wtcontr  dlcontr name  user state submit/start at
#     deadline queue slots ja-task-ID 

#
#  EXAMPLE
#  proc testproc ... { 
#     ...
#     if {[get_urgency_job_info $job_id] } {
#        if { $job_info(urg) < 10 } {
#           ...
#        }
#     } else {
#        ts_log_severe "get_urgency_job_info failed for job $job_id on host $host"
#     }
#     ...
#  }
#
#  SEE ALSO
#     sge_procedures/get_job_info()
#     sge_procedures/get_standard_job_info()
#     sge_procedures/get_extended_job_info()
#*******************************
proc get_urgency_job_info {jobid {variable job_info} { do_replace_NA 1 } } {
   get_current_cluster_config_array ts_config
   upvar $variable jobinfo
   set result [start_sge_bin "qstat" "-urg" ]
   if {$prg_exit_state == 0} {
      parse_qstat result jobinfo $jobid 2 $do_replace_NA
      return 1
   }
   return 0
}

# ADOC see sge_procedures/get_sge_error_generic()
proc get_sge_error_generic_vdep {messages_var} {
   upvar $messages_var messages

   # CSP errors
   lappend messages(index) "-100"
   set messages(-100) "*[translate_macro MSG_SEC_KEYFILENOTFOUND_S "*"]"

   # generic communication errors
   lappend messages(index) "-120"
   set messages(-120) "*[translate_macro MSG_GDI_UNABLE_TO_CONNECT_SUS "qmaster" "*" "*"]*"
   set messages(-120,description) "probably sge_qmaster is down"
}


#****** sge_procedures.60/drmaa_redirect_lib() *********************************
#  NAME
#     drmaa_redirect_lib() -- change drmaa lib version
#
#  SYNOPSIS
#     drmaa_redirect_lib { version host } 
#
#  FUNCTION
#     This function re-links the drmaa library for the specified host to
#     the specified version.
#
#  INPUTS
#     version           - "0.95" or "1.0"
#     host              - hostname
#
#  SEE ALSO
#     sge_procedures.60/get_current_drmaa_lib_extension()
#     sge_procedures.60/drmaa_redirect_lib()
#     sge_procedures.60/get_current_drmaa_mode()
#*******************************************************************************
proc drmaa_redirect_lib {version host} {
   global CHECK_USER ts_config
   ts_log_fine "Using DRMAA version $version on $host"

   set install_arch [resolve_arch $host]
   set lib_ext [get_current_drmaa_lib_extension $host]
   set fileserver_host [fs_config_get_server_for_path "$ts_config(product_root)/lib/$install_arch/"]

   # delete link on remote file server
   if {[is_remote_file $fileserver_host "root" "$ts_config(product_root)/lib/$install_arch/libdrmaa.$lib_ext"] == 1} {
      start_remote_prog $fileserver_host "root" "rm" "$ts_config(product_root)/lib/$install_arch/libdrmaa.$lib_ext"
   }
   # check if file exists on client side because of NFS timing issues
   if {[is_remote_file $host $CHECK_USER "$ts_config(product_root)/lib/$install_arch/libdrmaa.$lib_ext"] == 1} {
      # wait for link on client host to go away (because of timing issues)
      wait_for_remote_file $host $CHECK_USER "$ts_config(product_root)/lib/$install_arch/libdrmaa.$lib_ext" 120 1 1 
   }
   # create link on fileserver 
   start_remote_prog $fileserver_host "root" "ln" "-s $ts_config(product_root)/lib/$install_arch/libdrmaa.$lib_ext.$version $ts_config(product_root)/lib/$install_arch/libdrmaa.$lib_ext"

   # wait for link on client host
   wait_for_remote_file $host $CHECK_USER "$ts_config(product_root)/lib/$install_arch/libdrmaa.$lib_ext" 120

}

#****** sge_procedures.60/get_current_drmaa_mode() *****************************
#  NAME
#     get_current_drmaa_mode() -- return the current drmaa version string
#
#  SYNOPSIS
#     get_current_drmaa_mode { host } 
#
#  FUNCTION
#     Return the current linked drmaa library version string. 
#
#  INPUTS
#     host - hostname 
#
#  RESULT
#     string containting the version information from the libdrmaa link extention
#     (currently "0.95" or "1.0")
#
#  SEE ALSO
#     sge_procedures.60/get_current_drmaa_lib_extension()
#     sge_procedures.60/drmaa_redirect_lib()
#     sge_procedures.60/get_current_drmaa_mode()
#*******************************************************************************
proc get_current_drmaa_mode { host } {
   global ts_config
   ts_log_fine "checking DRMAA version on $host ..."
   
   set compile_arch [resolve_build_arch_installed_libs $host]
   set install_arch [resolve_arch $host]

   set files [get_file_names "$ts_config(product_root)/lib/$install_arch" "*drmaa*"]
   foreach file_base $files {
      set file "$ts_config(product_root)/lib/$install_arch/$file_base"
      set file_type [file type $file]
      ts_log_fine "$file_type: $file"
      if { $file_type == "link" } {
         set linked_to [file readlink $file]
         ts_log_fine "found drmaa lib link: $file_base -> $linked_to"
         ts_log_fine "lib is linked to $linked_to"
         set version_pos [string first "." $linked_to]
         incr version_pos 1
         set linked_to [string range $linked_to $version_pos end]
         set version_pos [string first "." $linked_to]
         incr version_pos 1
         set version [string range $linked_to $version_pos end ]
         ts_log_fine "version extension is \"$version\""
         return $version
      }
   }
}

#****** sge_procedures.60/get_current_drmaa_lib_extension() ********************
#  NAME
#     get_current_drmaa_lib_extension() -- get link extention name for the host
#
#  SYNOPSIS
#     get_current_drmaa_lib_extension { host } 
#
#  FUNCTION
#     Find out the host specific dynamic link extention (e.g. "so" or "dylib")
#
#  INPUTS
#     host - host for which the information is needed
#
#  RESULT
#     string containing the lib extention (e.g. "so")
#
#  SEE ALSO
#     sge_procedures.60/get_current_drmaa_lib_extension()
#     sge_procedures.60/drmaa_redirect_lib()
#     sge_procedures.60/get_current_drmaa_mode()
#*******************************************************************************
proc get_current_drmaa_lib_extension { host } {
   global ts_config
   set install_arch [resolve_arch $host]
   set files [get_file_names "$ts_config(product_root)/lib/$install_arch" "*drmaa*"]
   foreach file_base $files {
      set file "$ts_config(product_root)/lib/$install_arch/$file_base"
      set file_type [file type $file]
      if { $file_type == "link" } {
         set linked_to [file readlink $file]
         set version_pos [string first "." $linked_to]
         incr version_pos 1
         set linked_to [string range $linked_to $version_pos end]
         set version_pos [string first "." $linked_to]
         incr version_pos -1
         set lib_ext [string range $linked_to 0 $version_pos ]
         ts_log_fine "lib extension is \"$lib_ext\""
         return $lib_ext
      }
   }
}


# get_daemon_pid -- retrieves running daemon pid on remote host
proc get_daemon_pid { host service } {
   global CHECK_USER
   
   switch -exact $service {
      "master" -
      "qmaster" {
	 return [get_qmaster_pid $host [get_qmaster_spool_dir]]
      }
      "shadow" -
      "shadowd" {
	 return [get_shadowd_pid $host [get_qmaster_spool_dir]]
      }
      "execd" {
         return [get_execd_pid $host]
      }
      "bdb" {
	 ts_log_severe "NOT IMPLEMENTED"
      }
      "dbwriter" {
	 ts_log_severe "NOT IMPLEMENTED"
      }
      default {
	 ts_log_severe "Invalid service $service passed to get_daemon_pid{}"
      }
   }
}
#****** sge_procedures.60/shutdown_and_restart_qmaster() ********************
#  NAME
#     shutdown_and_restart_qmaster() -- Shutdown the qmaster and scheduler 
#     if possible 
#
#  SYNOPSIS
#     shutdown_and_restart_qmaster { host } 
#
#  FUNCTION
#     Shuts the qmaster and scheduler (if version >= 62) proc down and 
#     restarts it. 
#
#  INPUTS
#
#  RESULT
#     A newly restarted qmaster as side effect.
#
#  SEE ALSO
#     sge_procedures/shutdown_master_and_scheduler()
#     sge_procedures/startup_qmaster()   
#*******************************************************************************

proc shutdown_and_restart_qmaster { } {
   global ts_config

   shutdown_master_and_scheduler $ts_config(master_host) [get_qmaster_spool_dir]
   # startup qmaster with scheduler (if possible) 
   startup_qmaster 1       
}


proc call_startup_script { host service {script_file ""} {args ""} { timeout 30 } } {
   global ts_config CHECK_USER CHECK_ADMIN_USER_SYSTEM
   
   set ret 0
   
   if {[string compare $args "start"] == 0} {
      set msg "Starting"
   } elseif {[string compare $args "stop"] == 0} {
      set msg "Stopping"
   }
   
   if {[string length $script_file] == 0} {
      switch -exact $service {
         "master" -
         "qmaster" {
            set service "qmaster"
            set script_file "$ts_config(product_root)/$ts_config(cell)/common/sgemaster"
            set args "-$service $args"
         }
         "shadow" - 
         "shadowd" {
            set service "shadowd"
            set script_file "$ts_config(product_root)/$ts_config(cell)/common/sgemaster"
            set args "-$service $args"
         }
         "execd" -
         "bdb" -
         "dbwriter" {
            set script_file "$ts_config(product_root)/$ts_config(cell)/common/sge$service"
         }
         default {
	         ts_log_severe "Invalid service $service in smf_call_stop_script_and_restart{}"
         }
      }
   }
   
   if { $CHECK_ADMIN_USER_SYSTEM == 0 } { 
      if { [have_root_passwd] != 0  } {
         ts_log_warning "no root password set or ssh not available"
         return -1
      }
      set user "root"
   } else {
      set user $CHECK_USER
   }
   ts_log_fine "$msg $service: '$script_file $args' on host $host as user $user ..."
   set output [start_remote_prog $host $user "$script_file" "$args"]
   ts_log_fine "$output"
   if { $prg_exit_state != 0 } {
      ts_log_severe "Operation failed for $service service!"
      return -1
   }
   return 0
}
