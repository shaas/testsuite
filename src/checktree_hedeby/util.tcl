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

#****** util/do_ssh_login() ****************************************************
#  NAME
#     do_ssh_login() -- do ssl login on open spawn id
#
#  SYNOPSIS
#     do_ssh_login { spawn_id user host } 
#
#  FUNCTION
#     This procedure is used to login via ssh
#
#  INPUTS
#     spawn_id - spawn id of open spawn process
#     user     - user name for haithabu_passwd array
#     host     - host name for haithabu_passwd array
#
#  RESULT
#     0 on success 
#
#  EXAMPLE
#
#   set id [open_remote_spawn_process $ts_config(master_host) "$CHECK_USER" "ssh" "$haithabu_config(n1sm_user)@$haithabu_config(n1sm_host)" ]
#   set sp_id [ lindex $id 1 ]
#
#   set exit_state [do_ssh_login sp_id "n1sm_user" "n1sm_host"]
#   
#   if { $exit_state == 0 } {
#      send -i $sp_id -- "exit\n"
#
#      expect {
#         -i $sp_id "_exit_status_:*\n" {
#                set exit_state [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]
#                puts $CHECK_OUTPUT "exit state is: \"$exit_state\""
#            }
#      }
#   }
#   close_spawn_process $id
#
#
#  NOTES
#     very specific haithabu function
#
#  SEE ALSO
#      util/do_ssh_login()
#      util/do_sftp_login()
#*******************************************************************************
proc do_ssh_login { spawn_id user host } {
   global haithabu_config CHECK_OUTPUT ts_config
   global haithabu_passwd CHECK_USER CHECK_SHELL_PROMPT

   upvar sp_id $spawn_id

   # set id [open_remote_spawn_process $ts_config(master_host) "$CHECK_USER" "ssh" "$haithabu_config(n1sm_user)@$haithabu_config(n1sm_host)" ]
   set exit_state 1
   log_user 1

   set exit_state -1
   expect {
         -i $sp_id full_buffer { 
            add_proc_error "haithabu_get_required_passwords" -1 "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
         }

         -i $sp_id timeout {
            add_proc_error "haithabu_get_required_passwords" -1 "unexpected timeout"
         } 
         -i $sp_id eof {
            add_proc_error "haithabu_get_required_passwords" -1 "unexpected eof"
         } 
         -i $sp_id "_exit_status_:*\n" {
            set exit_state [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]
            puts $CHECK_OUTPUT "exit state is: \"$exit_state\""
            puts $CHECK_OUTPUT "process should not have finished here"

         }
         -i $sp_id "password:" {
            log_user 0
            send -i $sp_id -- "$haithabu_passwd($haithabu_config($user),$haithabu_config($host))\n"
            log_user 1
            puts $CHECK_OUTPUT "password send"
         } 
   }

   set timeout 1
   set nr_of_timeouts 0
   expect {
         -i $sp_id "$haithabu_config($user)*gid" {
            puts $CHECK_OUTPUT "got user name"
            set exit_state 0
         }
         -i $sp_id timeout {
            puts $CHECK_OUTPUT "sending id command ..."
            send -i $sp_id -- "id\n"
            incr nr_of_timeouts 1
            if { $nr_of_timeouts > 15 } {
               add_proc_error "haithabu_get_required_passwords" -1 "unexpected timeout"
               break
            }
            exp_continue
         } 
   }

#   close_spawn_process $id
   return $exit_state
}

