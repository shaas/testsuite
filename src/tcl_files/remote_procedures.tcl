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

global module_name
global rlogin_spawn_session_buffer
set module_name "remote_procedures.tcl"
global rlogin_max_open_connections
set rlogin_max_open_connections 20
global open_remote_spawn_script_cache

# if file is resourced, delete xterm_path_cache
global xterm_path_cache
if { [info exists xterm_path_cache] } {
   unset xterm_path_cache
}


global CHECK_SHELL_PROMPT CHECK_LOGIN_LINE
# initialize prompt handling, see expect manpage

# NOTE: CHECK_SHELL_PROMPT is regular expression matching !!!
set CHECK_SHELL_PROMPT ".*\[#>$%\]+"

# NOTE: CHECK_LOGIN_LINE is glob matching !!!
set CHECK_LOGIN_LINE "\[A-Za-z\]*\n"   

set descriptors [exec "/bin/sh" "-c" "ulimit -n"]
puts "    *********************************************"
puts "    * CONNECTION SETUP (remote_procedures.tcl)"
puts "    *********************************************"
puts "    * descriptors = $descriptors"
set rlogin_max_open_connections [expr ($descriptors - 15) / 3]
puts "    * rlogin_max_open_connections = $rlogin_max_open_connections"
puts "    *********************************************"

#****** remote_procedures/ts_send() ********************************************
#  NAME
#     ts_send() -- send to a spawned process (spawn_id)
#
#  SYNOPSIS
#     ts_send {spawn_id message {host ""} {passwd 0} {raise_error 1}} 
#
#  FUNCTION
#     Sends data to a spawned process.
#     Calls the expect function send, with some optional parameters:
#     1. Sends are slowed down, when the send_slow parameter of a host in the
#        testsuite host configuration is set != 0
#     2. Human like typing, when the paramter passwd is != 0.
#        Some operating systems will reject password input, when it is sent
#        at full speed.
#
#  INPUTS
#     spawn_id        - spawn id to send to
#     message         - the message to send
#     {host ""}       - optional - host associated with spawn_id
#     {passwd 0}      - optional - do human like send
#     {raise_error 1} - optional - raise error condition on errors
#
#  SEE ALSO
#     remote_procedures/open_remote_spawn_process()
#*******************************************************************************
proc ts_send {spawn_id message {host ""} {passwd 0} {raise_error 1}} {
   # we catch errors - spawn_id might be broken
   set catch_return [catch {
      # human like send (usually for password entry)
      if {$passwd} {
         #set send_human {default word variability min max}
         #   default      Average default interarrival time, in seconds
         #   word         Average interarrival time at word endings, in seconds
         #   variability  Measure of variability of interarrival times (.1 = very variable; 10 = very invariable)
         #   min          Minimum arrival time
         #   max          Maximum arrival time

         set send_human {.05 .1 1 .01 1}
         send -i $spawn_id -h -- "${message}"
      } else {
         # if no hostname is passed, try to figure it out from spawn_id
         if {$host == ""} {
            set host [get_spawn_id_hostname $spawn_id]
         }

         # get host specific send delay
         set delay [host_conf_get_send_speed $host]
         if {$delay > 0.0} {
            ts_log_finest "WARNING: SENDING WITH DELAY OF $delay"
            set send_slow "1 $delay"
            send -i $spawn_id -s -- "${message}"
         } else {
            send -i $spawn_id -- "${message}"
         }
      }
   } catch_output]

   if {$catch_return != 0} {
      ts_log_severe "send failed:\n$catch_output" $raise_error
   }
}

# procedures
#                                                             max. column:     |
#****** remote_procedures/setup_qping_dump() ***********************************
#  NAME
#     setup_qping_dump() -- start qping dump as remote process (as root)
#
#  SYNOPSIS
#     setup_qping_dump { log_array } 
#
#  FUNCTION
#     starts qping -dump as root user on the qmaster host and fills the
#     log_array with connection specific data
#
#  INPUTS
#     log_array - array for results and settings
#
#  SEE ALSO
#     remote_procedures/setup_qping_dump()
#     remote_procedures/get_qping_dump_output()
#     remote_procedures/cleanup_qping_dump_output()
#*******************************************************************************
proc setup_qping_dump { log_array  } {
   upvar $log_array used_log_array
   get_current_cluster_config_array ts_config

   set master_host $ts_config(master_host)
   set master_host_arch [resolve_arch $master_host]
   set qping_binary    "$ts_config(product_root)/bin/$master_host_arch/qping"
   set qping_arguments "-dump $master_host $ts_config(commd_port) qmaster 1"
   set qping_env(SGE_QPING_OUTPUT_FORMAT) "s:1 s:2 s:3 s:4 s:5 s:6 s:7 s:8 s:9 s:10 s:11 s:12 s:13 s:14 s:15"

   if { $ts_config(gridengine_version) >= 60 } {
      ts_log_fine "starting remote qping process ..."
      set sid [open_remote_spawn_process $master_host "root" $qping_binary $qping_arguments 0 "" qping_env]
      ts_log_fine "remote qping process started!"
      set sp_id [lindex $sid 1]
   } else {
      set sid   "unsupported version < 60"
      set sp_id "unsupported version < 60"
   }

   set used_log_array(spawn_sid)    $sid
   set used_log_array(spawn_id)     $sp_id
   set used_log_array(actual_line)  0
   set used_log_array(in_block)     0

   
   if { $ts_config(gridengine_version) >= 60 } {
      set timeout 15
      while { 1 } {
         expect {
            -i $used_log_array(spawn_id) -- full_buffer {
               ts_log_severe "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
               break
            }
            -i $used_log_array(spawn_id) eof {
               ts_log_severe "unexpected eof getting qping -dump connection to qmaster"
               break
            }
            -i $used_log_array(spawn_id) timeout {
               ts_log_severe "timeout for getting qping -dump connection to qmaster"
               break
            }
            -i $used_log_array(spawn_id) -- "*debug_client*crm*\n" {
               ts_log_fine "qping is now connected to qmaster!"
               break
            }
            -i $used_log_array(spawn_id) -- "_exit_status_*\n" {
               ts_log_fine "qping doesn't support -dump switch in this version"
               break
            }
            -i $used_log_array(spawn_id) -- "*\n" {
               ts_log_finest $expect_out(buffer)
            }
         }     
      }
   }
}


proc get_xterm_path { host } {
   global ts_config CHECK_USER xterm_path_cache

   if { [info exists xterm_path_cache($host)] } {
      return $xterm_path_cache($host)
   }

   set xterm_path [start_remote_prog $host $CHECK_USER "which" "xterm" ]
   if { [is_remote_file $host $CHECK_USER $xterm_path 1] } {
      set xterm_path_cache($host) $xterm_path
      return $xterm_path
   }
   set xterm_candidate_path "/usr/bin/X11/xterm"
   if { [is_remote_file $host $CHECK_USER $xterm_candidate_path 1] } {
      set xterm_path_cache($host) $xterm_candidate_path
      return $xterm_candidate_path
   }
   set xterm_candidate_path "/usr/openwin/bin/xterm"
   if { [is_remote_file $host $CHECK_USER $xterm_candidate_path 1] } {
      set xterm_path_cache($host) $xterm_candidate_path
      return $xterm_candidate_path
   }
   set xterm_candidate_path "/usr/X11R6/bin/xterm"
   if { [is_remote_file $host $CHECK_USER $xterm_candidate_path 1] } {
      set xterm_path_cache($host) $xterm_candidate_path
      return $xterm_candidate_path
   }
   return "xterm"
}

#****** remote_procedures/check_all_system_times() **********************************
#  NAME
#     check_all_system_times() -- check clock synchronity on each cluster deamon host
#
#  SYNOPSIS
#     check_all_system_times {} 
#
#  FUNCTION
#     If the sytem time difference is larger than +/-10 seconds from qmaster time
#     the function will fail
#  
#  RESULT
#     0 on success, 1 on error
#************************************************************************************
proc check_all_system_times {} {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   set return_value 0
   set host_list [get_all_hosts]

   foreach host $host_list {
      ts_log_fine "test connection to $host ..."
      set result [string trim [start_remote_prog $host $CHECK_USER "echo" "hallo"]]
      ts_log_fine $result
   }

   set test_start [timestamp]
   foreach host $host_list {
      ts_log_fine "test remote system time on host $host ..."
      set time($host) [get_remote_time $host]
      ts_log_finest "$host: remote time: $time($host)"
      # fix remote execution time difference
      set time($host) [expr ( $time($host) - [expr ( [timestamp] - $test_start ) ] )] 
      ts_log_finest "$host: corrected time because of execution time: $time($host)"
   }

   set reference_time $time($ts_config(master_host))
   foreach host $host_list {
      set diff [expr ( $reference_time - $time($host) )]
      ts_log_fine "host $host has a time difference of $diff seconds compared to host $ts_config(master_host)"

      if { $diff > 45 || $diff < -45 } {
         ts_log_warning "host $host has a time difference of $diff seconds compared to host $ts_config(master_host)"
         set return_value 1
      }

   }
   return $return_value
}

#****** remote_procedures/get_remote_time() ************************************
#  NAME
#     get_remote_time() -- get tcl timestamp on remote host
#
#  SYNOPSIS
#     get_remote_time { host } 
#
#  FUNCTION
#     This procedure returns the output of expect timestamp command on the
#     specified host
#
#  INPUTS
#     host - host where timestamp should be returned
#
#  RESULT
#     unix timestamp number
#
#  SEE ALSO
#     remote_procedures/check_all_system_times()
#*******************************************************************************
proc get_remote_time { host } {
   global ts_config 
   global CHECK_USER
   set tcl_bin [ get_binary_path $host "expect"]
   set time_script "$ts_config(testsuite_root_dir)/scripts/time.tcl"
   set result [string trim [start_remote_prog $host $CHECK_USER $tcl_bin $time_script]]
   set time [get_string_value_between "current time is" -1 $result]
   return $time
}


#****** remote_procedures/get_qping_dump_output() ******************************
#  NAME
#     get_qping_dump_output() -- get qping dump output
#
#  SYNOPSIS
#     get_qping_dump_output { log_array } 
#
#  FUNCTION
#     This function fills up the log_array with qping -dump information. 
#     The function will return after 2 seconds when no dump output is available
#
#  INPUTS
#     log_array - array for results and settings
#
#  SEE ALSO
#     remote_procedures/setup_qping_dump()
#     remote_procedures/get_qping_dump_output()
#     remote_procedures/cleanup_qping_dump_output()
#*******************************************************************************
proc get_qping_dump_output { log_array } {
   upvar $log_array used_log_array
   get_current_cluster_config_array ts_config
   set return_value 0


   if { $ts_config(gridengine_version) >= 60 } {
      set timeout 2
      log_user 0
      expect {
         -i $used_log_array(spawn_id) -- full_buffer {
            ts_log_severe "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
         }
         -i $used_log_array(spawn_id) eof {
         }
         -i $used_log_array(spawn_id) timeout {
            set return_value 1
         }
         -i $used_log_array(spawn_id) -- "_exit_status_" {
         }
         -i $used_log_array(spawn_id) -- "*\n" {
            set output $expect_out(buffer)
            set output [ split $output "\n" ]
            foreach line $output {
               set line [string trim $line]
   
               if {[string length $line] == 0} {
                  continue
               }
   
   # we got a qping output line
               
               if { [string match "??:??:??*" $line] != 0 } {
                  set qping_line [split $line "|"]
                  set used_log_array(line,$used_log_array(actual_line)) $line
                  set row 1
                  foreach column $qping_line {
                     set used_log_array(line,$row,$used_log_array(actual_line)) $column
                     incr row 1
                  }
   
                  while { $row < 15 } {
                     set used_log_array(line,$row,$used_log_array(actual_line)) "not available"
                     incr row 1
                  }
                  set used_log_array(block,$used_log_array(actual_line)) "not available"
                  incr used_log_array(actual_line) 1
                  continue
               }
               
   # here we try to log addition data for the last line
               if { [string match "*block start*" $line ] != 0 } {
                  set used_log_array(in_block) 1
                  set line_block $used_log_array(actual_line)
                  incr line_block -1
                  set used_log_array(block,$line_block) ""
               }
   
               if { $used_log_array(in_block) == 1 } {
                  set line_block $used_log_array(actual_line)
                  incr line_block -1
                  append used_log_array(block,$line_block) "$line\n"
               }
               if { [string match "*block end*" $line ] != 0 } {
                  set used_log_array(in_block) 0
               }
   
            }
         }
      }
      log_user 1
   
   # qping for 60u4 and higher
   #   01 yes    time     time of debug output creation
   #   02 yes    local    endpoint service name where debug client is connected
   #   03 yes    d.       message direction
   #   04 yes    remote   name of participating communication endpoint
   #   05 yes    format   message data format
   #   06 yes    ack type message acknowledge type
   #   07 yes    msg tag  message tag information
   #   08 yes    msg id   message id
   #   09 yes    msg rid  message response id
   #   10 yes    msg len  message length
   #   11 yes    msg time time when message was sent/received
   #   12  no    xml dump commlib xml protocol output
   #   13  no    info     additional information
   
   # qping for 60u2 - 60u3
   #
   #   01 time     time of debug output creation
   #   02 local    endpoint service name where debug client is connected
   #   03 d.       message direction
   #   04 remote   name of participating communication endpoint
   #   05 format   message data format
   #   06 ack type message acknowledge type
   #   07 msg tag  message tag information
   #   08 msg id   message id
   #   09 msg rid  message response id
   #   10 msg len  message length
   #   11 msg time time when message was sent/received
   #   12 xml dump commlib xml protocol output
   #   13 info     additional information
   } else {
      ts_log_fine "qping not supported !"
      set return_value 1
   }
   return $return_value
}

