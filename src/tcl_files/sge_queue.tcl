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

#****** sge_queue/set_queue_defaults() *****************************************
#  NAME
#     set_queue_defaults() -- create version dependent queue settings
#
#  SYNOPSIS
#     set_queue_defaults {change_array}
#
#  FUNCTION
#     Fills the array change_array with queue attributes for the specific 
#     version of SGE.
#
#  INPUTS
#     change_array - the resulting array
#
#*******************************************************************************
proc set_queue_defaults { change_array } {
   get_current_cluster_config_array ts_config
   upvar $change_array chgar

   set chgar(qname)                "template"
   set chgar(seq_no)               "0"
   set chgar(load_thresholds)      "np_load_avg=1.75"
   set chgar(suspend_thresholds)   "NONE"
   set chgar(nsuspend)             "1"
   set chgar(suspend_interval)     "00:05:00"
   set chgar(priority)             "0"
   set chgar(min_cpu_interval)     "00:05:00"
   set chgar(processors)           "UNDEFINED"
   set chgar(rerun)                "FALSE"
   set chgar(slots)                "1"
   set chgar(tmpdir)               "/tmp"
   set chgar(shell)                "/bin/csh"
   set chgar(prolog)               "NONE"
   set chgar(epilog)               "NONE"
   set chgar(starter_method)       "NONE"
   set chgar(suspend_method)       "NONE"
   set chgar(resume_method)        "NONE"
   set chgar(terminate_method)     "NONE"
   set chgar(notify)               "00:00:60"
   set chgar(owner_list)           "NONE"
   set chgar(user_lists)           "NONE"
   set chgar(xuser_lists)          "NONE"
   set chgar(subordinate_list)     "NONE"
   set chgar(complex_values)       "NONE"
   set chgar(calendar)             "NONE"
   set chgar(initial_state)        "default"
   set chgar(s_rt)                 "INFINITY"
   set chgar(h_rt)                 "INFINITY"
   set chgar(s_cpu)                "INFINITY"
   set chgar(h_cpu)                "INFINITY"
   set chgar(s_fsize)              "INFINITY"
   set chgar(h_fsize)              "INFINITY"
   set chgar(s_data)               "INFINITY"
   set chgar(h_data)               "INFINITY"
   set chgar(s_stack)              "INFINITY"
   set chgar(h_stack)              "INFINITY"
   set chgar(s_core)               "INFINITY"
   set chgar(h_core)               "INFINITY"
   set chgar(s_rss)                "INFINITY"
   set chgar(h_rss)                "INFINITY"
   set chgar(s_vmem)               "INFINITY"
   set chgar(h_vmem)               "INFINITY"
  
   # SGE version dependent defaults
   if { $ts_config(gridengine_version) == 53 } {
      set chgar(hostlist)             "unknown"
      set chgar(qtype)                "BATCH INTERACTIVE PARALLEL" 
      set chgar(shell_start_mode)     "NONE"
      set chgar(complex_list)         "NONE"
      if { $ts_config(product_type) == "sgeee" } {
         set chgar(fshare)            "0"
         set chgar(oticket)           "0"
      }
   } elseif { $ts_config(gridengine_version) >= 60 } {
      set chgar(hostlist)             "NONE"
      set chgar(qtype)                "BATCH INTERACTIVE" 
      set chgar(ckpt_list)            "NONE"
      set chgar(pe_list)              "make"
      set chgar(shell_start_mode)     "posix_compliant"
   }
   
   if { $ts_config(product_type) == "sgeee" } {
      set chgar(projects)           "NONE"
      set chgar(xprojects)          "NONE"
   }

}

#****** sge_queue/set_lab_defaults() *******************************************
#  NAME
#     set_lab_defaults() -- adjust the default queue settings
#
#  SYNOPSIS
#     set_lab_defaults {change_array}
#
#  FUNCTION
#     Adjust the default queue settings needed to run the tests in our lab 
#     properly.
#
#  INPUTS
#     change_array - the resulting array
#
#*******************************************************************************
proc set_lab_defaults {change_array} {
   get_current_cluster_config_array ts_config
   upvar $change_array chgar
   
   set chgar(load_thresholds)      "np_load_avg=7.00"
   set chgar(slots)                "10"

}