proc do_sftp_login { spawn_id user host } {
   global haithabu_config CHECK_OUTPUT ts_config
   global haithabu_passwd CHECK_USER CHECK_SHELL_PROMPT

   upvar sp_id $spawn_id

   # set id [open_remote_spawn_process $ts_config(master_host) "$CHECK_USER" "ssh" "$haithabu_config(n1sm_user)@$haithabu_config(n1sm_host)" ]
   set exit_state 1
   log_user 1

   set exit_state -1
   expect {
         -i $sp_id full_buffer { 
            add_proc_error "haithabu_get_required_passwords" -1 "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
         }

         -i $sp_id timeout {
            add_proc_error "haithabu_get_required_passwords" -1 "unexpected timeout"
         } 
         -i $sp_id eof {
            add_proc_error "haithabu_get_required_passwords" -1 "unexpected eof"
         } 
         -i $sp_id "_exit_status_:*\n" {
            set exit_state [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]
            puts $CHECK_OUTPUT "exit state is: \"$exit_state\""
            puts $CHECK_OUTPUT "process should not have finished here"

         }
         -i $sp_id "password:" {
            log_user 0
            send -i $sp_id -- "$haithabu_passwd($haithabu_config($user),$haithabu_config($host))\n"
            log_user 1
            puts $CHECK_OUTPUT "password send"
         } 
   }

   expect {
         -i $sp_id "sftp>" {
            puts $CHECK_OUTPUT "got shell prompt"
            set exit_state 0
         }
         -i $sp_id timeout {
            add_proc_error "haithabu_get_required_passwords" -1 "unexpected timeout"
         } 
   }


#   close_spawn_process $id
   return $exit_state
}

proc remove_hedeby {{raise_error 1}} {
   global hedeby_config
   # first step: remove preferences for all managed hosts
   foreach host [get_all_hedeby_managed_hosts] {
      remove_prefs_on_hedeby_host $host $raise_error
   }

   # second step: remove preferences for hedeby master host
   remove_prefs_on_hedeby_host $hedeby_config(hedeby_master_host) $raise_error
}

# return != 0 on error
proc shutdown_hedeby {} {
   global CHECK_OUTPUT
   global hedeby_config

   set ret_val 0
   set shutdown_user [get_hedeby_startup_user]

   # first step: shutdown all managed hosts
   foreach host [get_all_hedeby_managed_hosts] {
      set val [shutdown_hedeby_host "managed" $host $shutdown_user]
      if { $val != 0 } {
         set ret_val 1
      }
   }

   # second step: shutdown hedeby master host
   set val [shutdown_hedeby_host "master" $hedeby_config(hedeby_master_host) $shutdown_user]
   if { $val != 0 } {
      set ret_val 1
   }
   return $ret_val
}


# return != 0 on error
proc startup_hedeby {} {
   global CHECK_OUTPUT
   global hedeby_config

   set ret_val 0
   set startup_user [get_hedeby_startup_user]

   # first step: startup hedeby master host
   set val [startup_hedeby_host "master" $hedeby_config(hedeby_master_host) $startup_user]
   if { $val != 0 } {
      set ret_val 1
   }


   # second step: startup all managed hosts
   foreach host $hedeby_config(hedeby_host_resources) {
      set val [startup_hedeby_host "managed" $host $startup_user]
      if { $val != 0 } {
         set ret_val 1
      }
   }
   return $ret_val
}

proc get_hedeby_binary_path { binary_name {user_name ""} {hostname ""}} {
   global hedeby_config
   
   get_current_cluster_config_array ts_config


   if { $hostname == "" } {
      set hostname $hedeby_config(hedeby_master_host)
   }
   if { $user_name == "" } {
      set user_name [get_hedeby_admin_user]
   }

   set path ""

   switch -exact -- $binary_name {
      "sdmadm" {
         set path $hedeby_config(hedeby_product_root)/bin/sdmadm
      }
      default {
         add_proc_error "get_hedeby_binary_path" -1 "unexpected binary name: $binary_name"
      }
   }

   if { ![is_remote_file $hostname $user_name $path 1]} {
      add_proc_error "get_hedeby_binary_path" -1 "file \"$path\" not existing on host \"$hostname\" for user \"$user_name\""
   }
   return $path
}