#****** remote_procedures/cleanup_qping_dump_output() **************************
#  NAME
#     cleanup_qping_dump_output() -- shutdwon qping dump connection
#
#  SYNOPSIS
#     cleanup_qping_dump_output { log_array } 
#
#  FUNCTION
#     close qping -dump spawn connection
#
#  INPUTS
#     log_array - array for results and settings
#
#  SEE ALSO
#     remote_procedures/setup_qping_dump()
#     remote_procedures/get_qping_dump_output()
#     remote_procedures/cleanup_qping_dump_output()
#*******************************************************************************
proc cleanup_qping_dump_output { log_array } {
   upvar $log_array used_log_array
   get_current_cluster_config_array ts_config

   if { $ts_config(gridengine_version) >= 60 } {
      close_spawn_process $used_log_array(spawn_sid)
   }
}


#                                                             max. column:     |
#****** remote_procedures/start_remote_tcl_prog() ******
# 
#  NAME
#     start_remote_tcl_prog -- ??? 
#
#  SYNOPSIS
#     start_remote_tcl_prog { host user tcl_file tcl_procedure tcl_procargs } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     host          - ??? 
#     user          - ??? 
#     tcl_file      - ??? 
#     tcl_procedure - ??? 
#     tcl_procargs  - ??? 
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
#     ???/???
#*******************************
proc start_remote_tcl_prog { host user tcl_file tcl_procedure tcl_procargs} {
   global CHECK_DEFAULTS_FILE
   global CHECK_DEBUG_LEVEL
   get_current_cluster_config_array ts_config
 
   log_user 1
   ts_log_fine "--- start_remote_tcl_prog start ---"
   set tcl_bin [ get_binary_path $host "expect"]
   set tcl_prog "$ts_config(testsuite_root_dir)/scripts/remote_tcl_command.sh"
   set tcl_testhome "$ts_config(testsuite_root_dir)"
   set tcl_defaults  "$CHECK_DEFAULTS_FILE"
   
   ts_log_finest "tcl_bin: \"$tcl_bin\""
   ts_log_finest "tcl_prog: \"$tcl_prog\""
   ts_log_finest "tcl_testhome: \"$tcl_testhome\""
   ts_log_finest "tcl_defaults: \"$tcl_defaults\""


   set debug_arg ""
   if { $CHECK_DEBUG_LEVEL != 0 } {
      set debug_arg "debug"
   }
   set remote_args "$tcl_bin $ts_config(testsuite_root_dir)/tcl_files/$tcl_file $tcl_testhome $tcl_procedure \"$tcl_procargs\" $tcl_defaults $debug_arg"

   set result ""
   ts_log_finest "prog: $tcl_prog"
   ts_log_finest "remote_args: $remote_args"
   log_user 1

   set result [start_remote_prog "$host" "$user" "$tcl_prog" "$remote_args" prg_exit_state 600 0 "" "" 1 0 0]
   if { [string first "Error in procedure" $result] >= 0 } {
      ts_log_warning "error in $tcl_file, proc $tcl_procedure $tcl_procargs"
   }
   puts $result
   log_user 1
   ts_log_fine "--- start_remote_tcl_prog end   ---"
   return $result
}




#                                                             max. column:     |
#
#****** remote_procedures/start_remote_prog() ******
#  NAME
#     start_remote_prog() -- start remote application
#
#  SYNOPSIS
#     start_remote_prog { hostname user exec_command exec_arguments 
#     {exit_var prg_exit_state} {mytimeout 60} {background 0} {envlist ""}} 
#
#  FUNCTION
#     This procedure will start the given command on the given remote
#     host.
#
#  INPUTS
#     hostname                  - hostname
#     user                      - user name
#     exec_command              - application to start
#     exec_arguments            - application arguments
#     {exit_var prg_exit_state} - return value of the (last) remote command
#     {mytimeout 60}            - problem timeout (for connection building)
#     {background 0}            - if not 0 -> start remote prog in background
#                                 this will always take 15 seconds 
#     {cd_dir ""}               - directory to cd to before executing command
#     {envlist ""}              - array with environment settings to export
#                                 before starting program
#     { do_file_check 1 }       - internal parameter for file existence check
#                                 if 0: don't do a file existence check
#     { source_settings_file 1 }- if 1 (default):
#                                 source $SGE_ROOT/$SGE_CELL/settings.csh
#                                 if not 1: don't source settings file
#     { set_shared_lib_path 1 } - if 1 (default): set shared lib path
#                               - if not 1: don't set shared lib path 
#     { without_start_output 0 } - if 0 (default): put out start/end mark of output
#                                  if not 0:       don't print out start/end marks
#     { without_sge_single_line 0} - if 0 (default): set SGE_SINGLE_LINE=1 and export it 
#                                    if not 0:       unset SGE_SINGLE_LINE
#
#  RESULT
#     program output
#
#  EXAMPLE
#     set envlist(COLUMNS) 500
#     start_remote_prog "ahost" "auser" "ls" "-la" "prg_exit_state" "60" "0" "envlist"
#*******************************
# CR checked
proc start_remote_prog { hostname
                         user
                         exec_command
                         exec_arguments
                         {exit_var prg_exit_state}
                         {mytimeout 60}
                         {background 0}
                         {cd_dir ""}
                         {envlist ""}
                         {do_file_check 1}
                         {source_settings_file 1}
                         {set_shared_lib_path 0}
                         {raise_error 1}
                         {win_local_user 0}
                         {without_start_output 0}
                         {without_sge_single_line 0}
                       } {
   global CHECK_MAIN_RESULTS_DIR CHECK_DEBUG_LEVEL 
   upvar $exit_var back_exit_state

   if {$envlist != ""} {
      upvar $envlist users_env
   }

   set back_exit_state -1
   set tmp_exit_status_string ""
   if {[llength $exec_command] != 1} {
      puts "= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ="
      puts "  WARNING     WARNING   WARNING  WARNING"
      puts "  procedure start_remote_prog: \"$exec_command\""
      puts "  is not a command name; it has additional arguments" 
      puts "= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ="
      if {$CHECK_DEBUG_LEVEL == 2} {
         wait_for_enter 
      }
   }

   # open connection
   set id [open_remote_spawn_process "$hostname" "$user" "$exec_command" "$exec_arguments" $background $cd_dir users_env $source_settings_file 15 $set_shared_lib_path $raise_error $win_local_user $without_start_output $without_sge_single_line]
   if {$id == ""} {
      ts_log_severe "got no spawn id" $raise_error
      set back_exit_state -255
      return ""
   }

   set myspawn_id [ lindex $id 1 ]
   set output ""
   set do_stop 0

   # in debug mode, we want to see all shell I/O
   log_user 0
   if { $CHECK_DEBUG_LEVEL != 0 } {
      log_user 1
   }

   set timeout $mytimeout
   set real_end_found 0
   set real_start_found 0
   set nr_of_lines 0
   set find_out_more 0
   ts_log_finest "start_remote_prog: expecting ..."
   expect {
     -i $myspawn_id timeout {
        set find_out_more 1
     }
     -i $myspawn_id full_buffer {
        ts_log_severe "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value" $raise_error
     }
     -i $myspawn_id -- "*\n" {
        foreach line [split $expect_out(0,string) "\n"] {
           if {$line != ""} {
              if {$real_start_found} {
                 append output "$line\n"
                 incr nr_of_lines 1
                 set tmp_exit_status_start [string first "_exit_status_:" $line]
                 if { $tmp_exit_status_start >= 0 } {
                    # check if a ? is between _exit_status_:() - brackets
                    set tmp_exit_status_string [string range $line $tmp_exit_status_start end]
                    set tmp_exit_status_end [string first ")" $tmp_exit_status_string]
                    if {$tmp_exit_status_end >= 0 } {
                       set tmp_exit_status_string [ string range $tmp_exit_status_string 0 $tmp_exit_status_end ]
                    } else {
                       ts_log_severe "unexpected error - did not get full exit status string" $raise_error
                    }
                    set real_end_found 1
                    set real_start_found 0
                 }
              } else {
                 if {$real_end_found} {
                    #  here we read the last line ( _END_OF_FILE_ )
                    set do_stop 1
                    break
                 }
                 if { [ string first "_start_mark_:" $line ] >= 0 } {
                    set real_start_found 1
                    set output "_start_mark_\n"
                    if { $background == 1 } { 
                       set do_stop 1
                       break
                    }
                 }
              }
           }
        }
        if { !$do_stop } {
           exp_continue
        }
     }
   }


   if { $find_out_more == 1 } {
      set info_message_text ""
      append info_message_text "timeout error(1):\n"
      append info_message_text "maybe the shell is expecting an interactive answer from user?\n"
      append info_message_text "exec commando was: \"$exec_command $exec_arguments\"\n"
      append info_message_text "expect_out(buffer):\n>$expect_out(buffer)<\n"
      append info_message_text "more information in next error message in 5 seconds!!!\n"
      append info_message_text ""
      ts_log_severe "$info_message_text" $raise_error
      set timeout 5
      expect {
         -i $myspawn_id full_buffer {
            ts_log_severe "buffer overflow! Increment CHECK_EXPECT_MATCH_MAX_BUFFER value" $raise_error
         }
         -i $myspawn_id timeout {
            ts_log_severe "no more output available" $raise_error
         }
         -i $myspawn_id "*" {
            ts_log_severe "expect buffer:\n$expect_out(buffer)" $raise_error
         }
         -i $myspawn_id default {
            ts_log_severe "default - no more output available" $raise_error
         }
      }
   }
   ts_log_finest "start_remote_prog: expecting ... done"

   # parse output: cut leading sequence 
   set found_start [string first "_start_mark_" $output]
   if { $found_start >= 0 } {
      incr found_start 13
      set output [string range $output $found_start end]
   }

   # parse output: find end of output and rest
   if {$real_end_found == 1} {
      set found_end [string first "_exit_status_:" $output]
      if { $found_end >= 0 } {
         incr found_end -1
         set output [ string range $output 0 $found_end ] 
      }
   }

   # parse output: search exit status
   if {$real_end_found == 1} {
      set first_index [string first "(" $tmp_exit_status_string ]
      incr first_index 1
      set last_index [string first ")" $tmp_exit_status_string ]
      incr last_index -1 
      set exit_status [string range $tmp_exit_status_string $first_index $last_index]
   } else {
      set exit_status -1
   }

   ts_log_finest "E X I T   S T A T E   of remote prog: $exit_status"
   close_spawn_process $id
    
   if { $CHECK_DEBUG_LEVEL == 2 } {
      wait_for_enter
   }

   set back_exit_state $exit_status
   return $output
}

#****** remote_procedures/sendmail() *******************************************
#  NAME
#     sendmail() -- sendmail in mime format (first prototype)
#
#  SYNOPSIS
#     sendmail { to subject body { send_html 0 } { cc "" } { bcc "" } 
#     { from "" } { replyto "" } { organisation "" } } 
#
#  FUNCTION
#     This procedure is under construction
#
#  INPUTS
#     to                  - ??? 
#     subject             - ??? 
#     body                - ??? 
#     { send_html 0 }     - ??? 
#     { cc "" }           - ??? 
#     { bcc "" }          - ??? 
#     { from "" }         - ??? 
#     { replyto "" }      - ??? 
#     { organisation "" } - ??? 
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
#     ???/???
#*******************************************************************************
proc sendmail { to subject body { send_html 0 } { cc "" } { bcc "" } { from "" } { replyto "" } { organisation "" } { force_mail 0 } } {
   global CHECK_USER CHECK_ENABLE_MAIL CHECK_MAILS_SENT CHECK_MAX_ERROR_MAILS
   get_current_cluster_config_array ts_config

   if { $CHECK_ENABLE_MAIL != 1 && $force_mail == 0 } {
     ts_log_fine "mail sending disabled, mails sent: $CHECK_MAILS_SENT"
     ts_log_fine "mail subject: $subject"
     ts_log_fine "mail body:"
     ts_log_fine "$body"
     return -1
   }


   ts_log_fine "--> sending mail to $to from host $ts_config(mailx_host) ...\n"
   # setup mail message    
   set mail_file [get_tmp_file_name]
   set file [open $mail_file "w"]

   puts $file "Mime-Version: 1.0"
   if { $send_html != 0 } {
      puts $file "Content-Type: text/html ; charset=ISO-8859-1"
   } else {
      puts $file "Content-Type: text/plain ; charset=ISO-8859-1"
   }

   if { $organisation != "" }  {
      puts $file "Organization: $organisation"
   }
   if { $from != "" } {
      puts $file "From: $from"
   }
   if { $replyto != "" } {
      puts $file "Reply-To: $replyto"
   }
   puts $file "To: $to"
   foreach elem $cc {
      puts $file "Cc: $elem"
   }
   foreach elem $bcc {
      puts $file "Bcc: $elem"
   }

   set new_subject "[get_version_info] ($ts_config(cell)) - $subject"

   puts $file "Subject: $new_subject"
   puts $file ""
   # after this line the mail begins
   puts $file "Grid Engine Version: [get_version_info]"
   puts $file "Subject            : $subject"
   puts $file ""
   puts $file "$body"
   puts $file ""
   puts $file "."
   close $file


   # start sendmail

   # TODO: get sendmail path
   # TODO: configure mail host in testsuite configuration

   set command "/usr/lib/sendmail"
   set arguments "-B 8BITMIME -t < $mail_file"

   set result [start_remote_prog $ts_config(mailx_host) $CHECK_USER $command $arguments prg_exit_state 60 0 "" "" 1 0]
   if { $prg_exit_state != 0 } {
      ts_log_frame
      ts_log_fine "COULD NOT SEND MAIL:\n$result"
      ts_log_fine
      return -1
   }
   incr CHECK_MAILS_SENT 1
   if { $CHECK_MAILS_SENT == $CHECK_MAX_ERROR_MAILS } {
      set CHECK_ENABLE_MAIL 0
      sendmail $to "max mail count reached" "" 0 "" "" "" "" "" 1
   }
     
   return 0
}