#****** sge_queue/validate_queue() *********************************************
#  NAME
#     validate_queue() -- validate the queue settings
#
#  SYNOPSIS
#     validate_queue {change_array}
#
#  FUNCTION
#     Validate the queue settings. Adjust the queue settings according to sge 
#     version.
#
#  INPUTS
#     change_array - the resulting array
# 
#*******************************************************************************
proc validate_queue {change_array} {
   get_current_cluster_config_array ts_config
   upvar $change_array chgar
   
   # create cluster dependent tmpdir
   set chgar(tmpdir)               "/tmp/testsuite_$ts_config(commd_port)"

   vdep_validate_queue chgar

}

#****** sge_queue/add_queue() **************************************************
# 
#  NAME
#     add_queue -- Add a new queue configuration object
#
#  SYNOPSIS
#     add_queue {qname hostlist {change_array ""} {fast_add 1} {on_host ""} 
#     {as_user ""} {raise_error 1}} 
#
#  FUNCTION
#     Add a new queue configuration object corresponding to the content of 
#     the change_array.
#     Supports fast (qconf -Aq) and slow (qconf -aq) mode.
#
#  INPUTS
#     q_name        - queue name
#     hostlist      - the list of hosts
#     {change_array ""} - the queue description
#     {fast_add 1}    - use fast mode
#     {on_host ""}    - execute qconf on this host (default: qmaster host)
#     {as_user ""}    - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1} - raise error condition in case of errors?
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_project/get_queue_messages()
#*******************************************************************************
proc add_queue {qname hostlist {change_array ""} {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
   get_current_cluster_config_array ts_config

   upvar $change_array chgar

   if { $ts_config(gridengine_version) == 53 } {
      # non cluster queue: set queue and hostnames
      if { $hostlist == "@allhosts" || $hostlist == "" || $hostlist == "NONE" } {
         set hostlist $ts_config(execd_nodes)
         foreach host $hostlist {
            set cqueue [get_queue_instance ${qname} ${host}]
            set ret [add_queue $cqueue $host chgar $fast_add $on_host $as_user $raise_error]
         }
         return $ret
      }
   }

   set chgar(qname)     "$qname"
   set chgar(hostlist) $hostlist
   validate_queue chgar

   get_queue_messages messages "add" "$qname" $on_host $as_user
   
   if { $fast_add } {
      ts_log_fine "Add queue $chgar(qname) for hostlist $chgar(hostlist) from file ..."
      set option "-Aq"
      set_queue_defaults default_array
      set_lab_defaults default_array
      update_change_array default_array chgar
      set tmpfile [dump_array_to_tmpfile default_array]
      set result [start_sge_bin "qconf" "-Aq ${tmpfile}" $on_host $as_user]

   } else {
      ts_log_fine "Add queue $chgar(qname) for hostlist $chgar(hostlist) slow ..."
      set option "-aq"
      set vi_commands [build_vi_command chgar]
      set result [start_vi_edit "qconf" "-aq" $vi_commands messages $on_host $as_user]

   }

   return [handle_sge_errors "add_queue" "qconf $option" $result messages $raise_error]
}


#****** sge_queue/mod_queue() **************************************************
#  NAME
#     mod_queue() -- modify existing queue configuration object
#
#  SYNOPSIS
#     mod_queue { qname hostslist hange_array {fast_add 1} {on_host ""} 
#    {as_user ""} {raise_error 1}}
#
#  FUNCTION
#     Modify the queue $qname in the Grid Engine cluster.
#     Supports fast (qconf -Mq) and slow (qconf -mq) mode.
#
#  INPUTS
#     qname        - name of the (cluster) queue
#     hostlist     - the list of hosts
#     change_array - array containing the changed attributes.
#     {fast_add 1}     - use fast mode
#     {on_host ""}     - execute qconf on this host, default is master host
#     {as_user ""}     - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1}  - raise error condition?
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_queue/get_queue_messages()
#*******************************************************************************
proc mod_queue { qname hostlist change_array {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
  get_current_cluster_config_array ts_config

  upvar $change_array chgar

  if { $ts_config(gridengine_version) == 53 && ![string match "*@*" $qname] } {
      if { $hostlist == "@allhosts" || $hostlist == "" || $hostlist == "NONE" } {
         set hostlist $ts_config(execd_nodes)
         foreach host $hostlist {
            set cqueue [get_queue_instance ${qname} ${host}]
            set ret [mod_queue $cqueue $host chgar $fast_add $on_host $as_user $raise_error]
         }
         # aja: TODO: what to return?
         return $ret
      }
   }

   set chgar(qname) "$qname"
   validate_queue chgar

   get_queue_messages messages "mod" "$qname" $on_host $as_user
     
   if { $fast_add } {
      ts_log_fine "Modify queue $qname for hostlist $hostlist from file ..."
      # aja: TODO: suppress all messages coming from the procedure
      get_queue "$qname" curr_arr "" "" 0
      if {![info exists curr_arr]} {
         set_queue_defaults curr_arr
     }
      # aja: TODO: is this okay? procedures not checked
      if { $ts_config(gridengine_version) >= 60 } {
         if {[llength $hostlist] == 0} {
            set_cqueue_default_values curr_arr chgar
         } else {
            set_cqueue_specific_values curr_arr chgar $hostlist
         }
      } else {
         set chgar(hostlist) "$hostlist"
      }

      update_change_array curr_arr chgar

      set tmpfile [dump_array_to_tmpfile curr_arr]  
      set output [start_sge_bin "qconf" "-Mq $tmpfile" $on_host $as_user]
      set ret [handle_sge_errors "mod_queue" "qconf -Mq $qname" $output messages $raise_error]

   } else {
      ts_log_fine "Modify queue $qname for hostlist $hostlist slow ..."
      set vi_commands [build_vi_command chgar]
      set chgar(hostlist) $hostlist
      # BUG: different message for "vi" from fastadd ...
      set NOT_EXISTS [translate_macro MSG_CQUEUE_DOESNOTEXIST_S "$qname"]
      add_message_to_container messages -1 $NOT_EXISTS
      set result [start_vi_edit "qconf" "-mq $qname" $vi_commands messages $on_host $as_user]
      set ret [handle_sge_errors "mod_queue" "qconf -mq $qname" $result messages $raise_error]
   }
   return $ret
}

#****** sge_queue/del_queue() **************************************************
# 
#  NAME
#     del_queue -- delete queue configuration object
#
#  SYNOPSIS
#     del_queue { q_name hostlist {on_host ""} {as_user ""} {raise_error 1} } 
#
#  FUNCTION
#     remove a queue from the qmaster configuration
#
#  INPUTS
#     q_name - name of the queue to delete
#     {on_host ""}     - execute qconf on this host (default: qmaster host)
#     {as_user ""}     - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1}  - raise error condition in case of errors?
#
#  RESULT
#       0 - success
#     < 0 - error
#
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_queue/get_queue_messages()
#*******************************************************************************
# aja TODO: create procedure del_queue {qname hostlist {on_host ""} {as_user ""} {raise_error 1}}

#****** sge_procedures/get_queue() *********************************************
# 
#  NAME
#     get_queue -- get queue configuration information
#
#  SYNOPSIS
#     get_queue { q_name {output_var result} {on_host ""} {as_user ""} 
#    {raise_error 1} } 
#
#  FUNCTION
#     Get the actual configuration settings for the named queue
#     Represents qconf -sq command in SGE
#
#  INPUTS
#     q_name       - name of the queue
#     {output_var result} - result will be placed here
#     {on_host ""}        - execute qconf on this host (default: qmaster host)
#     {as_user ""}        - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1}     - raise error condition in case of errors?
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_queue/get_queue_messages()
#*******************************************************************************
proc get_queue { q_name {output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   ts_log_fine "Get queue $q_name ..."

   upvar $output_var out

   get_queue_messages messages "get" "$q_name" $on_host $as_user
   
   return [get_qconf_object "get_queue" "-sq $q_name" out messages 0 $on_host $as_user $raise_error]

}

#                                                             max. column:     |
#****** sge_queue/suspend_queue() ******
# 
#  NAME
#     suspend_queue -- set a queue in suspend mode
#
#  SYNOPSIS
#     suspend_queue { qname } 
#
#  FUNCTION
#     This procedure will set the given queue into suspend state
#
#  INPUTS
#     qname - name of the queue to suspend 
#
#  RESULT
#     0  - ok
#    -1  - error 
#
#  SEE ALSO
#     sge_procedures/mqattr()
#     sge_procedures/set_queue() 
#     sge_procedures/add_queue()
#     sge_procedures/del_queue()
#     sge_procedures/get_queue()
#     sge_procedures/suspend_queue()
#     sge_procedures/unsuspend_queue()
#     sge_procedures/disable_queue()
#     sge_procedures/enable_queue()
#*******************************
proc suspend_queue { qname } {
  global CHECK_USER
  get_current_cluster_config_array ts_config
  log_user 0 
   if { $ts_config(gridengine_version) == 53 } {
      set WAS_SUSPENDED [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_QUEUE_SUSPENDQ_SSS] "*" "*" "*" ]
   } else {
      set WAS_SUSPENDED [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_QINSTANCE_SUSPENDED]]
   }

  
  # spawn process
  set master_arch [resolve_arch $ts_config(master_host)]
  set program "$ts_config(product_root)/bin/$master_arch/qmod"
  set sid [open_remote_spawn_process $ts_config(master_host) $CHECK_USER $program "-s $qname"]
  set sp_id [ lindex $sid 1 ]
  set result -1	

  log_user 0
  set timeout 30
  expect {
     -i $sp_id full_buffer {
         set result -1
         ts_log_severe "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
     }
     -i $sp_id "was suspended" {
         set result 0
     }
      -i $sp_id "*${WAS_SUSPENDED}*" {
         set result 0
     }

	  -i $sp_id default {
         ts_log_fine $expect_out(buffer)
	      set result -1
	  }
  }
  # close spawned process 
  close_spawn_process $sid
  log_user 1
  if { $result != 0 } {
     ts_log_severe "could not suspend queue \"$qname\""
  }

  return $result
}

#                                                             max. column:     |
#****** sge_queue/unsuspend_queue() ******
# 
#  NAME
#     unsuspend_queue -- set a queue in suspend mode
#
#  SYNOPSIS
#     unsuspend_queue { queue } 
#
#  FUNCTION
#     This procedure will set the given queue into unsuspend state
#
#  INPUTS
#     queue - name of the queue to set into unsuspend state
#
#  RESULT
#     0  - ok
#    -1  - error 
#
#  SEE ALSO
#     sge_procedures/mqattr()
#     sge_procedures/set_queue() 
#     sge_procedures/add_queue()
#     sge_procedures/del_queue()
#     sge_procedures/get_queue()
#     sge_procedures/suspend_queue()
#     sge_procedures/unsuspend_queue()
#     sge_procedures/disable_queue()
#     sge_procedures/enable_queue()
#*******************************
proc unsuspend_queue { queue } {
   global CHECK_USER
   get_current_cluster_config_array ts_config

  set timeout 30
  log_user 0 
   
   if { $ts_config(gridengine_version) == 53 } {
      set UNSUSP_QUEUE [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_QUEUE_UNSUSPENDQ_SSS] "*" "*" "*" ]
   } else {
      set UNSUSP_QUEUE [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_QINSTANCE_NSUSPENDED]]
   }

  # spawn process
  set master_arch [resolve_arch $ts_config(master_host)]
  set program "$ts_config(product_root)/bin/$master_arch/qmod"
  set sid [open_remote_spawn_process $ts_config(master_host) $CHECK_USER $program "-us $queue"]
  set sp_id [ lindex $sid 1 ]
  set result -1	
  log_user 0 

  set timeout 30
  expect {
      -i $sp_id full_buffer {
         set result -1
         ts_log_severe "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
      }
      -i $sp_id "unsuspended queue" {
         set result 0 
      }
      -i $sp_id  "*${UNSUSP_QUEUE}*" {
         set result 0 
      }
      -i $sp_id default {
         ts_log_fine $expect_out(buffer) 
         set result -1 
      }
  }
  # close spawned process 
  close_spawn_process $sid
  log_user 1   
  if { $result != 0 } {
     ts_log_severe "could not unsuspend queue \"$queue\""
  }
  return $result
}

