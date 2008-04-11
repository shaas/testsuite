#!/vol2/TCL_TK/glinux/bin/expect
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

proc get_sge_smf_cmd {} {
  global ts_config

  return "SGE_ROOT=$ts_config(product_root); export SGE_ROOT;\
SGE_CELL=$ts_config(cell); export SGE_CELL;\
cd $ts_config(product_root)/util/sgeSMF; ./sge_smf.sh"
}

proc get_all_smf_hosts {} {
   global ts_config CHECK_USER

   set smf_hosts ""
   set hosts [get_all_hosts]
   foreach host $hosts {
      start_remote_prog $host $CHECK_USER "/bin/sh" "-c [get_sge_smf_cmd] supported" prg_exit_state
      if { $prg_exit_state == 0 } {
         lappend smf_hosts $host
      }
   }
   return [lsort -unique $smf_hosts]
}

proc has_smf_hosts {} {
   set smf_hosts [get_all_smf_hosts]
   if {[llength $smf_hosts] == 0} {
      ts_log_finer "No SMF capable host in your configuration"
   }
}

proc get_smf_hosts { {num_hosts 1} } {
   set smf_hosts [get_all_smf_hosts]
   if {[llength $smf_hosts] < $num_hosts} {
      ts_log_severe "Not enough SMF capable hosts in your configuration. Found [llength $smf_hosts]. Needed $num_hosts."
   }

   #TODO: Better selection mechanism
   return [lrange $smf_hosts 0 $num_hosts-1]
}

proc is_smf_host { host } {
   set smf_hosts [get_all_smf_hosts]
   if { [lsearch -exact $smf_hosts $host] == -1 } {
      return 0
   }
   return 1;
}

proc smf_service_exists {host service} {
   global ts_config CHECK_USER

   set fmri [get_sge_fmri $host $service 0]
   start_remote_prog $host $CHECK_USER "/usr/bin/svcs" "-H $fmri"
   return $prg_exit_state
}

proc start_smf_service {host service {exit_var prg_exit_state}} {
   upvar $exit_var back_exit_state
   global ts_config CHECK_USER

   set fmri [get_sge_fmri $host $service]
   if {[string length $fmri] == 0} {
      set back_exit_state 1
      return "-service_missing-"
   }

   ts_log_fine "Starting $service:$ts_config(cluster_name) on host $host as user root ..."
   set output [start_remote_prog $host "root" "/usr/sbin/svcadm" "enable -st $fmri" back_exit_state]
   if { $back_exit_state != 0 } {
      return ""
   }
   ts_log_fine "pid=[smf_get_pid $host $service]"
   return $output
}

proc stop_smf_service {host service {exit_var prg_exit_state}} {
   upvar $exit_var back_exit_state
   global ts_config CHECK_USER

   set fmri [get_sge_fmri $host $service]
   if {[string length $fmri] == 0} {
      set back_exit_state 1
      return "-service_missing-"
   }

   ts_log_fine "Stopping $service:$ts_config(cluster_name) on host $host as user root ..."
   set output [start_remote_prog $host "root" "/usr/sbin/svcadm" "disable -st $fmri" back_exit_state]
   if { $back_exit_state != 0 } {
      return ""
   }
   ts_log_finest "pid=[smf_get_pid $host $service]"
   return $output
}

proc is_smf_service_state { host service state {exit_var prg_exit_state} } {
   upvar $exit_var back_exit_state
   global ts_config CHECK_USER

   set fmri [get_sge_fmri $host $service]
   if {[string length $fmri] == 0} {
      set back_exit_state 1
      return "false"
   }
   set output [get_smf_service_state $host $service back_exit_state]
   if {[string compare $state $output] == 0} {
      return "true"
   }
   return "false"
}


proc get_smf_service_state { host service {exit_var prg_exit_state} } {
   upvar $exit_var back_exit_state
   global ts_config CHECK_USER

   set fmri [get_sge_fmri $host $service]
   if {[string length $fmri] == 0} {
      set back_exit_state 1
      return "-service_missing-"
   }
   set output [start_remote_prog $host $CHECK_USER "/usr/bin/svcs" "-H -o STATE $fmri" back_exit_state]
   return [string trim $output]
}