proc get_hedeby_system_name { } {
   global hedeby_config
   set pref_type [get_hedeby_pref_type]
   set sys_name ts_${pref_type}_$hedeby_config(hedeby_cs_port)
   return $sys_name
}

proc get_hedeby_pref_type { } {
   global CHECK_ADMIN_USER_SYSTEM

   return "user"
   # TODO: add support for system !!! (question: what is the name of the admin user - root or testsuite user ???

   if {$CHECK_ADMIN_USER_SYSTEM == 0} {
      return "system"
   } else {
      return "user"
   }
}

proc get_hedeby_admin_user { } {
   global CHECK_USER
   return $CHECK_USER
}

proc get_bundle_string { id } {
   # TODO: find a way to get the bundle messages for parsing the output of the command
   set ret_val ""
   switch -exact -- $id {
      "bootstrap.log.info.jvm_started" { set ret_val "Jvm {0} started\r\n" }
      "ParentStartupService.skipRunningJvm" { set ret_val "Can not start jvm {0}: pid file {1} already exists\r\n" }
      "ParentStartupService.skippedRunningJvms" { set ret_val "Can not start following already running jvms: {0}\r\n" }
      "client.status.other" { set ret_val "Other:\r\n" }
      "client.status.service" { set ret_val "{0}: {1} -- status: {2}\r\n"}
   }
   if { $ret_val == "" } {
      add_proc_error "get_bundle_string" -1 "cannot find bundle string \"$id\""
      set ret_val "This is a return value for a unknown bundle string"
   }
   set ret_val [string trim $ret_val]
   return $ret_val
}


proc create_bundle_string { id {params_array "params"} {default_param ""} } {
   global CHECK_OUTPUT
   upvar $params_array params
   # get bundle string
   set bundle_string [get_bundle_string $id]
   set result_string $bundle_string

   # puts $CHECK_OUTPUT "bundle string: \"$result_string\""
   # get number of params in bundle string
   set i 0
   while { [string match "*{$i}*" $bundle_string] } {
      incr i 1
   }
   # puts $CHECK_OUTPUT "bundle string has $i parameter"
   for { set x 0 } { $x < $i } { incr x 1 } {
      set par_start [string first "{$x}" $result_string]
      set par_end $par_start
      incr par_end 2
      if { [info exists params($x)] && $use_asterisk == 0} {
         set param_string $params($x)
      } else {
         if { $default_param != "" } {
            set param_string $default_param
         } else {
            add_proc_error "create_bundle_string" -1 "parameter $x is missing in params array"
            set param_string "{$x}"
         }
      }
      set result_string [string replace $result_string $par_start $par_end $param_string]
      #puts $CHECK_OUTPUT "result $x: \"$result_string\""
   }
   # puts $CHECK_OUTPUT "output string: \"$result_string\""
   return $result_string
}