#                                                             max. column:     |
#****** sge_queue/disable_queue() ******
# 
#  NAME
#     disable_queue -- disable queues
#
#  SYNOPSIS
#     disable_queue { queue } 
#
#  FUNCTION
#     Disable the given queue/queue list
#
#  INPUTS
#     queue - name of queues to disable
#
#  RESULT
#     0  - ok
#    -1  - error
#
#  SEE ALSO
#     sge_procedures/mqattr()
#     sge_procedures/set_queue() 
#     sge_procedures/add_queue()
#     sge_procedures/del_queue()
#     sge_procedures/get_queue()
#     sge_procedures/suspend_queue()
#     sge_procedures/unsuspend_queue()
#     sge_procedures/disable_queue()
#     sge_procedures/enable_queue()
#*******************************
proc disable_queue { queuelist } {
  global CHECK_USER
  get_current_cluster_config_array ts_config
  
  set return_value ""
  # spawn process

  set nr_of_queues 0
  set nr_disabled 0

  foreach elem $queuelist {
     set queue_name($nr_of_queues) $elem
     incr nr_of_queues 1
  }

  set queue_nr 0
  while { $queue_nr != $nr_of_queues } {
     log_user 0
     set queues ""
     set i 100  ;# maximum 100 queues at one time (= 2000 byte commandline with avg(len(qname)) = 20
     while { $i > 0 } {
        if { $queue_nr < $nr_of_queues } {
           append queues " $queue_name($queue_nr)"
           incr queue_nr 1
        }
        incr i -1
     }   
     
     set result [start_sge_bin "qmod" "-d $queues"]
     ts_log_fine "disable queue(s) $queues"
     set res_split [ split $result "\n" ]   
     foreach elem $res_split {
        ts_log_fine "line: $elem"
        if { [ string first "has been disabled" $elem ] >= 0 } {
           incr nr_disabled 1 
        } else {
           # try to find localized output
           foreach q_name $queues {
              if { $ts_config(gridengine_version) == 53 } {
                set HAS_DISABLED [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_QUEUE_DISABLEQ_SSS] $q_name $CHECK_USER "*" ]
              } else {
                set HAS_DISABLED [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_QINSTANCE_DISABLED]]
              }

              if { [ string match "*${HAS_DISABLED}*" $elem ] } {
                 incr nr_disabled 1
                 break
              } 
           }
        }
     }
  }    

  if { $nr_of_queues != $nr_disabled } {
     ts_log_severe "could not disable all queues"
     return -1
  }
 
  return 0
}