proc get_sge_fmri {host service {check_fmri 1}} {
   global ts_config CHECK_USER
   
   switch -exact $service {
      "qmaster"  -
      "shadowd"  -
      "execd"    -
      "bdb"      -
      "dbwriter" { 
         set fmri "svc:/application/sge/$service:$ts_config(cluster_name)" 
      }
      default { 
         #Treat as FMRI
	 set fmri $service
      }
   }
   if {$check_fmri != 1} {
      return $fmri
   }
   #Check service exists
   start_remote_prog $host $CHECK_USER "/usr/bin/svcs" "-H $fmri"
   if {$prg_exit_state != 0} {
      ts_log_severe "No service $service found on host $host!"
      return ""
   }
   return $fmri
}


proc smf_kill_and_restart { host service {signal 15} {timeout 30} {kill_restarts 1}} {
   global ts_config CHECK_USER CHECK_ADMIN_USER_SYSTEM
   
   if { $CHECK_ADMIN_USER_SYSTEM == 0 } { 
      if { [have_root_passwd] != 0  } {
         ts_log_warning "no root password set or ssh not available"
         return -1
      }
      set user "root"
   } else {
      set user $CHECK_USER
   }
   
   set old_ctid [string trim [start_remote_prog $host "root" "/usr/bin/svcs" "-H -o CTID svc:/application/sge/$service:$ts_config(cluster_name)"]]
   if {[string match $old_ctid "-"] == 1} {
      ts_log_severe "No CTID for $service. Manually stopped?"
      return -1
   }
   set daemon_pid [smf_get_pid $host $service]
   if {$daemon_pid == -1} {
      ts_log_severe "Got pid=-1 for $service - cannot do kill"
      return -1
   }
   
   ts_log_fine "Stopping $service: 'kill -$signal $daemon_pid' on host $host as user $user ..."
   set elapsed 0
   while { $elapsed < $timeout } {
      ts_log_fine "Killing ..."
      set output [start_remote_prog $host $user "kill" "-$signal $daemon_pid"]
      ts_log_fine $output
      if {[is_pid_with_name_existing $host $daemon_pid [smf_get_process_name $service]] == 0} {
	 after 1000
	 incr elapsed 1
      } else {
	 break
      }
   }
   if {$elapsed >= $timeout} {
      ts_log_severe "Timeout $timeout secs: $service on $host is still not down"
      return -1
   }
   
   #KILL RESTART service
   if {$kill_restarts == 1} {
      #SMF RESTARTS DAEMON AUTOMATICALLY
      #Wait until online
      if {[smf_check_service_state $host $service "online" $timeout]} {
	 return -1
      }
      set new_ctid [string trim [start_remote_prog $host "root" "/usr/bin/svcs" "-H -o CTID svc:/application/sge/$service:$ts_config(cluster_name)"]]
      if {[string match $old_ctid "-"] == 1} {
         ts_log_severe "No CTID for $service. Manually stopped?"
         return -1
      }
      if {$old_ctid == $new_ctid} {
         ts_log_severe "$service not restarted (has the same CTID)"
         return -1
      }
      if {[string is false [is_smf_service_state $host $service "online"]] == 1} {
	 ts_log_severe "$service service is in '[get_smf_service_state $host $service]' STATE, expected 'online' on host $host"
         return -1
      }
      ts_log_fine "OK - SMF restarted $service"
   #KILL DISABLES service temporary
   } else {
      #Check disabled and restart
      if {[smf_check_service_state $host $service "disabled" $timeout] == -1 ||
	  [start_smf_service $host $service] == -1 ||
	  [smf_check_service_state $host $service "online" 20] == -1} {
	 return -1
      }
   }   
   return 0 
}


proc smf_get_process_name { service } {
   switch -exact $service {
      "master" -
      "qmaster" {
	 return "sge_qmaster"
      }
      "shadow" -
      "shadowd" {
	 return "sge_shadowd"
      }
      "execd" {
	 return "sge_execd"
      }
      "bdb" {
	 return "berkeley_db_svc"
      }
      "hedeby" -
      "sdm" -
      "dbwriter" {
	 return "java"
      }
      default {
	 ts_log_severe "Invalid argument $service passed to smf_get_process_name{}"
	 return ""
      }
   }
}

proc smf_check_service_state {host service state {timeout 30}} {
   #Check service state
   set elapsed 0
   while {[string is false [is_smf_service_state $host $service $state]] == 1} {
      after 1000
      incr elapsed 1
      if {$elapsed >= $timeout} {
         ts_log_severe "Timeout $elapsed secs: $service service STATE is '[get_smf_service_state $host $service]', expected '$state' on host $host"
         return -1
      }
   }
   return 0
}