proc sendmail_wrapper { address cc subject body } {
   global CHECK_USER
   get_current_cluster_config_array ts_config


#   set html_text ""
#   foreach line [split $body "\n"] {
#      append html_text [create_html_text $line]
#   }
#   return [sendmail $address $subject $html_text 1 $cc "" $address $address "Gridware"]

   if { $ts_config(mail_application) == "mailx" } {
      ts_log_fine "using mailx to send mail ..."
      return 1
   }
   if { $ts_config(mail_application) == "sendmail" } {
      ts_log_fine "using sendmail to send mail ..."
      sendmail $address $subject $body 0 $cc "" $address $address "Gridware"
      return 0
   }

   

   ts_log_fine "starting $ts_config(mail_application) on host $$ts_config(mailx_host) to send mail ..."
   set tmp_file [get_tmp_file_name]
   set script [ open "$tmp_file" "w" "0755" ]
   puts $script "Grid Engine Version: [get_version_info]"
   puts $script "Subject            : $subject"
   puts $script ""
   puts $script $body
   puts $script ""
   flush $script
   close $script

   set new_subject "[get_version_info] ($ts_config(cell)) - $subject"

   wait_for_remote_file $ts_config(mailx_host) $CHECK_USER $tmp_file
   set result [start_remote_prog $ts_config(mailx_host) $CHECK_USER $ts_config(mail_application) "\"$address\" \"$cc\" \"$new_subject\" \"$tmp_file\""]
   ts_log_fine "mail application returned exit code $prg_exit_state:"
   ts_log_fine $result
   return 0
}

proc create_error_message {err_string} {
  set err_complete  [split $err_string "|"]
  set err_procedure [lindex $err_complete 0]
  set err_checkname [lindex $err_complete 1]
  set err_calledby  [lindex $err_complete 2]
  set err_list      [lrange $err_complete 3 end]
   set err_text ""
   foreach elem $err_list {
      if {$err_text != ""} {
         append err_text "|"
      }
      append err_text $elem
   }
  
  append output "check       : $err_checkname\n"
  append output "procedure   : $err_procedure\n"
  if { [ string compare $err_calledby $err_procedure ] != 0 } {
     append output "called from : $err_calledby\n"
  }
  append output "----------------------------------------------------------------\n"
  append output "$err_text\n"
  append output "----------------------------------------------------------------\n"

  return $output
}



proc show_proc_error {result new_error} {
   global check_name
   global CHECK_ACT_LEVEL
   global CHECK_SEND_ERROR_MAILS

   get_current_cluster_config_array ts_config


   if { $result != 0 } {
      set category "error"
      if { $result == -3 } {
         set category "unsupported test warning"
      }
      ts_log_frame
      ts_log_fine "$category"
      ts_log_fine "runlevel    : \"[get_run_level_name $CHECK_ACT_LEVEL]\", ($CHECK_ACT_LEVEL)"
      ts_log_newline
      set error_output [create_error_message $new_error]
      ts_log_fine $error_output 
      ts_log_frame

      if { $CHECK_SEND_ERROR_MAILS == 1 } {
         append mail_body "\n"
         append mail_body "Date            : [exec date]\n"
         append mail_body "check_name      : $check_name\n"
         append mail_body "category        : $category\n"
         append mail_body "runlevel        : [get_run_level_name $CHECK_ACT_LEVEL] (level: $CHECK_ACT_LEVEL)\n"
         append mail_body "check host      : $ts_config(master_host)\n"
         append mail_body "product version : [get_version_info]\n"
         append mail_body "SGE_ROOT        : $ts_config(product_root)\n"
         append mail_body "master host     : $ts_config(master_host)\n"
         append mail_body "execution hosts : $ts_config(execd_hosts)\n\n"

         append mail_body "$error_output"
         set catch_return [catch {
            foreach level "1 2 3 4" {
               upvar $level expect_out out
               if {[info exists out]} {
                  append mail_body "----- expect buffer in upper level $level --------\n"
                  foreach i [array names out] {
                     append mail_body "$i:\t$out($i)\n"
                  }
               }
            }
         } catch_error_message ]
         if { $catch_return != 0 } {
            ts_log_fine "catch returned not 0: $catch_error_message"
         }
       
         append mail_body "\nTestsuite configuration (ts_config):\n"
         append mail_body "====================================\n"
         show_config ts_config 0 mail_body

         mail_report "testsuite $category - $check_name" $mail_body
      }
   }
}



#****** remote_procedures/close_spawn_id() *************************************
#  NAME
#     close_spawn_id() -- close spawn_id and wait child process
#
#  SYNOPSIS
#     close_spawn_id { spawn_id } 
#
#  FUNCTION
#     Closes a certain spawn id and calls wait to have the child process
#     cleaned up.
#
#  INPUTS
#     spawn_id - the spawn_id to close
#
#  NOTES
#     The function should be called within a catch block.
#     Both close and wait called here might raise an exception.
#*******************************************************************************
proc close_spawn_id {spawn_id} {
   close -i $spawn_id
   wait -nowait -i $spawn_id
}

#****** remote_procedures/increase_timeout() ***********************************
#  NAME
#     increase_timeout() -- stepwise increase expect timeout
#
#  SYNOPSIS
#     increase_timeout { {max 5} {step 1} } 
#
#  FUNCTION
#     Stepwise increases the timeout variable in the callers context.
#     timeout is increased by $step per call of this function 
#     up to $max.
#
#  INPUTS
#     {max 5}  - maximum timeout value
#     {step 1} - step
#*******************************************************************************
proc increase_timeout {{max 5} {step 1}} {
   upvar timeout timeout

   if {$timeout < $max} {
      incr timeout $step
   }
}

#****** remote_procedures/map_special_users() **********************************
#  NAME
#     map_special_users() -- map special user names and windows user names
#
#  SYNOPSIS
#     map_special_users { hostname user win_local_user } 
#
#  FUNCTION
#     Does username mapping for windows users.
#
#     The user id "root" is mapped to the windows user name "Administrator".
#     If we connect to a windows machine, usually the connection will be done
#     as windows domain user.
#     There are cases where we have to become a local user (user Administrator, 
#     or parameter win_local_user set to 1).
#     In this case, we'll use as hostname "$hostname+$user".
#
#     On UNIX systems, using rlogin, we'll always connect as CHECK_USER, and
#     later on switch to root or the target user.
#     Using ssh, we'll connect as CHECK_USER, or as root, and later on 
#     switch to the target user.
#
#     On Windows systems, we'll always connect as the target user (CHECK_USER,
#     Administrator, other target user).
#
#  INPUTS
#     hostname       - host to which we want to connect
#     user           - the target user id (may also be a special user id)
#     win_local_user - do we want to connect as windows local or domain user?
#
#  RESULT
#     The functions sets the following variables in the callers context:
#        - real_user:         this is the real user name on the target machine, 
#                             after mapping special users,
#                             or user name "root" to windows "Administrator".
#        - connect_user:      We'll connect to the target host as this user.
#        - connect_full_user: We'll use this user name on the rlogin / ssh 
#                             commandline.
#
#  EXAMPLE
#     map_special_users unix_host root 0
#        real_user         = root
#        connect_user      = CHECK_USER
#        connect_full_user = CHECK_USER
#
#     map_special_users unix_host sgetest 1
#        real_user         = sgetest
#        connect_user      = sgetest
#        connect_full_user = sgetest
#
#     map_special_users win_host root 0
#        real_user         = Administrator
#        connect_user      = Administrator
#        connect_full_user = win_host+Administrator
#
#     map_special_users win_host sgetest 0
#        real_user         = sgetest
#        connect_user      = sgetest
#        connect_full_user = sgetest
#
#     map_special_users win_host sgetest 1
#        real_user         = sgetest
#        connect_user      = sgetest
#        connect_full_user = win_host+sgetest
#
#  SEE ALSO
#     remote_procedures/open_remote_spawn_process()
#*******************************************************************************
proc map_special_users {hostname user win_local_user} {
   global CHECK_USER

   upvar real_user         real_user          ;# this is the real user name on the target machine
   upvar connect_user      connect_user       ;# we'll connect as this user
   upvar connect_full_user connect_full_user  ;# using this name in rlogin/ssh -l option (windows domain!)

   set real_user $user

   # on interix, the root user is Administrator
   # and we have to connect as the target user, as su doesn't work
   # for Administrator, we have to use "hostname+Administrator" (local user)
   if {[host_conf_get_arch $hostname] == "win32-x86"} {
      if {$user == "root"} {
         set real_user "Administrator"
         if {!$win_local_user} {
            set win_local_user 1
         }
      }

      set connect_user        $real_user

      if {$win_local_user} {
         set connect_full_user   "$hostname+$real_user"
      } else {
         set connect_full_user   $real_user
      }
   } else {
      # on unixes, we connect
      # with rlogin always as CHECK_USER (and su later, if necessary)
      # despite having the root password, we do not connect as root, as some unixes
      # disallow root login from network
      #
      # with ssh either as CHECK_USER
      #          or     as root (and su later, if necessary)
      if {[have_ssh_access]} {
         if {$real_user == $CHECK_USER} {
            set connect_user $CHECK_USER
            set connect_full_user $CHECK_USER
         } else {
            set connect_user "root"
            set connect_full_user "root"
         }
      } else {
         set connect_user $CHECK_USER
         set connect_full_user $CHECK_USER
      }
   }

   ts_log_finest "map_special_users: $user on host $hostname"
   ts_log_finest "   real_user:         $real_user"
   ts_log_finest "   connect_user:      $connect_user"
   ts_log_finest "   connect_full_user: $connect_full_user"
}