#                                                             max. column:     |
#****** sge_queue/enable_queue() ******
# 
#  NAME
#     enable_queue -- enable queuelist
#
#  SYNOPSIS
#     enable_queue { queue } 
#
#  FUNCTION
#     This procedure enables a given queuelist by calling the qmod -e binary
#
#  INPUTS
#     queue - name of queues to enable (list)
#
#  RESULT
#     0  - ok
#    -1  - on error
#
#  SEE ALSO
#     sge_procedures/mqattr()
#     sge_procedures/set_queue() 
#     sge_procedures/add_queue()
#     sge_procedures/del_queue()
#     sge_procedures/get_queue()
#     sge_procedures/suspend_queue()
#     sge_procedures/unsuspend_queue()
#     sge_procedures/disable_queue()
#     sge_procedures/enable_queue()
#*******************************
proc enable_queue { queuelist } {
  global CHECK_USER
  get_current_cluster_config_array ts_config
  
  set return_value ""
  # spawn process

  set nr_of_queues 0
  set nr_enabled 0

  foreach elem $queuelist {
     set queue_name($nr_of_queues) $elem
     incr nr_of_queues 1
  }

  set queue_nr 0
  while { $queue_nr != $nr_of_queues } {
     log_user 0
     set queues ""
     set i 100  ;# maximum 100 queues at one time (= 2000 byte commandline with avg(len(qname)) = 20
     while { $i > 0 } {
        if { $queue_nr < $nr_of_queues } {
           append queues " $queue_name($queue_nr)"
           incr queue_nr 1
        }
        incr i -1
     }   
     set result [start_sge_bin "qmod" "-e $queues"]
     ts_log_fine "enable queue(s) $queues"
     set res_split [ split $result "\n" ]   
     foreach elem $res_split {
        ts_log_fine "line: $elem"
        if { [ string first "has been enabled" $elem ] >= 0 } {
           incr nr_enabled 1 
        } else {
           # try to find localized output
           foreach q_name $queues {
              if { $ts_config(gridengine_version) == 53 } {
                 set BEEN_ENABLED  [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_QUEUE_ENABLEQ_SSS] $q_name $CHECK_USER "*" ]
              } else {
                 set BEEN_ENABLED  [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_QINSTANCE_NDISABLED]]
              }
              if { [ string match "*${BEEN_ENABLED}*" $elem ] } {
                 incr nr_enabled 1
                 break
              } 
           }
        }
     }
  }    

  if { $nr_of_queues != $nr_enabled } {
     ts_log_severe "could not enable all queues nr. queues: $nr_of_queues, nr_enabled: $nr_enabled"
     return -1
  }
  return 0
}