proc smf_wait_until_daemon_gone { host service daemon_pid {timeout 30} {more_info ""}} {
   #Wait for service to disappear
   ts_log_finer "Waiting for $service to go down ..."
   set elapsed 0
   while {[is_pid_with_name_existing $host $daemon_pid [smf_get_process_name $service]] == 0} {
      after 1000
      incr elapsed 1
      if {$elapsed >= $timeout} {
         ts_log_severe "Timeout $timeout secs: $service on $host is still not down."
	 if {[string length $more_info] > 0} {
	    ts_log_severe "More info: $more_info"
	 }
         return -1
      }
   }
   return 0
}

proc smf_get_pid {host service} {
   global CHECK_USER
   
   set bin [smf_get_process_name $service]
   set output [start_remote_prog $host $CHECK_USER "/usr/bin/svcs" "-lp $service"]
   foreach line [split $output "\n"] {
      if {[string compare [lindex $line 0] "process"] == 0} {
	 if {[string match "*/$bin" [lindex $line 2]] == 1} {
	    return [lindex $line 1]
	 }
      }
   }
   return -1
}

proc smf_stop_over_qconf {host service {timeout 30}} {
   global ts_config CHECK_USER CHECK_ADMIN_USER_SYSTEM
   
   set ret 0
   set path $ts_config(product_root)/$ts_config(cell)/common
   
   if { $CHECK_ADMIN_USER_SYSTEM == 0 } {
      if { [have_root_passwd] != 0  } {
         ts_log_warning "no root password set or ssh not available"
         return -1
      }
      set user "root"
   } else {
      set user $CHECK_USER
   }
   
   set daemon_pid [smf_get_pid $host $service]
   
   #Check execd is known by qmaster
   if {[string match $service "execd"] == 1} {
      set elapsed 0
      while { $elapsed < $timeout } {
         start_sge_bin "qconf" "-se $host" $host $user
         if {$prg_exit_state != 0} {
	    after 1000
	    incr elapsed 1
         } else {
	    break
         }
      }
      if {$elapsed >= $timeout} {
         ts_log_severe "Timeout $timeout secs: Execd $host is still not known to qmaster"
	 return -1
      }
   }
   
   #Only qmaster and execd has qconf option
   switch -exact $service {
      "master" -
      "qmaster" {
	 ts_log_fine "Stopping $service: qconf -km on host $host as user $user"
	 set output [start_sge_bin "qconf" "-km" $host $user]
	 if {$prg_exit_state != 0} {
	    ts_log_severe "qconf -km failed: $output"
	    return -1
	 }
	 #Wait for qmaster to disappear
	 if {[smf_wait_until_daemon_gone $host $service $daemon_pid] != 0} {
	    return -1
	 }
      }
      "execd" {
	 #Submit a job to execd we are about to shutdown
	 set jid1 [submit_job "-o /dev/null -j y -q *@$host $ts_config(product_root)/examples/jobs/sleeper.sh 234" 1 60 $host $user "" 0 "qsub"]
	 if {$jid1 < 0} {
	    ts_log_severe "Could not submit a sleeper job!"
	    return -1
	 }
	 #Wait for job to be running on execd
	 ts_log_fine "Waiting for job($jid1) to be running on $host ..."
	 set elapsed 0
	 while {[is_job_running $jid1 ""] != 1} {
	    after 1000
	    incr elapsed 1
	    if {$elapsed >= $timeout} {
	       ts_log_severe "Timeout $timeout secs: job($jid1) is still not running"
	       return -1
	    }
	 }
	 #Stop execd
	 ts_log_fine "Stopping $service: qconf -ke $host as user $user"
	 set output [start_sge_bin "qconf" "-ke $host" $host $user]
	 if {$prg_exit_state != 0} {
	    ts_log_severe "qconf -ke $host failed: $output"
	    return -1
	 }
	 #Wait for execd to disappear
	 if {[smf_wait_until_daemon_gone $host $service $daemon_pid $timeout] != 0} {
	    return -1
	 }
	 #Check job still runs
	 if {[is_job_running $jid1 ""] != 1} {
	    ts_log_severe "Job $jid1 is gone. Should be present."
	    return -1
	 }
	 #Restart execd
	 start_smf_service $host "execd"
	 if {$prg_exit_state != 0} {
	    ts_log_severe "Could restart execd."
	    return -1
	 }
	 #Submit new job to this execd 
	 set jid2 [submit_job "-o /dev/null -j y -q *@$host $ts_config(product_root)/examples/jobs/sleeper.sh 432" 1 60 $host $user "" 0 "qsub"]
	 if {$jid2 < 0} {
	    ts_log_severe "Could not submit second sleeper job!"
	    return -1
	 }
	 #Wait for job to be running on execd
	 ts_log_fine "Waiting for job($jid2) to be running on $host ..."
	 set elapsed 0
	 while {[is_job_running $jid2 ""] != 1} {
	    after 1000
	    incr elapsed 1
	    if {$elapsed >= $timeout} {
	       ts_log_severe "Timeout $timeout secs: job($jid2) is still not running"
	       return -1
	    }
	 }
	 #Get job shepherds pids
	 set pid1 [get_pid_from_file $host "[get_execd_spool_dir $host]/$host/active_jobs/$jid1.1/pid"]
	 set pid2 [get_pid_from_file $host "[get_execd_spool_dir $host]/$host/active_jobs/$jid2.1/pid"]
	 if {$pid1 == -1 || $pid2 == -1} {
	    ts_log_severe "Could not get job shepherds pids!"
	    return -1
	 }
	 #Shutdown execd and kill jobs
	 ts_log_fine "Stopping $service: qconf -kej $host as user $user"
	 set output [start_sge_bin "qconf" "-kej $host" $host $user]
	 if {$prg_exit_state != 0} {
	    ts_log_severe "qconf -kej $host failed: $output"
	    return -1
	 }
	 #Wait for execd to disappear
	 if {[smf_wait_until_daemon_gone $host $service $daemon_pid $timeout $output] != 0} {
	    return -1
	 }
         #Check jobs gone
	 ts_log_fine "Waiting for job($jid1) and job($jid2) to disappear on $host ..."
	 set elapsed 0
	 while {[ is_pid_with_name_existing $host $pid1 "sge_shepherd" ] == 0 || \
	        [ is_pid_with_name_existing $host $pid2 "sge_shepherd" ] == 0} {
	    after 1000
	    incr elapsed 1
	    if {$elapsed >= $timeout} {
	       ts_log_severe "Timeout $timeout secs: jobs are still running"
	       return -1
	    }
	 }
      }
      default {
	 #Unsupported, just stop so we can continue with start test
	 stop_smf_service $host $service
	 if {$prg_exit_state != 0} {
	    return -1
	 }
	 return 0
      }
   }
   #Check disabled
   return [smf_check_service_state $host $service "disabled" 60]
}