#****** remote_procedures/open_remote_spawn_process() **************************
#  NAME
#     open_remote_spawn_process() -- open spawn process on remote host
#
#  SYNOPSIS
#     open_remote_spawn_process { hostname user exec_command exec_arguments 
#     { background 0 } {envlist ""} { source_settings_file 1 } 
#     { nr_of_tries 15 } } 
#
#  FUNCTION
#     This procedure creates a shell script with default settings for Grid
#     Engine and starts it as spawn process on the given host.
#
#  INPUTS
#     hostname                   -  remote host (can also be local host!)
#     user                       -  user to start script
#     exec_command               -  command after script init
#     exec_arguments             -  arguments for command
#     { background 0 }           -  if not 0: 
#                                      start command with "&" in background 
#                                   if 2:
#                                      wait 30 seconds after starting 
#                                      background process
#     {cd_dir ""}                -  directory in which to execute the command
#     {envlist ""}               -  array with environment settings to export
#                                   before starting program
#     { source_settings_file 1 } -  if 1 (default):
#                                      source $SGE_ROOT/$SGE_CELL/settings.csh
#                                   if not 1:
#                                      don't source settings file
#     { nr_of_tries 15 }         -  timout value
#     { without_start_output 0 } - if 0 (default): put out start/end mark of output
#                                  if not 0:       don't print out start/end marks
#     { without_sge_single_line 0} - if 0 (default): set SGE_SINGLE_LINE=1 and export it 
#                                    if not 0:       unset SGE_SINGLE_LINE
#
#
#  RESULT
#     spawn id of process (internal format, see close_spawn_process for details)
#
#  EXAMPLE
#     set id [open_remote_spawn_process "boromir" "testuser" "ls" "-la"]
#     set do_stop 0
#     set output ""
#     set sp_id [lindex $id 1]
#     while { $do_stop == 0 } {
#        expect {
#           -i $sp_id full_buffer {     ;# input buffer default size is 2000 byte 
#              set do_stop 1
#              puts "error - buffer overflow" 
#           } 
#           -i $sp_id timeout { set do_stop 1 }
#           -i $sp_id eof { set do_stop 1 }
#           -i $sp_id "*\r" {
#              set output "$output$expect_out(0,string)"
#           }
#        }
#     }  
#     close_spawn_process $id
#     ts_log_fine ">>> output start <<<"
#     ts_log_fine $output
#     ts_log_fine ">>> output end <<<"
#
#  NOTES
#     The spawn command is from the TCL enhancement EXPECT
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     remote_procedures/increase_timeout()
#     remote_procedures/close_spawn_id()
#     remote_procedures/map_special_users()
#*******************************************************************************
proc open_remote_spawn_process { hostname
                                 user
                                 exec_command
                                 exec_arguments
                                 {background 0}
                                 {cd_dir ""}
                                 {envlist ""}
                                 {source_settings_file 1}
                                 {nr_of_tries 15}
                                 {set_shared_lib_path 0}
                                 {raise_error 1}
                                 {win_local_user 0}
                                 {without_start_output 0}
                                 {without_sge_single_line 0}
                                 {shell_script_name_var shell_script_name}
                               } {

   global CHECK_USER
   global CHECK_EXPECT_MATCH_MAX_BUFFER CHECK_DEBUG_LEVEL
   global CHECK_LOGIN_LINE CHECK_SHELL_PROMPT
   global open_remote_spawn_script_cache
   upvar $shell_script_name_var used_script_name
   get_current_cluster_config_array ts_config

   set testsuite_root_dir $ts_config(testsuite_root_dir)
   ts_log_finest "open_remote_spawn_process on host \"$hostname\""
   ts_log_finest "user:           $user"
   ts_log_finest "exec_command:   $exec_command"
   ts_log_finest "exec_arguments: $exec_arguments"

   # check parameters
   if {$nr_of_tries < 5} {
      ts_log_config "unreasonably low nr_of_tries: $nr_of_tries, setting to 5" $raise_error
   }
   # the win_local_user feature is only needed on windows
   # reset it for non windows hosts
   if {$win_local_user && [host_conf_get_arch $hostname] != "win32-x86"} {
      set win_local_user 0
   }

   # handle special user ids
   map_special_users $hostname $user $win_local_user

   # common part of all error messages
   set error_info "connection to host \"$hostname\" as user \"$user\""

   # if command shall be started as other user than CHECK_USER
   # we need root access
   # unless the target host is windows - here we need each user's password
   if {$real_user != $CHECK_USER && [host_conf_get_arch $hostname] != "win32-x86"} {
      if {[have_root_passwd] == -1} {
         ts_log_warning "${error_info}\nroot access required" $raise_error
         return "" 
      }
   }

   # we might want to pass a special environment
   set env_string ""
   if {$envlist != ""} {
      upvar $envlist users_env
      foreach var [array names users_env] {
         append env_string "$var=$users_env($var)"
      }
   }

   # for code coverage testing, we might need a special environment
   if {[coverage_enabled]} {
      coverage_per_process_setup $hostname $real_user users_env
   }

   # if the same script is executed multiple times, don't recreate it
   set re_use_script 0
   # we check for a combination of all parameters
   set spawn_command_arguments "$hostname$user$exec_command$exec_arguments$background$cd_dir$env_string$source_settings_file$set_shared_lib_path$win_local_user$without_start_output$without_sge_single_line"
   if {[info exists open_remote_spawn_script_cache($spawn_command_arguments)]} {
      if {[file isfile $open_remote_spawn_script_cache($spawn_command_arguments)]} {
         set re_use_script 1
      } else {
         # script file does not exist anymore - remove from cache
         unset open_remote_spawn_script_cache($spawn_command_arguments)
      }
   }

   # either use the previous script, or create a new one
   if {$re_use_script} {
      set script_name $open_remote_spawn_script_cache($spawn_command_arguments)
      ts_log_finest "re-using script $script_name"
   } else {
      set command_name [file tail $exec_command]
      set script_name [get_tmp_file_name $hostname $command_name "sh"]
      # add script name to cache
      set open_remote_spawn_script_cache($spawn_command_arguments) $script_name
      create_shell_script "$script_name" $hostname "$exec_command" "$exec_arguments" $cd_dir users_env "/bin/sh" 0 $source_settings_file $set_shared_lib_path $without_start_output $without_sge_single_line
      ts_log_finest "created $script_name"
   }
   set used_script_name $script_name


   # get info about an already open rlogin connection
   set create_alternate_connection 0
   set open_new_connection 1
   if {[get_open_spawn_rlogin_session $hostname $user $win_local_user con_data]} {
      if { $con_data(in_use) } {
         set info_text "connection to host \"$con_data(hostname)\" ad user \"$con_data(user)\" is in use by script:\n"
         append info_text "$con_data(command_script)\n"
         append info_text "command string: $con_data(command_name) $con_data(command_args)\n"
         ts_log_finer $info_text

         set found_alternative 0
         ts_log_finest "session is in use, looking for alternate session ..."
         foreach alternative $con_data(alternate_sessions) {
            if {[is_spawn_process_in_use $alternative] == 0} {
               fill_session_info_array $alternative con_data
               ts_log_finest "found alternate session!"
               set found_alternative 1
               break
            }
         }
         if {!$found_alternative} { 
            ts_log_finest "no alternate session available!"
            set create_alternate_connection 1
         }
      } 
      if {$create_alternate_connection == 0} {
         # check if the connection is OK - if not, we'll try to reopen it
         if {[check_rlogin_session $con_data(spawn_id) $con_data(pid) $hostname $user $con_data(nr_shells)]} {
            ts_log_finest "Using open rlogin connection to host \"$hostname\", user \"$user\""
            set open_new_connection 0
            set spawn_id     $con_data(spawn_id)
            set pid          $con_data(pid)
            set nr_of_shells $con_data(nr_shells)
            ts_log_finest "session \"$spawn_id\" has alternate sessions: $con_data(alternate_sessions)"
         }
      }
   }

   if {$open_new_connection} {
      # on interix (windows), we often get a message
      # "in.rlogind: Forkpty: Permission denied."
      # we want to try rlogin until success
      set connect_succeeded 0
      while {$connect_succeeded == 0} {
         # no open connection - open a new one
         ts_log_finest "opening connection to host $hostname"

         # on unixes, we connect as CHECK_USER which will give us no passwd question,
         # and handle root passwd question when switching to the target user later on
         #
         # on windows, we have to directly connect as the target user, where we get
         # a passwd question for root and first/second foreign user
         # 
         # for unixes, we reject a passwd question (passwd = ""), for windows, we 
         # send the stored passwd
         set passwd ""

         # we either open an ssh connection (as CHECK_USER or root) 
         # or rlogin as CHECK_USER
         #
         # on windows hosts, login as root and su - <user> doesn't work.
         # here we connect as target user and answer the passwd question
         # for connections as CHECK_USER, we don't expect a password question
         if {[host_conf_get_arch $hostname] == "win32-x86" && $connect_full_user != $CHECK_USER} {
            set passwd [get_passwd $real_user]
         }

         set tmp_help [have_ssh_access];
         set tmp_log_user [log_user]
         log_user 0
         if { $CHECK_DEBUG_LEVEL != 0 } {
            log_user 1
         }
         if {$tmp_help || $ts_config(connection_type) == "ssh_with_password"} {
            set ssh_binary [get_binary_path $ts_config(master_host) ssh]
            set pid [spawn $ssh_binary "-l" $connect_full_user $hostname]
         } else {
            set pid [spawn "rlogin" $hostname "-l" $connect_full_user]
         }
         set log_user $tmp_log_user

         if {$pid == 0 } {
           ts_log_warning "${error_info}\ncould not spawn! (pid = $pid)"  $raise_error
           return "" 
         }

         # in debug mode we want to see all the shell output
         log_user 0
         if {$CHECK_DEBUG_LEVEL != 0} {
            log_user 1
         }

         # we now have one open shell
         set nr_of_shells 1

         # set buffer size for new connection
         match_max -i $spawn_id $CHECK_EXPECT_MATCH_MAX_BUFFER
         ts_log_finest "open_remote_spawn_process -> buffer size is: [match_max -i $spawn_id]"

         # wait for shell to start
         set connect_errors 0
         set password_sent 0
         set unrecognized_messages {}
         set catch_return [catch {
            set num_tries $nr_of_tries
            set timeout 2
            expect {
               -i $spawn_id eof {
                  ts_log_warning "${error_info}\nunexpected eof" $raise_error
                  set connect_errors 1
               }
               -i $spawn_id full_buffer {
                  ts_log_warning "${error_info}\nbuffer overflow" $raise_error
                  set connect_errors 1
               }
               -i $spawn_id timeout {
                  incr num_tries -1
                  if {$num_tries > 0} {
                     if {$num_tries < 77} {
                        ts_log_progress
                        ts_send $spawn_id "\n" $hostname
                     }
                     increase_timeout
                     exp_continue
                  } else {
                     ts_log_warning "${error_info}\nstartup timeout"  $raise_error
                     set connect_errors 1
                  }
               }
               -i $spawn_id "assword:" {
                  if {$passwd == ""} {
                     ts_log_warning "${error_info}\ngot unexpected password question" $raise_error
                     set connect_errors 1
                  } else {
                     ts_log_finest "Got password question"
                     log_user 0  ;# in any case before sending password
                     ts_send $spawn_id "$passwd\n" $hostname 1
                     if {$CHECK_DEBUG_LEVEL != 0} {
                        log_user 1
                     }
                     set password_sent 1
                     exp_continue
                  }
               }
               -i $spawn_id -- "The authenticity of host*" {
                  ts_log_finest "Got ssh \"authenticity of host\""
                  ts_send $spawn_id "yes\n" $hostname
                  exp_continue
               }
               -i $spawn_id -- "Are you sure you want to continue connecting (yes/no)?*" {
                  ts_log_finest "Got ssh continue connection question"
                  ts_send $spawn_id "yes\n" $hostname
                  exp_continue
               }
               -i $spawn_id -- "Please type 'yes' or 'no'*" {
                  ts_log_finest "Go yes/no question"
                  ts_send $spawn_id "yes\n" $hostname
                  exp_continue
               }
               -i $spawn_id -- "onnection reset by peer*" {
                  set error_message    "${error_info}\nConnection reseted by peer ($ts_config(master_host) -> $hostname):"
                  append error_message "\n"
                  append error_message "\n    It could be that (x)inetd on host $hostname limits the number of parallel connections"
                  append error_message "\n    Please check your (x)inetd configuration"
                  append error_message "\n"
                  append error_message "\n    On some linuxes the configuration of xinetd is stored in /etc/xinetd.conf"
                  append error_message "\n    Search for the \"instances\" parameter."
                  append error_message "\n    --------------------------------------"
                  append error_message "\n    defaults"
                  append error_message "\n    { ..."
                  append error_message "\n            instances       = 30"
                  append error_message "\n            ^^^^^^^^^^^^^^^^^^^^"
                  append error_message "\n    ... }"
                  append error_message "\n    --------------------------------------"
                  append error_message "\n    To find out how many rlogin connections are already open you can use"
                  append error_message "\n    the following command:"
                  append error_message "\n    # ps -ef \| grep xinetd"
                  append error_message "\n    root      2076     1  0 Jul25 \?        00:00:02 /usr/sbin/xinetd"
                  append error_message "\n    # pstree -p 2076 \| wc -l"
                  append error_message "\n         23"
                  append error_message "\n"

                  ts_log_warning "$error_message" $raise_error
                  set connect_errors 1
               }
               -i $spawn_id "in.rlogind: Forkpty: Permission denied." {
                  # interix (windows) rlogind doesn't let us login
                  # sleep a while and retry
                  ts_log_progress FINE "x"
                  sleep 10
                  exp_continue
               }
               -i $spawn_id -re $CHECK_SHELL_PROMPT {
                  set line [ string trimright $expect_out(buffer) "\n\r" ]
                  ts_log_finest "recognized shell prompt: \"$line\" - ts will continue now ..."
               }
               -i $spawn_id -- $CHECK_LOGIN_LINE {
                  set line [ string trimright $expect_out(buffer) "\n\r" ]
                  ts_log_finest "unrecognized login output: \"$line\""
                  lappend unrecognized_messages "$line"
                  exp_continue
               }
            }
         } catch_error_message]
         if {$catch_return == 1} {
            ts_log_warning "${error_info}\n$catch_error_message"  $raise_error
            set connect_errors 1
         }

         # did we have errors?
         if {$connect_errors} {
            catch {close_spawn_id $spawn_id}
            if {[llength unrecognized_messages] > 0} {
                ts_log_warning "unrecognized_messages: $unrecognized_messages"  $raise_error
            }
            return ""
         }

         # now we should have a running shell
         # try to start a shell script doing some output we'll wait for
         set catch_return [catch {
            set num_tries $nr_of_tries
            # try to start the shell_start_output.sh script
            ts_send $spawn_id "$testsuite_root_dir/scripts/shell_start_output.sh\n" $hostname
            set timeout 2
            expect {
               -i $spawn_id eof {
                  ts_log_warning "${error_info}\nunexpected eof" $raise_error
                  set connect_errors 1
               }
               -i $spawn_id full_buffer {
                  ts_log_warning "${error_info}\nbuffer overflow" $raise_error
                  set connect_errors 1
               }
               -i $spawn_id timeout {
                  incr num_tries -1
                  if {$num_tries > 0} {
                     # try to restart the shell_start_output.sh script
                     ts_send $spawn_id "$testsuite_root_dir/scripts/shell_start_output.sh\n" $hostname
                     increase_timeout
                     exp_continue
                  } else {
                     # final timeout
                     ts_log_warning "${error_info}\ntimeout" $raise_error
                     ts_send $spawn_id "\003" $hostname ;# send CTRL+C to stop poss. running processes
                     set connect_errors 1
                  }
                  
               }
               -i $spawn_id "assword:" {
                  if {$passwd == ""} {
                     ts_log_warning "${error_info}\ngot unexpected password question" $raise_error
                     set connect_errors 1
                  } else {
                     log_user 0  ;# in any case before sending password
                     ts_send $spawn_id "$passwd\n" $hostname 1
                     if {$CHECK_DEBUG_LEVEL != 0} {
                        log_user 1
                     }
                     exp_continue
                  }
               }
               -i $spawn_id "The authenticity of host*" {
                  ts_send $spawn_id "yes\n" $hostname
                  exp_continue
               }
               -i $spawn_id "Are you sure you want to continue connecting (yes/no)?*" {
                  ts_send $spawn_id "yes\n" $hostname
                  exp_continue
               }
               -i $spawn_id "Please type 'yes' or 'no'*" {
                  ts_send $spawn_id "yes\n" $hostname
                  exp_continue
               }
               -i $spawn_id "ts_shell_response*\n" {
                  # got output from shell_start_output.sh - leaving expect
                  ts_log_finest "shell started"
                  set connect_succeeded 1
               }
               -i $spawn_id "in.rlogind: Forkpty: Permission denied." {
                  # interix (windows) rlogind doesn't let us login
                  # sleep a while and retry
                  ts_log_progress FINE "x"
                  sleep 10
                  continue
               }
            }
         } catch_error_message ]
         if { $catch_return == 1 } {
            ts_log_warning "${error_info}\n$catch_error_message"  $raise_error
            set connect_errors 1
         }
             
         # did we have errors?
         if {$connect_errors} {
            catch {close_spawn_id $spawn_id}
            return ""
         }
      } ;# end while loop for interix connection problems

      # now we know that we have a connection and can start a shell script
      # try to check login id
      set catch_return [ catch {
         ts_send $spawn_id "$testsuite_root_dir/scripts/check_identity.sh\n" $hostname
         set num_tries $nr_of_tries
         set timeout 2
         expect {
            -i $spawn_id eof {
               ts_log_warning "${error_info}\nunexpected eof" $raise_error
               set connect_errors 1
            }
            -i $spawn_id full_buffer {
               ts_log_warning "${error_info}\nbuffer overflow" $raise_error
               set connect_errors 1
            }
            -i $spawn_id timeout {
               incr num_tries -1
               if {$num_tries > 0} {
                  ts_send $spawn_id "$testsuite_root_dir/scripts/check_identity.sh\n" $hostname
                  increase_timeout
                  exp_continue
               } else {
                  # final timeout
                  ts_log_warning "${error_info}\nshell doesn't start or runs not as user $CHECK_USER on host $hostname"  $raise_error
                  ts_send $spawn_id "\003" $hostname ;# send CTRL+C to stop poss. running processes
                  set connect_errors 1
               }
             }
             -i $spawn_id -- "TS_ID: ->*${connect_user}*\n" { 
                 ts_log_finest "logged in as ${connect_user} - fine" 
             }
          }
      } catch_error_message]
      if {$catch_return == 1} {
         ts_log_warning "${error_info}\n$catch_error_message"  $raise_error
         set connect_errors 1
      }

      # did we have errors?
      if {$connect_errors} {
         catch {close_spawn_id $spawn_id}
         return ""
      }

      # here we switch to the target user.
      # if we connected to a windows host, we must already be the target user, do nothing
      # if target user is CHECK_USER, do nothing.
      # if we have ssh access, and target_user is root, do nothing
      # else switch user
      set switch_user 1
      if {$real_user == $connect_user} {
         set switch_user 0
      }

      if {$switch_user} {
         ts_log_finest "we have to switch user"
         set catch_return [ catch {
            if {[have_ssh_access]} {
               ts_log_finest "have ssh root access - switching to $real_user"
               ts_send $spawn_id "su - $real_user\n" $hostname
            } else {
               # we had rlogin access and are CHECK_USER
               if {$real_user == "root"} {
                  ts_log_finest "switching to root user"
                  ts_send $spawn_id "su - root\n" $hostname
               } else {
                  ts_log_finest "switching to $real_user user"
                  ts_send $spawn_id "su - root -c 'su - $real_user'\n"  $hostname
               }
            }
            incr nr_of_shells 1

            # without ssh access, we'll get the passwd question here
            if {![have_ssh_access]} {
               set timeout 60
               expect {
                  -i $spawn_id full_buffer {
                     ts_log_warning "${error_info}\nbuffer overflow" $raise_error
                     set connect_errors 1
                  }
                  -i $spawn_id eof {
                     ts_log_warning "${error_info}\nunexpected eof" $raise_error
                     set connect_errors 1
                  }
                  -i $spawn_id timeout {
                     ts_log_warning "${error_info}\ntimeout waiting for passwd question" $raise_error
                     set connect_errors 1
                  }
                  -i $spawn_id "assword:" {
                     log_user 0  ;# in any case before sending password
                     ts_send $spawn_id "[get_root_passwd]\n" $hostname 1
                     ts_log_finest "root password sent" 
                     if {$CHECK_DEBUG_LEVEL != 0} {
                        log_user 1
                     }
                  }
               }
            }
         } catch_error_message]
         if {$catch_return == 1} {
            ts_log_warning "${error_info}\n$catch_error_message"  $raise_error
            set connect_errors 1
         }

         # did we have errors?
         if {$connect_errors} {
            catch {close_spawn_id $spawn_id}
            return ""
         }

         # now we should have the id of the target user
         # check login id
         set catch_return [catch {
            ts_send $spawn_id "$testsuite_root_dir/scripts/check_identity.sh\n" $hostname
            set num_tries $nr_of_tries
            set timeout 2
            expect {
               -i $spawn_id eof {
                  ts_log_warning "${error_info}\nunexpected eof" $raise_error
                  set connect_errors 1
               }
               -i $spawn_id full_buffer {
                  ts_log_warning "${error_info}\nbuffer overflow" $raise_error
                  set connect_errors 1
               }
               -i $spawn_id timeout {
                  incr num_tries -1
                  if {$num_tries > 0} {
                     ts_send $spawn_id "$testsuite_root_dir/scripts/check_identity.sh\n" $hostname
                     increase_timeout
                     exp_continue
                  } else {
                     # final timeout
                     ts_log_warning "${error_info}\nshell doesn't start or runs not as user $real_user on host $hostname"  $raise_error
                     ts_send $spawn_id "\003" $hostname ;# send CTRL+C to stop poss. still running processes
                     set connect_errors 1
                  }
               }
               -i $spawn_id -- "TS_ID: ->*${real_user}*\n" { 
                  ts_log_finest "correctly switched to user $real_user - fine" 
               }
               -i $spawn_id -- "TS_ID: ->*${connect_user}*\n" { 
                  ts_log_warning "${error_info}\nswitch to user $real_user didn't succeed, we are still ${connect_user}" $raise_error
                  set connect_errors 1
               }
               -i $spawn_id "ermission denied" {
                  ts_log_warning "${error_info}\npermission denied" $raise_error
                  set connect_errors 1
               }
               -i $spawn_id "does not exist" {
                  ts_log_warning "${error_info}\nuser $real_user doesn not exist on host $hostname" $raise_error
                  set connect_errors 1
               }
               -i $spawn_id "nknown*id" {
                  ts_log_warning "${error_info}\nuser $real_user doesn not exist on host $hostname" $raise_error
                  set connect_errors 1
               }
            }
         } catch_error_message]
         if {$catch_return == 1} {
            ts_log_warning "${error_info}\n$catch_error_message"  $raise_error
            set connect_errors 1
         }

         # did we have errors?
         if {$connect_errors} {
            catch {close_spawn_id $spawn_id}
            return ""
         }
      } ;# switch user

      # autocorrection and autologout might make problems
      set catch_return [catch {
         ts_send $spawn_id "unset autologout\n" $hostname
         ts_send $spawn_id "unset correct\n" $hostname
         # JG: TODO: what if the target user has a sh/ksh/bash?
      } catch_error_message]
      if {$catch_return == 1} {
         ts_log_warning "${error_info}\n$catch_error_message"  $raise_error
         catch {close_spawn_id $spawn_id}
         return ""
      }
      # store the connection
      if {$create_alternate_connection} {
         set alternate_connection_of $con_data(spawn_id)    
      } else {
         set alternate_connection_of ""    
      }

      add_open_spawn_rlogin_session $hostname     $user           $win_local_user $spawn_id    \
                                    $pid          $nr_of_shells   $real_user      $script_name \
                                    $exec_command $exec_arguments $alternate_connection_of
   } ;# opening new connection

   ts_log_finest "working on session \"$spawn_id\""
   # If we call the command for the first time, make sure it is available on the remote machine
   # we wait for some time, as the it might take some time until the command is visible (NFS)
   if {$re_use_script == 0} {
      set catch_return [catch {
         ts_send $spawn_id "$testsuite_root_dir/scripts/file_check.sh $script_name\n" $hostname
         set connect_errors 0
         set num_tries $nr_of_tries
         set timeout 2
         expect {
            -i $spawn_id full_buffer {
               ts_log_warning "${error_info}\nbuffer overflow" $raise_error
               set connect_errors 1
            }
            -i $spawn_id eof {
               ts_log_warning "${error_info}\nunexpected eof" $raise_error
               set connect_errors 1
            }
            -i $spawn_id timeout {
               incr num_tries -1
               if {$num_tries > 0} {
                  ts_send $spawn_id "$testsuite_root_dir/scripts/file_check.sh $script_name\n" $hostname
                  increase_timeout
                  exp_continue
               } else {
                  ts_log_warning "${error_info}\ntimeout waiting for file_check.sh script" $raise_error
                  set connect_errors 1
               }
            }
            -i $spawn_id -- "TS_OK" {
            }
         }
      } catch_error_message]
      if {$catch_return == 1} {
         ts_log_warning "${error_info}\n$catch_error_message"  $raise_error
         set connect_errors 1
      }

      # If the connection was OK before, but the file check failed, 
      # we might have NFS problems.
      # Nothing we can do about it. We'll close the connection and
      # return error.
      if {$connect_errors} {
         close_spawn_process "$pid $spawn_id $nr_of_shells" 1 0
         return ""
      }
   } else {
      ts_log_finest "skip checking remote script, using already used script ..."
   }

   # prepare for background start
   if {$background} {
      append script_name " &"
   }

   # now start the commmand and set the connection to busy
   ts_log_finest "$user starting command on $hostname: $exec_command $exec_arguments"
   set_spawn_process_command_script $spawn_id $script_name $exec_command $exec_arguments
   set catch_return [catch {
      ts_send $spawn_id "$script_name\n" $hostname
      set_spawn_process_in_use $spawn_id
   } catch_error_message]
   if {$catch_return == 1} {
      # The connection was OK before, but send failed?
      # Should be a rare situation.
      # We'll close the connection and return error
      ts_log_warning "${error_info}\n$catch_error_message"  $raise_error
      close_spawn_process "$pid $spawn_id $nr_of_shells" 1 0
      return ""
   }

   # for background processes, wait some time
   if {$background == 2} {
      set back_time 15 ;# let background process time to do his initialization
      while {$back_time > 0} {
         ts_log_progress
         sleep 1
         incr back_time -1
      }
      ts_log_fine "hope background process is initalized now!"
   }

   ts_log_finest "number of open shells: $nr_of_shells"

   set back "$pid $spawn_id $nr_of_shells"
   return $back
}