#                                                             max. column:     |
#****** sge_queue/get_queue_state() ******
# 
#  NAME
#     get_queue_state -- get the state of a queue
#
#  SYNOPSIS
#     get_queue_state { queue } 
#
#  FUNCTION
#     This procedure returns the state of the queue by parsing output of qstat -f. 
#
#  INPUTS
#     queue - name of the queue
#
#  RESULT
#     The return value can contain more than one state. Here is a list of possible
#     states:
#
#     u(nknown)
#     a(larm)
#     A(larm)
#     C(alendar  suspended)
#     s(uspended)
#     S(ubordinate)
#     d(isabled)
#     D(isabled)
#     E(rror)
#
#*******************************
proc get_queue_state { queue_name } {
  get_current_cluster_config_array ts_config

  # resolve the queue name
  set queue [resolve_queue $queue_name]
  set result [start_sge_bin "qstat" "-f -q $queue"]
  if {$prg_exit_state != 0} {
     ts_log_severe "qstat -f -q $queue failed:\n$result"
     return ""
  }

  # split each line as listelement
  set back ""
  set help [split $result "\n"]
  foreach line $help { 
      if {[string compare [lindex $line 0] $queue] == 0} {
         set back [lindex $line 5]
         return $back
      }
  }

  ts_log_severe "queue \"$queue\" not found" 
  return ""
}