proc parse_bundle_string_params { output id {params_array params}  } {
   global CHECK_OUTPUT
   upvar $params_array par

   if { [info exists par] } {
      unset par
   }

   set par(count) 0

   set bundle_string [get_bundle_string $id]
   #puts $CHECK_OUTPUT "output: $output"
   #puts $CHECK_OUTPUT "bundle: $bundle_string"
   set i 0
   while { [string match "*{$i}*" $bundle_string] } {
      incr i 1
   }
   set par(count) $i

   set max_pos 0

   for { set x 0 } { $x < $i } { incr x 1 } {
      set par($x,index) [string first "{$x}" $bundle_string]
      if { $max_pos > $par($x,index) } {
         add_proc_error "parse_bundle_string_params" -1 "This parser currently expects the bundle string parameters in the correct order!"
      }
      set max_pos $par($x,index)
      set irange_end $par($x,index)
      incr irange_end -1
      if { $irange_end < 0 } {
         set irange_end 0
      }
      if {$x > 0 } {
         set prev_par $x
         incr prev_par -1
         set irange_start $par($prev_par,index)
         incr irange_start 3
      } else {
         set irange_start 0
      }
      # here we have the string before the current parameter
      if { $irange_start != $irange_end } {
         set par($x,before) [string range $bundle_string $irange_start $irange_end]
      } else {
         set par($x,before) ""
      }
      #puts $CHECK_OUTPUT "before $x ($irange_start - $irange_end): \"$par($x,before)\""
   }

   set last_static_string ""
   incr x -1
   set endOfLastParam $par($x,index)
   incr endOfLastParam 3
   set bundleStrLength [string length $bundle_string]
   set restString ""
   if { $endOfLastParam != $bundleStrLength} {
      # handle situations where the last param is not the last string content
      set restString [string range $bundle_string $endOfLastParam end ]
   }
   #puts $CHECK_OUTPUT "rest string: \"$restString\""

   

   set parse_string $output
   for { set x 0 } { $x < $i } { incr x 1 } {
      set before $par($x,before)
      set before_length [string length $before]
      if { $before_length > 0 } {
         if { [string first $before $parse_string] != 0 } {
            set error_text "error parsing string can't find before sequence of param $x!\n"
            append error_text "   bundle string: \"$bundle_string\"\n"
            append error_text "   parse string:  \"$output\""
            add_proc_error "parse_bundle_string_params" -1 $error_text
         } else {
            set parse_string [string range $parse_string $before_length end]
            #puts $CHECK_OUTPUT "remaining parse string: \"$parse_string\"" 
         }
      }
      set next_param $x
      incr next_param 1
       
      if { $next_param < $i } {
         # now we copy from begining to the start of the next param
         set next_str $par($next_param,before)
         if { $next_str == "" } {
            add_proc_error "parse_bundle_string_params" -1 "error parsing string some of the parameters have no separator string"
         }
      } else {
         # we use the rest for the last param
         set next_str $restString
      }

      if { $next_str == "" } {
         # this is the last param, use the rest of the parse string for last param
         set par($x) $parse_string
         set parse_string ""
      } else {
         set index [string first $next_str $parse_string]
         incr index -1
         set par($x) [string range $parse_string 0 $index]
         incr index 1
         set parse_string [string range $parse_string $index end]
      }
      #puts $CHECK_OUTPUT "par($x) = \"$par($x)\""
      #puts $CHECK_OUTPUT "remaining parse string: \"$parse_string\"" 
   }
}

proc get_hedeby_startup_user { } {
   global CHECK_OUTPUT
   global CHECK_USER
   set pref_type [get_hedeby_pref_type]
   if { $pref_type == "system" } {
      set user "root"
   } else {
      set user $CHECK_USER
   }
   return $user
}

proc get_hedeby_cs_url { } {
   global hedeby_config
   return "$hedeby_config(hedeby_master_host):$hedeby_config(hedeby_cs_port)"
}


proc get_hedeby_local_spool_dir { host } {
   set spool_dir [get_local_spool_dir $host "hedeby_spool" 0 ]
   return $spool_dir
}

proc cleanup_hedeby_local_spool_dir { host } {
   global CHECK_OUTPUT 
   global CHECK_USER
   # to be able to cleanup (delete) the spooldir the file
   # permissions have to be set to the testsuite user
   set local_spool_dir [get_hedeby_local_spool_dir $host]
   if { $local_spool_dir != "" } {
      set comargs "-R $CHECK_USER $local_spool_dir"
      puts $CHECK_OUTPUT "${host}(root): doing chown $comargs ..."
      set output [start_remote_prog $host "root" "chown" $comargs]
      puts $CHECK_OUTPUT $output
      if { $prg_exit_state != 0 } {
         add_proc_error "cleanup_hedeby_local_spool_dir" -1 "doing chown $comargs returned exit code: $prg_exit_state\n$output"
      }
   }
   set spool_dir [get_local_spool_dir $host "hedeby_spool" 1 ]
   remote_delete_directory $host $spool_dir
   return $spool_dir
}