#                                                             max. column:     |
#****** remote_procedures/open_spawn_process() ******
# 
#  NAME
#     open_spawn_process -- start process with the expect "spawn" command
#
#  SYNOPSIS
#     open_spawn_process { args } 
#
#  FUNCTION
#     Starts process given in "args" and returns its spawn id and pid in a list. 
#     The first list element is the pid and the second is the spawn id. The return 
#     value is used in close_spawn_process to close the connection to this 
#     process.
#
#  INPUTS
#     args - full argument list of the process to start
#
#  RESULT
#     tcl list with id and pid of the process
#
#     - first element is the pid
#     - second element is the spawn id
#
#  EXAMPLE
#     set arch [resolve_arch [gethostname]]
#     set id [ 
#       open_spawn_process "$ts_config(product_root)/bin/$arch/qconf" "-dq" "$q_name"
#     ]
#     expect {
#       ...
#     }
#     puts "pid: [ lindex $id 0]"
#     puts "spawn id: [ lindex $id 1]"
#     close_spawn_process $id
#
#
#  NOTES
#     always close an opened spawn id with the procedure close_spawn_process
#
#  SEE ALSO
#     remote_procedures/open_spawn_process
#     remote_procedures/open_root_spawn_process
#     remote_procedures/close_spawn_process
#     remote_procedures/start_remote_tcl_prog
#     remote_procedures/start_remote_prog
#*******************************
proc open_spawn_process {args} {
   global CHECK_EXPECT_MATCH_MAX_BUFFER

   set arguments ""
   set my_arg_no 0

   foreach elem $args {
      incr my_arg_no 1
      if {$my_arg_no == 1} {
        set arguments "$elem"
      } else {
        set arguments "$arguments $elem"
      }
   }
   ts_log_finest $arguments
   set open_spawn_arguments $arguments

   ts_log_finest "starting spawn process ..."

   set pid   [ eval spawn $open_spawn_arguments ]
   set sp_id [ set spawn_id ]
   set back $pid
   lappend back $sp_id
   ts_log_finest "open_spawn_process:  arguments: $args"
      match_max -i $spawn_id $CHECK_EXPECT_MATCH_MAX_BUFFER
      ts_log_finest "open_spawn_process -> buffer size is: [match_max]"

   if {$pid == 0 } {
     ts_log_severe "could not spawn! (ret_pid = $pid)" 
   }
   return $back
}

#****** remote_procedures/get_busy_spawn_rlogin_sessions() *********************
#  NAME
#     get_busy_spawn_rlogin_sessions() -- get number of busy rlogin sessions
#
#  SYNOPSIS
#     get_busy_spawn_rlogin_sessions { } 
#
#  FUNCTION
#     Returns the number of busy rlogin / ssh sessions.
#     Busy means, that a command is running in the session.
#     After a close_spawn_process, a session may stay open, but it will
#     be marked "idle".
#
#  RESULT
#     Number of busy sessions (a number 0 ... n)
#*******************************************************************************
proc get_busy_spawn_rlogin_sessions {} {
   set busy 0

   set sessions [get_open_rlogin_sessions]
   foreach session $sessions {
      if {[is_spawn_process_in_use $session]} {
         incr busy
      }
   }

   return $busy
}