#****** sge_queue/clear_queue() *****************************************
#  NAME
#     clear_queue() -- clear queue $queue
#
#  SYNOPSIS
#     clear_queue { queue {output_var result} {on_host ""} {as_user ""} {raise_error 1}  }
#
#  FUNCTION
#     Calls qconf -cq $queue to clear queue $queue
#
#  INPUTS
#     output_var      - result will be placed here
#     queue           - queue to be cleared
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - raise an error condition on error (default), or just
#                       output the error message to stdout
#
#  RESULT
#     0 on success, an error code on error.
#     For a list of error codes, see sge_procedures/get_sge_error().
#
#  SEE ALSO
#     sge_calendar/get_calendar()
#     sge_calendar/get_calendar_error()
#*******************************************************************************
proc clear_queue {queue {output_var result}  {on_host ""} {as_user ""} {raise_error 1}} {

   upvar $output_var out

   # clear output variable
   if {[info exists out]} {
      unset out
   }

   set ret 0
   set result [start_sge_bin "qconf" "-cq $queue" $on_host $as_user]

   # parse output or raise error
   if {$prg_exit_state == 0} {
      parse_simple_record result out
   } else {
      set ret [clear_queue_error $result $queue $raise_error]
   }

   return $ret

}
#****** sge_queue/clear_queue_error() ***************************************
#  NAME
#     clear_queue_error() -- error handling for clear_queue
#
#  SYNOPSIS
#     clear_queue_error { result queue raise_error }
#
#  FUNCTION
#     Does the error handling for clear_queue.
#     Translates possible error messages of qconf -cq,
#     builds the datastructure required for the handle_sge_errors
#     function call.
#
#     The error handling function has been intentionally separated from
#     clear_queue. While the qconf call and parsing the result is
#     version independent, the error messages (macros) usually are version
#     dependent.
#
#  INPUTS
#     result      - qconf output
#     queue       - queue for which qconf -cq has been called
#     raise_error - raise error condition?
#
#  RESULT
#     Returncode for clear_queue function:
#      -1:  invalid queue or job "queue"
#     -99: other error
#
#  SEE ALSO
#     sge_calendar/get_calendar
#     sge_procedures/handle_sge_errors
#*******************************************************************************
proc clear_queue_error {result queue raise_error} {

   # recognize certain error messages and return special return code
   set messages(index) "-1 "
   set messages(-1) [translate_macro MSG_QUEUE_INVALIDQORJOB_S $queue]

   # we might have version dependent, calendar specific error messages
   get_clear_queue_error_vdep messages $queue

   set ret 0
   # now evaluate return code and raise errors
   set ret [handle_sge_errors "get_calendar" "qconf -cq $queue" $result messages $raise_error]

   return $ret
}