# this procedure returns all possible managed hosts!!!
proc get_all_hedeby_managed_hosts {} {
   global hedeby_config
   set host_list [get_all_execd_hosts]
   foreach host $hedeby_config(hedeby_host_resources) {
      lappend host_list $host
   }

   set new_host_list {}
   foreach host $host_list {
      if { $host != $hedeby_config(hedeby_master_host) } {
         lappend new_host_list  $host
      }
   }

   return $new_host_list
}

proc is_hedeby_process_running { host pid } {
   global CHECK_OUTPUT

   puts $CHECK_OUTPUT "checking pid $pid on host $host ..."
   get_ps_info $pid $host ps_info

   set result 0
   if {$ps_info($pid,error) == 0} {
        puts $CHECK_OUTPUT "process string of pid $pid is $ps_info($pid,string)"
        set result 1
   } else {
        puts $CHECK_OUTPUT "pid $pid not found!"
        set result 0
   }

   return $result
}

proc kill_hedeby_process { host user component pid {atimeout 60}} {
   global CHECK_OUTPUT

   set delete_pid_file 0
   puts $CHECK_OUTPUT "***********************************************************************"
   puts $CHECK_OUTPUT "killing component \"$component\" with pid \"$pid\" using SIGTERM ..."
   start_remote_prog $host $user "kill" "$pid"
   set wait_time [timestamp]
   incr wait_time $atimeout
   set terminated 0
   while { [timestamp] < $wait_time } {
      after 2000
      set is_pid_running [is_hedeby_process_running $host $pid]
      if { $is_pid_running == 0 } {
         set terminated 1
         break
      }
   }
   if { $terminated == 0 } {
      puts $CHECK_OUTPUT "***********************************************************************"
      puts $CHECK_OUTPUT "killing component \"$component\" with pid \"$pid\" using SIGKILL ..."
      start_remote_prog $host $user "kill" "-9 $pid"
      set is_pid_running [is_hedeby_process_running $host $pid]
      if { $is_pid_running } {
         add_proc_error "shutdown_hedeby_host" -1 "cannot shutdown component \"$component\" on host \"$host\" as user \"$user\""
      } else {
         # we killed with SIGKILL, we have to delete the pid file
         set delete_pid_file 1
      }
   }
   # components should have delete the pidfiles by itself here (SIGTERM is normal shutdown)
   if { $delete_pid_file } {
      set del_pid_file [get_hedeby_local_spool_dir $host]
      append del_pid_file "/run/$component"
      puts $CHECK_OUTPUT "delete pid file \"$del_pid_file\"\nfor component \"$component\" on host \"$host\" as user \"$user\" ..."
      delete_remote_file $host $user $del_pid_file
   }
}