#****** remote_procedures/dump_spawn_rlogin_sessions() *************************
#  NAME
#     dump_spawn_rlogin_sessions() -- dump connection information
#
#  SYNOPSIS
#     dump_spawn_rlogin_sessions { {do_output 1} } 
#
#  FUNCTION
#     Dumps information about open connections to a string buffer.
#     If do_output is 1, the string buffer will be written to 
#     stdout.
#
#  INPUTS
#     {do_output 1} - do output to stdout
#
#  RESULT
#     string containing info output
#
#  EXAMPLE
#     set output [dump_spawn_rlogin_sessions 0]
#     ts_log_fine $output
#                         | myname   |     root | sgetest1 | sgetest2 | 
#     --------------------|----------|----------|----------|----------|
#     host1               |     idle |      --  |      --  |      --  | 
#     host2               |      --  |      --  |      --  |      --  | 
#     host3               |      --  |      --  |      --  |      --  | 
#     host4               |     idle |      --  |      --  |      --  | 
#     host5               |      --  |      --  |      --  |      --  | 
#     host6               |     idle |      --  |      --  |      --  | 
#     host3.domain.com    |     idle |      --  |      --  |      --  | 
#
#*******************************************************************************
# interactive only use - use puts to do output
proc dump_spawn_rlogin_sessions {{do_output 1}} {
   set host_list [host_conf_get_cluster_hosts]
   set user_list [user_conf_get_cluster_users]
   set sessions  [get_open_rlogin_sessions]

   # examine all open sessions
   foreach session $sessions {
      # get detailed session information
      get_spawn_id_rlogin_session $session connection
      set user $connection(user)
      set host $connection(hostname)

      # extend host and user list if necessary
      if {[lsearch $host_list $host] < 0} {
         lappend host_list $host
      }
      if {[lsearch $user_list $user] < 0} {
         lappend user_list $user
      }

      # output idle or busy
      if {[is_spawn_process_in_use $connection(spawn_id)]} {
         set result_array($user,$host) "busy"
      } else {
         set result_array($user,$host) "idle"
      }
   }

   set ret [print_xy_array $user_list $host_list result_array " -- "]
   
   if {$do_output} {
      puts ""
      puts $ret
      puts ""
   }

   return $ret
}

#****** remote_procedures/add_open_spawn_rlogin_session() **********************
#  NAME
#     add_open_spawn_rlogin_session() -- add spawn id to open connection list
#
#  SYNOPSIS
#     add_open_spawn_rlogin_session { hostname user spawn_id pid } 
#
#  FUNCTION
#     This procedure will add the given spawn id to the internal bookkeeping
#     of connections.
#  
#     If the number of open connections exceeds a maximum (determined from
#     file descriptor limit), the connection that has been idle for the 
#     longest time will be closed.
#
#     The following data structures are used for keeping track of sessions:
#        rlogin_spawn_session_buffer: TCL Array containing all parameters of
#           all sessions. It has one index element containing the names of all
#           open sessions (spawn ids).
#           Per spawn_id, the following data is stored:
#              - pid        pid of the expect child process from spawn command
#              - hostname   name of host to which we connected
#              - user       user for which the connection has been established.
#              - win_local_user For windows, we usually will connect as domain user.
#                               For some operations, e.g. accessing the local
#                               spool directory of an exec host, we have to use
#                               local users.
#              - ltime      timestamp of last use of the connection
#              - nr_shells  number of shells started in the connection
#              - in_use     is the connection in use or idle
#           The following names are used in the TCL array:
#              - index            {exp4 exp6}
#              - exp4,pid         12345
#              - exp4,hostname    myhostname
#              - ...
#              - exp6,pid         23455
#              - ...
#
#        rlogin_spawn_session_idx: TCL Array acting as an index for quick lookup
#           of connections by hostname and user.
#           It contains one entry per session. The array names are
#           <hostname>,<user>,<win_local_user>, e.g.
#           gimli,sgetest,0        exp4
#           balrog,sgetest,0       exp6
#           balrog,sgetest1,0      exp8
#           bofur,sgetest,1        exp10
#
#  INPUTS
#     hostname       - hostname of rlogin connection
#     user           - user who logged in
#     win_local_user - is the user a windows local (1) or domain user (0)
#     spawn_id       - spawn process id
#     pid            - process id of rlogin session
#
#  SEE ALSO
#     remote_procedures/get_open_spawn_rlogin_session
#     remote_procedures/get_spawn_id_rlogin_session
#     remote_procedures/del_open_spawn_rlogin_session
#     remote_procedures/remove_oldest_spawn_rlogin_session()
#*******************************************************************************
proc add_open_spawn_rlogin_session {hostname user win_local_user spawn_id \
                                    pid nr_of_shells real_user command_script \
                                    command_name command_args alternate_con_of} {
   global rlogin_spawn_session_buffer rlogin_spawn_session_idx
   global do_close_rlogin rlogin_max_open_connections 

   if {$do_close_rlogin != 0} {
      ts_log_finest "close_rlogin argument set, closing rlogin connections after use"
      return  
   }

   # if the number of connections exceed a certain maximum,
   # we have to close one connection - the one idle for the longest time
   set num_connections 0
   if {[info exists rlogin_spawn_session_buffer(index)]} {
      set num_connections [llength $rlogin_spawn_session_buffer(index)]
   }
   if {$num_connections >= $rlogin_max_open_connections} {
      ts_log_finest "number of open connections($num_connections) > rlogin_max_open_connections($rlogin_max_open_connections)"
      remove_oldest_spawn_rlogin_session
   }

   ts_log_finest "adding spawn_id $spawn_id, pid=$pid to host $hostname, user $user"

   # add session data
   set rlogin_spawn_session_buffer($spawn_id,pid)                 $pid
   set rlogin_spawn_session_buffer($spawn_id,hostname)            $hostname
   set rlogin_spawn_session_buffer($spawn_id,user)                $user
   set rlogin_spawn_session_buffer($spawn_id,real_user)           $real_user
   set rlogin_spawn_session_buffer($spawn_id,win_local_user)      $win_local_user
   set rlogin_spawn_session_buffer($spawn_id,ltime)               [timestamp]
   set rlogin_spawn_session_buffer($spawn_id,nr_shells)           $nr_of_shells
   set rlogin_spawn_session_buffer($spawn_id,in_use)              0
   set rlogin_spawn_session_buffer($spawn_id,command_script)      $command_script
   set rlogin_spawn_session_buffer($spawn_id,command_name)        $command_name
   set rlogin_spawn_session_buffer($spawn_id,command_args)        $command_args
   set rlogin_spawn_session_buffer($spawn_id,alternate_sessions)  ""
   set rlogin_spawn_session_buffer($spawn_id,is_alternate_of)     ""
  

   # add session to index
   lappend rlogin_spawn_session_buffer(index) $spawn_id

   if { $alternate_con_of != "" } {
      ts_log_finest "adding alternate session for spawn id \"$alternate_con_of\""
      lappend rlogin_spawn_session_buffer($alternate_con_of,alternate_sessions) $spawn_id
      set rlogin_spawn_session_buffer($spawn_id,is_alternate_of) $alternate_con_of
   } else {
      # add session to search index
      set rlogin_spawn_session_idx($hostname,$user,$win_local_user) $spawn_id
   }
}

#****** remote_procedures/remove_oldest_spawn_rlogin_session() *****************
#  NAME
#     remove_oldest_spawn_rlogin_session() -- remove oldest idle rlogin session
#
#  SYNOPSIS
#     remove_oldest_spawn_rlogin_session { } 
#
#  FUNCTION
#     Scans through all open rlogin session, and will close the session
#     that has been idle for the longest time.
#
#     If no session is idle, raise an error.
#
#     See remote_procedures/add_open_spawn_rlogin_session() for a description
#     of the data structures.
#
#  SEE ALSO
#     remote_procedures/add_open_spawn_rlogin_session()
#*******************************************************************************
proc remove_oldest_spawn_rlogin_session {} {
   global rlogin_spawn_session_buffer

   ts_log_finest "removing oldest not used rlogin session (rlogin_max_open_connections overflow)"
   set last [timestamp]
   set remove_spawn_id ""
   foreach spawn_id $rlogin_spawn_session_buffer(index) {
      set time $rlogin_spawn_session_buffer($spawn_id,ltime)
      ts_log_finest "$time $spawn_id $rlogin_spawn_session_buffer($spawn_id,in_use)"
      # only consider idle connections for closing
      if {$rlogin_spawn_session_buffer($spawn_id,in_use) == 0 && $last > $time} {
         set last $time
         set remove_spawn_id $spawn_id
      } 
   }

   # if we found no idle connection - error.
   if {$remove_spawn_id == ""} {
      ts_log_warning "all [llength $rlogin_spawn_session_buffer(index)] sessions are in use - no oldest one to close.\nPlease check your file descriptor limit vs. cluster size.\nThis problem may also be caused by missing close_spawn_process calls."
   } else {
      ts_log_finest "longest not used element: $remove_spawn_id"

      # close the connection. We are not intested in the exit code of the 
      # previously executed command, so don't make close_spawn_process check
      # the exit code
      set pid $rlogin_spawn_session_buffer($remove_spawn_id,pid)
      set nr_shells $rlogin_spawn_session_buffer($remove_spawn_id,nr_shells)
      close_spawn_process "$pid $remove_spawn_id $nr_shells" 1 0
   }
}

#****** remote_procedures/get_open_spawn_rlogin_session() **********************
#  NAME
#     get_open_spawn_rlogin_session() -- get rlogin connection data
#
#  SYNOPSIS
#     get_open_spawn_rlogin_session {hostname user back_var} 
#
#  FUNCTION
#     This procedure returns the corresponding spawn_id for hostname and user
#     name.
#
#     See remote_procedures/add_open_spawn_rlogin_session() for a description
#     of the data structures.
#
#  INPUTS
#     hostname       - hostname of rlogin connection 
#     user           - user who logged in 
#     win_local_user - is the user a windows local (1) or domain user (0)
#     back_var       - name of array to store data in
#                      (the array has following names:
#                         back_var(spawn_id) 
#                         back_var(pid)     
#                         back_var(hostname) 
#                         back_var(user))
#
#  RESULT
#     1 on success, 0 if no connection is available
#
#  EXAMPLE
#     get_open_spawn_rlogin_session $hostname $user $win_local_user con_data
#     if { $con_data(pid) != 0 } {
#     }
#
#  NOTES
#     The back_var array is set to "0" if no connection is available 
#
#  SEE ALSO
#     remote_procedures/add_open_spawn_rlogin_session
#     remote_procedures/get_open_spawn_rlogin_session
#     remote_procedures/get_spawn_id_rlogin_session
#     remote_procedures/check_rlogin_session
#*******************************************************************************
proc get_open_spawn_rlogin_session {hostname user win_local_user back_var} {
   global rlogin_spawn_session_buffer rlogin_spawn_session_idx
   global do_close_rlogin

   upvar $back_var back 

   ts_log_finest "get open session for $hostname/$user/$win_local_user ..."
   # we shall not reuse connections, or
   # connection to this host/user does not exist yet
   if {$do_close_rlogin != 0 || ![info exists rlogin_spawn_session_idx($hostname,$user,$win_local_user)]} {
      clear_open_spawn_rlogin_session back
      return 0
   }

   set spawn_id $rlogin_spawn_session_idx($hostname,$user,$win_local_user)
   fill_session_info_array $spawn_id back
   return 1
}

#****** remote_procedures/del_open_spawn_rlogin_session() **********************
#  NAME
#     del_open_spawn_rlogin_session() -- remove rlogin session
#
#  SYNOPSIS
#     del_open_spawn_rlogin_session { spawn_id } 
#
#  FUNCTION
#     Removes a certain session from the internal bookkeeping.
#
#     See remote_procedures/add_open_spawn_rlogin_session() for a description
#     of the data structures.
#
#  INPUTS
#     spawn_id - spawn id to remove
#
#  SEE ALSO
#     remote_procedures/add_open_spawn_rlogin_session()
#*******************************************************************************
proc del_open_spawn_rlogin_session {spawn_id} {
   global rlogin_spawn_session_buffer rlogin_spawn_session_idx

   if {[info exists rlogin_spawn_session_buffer($spawn_id,pid)]} {
      set remove_from_index 1
      # if session is an alternate session for a different session, remove the session reference
      set super_session $rlogin_spawn_session_buffer($spawn_id,is_alternate_of)
      if {$super_session != ""} {
         ts_log_finer "super session of \"$spawn_id\" is \"$super_session\""
         if {[info exists rlogin_spawn_session_buffer($super_session,pid)]} {
            set remove_from_index 0  ;# never remove alternate session from search index
            ts_log_finer "removing reference from super session \"$super_session\" to session \"$spawn_id\""
            ts_log_finer "super session $super_session: \"$rlogin_spawn_session_buffer($super_session,alternate_sessions)\""
            set pos [lsearch -exact $rlogin_spawn_session_buffer($super_session,alternate_sessions) $spawn_id]
            set rlogin_spawn_session_buffer($super_session,alternate_sessions) \
                [lreplace $rlogin_spawn_session_buffer($super_session,alternate_sessions) $pos $pos]
            ts_log_finest "super session $super_session: \"$rlogin_spawn_session_buffer($super_session,alternate_sessions)\""
         } else {
            ts_log_fine "no information in session buffer for super session \"$super_session\""
         }
      } else {
         ts_log_finer "no super session found"
      }

      # if session is super session make alternate session to new supersession
      if {[llength $rlogin_spawn_session_buffer($spawn_id,alternate_sessions)] > 0} {
         ts_log_finer "removing super session - declaring first alternate session to new super session"
         
         set new_super_session [lindex $rlogin_spawn_session_buffer($spawn_id,alternate_sessions) 0]
         ts_log_finer "new supersession is: \"$new_super_session\""
         if {[info exists rlogin_spawn_session_buffer($new_super_session,pid)]} {
            # get all alternative session from super session and add it to first alternate session
            set alternate_sessions $rlogin_spawn_session_buffer($spawn_id,alternate_sessions)
            set pos [lsearch -exact $alternate_sessions $new_super_session]
            set alternate_sessions [lreplace $alternate_sessions $pos $pos]
            set rlogin_spawn_session_buffer($new_super_session,is_alternate_of) ""
            set rlogin_spawn_session_buffer($new_super_session,alternate_sessions) $alternate_sessions
            ts_log_finer "session \"$new_super_session\" will be new super session with alternate list: \"$alternate_sessions\""
            
            # update session index info
            set remove_from_index 0
            set hostname       $rlogin_spawn_session_buffer($spawn_id,hostname)
            set user           $rlogin_spawn_session_buffer($spawn_id,user)
            set win_local_user $rlogin_spawn_session_buffer($spawn_id,win_local_user)
            set rlogin_spawn_session_idx($hostname,$user,$win_local_user) $new_super_session
         } else {
            ts_log_severe "error occured for removing super session"
         }
      } 

      if {$remove_from_index != 0} {
         # remove session from search index
         set hostname       $rlogin_spawn_session_buffer($spawn_id,hostname)
         set user           $rlogin_spawn_session_buffer($spawn_id,user)
         set win_local_user $rlogin_spawn_session_buffer($spawn_id,win_local_user)
         if {[info exists rlogin_spawn_session_idx($hostname,$user,$win_local_user)]} {
            unset rlogin_spawn_session_idx($hostname,$user,$win_local_user)
         } else {
            ts_log_severe "spawn session index rlogin_spawn_session_idx($hostname,$user,$win_local_user) not found"
         }
      }

      # remove session from array index
      set pos [lsearch -exact $rlogin_spawn_session_buffer(index) $spawn_id]
      set rlogin_spawn_session_buffer(index) [lreplace $rlogin_spawn_session_buffer(index) $pos $pos]

      # remove session data
      unset rlogin_spawn_session_buffer($spawn_id,pid)
      unset rlogin_spawn_session_buffer($spawn_id,hostname)
      unset rlogin_spawn_session_buffer($spawn_id,user)
      unset rlogin_spawn_session_buffer($spawn_id,real_user)
      unset rlogin_spawn_session_buffer($spawn_id,win_local_user)
      unset rlogin_spawn_session_buffer($spawn_id,ltime)
      unset rlogin_spawn_session_buffer($spawn_id,nr_shells)
      unset rlogin_spawn_session_buffer($spawn_id,in_use)
      unset rlogin_spawn_session_buffer($spawn_id,command_script)
      unset rlogin_spawn_session_buffer($spawn_id,command_name)
      unset rlogin_spawn_session_buffer($spawn_id,command_args)
      unset rlogin_spawn_session_buffer($spawn_id,alternate_sessions)
      unset rlogin_spawn_session_buffer($spawn_id,is_alternate_of)
   } else {
      ts_log_fine "session buffer not found"
   }
}