#****** sge_queue/get_queue_list() *********************************************
#  NAME
#     get_queue_list() -- get a list of all queues
#
#  SYNOPSIS
#     get_queue_list { {output_var result} {on_host ""} {as_user ""} {raise_error 1}
#
#  FUNCTION
#     Calls qconf -sql to retrieve the list of all queues
#
#  INPUTS
#     {output_var result} - result will be placed here
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - raise an error condition on error (default), or just
#                       output the error message to stdout
#
#  RESULT
#     0 on success, an error code on error.
#     For a list of error codes, see sge_procedures/get_sge_error().
#
#  SEE ALSO
#     sge_procedures/get_sge_error()
#     sge_procedures/get_qconf_list()
#*******************************************************************************
proc get_queue_list {{output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   ts_log_fine "Get queue list ..."

   upvar $output_var out

   get_queue_messages messages "list" "" $on_host $as_user 
   
   return [get_qconf_object "get_queue_list" "-sql" out messages 1 $on_host $as_user $raise_error]

}

#****** sge_queue/get_queue_messages() *************************************
#  NAME
#     get_queue_messages() -- returns the set of messages related to action 
#                              on queue, i.e. add, modify, delete, get
#
#  SYNOPSIS
#     get_queue_messages {msg_var action obj_name result {on_host ""} {as_user ""}} 
#
#  FUNCTION
#     Returns the set of messages related to action on sge queue. This function
#     is a wrapper of sge_object_messages which is general for all types of objects
#
#  INPUTS
#     msg_var       - array of messages (the pair of message code and message value)
#     action        - action examples: add, modify, delete,...
#     obj_name      - sge object name
#     {on_host ""}  - execute on this host, default is master host
#     {as_user ""}  - execute qconf as this user, default is $CHECK_USER
#
#  SEE ALSO
#     sge_procedures/sge_client_messages()
#*******************************************************************************
proc get_queue_messages {msg_var action obj_name {on_host ""} {as_user ""}} {
   get_current_cluster_config_array ts_config

   upvar $msg_var messages
   if { [info exists messages]} {
      unset messages
   }

   if {$ts_config(gridengine_version) == 53} {
      set QUEUE [translate_macro MSG_OBJ_QUEUE]
   } else {
      # CD: why don't we have "cluster queue" in $SGE_OBJ_CQUEUE ?
      set QUEUE "cluster [translate_macro MSG_OBJ_QUEUE]"
   }
     
   # set the expected client messages
   sge_client_messages messages $action $QUEUE $obj_name $on_host $as_user
   
   # the place for exceptions: # VD version dependent  
   #                           # CD client dependent
   # see sge_procedures/sge_client_messages
   switch -exact $action {
      "add" {
         add_message_to_container messages -4 "error: [translate_macro MSG_ULONG_INCORRECTSTRING "*"]"
         add_message_to_container messages -5 [translate_macro MSG_CQUEUE_UNKNOWNUSERSET_S "*"]
         add_message_to_container messages -6 [translate_macro MSG_HGRP_UNKNOWNHOST "*" ]
      }
      "get" {
         add_message_to_container messages -1 [translate_macro MSG_CQUEUE_NOQMATCHING_S "$obj_name"]
      }
      "mod" {
         add_message_to_container messages -5 "error: [translate_macro MSG_ULONG_INCORRECTSTRING "*"]"
         add_message_to_container messages -6 [translate_macro MSG_CQUEUE_UNKNOWNUSERSET_S "*"]
         add_message_to_container messages -7 [translate_macro MSG_HGRP_UNKNOWNHOST "*" ]
         if {$ts_config(gridengine_version) >= 62} {
            #AP: TODO: find the parameters for this message:
            set AR_REJECTED_SSU [translate_macro MSG_PARSE_MOD_REJECTED_DUE_TO_AR_SSU "*" "*"]
            set AR_REJECTED_SU [translate_macro MSG_PARSE_MOD3_REJECTED_DUE_TO_AR_SU "*" "*"]
            set SLOT_RESERVED [translate_macro MSG_QINSTANCE_SLOTSRESERVED_USS "*" "*" "*"]
            add_message_to_container messages -8 $AR_REJECTED_SSU
            add_message_to_container messages -9 $AR_REJECTED_SU
            add_message_to_container messages -10 $SLOT_RESERVED
         }
      }
      "del" {
      }
      "list" {
         set NOT_DEFINED [translate_macro MSG_QCONF_NOXDEFINED_S "cqueue list"]
         add_message_to_container messages -1 $NOT_DEFINED
      }
   } 
}