proc smf_start_svcadm {host service action {flags ""} {wait_for_new_process 0} {timeout 15}} {
   global ts_config
   
   set fmri [get_sge_fmri $host $service]
   if {[string length $fmri] == 0} {
      return -1
   }
   set old_ctid -1
   set args "$action $flags $fmri"
   
   #Setup different actions
   switch -exact $action {
      "enable" {
	 set expected_state "online"
	 set text_action "Starting"
      }
      "disable" {
	 set expected_state "disabled"
	 set text_action "Stopping"
      }
      "restart" {
	 set expected_state "online"
	 set text_action "Restarting"
	 set old_ctid [string trim [start_remote_prog $host "root" "/usr/bin/svcs" "-H -o CTID svc:/application/sge/$service:$ts_config(cluster_name)"]]
	 if {[string match $old_ctid "-"] == 1} {
            ts_log_severe "No CTID for $service. STATE '[get_smf_service_state $host $service]', expected 'online'."
            return -1
         }
      }
      default {
	 ts_log_severe "Unsupported action $action in smf_start_svcadm{}"
	 return -1
      }
   }
   
   ts_log_fine "$text_action $service: 'svcadm $args' on host $host as user root"
   #Run svcadm
   start_remote_prog $host "root" "/usr/sbin/svcadm" "$args"
   
   if {$wait_for_new_process == 0} {
      if {$prg_exit_state != 0} {
	 return -1
      }
      return 0
   }
   #Wait for the transition to happen
   set elapsed 0
   while {[string is false [is_smf_service_state $host $service "$expected_state"]] == 1} {
      after 1000
      incr elapsed 1
      if {$elapsed >= $timeout} {
         ts_log_severe "Timeout $timeout: Service $service not \"$action\"ed on host $host! STATE '[get_smf_service_state $host $service]', expected '$expected_state'."
         return -1
      }
   }
   #restart action handling
   if {$old_ctid != -1} {
      set new_ctid [string trim [start_remote_prog $host "root" "/usr/bin/svcs" "-H -o CTID svc:/application/sge/$service:$ts_config(cluster_name)"]]
      if {[string match $new_ctid "-"] == 1} {
         ts_log_severe "No CTID for $service. STATE '[get_smf_service_state $host $service]', expected '$expected_state'."
         return -1
      }
      if {$old_ctid == $new_ctid} {
         ts_log_severe "$service not restarted"
         return -1
      }
   }
   return 0
}