# return 0 on success, 1 on error
proc shutdown_hedeby_host { type host user } {
   global CHECK_OUTPUT 
   global hedeby_config

   set ret_val 0
   puts $CHECK_OUTPUT "check if \"$type\" host \"$host\" has running components ..."
   
   set pid_list {}
   set run_dir [get_hedeby_local_spool_dir $host]
   append run_dir "/run"
   if { [remote_file_isdirectory $host $run_dir] } {
      set running_components [start_remote_prog $host $user "ls" "$run_dir"]
      if { [llength $running_components] == 0 } {
         debug_puts "no hedeby component running on host $host!"
         return $ret_val
      }
      foreach component $running_components {
         set comp_file $run_dir/$component
         get_file_content $host $user $comp_file
         if { $file_array(0) == 2} {
             set pid [string trim $file_array(1)]
             lappend pid_list $pid
             set run_list($pid,comp) $component
             puts $CHECK_OUTPUT "component $run_list($pid,comp) has pid \"$pid\""
             
             set url [string trim $file_array(2)]
             puts $CHECK_OUTPUT "component $run_list($pid,comp) has url \"$url\""
             if {[string match "*$host*" $url]} {
                puts $CHECK_OUTPUT "url string contains hostname \"$host\""
             } else {
                add_proc_error "shutdown_hedeby_host" -1 "runfile url for component $component on host $host contains not the correct hostname \"$host\""
             }
             set sysname [get_hedeby_system_name]
             if {[string match "*$sysname*" $url]} {
                puts $CHECK_OUTPUT "url string contains system name \"$sysname\""
             } else {
                add_proc_error "shutdown_hedeby_host" -1 "runfile url for component $component on host $host contains not the correct system name \"$sysname\""
             }
         } else {
             add_proc_error "shutdown_hedeby_host" -1 "runfile for component $component on host $host contains not the expected 2 lines"
             return 1
         }
      }
   } else {
      debug_puts "no hedeby run directory found on host $host!"
      return $ret_val
   }
   puts $CHECK_OUTPUT "shutting down \"$type\" host \"$host\" ..."

   switch -exact -- $type {
      "managed" {
         if { $host == $hedeby_config(hedeby_master_host) } {
            add_proc_error "shutdown_hedeby_host" -1 "host \"$host\" is the master host!"
            return 1
         }
         set ret [sdmadm_shutdown $host $user output [get_hedeby_pref_type] [get_hedeby_system_name]]
         if { $ret != 0 } {
            set ret_val 1
         }
      }
      "master" {
         if { $host != $hedeby_config(hedeby_master_host) } {
            add_proc_error "shutdown_hedeby_host" -1 "host \"$host\" is NOT the master host!"
            return 1
         }
         set ret [sdmadm_shutdown $host $user output [get_hedeby_pref_type] [get_hedeby_system_name]]
         if { $ret != 0 } {
            set ret_val 1
         }
      }
      default {
         add_proc_error "shutdown_hedeby_host" -1 "unexpected host type: \"$type\" supported are \"managed\" or \"master\""
         set ret_val 1
      }
   }
   if { $ret_val != 0 } {
      puts $CHECK_OUTPUT "try to kill all components ..."
      foreach pid $pid_list {
         set delete_pid_file 0
         set is_pid_running [is_hedeby_process_running $host $pid]
         if { $is_pid_running } {
            kill_hedeby_process $host $user $run_list($pid,comp) $pid
         } else {
            # there was an old pid file without running component -> delete the pid file
            set delete_pid_file 1
         }
         if { $delete_pid_file } {
            set del_pid_file "$run_dir/$run_list($pid,comp)"
            puts $CHECK_OUTPUT "delete pid file \"$del_pid_file\"\nfor component \"$run_list($pid,comp)\" on host \"$host\" as user \"$user\" ..."
            delete_remote_file $host $user $del_pid_file
         }
      }
   } else {
      # check pid files and processes
      puts $CHECK_OUTPUT "check that no pid is running after sdmadm shutdown and pid files are removed ..."
      foreach pid $pid_list {
         set is_pid_running [is_hedeby_process_running $host $pid]
         if { $is_pid_running } {
            set ret_val 1
            add_proc_error "shutdown_hedeby_host" -1 "cannot shutdown component \"$run_list($pid,comp)\" on host \"$host\" as user \"$user\".\n(process with pid \"$pid\" is still running)"
         }
         set pid_file "$run_dir/$run_list($pid,comp)"
         if { [is_remote_file $host $user $pid_file] } {
            add_proc_error "shutdown_hedeby_host" -1 "cannot shutdown component \"$run_list($pid,comp)\" on host \"$host\" as user \"$user\"\n(pid file \"$pid_file\" wasn't removed)"
         }
         kill_hedeby_process $host $user $run_list($pid,comp) $pid
      }
   }
   return $ret_val
}