#****** remote_procedures/is_spawn_id_rlogin_session() *************************
#  NAME
#     is_spawn_id_rlogin_session() -- does a certain session exist?
#
#  SYNOPSIS
#     is_spawn_id_rlogin_session { spawn_id } 
#
#  FUNCTION
#     Returns if the given expect spawn id exists in the connection bookkeeping.
#
#  INPUTS
#     spawn_id - spawn id to check
#
#  RESULT
#     1, if the connection exists, else 0
#
#  SEE ALSO
#     remote_procedures/add_open_spawn_rlogin_session()
#*******************************************************************************
proc is_spawn_id_rlogin_session {spawn_id} {
   global rlogin_spawn_session_buffer

   if {[info exists rlogin_spawn_session_buffer($spawn_id,pid)]} {
      return 1
   }

   return 0
}

#****** remote_procedures/get_open_rlogin_sessions() ***************************
#  NAME
#     get_open_rlogin_sessions() -- return list of all spawn ids
#
#  SYNOPSIS
#     get_open_rlogin_sessions { } 
#
#  FUNCTION
#     Returns a list of all spawn ids in the internal bookkeeping.
#
#  RESULT
#     list of spawn ids
#
#  SEE ALSO
#     remote_procedures/add_open_spawn_rlogin_session()
#*******************************************************************************
proc get_open_rlogin_sessions {} {
   global rlogin_spawn_session_buffer

   set ret {}

   if {[info exists rlogin_spawn_session_buffer(index)]} {
      set ret [lsort -dictionary $rlogin_spawn_session_buffer(index)]
   }

   return $ret
}

#
# internal utility function used by get_spawn_*
# clears the return buffer in case of errors / connection not found
#
proc clear_open_spawn_rlogin_session {back_var} {
   upvar $back_var back

   set back(spawn_id)       "0"
   set back(pid)            "0"
   set back(hostname)       "0"
   set back(user)           "0"
   set back(real_user)      ""
   set back(win_local_user) "0"
   set back(ltime)           0
   set back(in_use)          0
   set back(nr_shells)       0
   set back(command_script)     ""
   set back(command_name)       ""
   set back(command_args)       ""
   set back(alternate_sessions) ""
   set back(is_alternate_of)    ""

}

#****** remote_procedures/get_spawn_id_rlogin_session() ************************
#  NAME
#     get_spawn_id_rlogin_session() -- get rlogin connection data
#
#  SYNOPSIS
#     get_spawn_id_rlogin_session { id back_var } 
#
#  FUNCTION
#     This procedure returns the corresponding data for a rlogin spawn id
#
#     See remote_procedures/add_open_spawn_rlogin_session() for a description
#     of the data structures.
#
#  INPUTS
#     id       - spawn id of connection
#     back_var - name of array to store data in
#                (the array has following names:
#                 back_var(spawn_id) 
#                 back_var(pid)     
#                 back_var(hostname) 
#                 back_var(user))
#
#
#  RESULT
#     1 on success, 0 if no connection is available
#
#  EXAMPLE
#     get_spawn_id_rlogin_session $sp_id con_data
#       if { $con_data(pid) != 0 } { ...}
#
#  NOTES
#     The back_var array is set to "0" if no connection is available 
#
#  SEE ALSO
#     remote_procedures/add_open_spawn_rlogin_session
#     remote_procedures/get_open_spawn_rlogin_session
#     remote_procedures/get_spawn_id_rlogin_session
#     remote_procedures/check_rlogin_session
#*******************************************************************************
proc get_spawn_id_rlogin_session {spawn_id back_var} {
   global rlogin_spawn_session_buffer
   global do_close_rlogin

   upvar $back_var back 

   if {$do_close_rlogin || ![info exists rlogin_spawn_session_buffer($spawn_id,pid)]} {
      clear_open_spawn_rlogin_session back
      return 0 
   }

   fill_session_info_array $spawn_id back
   return 1 
}

#****** remote_procedures/fill_session_info_array() ****************************
#  NAME
#     fill_session_info_array() -- set relevant session info into array
#
#  SYNOPSIS
#     fill_session_info_array { spawn_id array_name } 
#
#  FUNCTION
#     This procedure is used to set the specified session information into 
#     the specified array variable
#
#  INPUTS
#     spawn_id   - spawn id of session
#     array_name - name of variable array to store information
#
#*******************************************************************************
proc fill_session_info_array { spawn_id array_name } {
   global rlogin_spawn_session_buffer
   upvar $array_name back
   if {[info exists back]} {
      unset back
   }
   set back(spawn_id)           $spawn_id
   set back(pid)                $rlogin_spawn_session_buffer($spawn_id,pid)
   set back(hostname)           $rlogin_spawn_session_buffer($spawn_id,hostname)
   set back(user)               $rlogin_spawn_session_buffer($spawn_id,user)
   set back(real_user)          $rlogin_spawn_session_buffer($spawn_id,real_user)
   set back(win_local_user)     $rlogin_spawn_session_buffer($spawn_id,win_local_user)
   set back(ltime)              $rlogin_spawn_session_buffer($spawn_id,ltime)
   set back(in_use)             $rlogin_spawn_session_buffer($spawn_id,in_use)
   set back(nr_shells)          $rlogin_spawn_session_buffer($spawn_id,nr_shells)
   set back(command_script)     $rlogin_spawn_session_buffer($spawn_id,command_script)
   set back(command_name)       $rlogin_spawn_session_buffer($spawn_id,command_name)
   set back(command_args)       $rlogin_spawn_session_buffer($spawn_id,command_args)
   set back(alternate_sessions) $rlogin_spawn_session_buffer($spawn_id,alternate_sessions)
   set back(is_alternate_of)    $rlogin_spawn_session_buffer($spawn_id,is_alternate_of)

   ts_log_finest "spawn_id  :         $back(spawn_id)"
   ts_log_finest "pid       :         $back(pid)"
   ts_log_finest "hostname  :         $back(hostname)"
   ts_log_finest "user      :         $back(user)"
   ts_log_finest "real_user :         $back(real_user)"
   ts_log_finest "win_local_user :    $back(win_local_user)"
   ts_log_finest "ltime     :         $back(ltime)"
   ts_log_finest "nr_shells :         $back(nr_shells)"
   ts_log_finest "command_script:     $back(command_script)"
   ts_log_finest "command_name:       $back(command_name)"
   ts_log_finest "command_args:       $back(command_args)"
   ts_log_finest "alternate_sessions: $back(alternate_sessions)"
   ts_log_finest "is_alternate_of:    $back(is_alternate_of)"
}

#****** remote_procedures/get_spawn_id_hostname() ******************************
#  NAME
#     get_spawn_id_hostname() -- get host associated with spawn_id
#
#  SYNOPSIS
#     get_spawn_id_hostname { spawn_id } 
#
#  FUNCTION
#     Get the name of the host to which a spawned process (rlogin) had been
#     opened.
#     If this information is not (yet) known (e.g. while opening the connection),
#     an empty string ("") is returned.
#
#  INPUTS
#     spawn_id - spawn id of the connection
#
#  RESULT
#     hostname, or ""
#
#  SEE ALSO
#     remote_procedures/ts_send()
#*******************************************************************************
proc get_spawn_id_hostname {spawn_id} {
   global rlogin_spawn_session_buffer

   if {[info exists rlogin_spawn_session_buffer($spawn_id,hostname)]} {
      return $rlogin_spawn_session_buffer($spawn_id,hostname)
   } else {
      return ""
   }
}

#****** remote_procedures/close_open_rlogin_sessions() *************************
#  NAME
#     close_open_rlogin_sessions() -- close all open rlogin sessions
#
#  SYNOPSIS
#     close_open_rlogin_sessions { } 
#
#  FUNCTION
#     This procedure closes all open rlogin expect sessions.
#
#*******************************************************************************
proc close_open_rlogin_sessions {{if_not_working 0} {older_than 0}} {
   global do_close_rlogin

   # if we called testsuite with option close_rlogin, we have no open sessions
   if {$do_close_rlogin} {
      ts_log_finest "close_open_rlogin_sessions - open rlogin session mode not activated!"
      return 0 
   }

   # gather all session names
   set sessions [get_open_rlogin_sessions]
   foreach spawn_id $sessions {
      if {![get_spawn_id_rlogin_session $spawn_id back]} {
         # spawn_id has been closed in the meantime
         continue
      }
      if {$if_not_working} {
         if {[check_rlogin_session $spawn_id $back(pid) $back(hostname) $back(user) $back(nr_shells) 1]} {
            ts_log_finest "will not close spawn id $spawn_id - session is ok!"
            continue
         }
      }

      # delete outdated connections only if they have not been recently in use
      if {$older_than > 0} {
         # ignore connections that are in use
         if {$back(in_use)} {
            continue
         }

         set now [timestamp]
         if {$back(ltime) > [expr $now - $older_than]} {
            continue
         } else {
            ts_log_finer "session $spawn_id hasn't been used since [clock format $back(ltime)]"
         }
      }

      # now close the connection
      ts_log_finer "close_open_rlogin_sessions - closing $spawn_id ($back(user)@$back(hostname)) ... "
      close_spawn_process "$back(pid) $spawn_id $back(nr_shells)" 1 0 ;# don't check exit state
   }
}

global last_close_outdated_rlogin_sessions
set last_close_outdated_rlogin_sessions 0
proc close_outdated_rlogin_sessions { } {
   global last_close_outdated_rlogin_sessions

   # only do this check once a minute
   if {$last_close_outdated_rlogin_sessions > [expr [timestamp] - 60]} {
      return
   }

   ts_log_finest "checking connections ..."

   # set the last check timestamp here,
   # to reduce the probability of recursive calls
   set last_close_outdated_rlogin_sessions [timestamp]

   # close connections idle for more than 10 minutes
   close_open_rlogin_sessions 0 600

   # set the last check timestamp - no check for one minute
   set last_close_outdated_rlogin_sessions [timestamp]
}