proc smf_generic_test {host service {timeout 30} {kill_restarts 1}} {
   global ts_config CHECK_USER
   
   set ret 0
   if { [is_smf_host $host] == 0 } {
      ts_log_severe "Your $service host $host does not support SMF. Skipping test."
      return -1
   }
   #Stop running daemon
   set ret [shutdown_daemon $host $service]
   if {$ret != 0} {
      #We had timeout when shutting down the daemon
      ts_log_fine "Aborting current test iteration..."
      return -1
   }
   
   #Register with SMF
   ts_log_fine "Registering $service:$ts_config(cluster_name) service ..."
   set output [start_remote_prog $host "root" "/bin/sh" "-c [get_sge_smf_cmd] register $service $ts_config(cluster_name)" prg_exit_state]
   if { [string length [string trim $output]] != 0 || $prg_exit_state != 0 } {
      ts_log_severe "ERROR: Register did not succeed!"
      return -1
   }
   #Start over SMF
   start_smf_service $host $service
   if { [string is false [is_smf_service_state $host $service "online"]] == 1 } {
      ts_log_severe "$service service is in '[get_smf_service_state $host $service]' STATE, expected 'online' on host $host"
      return -1
   }
   
   #Advaced restart tests
   set ret [smf_advanced_restart_test $host $service $timeout $kill_restarts]
   if {$ret != 0} {
      ts_log_fine "Aborting current test iteration..."
      return -1
   }

   #Unregister (stops the service first)
   ts_log_fine "Unregistering $service:$ts_config(cluster_name) service ..."
   set output [start_remote_prog $host "root" "/bin/sh" "-c [get_sge_smf_cmd] unregister $service $ts_config(cluster_name)" prg_exit_state]
   if { [string length [string trim $output]] != 0 || $prg_exit_state != 0 } {
      ts_log_severe "ERROR: Unregister did NOT succeed!"
      return -1
   }
   #Check service is gone
   if {[smf_service_exists $host $service] == 0 } {
      ts_log_severe "ERROR: $service service was supposed to be removed already on host $host!\nState is [get_smf_service_state $host $service]"
      return -1;
   }
   #Start service normally
   startup_daemon $host $service
   ts_log_fine ">>>"
}

proc smf_advanced_restart_test {host service {timeout 30} {kill_restarts 1}} {
   global ts_config CHECK_USER
   
   #TODO - would be nice to test reboot behavior, maybe by using a reserved zones in cluster config
   
   ###############
   #STARTUP SCRIPT
   ###############
   #Stop
   if {[call_startup_script $host $service "" "stop" $timeout] != 0 ||
       [smf_check_service_state $host $service "disabled" 60] != 0} {
      return -1
   }
   #Start
   if {[call_startup_script $host $service "" "start" $timeout] != 0 ||
       [smf_check_service_state $host $service "online" 20] != 0} {
      return -1
   }
   #Wait until we see the pid?
   ts_log_fine "PID=[smf_get_pid $host $service]"
   #####
   #KILL
   #####
   #Stop using kill -15
   if {[smf_kill_and_restart $host $service 15 $timeout $kill_restarts] != 0} {
      return -1
   }
   
   #Stop using kill -9 - INCORRECT shutdown (SMF always restarts the service)
   if {[smf_kill_and_restart $host $service 9 $timeout 1] != 0} {
      return -1
   }
   ######
   #QCONF
   ######
   #qconf -km,-ke[j]
   #ignored for non-applicable services
   if {[smf_stop_over_qconf $host $service $timeout] != 0} {
      return -1
   }
   #######
   #SVCADM
   #######
   #svcadm enable -t
   if {[smf_start_svcadm $host $service "enable" "-t" 1] == -1} {
      return -1
   }
   #svcadm disable -t
   if {[smf_start_svcadm $host $service "disable" "-t" 1] == -1} {
      return -1
   }
   #svcadm enable -st
   if {[smf_start_svcadm $host $service "enable" "-st"] == -1} {
      return -1
   }
   #svcadm disable -st
   if {[smf_start_svcadm $host $service "disable" "-st"] == -1} {
      return -1
   }
   #svcadm restart
   start_smf_service $host $service
   if {[smf_start_svcadm $host $service "restart" "" 1] == -1} {
      return -1
   }
   return 0
}