# return 0 on success, 1 on error
proc startup_hedeby_host { type host user } {
   global CHECK_OUTPUT 
    
   set ret_val 0
   puts $CHECK_OUTPUT "startup \"$type\" host \"$host\" ..."

   # TODO: add more checking for "managed" and "master"
   # TODO: test with get_ps_info if the processes have started
   # TODO: check that all pid are written and no one is missing

   switch -exact -- $type {
      "managed" {
         set ret [sdmadm_start $host $user output [get_hedeby_pref_type] [get_hedeby_system_name]]
         if { $ret != 0 } {
            set ret_val 1
         } 
         set match_string [create_bundle_string "bootstrap.log.info.jvm_started" xyz "*"]
      }
      "master" {
         set ret [sdmadm_start $host $user output [get_hedeby_pref_type] [get_hedeby_system_name]]
         if { $ret != 0 } {
            set ret_val 1
         }
         set help [create_bundle_string "bootstrap.log.info.jvm_started" xzy "*"]
         set match_string "$help\r\n$help"  ;# we expect 2
      }
      default {
         add_proc_error "startup_hedeby_host" -1 "unexpected host type: \"$type\" supported are \"managed\" or \"master\""
         set ret_val 1
      }
   }
   if { [string match "*$match_string*" $output]} {
      puts $CHECK_OUTPUT "output matches expected result"
   } else {
      set error_text ""
      append error_text "startup hedeby host ${host} failed:\n"
      append error_text "\"$output\"\n"
      append error_text "The expected output doesn't match and exit value should not be 0:\n"
      append error_text "match string:\n"
      append error_text "\"$match_string\"\n"
      add_proc_error "startup_hedeby_host" -1 $error_text
      set ret_val 1
   }
   return $ret_val
}


proc remove_prefs_on_hedeby_host { host {raise_error 1}} {
   global CHECK_OUTPUT 

   set pref_type [get_hedeby_pref_type]
   set sys_name [get_hedeby_system_name]
   puts $CHECK_OUTPUT "removing \"$pref_type\" preferences for hedeby system \"$sys_name\" on host \"$host\" ..."

   set remove_user [get_hedeby_startup_user]

   sdmadm_remove_system $host $remove_user output $pref_type $sys_name $raise_error
}


proc reset_hedeby {} {
   add_proc_error "reset_hedeby" -3 "not implemented"
   # shutdown hedeby system ?
   # reset all resources to install state = OK (same as after install with cleanup system)
   # startup hedeby system ?
   # TODO: check if this procedure (reset_hedeby) should be implemented or not
   return 0
}

proc sdmadm_command { host user arg_line {exit_var prg_exit_state} } {
   upvar $exit_var back_exit_state
   global CHECK_OUTPUT
   puts $CHECK_OUTPUT "${host}($user): starting \"sdmadm $arg_line\" ..."
   set sdmadm_path [get_hedeby_binary_path "sdmadm" $user]
   set my_env(JAVA_HOME) [get_java_home_for_host $host "1.5"]
   return [start_remote_prog $host $user $sdmadm_path $arg_line back_exit_state 60 0 "" my_env 1 0 0]
}

proc sdmadm_start { host user output {preftype ""} {sys_name ""} {jvm_name ""} {raise_error 1} } {
   global CHECK_OUTPUT
   upvar $output output_return
   set args {}
   if { $preftype != "" } {
      lappend args "-p $preftype"
   }
   if { $sys_name != "" } {
      lappend args "-s $sys_name"
   }

   set arg_line ""
   foreach arg $args {
      append arg_line $arg
      append arg_line " "
   }
   append arg_line "start"

   if { $jvm_name != "" } {
      append arg_line " -j $jvm_name"
   }

   set output [sdmadm_command $host $user $arg_line]
   puts $CHECK_OUTPUT $output
   
   if { $prg_exit_state != 0 } {
      add_proc_error "sdmadm_start" -1 "${host}(${user}): sdmadm $arg_line failed:\n$output" $raise_error
   }

   set output_return $output  ;# set the output
   return $prg_exit_state
}