#****** remote_procedures/check_rlogin_session() *******************************
#  NAME
#     check_rlogin_session() -- check if rlogin session is alive
#
#  SYNOPSIS
#     check_rlogin_session { spawn_id pid hostname user } 
#
#  FUNCTION
#     This procedure checks if the given rlogin spawn session is alive. If not
#     it will close the session.
#
#  INPUTS
#     spawn_id - spawn process id
#     pid      - process id of rlogin session
#     hostname - hostname of rlogin connection 
#     user     - user who logged in 
#     { only_check 0 } - if not 0: don't close spawn session on error
#
#  RESULT
#     1 on success, 0 if no connection is available
#
#  SEE ALSO
#     remote_procedures/add_open_spawn_rlogin_session
#     remote_procedures/get_open_spawn_rlogin_session
#     remote_procedures/get_spawn_id_rlogin_session
#     remote_procedures/check_rlogin_session
#*******************************************************************************
proc check_rlogin_session { spawn_id pid hostname user nr_of_shells {only_check 0} {raise_error 1}} {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   ts_log_finest "check_rlogin_session: $spawn_id $pid $hostname $user $nr_of_shells $only_check"
   if {![is_spawn_id_rlogin_session $spawn_id]} {
      # connection is not open
      ts_log_finest "check_rlogin_session: connection is not open"
      return 0
   }

   # handle special user ids
   get_spawn_id_rlogin_session $spawn_id con_data
   map_special_users $hostname $user $con_data(win_local_user)

   # perform the following test:
   # - start the check_identity.sh script
   # - wait for correct output
   # - expect that sends may fail, pass raise_error = 0 to ts_send
   set connection_ok 0
   set catch_return [catch {
      ts_send $spawn_id "$ts_config(testsuite_root_dir)/scripts/check_identity.sh\n" $con_data(hostname) 0 0
      set num_tries 30
      set timeout 1
      expect {
         -i $spawn_id full_buffer {
            ts_log_info "buffer overflow" $raise_error
         }
         -i $spawn_id eof {
            ts_log_info "unexpected eof" $raise_error
         }
         -i $spawn_id timeout {
            incr num_tries -1
            if {$num_tries > 0} {
               if {$num_tries < 12} {
                  ts_log_progress
               }
               ts_send $spawn_id "$ts_config(testsuite_root_dir)/scripts/check_identity.sh\n" $con_data(hostname) 0 0
               increase_timeout
               exp_continue
            } else {
               ts_log_info "timeout waiting for shell response" $raise_error
            }
         }
         -i $spawn_id -- "TS_ID: ->*${real_user}*\n" {
            set connection_ok 1
         }
      }
   } catch_error_message]
   if { $catch_return == 1 } {
      ts_log_info "$catch_error_message" $raise_error
   }

   # are we done?
   if {$connection_ok} {
      ts_log_finest "connection is ok"
      return 1
   }

   # if we got here, there was an error
   # in case we shall not only check, but also react on errors,
   # we'll close the connection now
   if {$only_check == 0} {
      ts_log_fine "check_rlogin_session: closing $spawn_id $pid to enable new rlogin session ..."

      # unregister connection
      close_spawn_process "$pid $spawn_id $nr_of_shells" 1 0 ;# don't check exit state
   }

   return 0 ;# error
}

#****** remote_procedures/set_spawn_process_in_use() ***************************
#  NAME
#     set_spawn_process_in_use() -- set info if a session is in use
#
#  SYNOPSIS
#     set_spawn_process_in_use { spawn_id {in_use 1} } 
#
#  FUNCTION
#     Stores the information, if a certain session is in use or not, in the 
#     internal bookkeeping.
#
#  INPUTS
#     spawn_id   - ??? 
#     {in_use 1} - ??? 
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
#     ???/???
#*******************************************************************************
proc set_spawn_process_in_use {spawn_id {in_use 1}} {
   global rlogin_spawn_session_buffer

   set rlogin_spawn_session_buffer($spawn_id,in_use) $in_use
   set rlogin_spawn_session_buffer($spawn_id,ltime) [timestamp]
}

#****** remote_procedures/set_spawn_process_command_script() *******************
#  NAME
#     set_spawn_process_command_script() -- set session information data
#
#  SYNOPSIS
#     set_spawn_process_command_script { spawn_id script cname cargs } 
#
#  FUNCTION
#     This procedure is used to update the session buffer and set the started
#     command script, command name and arguments
#
#  INPUTS
#     spawn_id - spawn id of the session
#     script   - script which was started
#     cname    - command name (full path)
#     cargs    - command arguments
#*******************************************************************************
proc set_spawn_process_command_script { spawn_id script cname cargs } {
   global rlogin_spawn_session_buffer
   set rlogin_spawn_session_buffer($spawn_id,command_script) $script
   set rlogin_spawn_session_buffer($spawn_id,command_name) $cname
   set rlogin_spawn_session_buffer($spawn_id,command_args) $cargs
}

#****** remote_procedures/is_spawn_process_in_use() ****************************
#  NAME
#     is_spawn_process_in_use() -- check if spawn id is in use
#
#  SYNOPSIS
#     is_spawn_process_in_use { spawn_id } 
#
#  FUNCTION
#     Test if given spawn id is already in use
#
#     See remote_procedures/add_open_spawn_rlogin_session() for a description
#     of the data structures.
#
#  INPUTS
#     spawn_id - internal spawn id number from open_remote_spawn_process()
#
#  RESULT
#     0    : not in use
#     not 0: this spawn id is in use
#
#  SEE ALSO
#     remote_procedures/open_remote_spawn_process()
#     remote_procedures/add_open_spawn_rlogin_session()
#*******************************************************************************
proc is_spawn_process_in_use {spawn_id} {
   global rlogin_spawn_session_buffer

   if {[info exists rlogin_spawn_session_buffer($spawn_id,pid)]} {
      return $rlogin_spawn_session_buffer($spawn_id,in_use)
   }

   return 0
}

#                                                             max. column:     |
#****** remote_procedures/close_spawn_process() ******
# 
#  NAME
#     close_spawn_process -- close open spawn process id 
#
#  SYNOPSIS
#     close_spawn_process { id { check_exit_state 0 } } 
#
#  FUNCTION
#     This procedure will close the process associated with the spawn id
#     returned from the procedures open_spawn_process or open_root_spawn_process.
#
#     Sends a CTRL-C to the session to terminate possibly still running
#     processes.
#
#  INPUTS
#     id - spawn process id (returned from open_spawn_process or 
#          open_root_spawn_process)
#     { check_exit_state 0 } - if 0: check exit state
#
#  RESULT
#     exit state of the "spawned" process
#
#  EXAMPLE
#     see open_root_spawn_process or open_spawn_process 
#
#  NOTES
#     After a process is "spawned" with the  open_spawn_process procedure it 
#     must be closed with the close_spawn_process procedure. id is the return 
#     value of open_spawn_process or open_root_spawn_process.
#     If a open spawn process id is not closed, it will not free the file
#     descriptor for that id. If all file descriptors are used, no new spawn
#     process can be forked!
#
#  SEE ALSO
#     remote_procedures/open_spawn_process
#     remote_procedures/open_root_spawn_process
#     remote_procedures/close_spawn_process
#     remote_procedures/start_remote_tcl_prog
#     remote_procedures/start_remote_prog
#*******************************
proc close_spawn_process {id {check_exit_state 0} {keep_open 1}} {
   global CHECK_DEBUG_LEVEL
   global CHECK_SHELL_PROMPT
   get_current_cluster_config_array ts_config
 
   set pid      [lindex $id 0]
   set spawn_id [lindex $id 1]
   if {[llength $id] > 2} {
      set nr_of_shells [lindex $id 2]
   } else {
      set nr_of_shells 0
   }

   ts_log_finest "close_spawn_process: closing $spawn_id $pid"

   # in debug mode we want to see all the shell output
   log_user 0
   if {$CHECK_DEBUG_LEVEL != 0} {
      log_user 1
   }

   # get connection info
   if {![get_spawn_id_rlogin_session $spawn_id con_data]} {
      ts_log_severe "connection \"$spawn_id\" is not open"
   }

   if {$keep_open} {
      # regular call from a check.
      # there might still be a program running
      # stop it by sending CTRL C and mark the connection as idle
      set do_return ""

      # mark the connection idle
      set_spawn_process_in_use $spawn_id 0

      # if we have code coverage analysis enabled, give the process
      # some time to finish writing coverage data
      # hopefully one second is enough
      if {[coverage_enabled]} {
         sleep 2
      }

      # stop still remaining running processes and wait for shell prompt
      set catch_return [catch {
         # first check the shell by expecting the shell prompt when
         # sending just a ENTER
         # if this is not working, send CTRL-C
         ts_log_finest "real user of connection is \"$con_data(real_user)\""
         ts_send $spawn_id "$ts_config(testsuite_root_dir)/scripts/check_identity.sh\n" $con_data(hostname)
         set timeout 2
         set num_tries 10
         expect {
            -i $spawn_id eof {
               ts_log_warning "unexpected eof"
               close_spawn_id $spawn_id
            }
            -i $spawn_id full_buffer {
               ts_log_warning "buffer overflow"
               close_spawn_id $spawn_id
            }
            -i $spawn_id timeout {
               incr num_tries -1
               if {$num_tries > 0} {
                  ts_log_finest "close_spawn_process: sending CTRL-C"
                  ts_send $spawn_id "\003" $con_data(hostname) ;# CTRL-C
                  ts_send $spawn_id "\n" $con_data(hostname)
                  ts_send $spawn_id "$ts_config(testsuite_root_dir)/scripts/check_identity.sh\n" $con_data(hostname)
                  increase_timeout
                  exp_continue
               } else {
                  ts_log_warning "timeout waiting for shell prompt"
               }
            }
            -i $spawn_id -- "TS_ID: ->*${con_data(real_user)}*\n" {
               ts_log_finest "logged in as ${con_data(real_user)} - fine"
               set do_return -1
            }
         }
      } catch_error_message]
      if {$catch_return == 1} {
         ts_log_warning $catch_error_message
      }
      
      # are we done?
      if {$do_return != ""} {
         testsuite_background_tasks
         return $do_return
      }
      
      # if we get here, we ran into an error
      # we will not return, but continue, really closing the connection
   }

   # we have shells to close (by sending exit)
   # at this point, we might have a bad rlogin session,
   # e.g. passed from check_rlogin_session.
   # expect ts_send to fail - pass raise_error = 0
   set do_close_connection 1
   if {$nr_of_shells > 0} {
      ts_log_finest "nr of open shells: $nr_of_shells"
      ts_log_finest "-->sending $nr_of_shells exit(s) to shell on id $spawn_id"
      set catch_return [catch {
         # send CTRL-C to stop poss. still running processes
         ts_send $spawn_id "\003" "" 0 0
         
         # wait for CTRL-C to take effect
         set timeout 5
         expect {
            -i $spawn_id full_buffer {
               ts_log_warning "buffer overflow"
            }
            -i $spawn_id eof {
               # do not raise an error here - we use this code to close broken connections
               ts_log_finest "eof while waiting for shell prompt after CTRL-C"
            }
            -i $spawn_id timeout {
               # do not raise an error here - we use this code to close broken connections
               ts_log_finest "timeout while waiting for shell prompt after CTRL-C"
            }
            -i $spawn_id -re $CHECK_SHELL_PROMPT {
               ts_log_finest "got shell prompt after CTRL-C"
            }
         }

         # now we try to close the shells with "exit"
         ts_send $spawn_id "exit\n" "" 0 0
         expect {
            -i $spawn_id full_buffer {
               ts_log_warning "buffer overflow"
            }
            -i $spawn_id eof {
               # do not raise an error here - we use this code to close broken connections
               set do_close_connection 0
               ts_log_finest "eof after exit - ok"
            }
            -i $spawn_id timeout {
               # do not raise an error here - we use this code to close broken connections
               ts_log_finest "timeout while waiting for shell prompt after exit"
            }
            -i $spawn_id -re $CHECK_SHELL_PROMPT {
               ts_log_finest "got shell prompt after exit"
               # if we get a shell prompt, the exit succeeded, one shell exited
               incr nr_of_shells -1

               # if we still have open shells, send "exit"
               if {$nr_of_shells > 0} {
                  ts_log_finest "sending exit to shell (nr of shells=$nr_of_shells)..."
                  ts_send $spawn_id "exit\n" "" 0 0
               } else {
                  ts_log_finest "all shells exited - wait for EOF ..."
               }
               # we wait for eof, so we continue ...
               exp_continue 
            }
         }
      } catch_error_message]
      if {$catch_return == 1} {
         ts_log_fine "close_spawn_process (exit) $catch_error_message"
      }
   }

   # unregister connection
   del_open_spawn_rlogin_session $spawn_id

   if {$do_close_connection} {
      ts_log_finer "There was no eof when closing connection, closing spawn id ..."
      # now shutdown the spawned process
      set catch_return [catch {
         ts_log_finest "closing $spawn_id"
         close -i $spawn_id
      } catch_error_message]

      if {$catch_return == 1} {
         ts_log_fine "close_spawn_process (close) $catch_error_message"
      }
   }

   # wait for spawned process to exit
   set wait_code 0
   set catch_return [catch {
      set wait_return   [wait -i $spawn_id]
      set wait_pid      [lindex $wait_return 0]
      set wait_spawn_id [lindex $wait_return 1]
      set wait_error    [lindex $wait_return 2]
      set wait_code     [lindex $wait_return 3]

      ts_log_finest "closed buffer   : $spawn_id"
      ts_log_finest "wait pid        : $wait_pid"
      ts_log_finest "wait spawn id   : $wait_spawn_id"
      ts_log_finest "wait error      : $wait_error (-1 = operating system error, 0 = exit)"
      ts_log_finest "wait code       : $wait_code  (os error code or exit status)"

      # if requested by caller, do certain error checks:
      if {$check_exit_state == 0} {
         # did we close the correct spawn id?
         if {$spawn_id != $wait_spawn_id} {
            ts_log_warning "closed wrong spawn id: expected $spawn_id, but got $wait_spawn_id"
         }

         # did we close the correct pid?
         if {$pid != $wait_pid} {
            ts_log_warning "closed wrong pid: expected $pid, but got $wait_pid"
         }

         # on regular exit: check exit code, shall be 0
         if {$wait_error == 0} {
            if {$wait_code != 0} {
               ts_log_warning "wait exit status: $wait_code"
            }
         } else {
            ts_log_finest "*** operating system error: $wait_code"
            ts_log_finest "spawn id: $wait_spawn_id"
            ts_log_finest "wait pid: $wait_pid"
            ts_log_severe -1 "operating system error: $wait_code"
         }
      }
   } catch_error_message]
   if {$catch_return == 1} {
      ts_log_warning "$catch_error_message" 
   }

   return $wait_code ;# return exit state
}