proc sdmadm_shutdown { host user output {preftype ""} {sys_name ""} {jvm_name ""} {raise_error 1} } {
   global CHECK_OUTPUT
   upvar $output output_return
   set args {}
   if { $preftype != "" } {
      lappend args "-p $preftype"
   }
   if { $sys_name != "" } {
      lappend args "-s $sys_name"
   }

   set arg_line ""
   foreach arg $args {
      append arg_line $arg
      append arg_line " "
   }
   append arg_line "shutdown"

   if { $jvm_name != "" } {
      append arg_line " -j $jvm_name"
   }

   set output [sdmadm_command $host $user $arg_line]
   puts $CHECK_OUTPUT $output

   if { $prg_exit_state != 0 } {
      add_proc_error "sdmadm_shutdown" -1 "${host}(${user}): sdmadm $arg_line failed:\n$output" $raise_error
   }

   set output_return $output  ;# set the output
   return $prg_exit_state
}


proc sdmadm_remove_system { host user output {preftype ""} {sys_name ""} {raise_error 1} } {
   global CHECK_OUTPUT
   upvar $output output_return

   set args {}
   if { $preftype != "" } {
      lappend args "-p $preftype"
   }
   if { $sys_name != "" } {
      lappend args "-s $sys_name"
   }
   set arg_line ""
   foreach arg $args {
      append arg_line $arg
      append arg_line " "
   }
   append arg_line "remove_system"

   set output [sdmadm_command $host $user $arg_line]
   puts $CHECK_OUTPUT $output

   if { $prg_exit_state != 0 } {
      add_proc_error "sdmadm_remove_system" -1 "${host}(${user}): sdmadm $arg_line failed:\n$output" $raise_error
   }

   set output_return $output  ;# set the output
   return $prg_exit_state
}

proc sdmadm_show_status { host user output {preftype ""} {sys_name ""} {raise_error 1} } {
   global CHECK_OUTPUT
   upvar $output output_return

   set args {}
   if { $preftype != "" } {
      lappend args "-p $preftype"
   }
   if { $sys_name != "" } {
      lappend args "-s $sys_name"
   }
   set arg_line ""
   foreach arg $args {
      append arg_line $arg
      append arg_line " "
   }
   append arg_line "show_status"

   set output [sdmadm_command $host $user $arg_line]
   puts $CHECK_OUTPUT $output

   if { $prg_exit_state != 0 } {
      add_proc_error "sdmadm_remove_system" -1 "${host}(${user}): sdmadm $arg_line failed:\n$output" $raise_error
   }

   set output_return $output  ;# set the output
   return $prg_exit_state
}

proc parse_sdmadm_show_status_output { output_var {status_array "ss_out" } } {
   global CHECK_OUTPUT
   upvar $output_var out
   upvar $status_array ss

    set help [split $out "\n"]

    set ss(showed_status_count) 0

    # get string for other line
    set other_string [create_bundle_string "client.status.other"]
    
    # get match string for service output line
    set comp_string [create_bundle_string "client.status.service" xyz "*"]

    set section ""
    set help [split $out "\n"]

    foreach ls $help {
       set line [string trim $ls]
#       puts $CHECK_OUTPUT "parse line: \"$line\""
       if { [string match $other_string $line] } {
          set section "other"
          debug_puts "found section \"$section\""
          continue
       }
       if { $section == "other" } {
          if { [string match $comp_string $line] } {
             parse_bundle_string_params $line "client.status.service" params
             set host   $params(0)
             set comp   $params(1)
             set status $params(2)
             set ss($host,$comp,status)  $status
             set ss($host,$comp,section) $section
             incr ss(showed_status_count) 1
             debug_puts "section $section: found comp \"$comp\" on host \"$host\" with status \"$status\""
          }
       }
    }
}


