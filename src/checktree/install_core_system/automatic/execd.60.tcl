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

proc autoinst_statistics {} {
   uplevel {
      set now [timestamp]
      if {$now > $monitor_time} {
         set monitor_time $now
         clear_screen
         # we do not use the logging framework here - it's screen only output
         puts  "Autoinstall of execution hosts ($parallel_install in parallel)"
         puts  "=========================================================================="
         puts  "Pending:         [llength $pending_install]"
         puts  "Running:         $running_install"
         puts  "Finished:        $finished_install"
         puts  ""
      }
   }
}
#                                                             max. column:     |
#****** install_core_system/install_execd() ******
# 
#  NAME
#     install_execd -- ??? 
#
#  SYNOPSIS
#     install_execd { } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
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
proc install_execd {} {
   global CORE_INSTALLED
   global check_use_installed_system
   global CHECK_COMMD_PORT CHECK_ADMIN_USER_SYSTEM CHECK_USER
   global CHECK_DEBUG_LEVEL CHECK_EXECD_INSTALL_OPTIONS
   global CHECK_COMMD_PORT
   global CHECK_MAIN_RESULTS_DIR
   global ts_config

   set CORE_INSTALLED ""
   set INST_VERSION 0 
   set LOCAL_ALREADY_CHECKED 0 
 
   read_install_list

   #string trimrigth $params in start_remote_prog removed the \" -> ", so we need \\\"
   set INST_VERSION [start_remote_prog $ts_config(master_host) $CHECK_USER "cat" "$ts_config(product_root)/inst_sge | grep \"SCRIPT_VERSION\" | cut -d\\\" -f2" ]

   ts_log_fine "inst_sge version: $INST_VERSION"

   if {!$check_use_installed_system} {
      set feature_install_options ""
      if {$ts_config(submit_only_hosts) != "none"} {
         foreach elem $ts_config(submit_only_hosts) {
            ts_log_fine "do a qconf -as $elem ..."
            set result [start_sge_bin "qconf" "-as $elem"]
            ts_log_fine $result
         }
      }
      if {$ts_config(product_feature) == "csp"} {
         set feature_install_options "-csp"
         set my_csp_host_list $ts_config(execd_nodes)
         if { $ts_config(submit_only_hosts) != "none" } {
            foreach elem $ts_config(submit_only_hosts) {
               lappend my_csp_host_list $elem
            }
         }
         foreach exec_host $my_csp_host_list {
            if {$exec_host == $ts_config(master_host)} {
               continue;
            }
            copy_certificates $exec_host
         }
      }
   }

   # handle install re_init case
   if {$check_use_installed_system != 0} {
      puts "no need to install execd on hosts \"$ts_config(execd_nodes)\", noinst parameter is set"
      foreach exec_host $ts_config(execd_nodes) {
         if {[startup_execd $exec_host] == 0} {
            lappend CORE_INSTALLED $exec_host
            write_install_list
            continue
         } else {
            ts_log_warning "could not startup execd on host $exec_host"
            return
         }
      }

      return
   }

   # install script available?
   if {[file isfile "$ts_config(product_root)/install_execd"] != 1} {
      ts_log_severe "install_execd file not found"
      return
   }

   # for some architectures, we have to install a load sensor file
   foreach exec_host $ts_config(execd_nodes) {
      set remote_arch [resolve_arch $exec_host]
      set sensor_file [get_loadsensor_path $exec_host]
      if {[string compare $sensor_file ""] != 0} {
         ts_log_fine "installing load sensor:"
         ts_log_fine "======================="
         ts_log_fine "architecture: $remote_arch"
         ts_log_fine "sensor file:  $sensor_file"
         ts_log_fine "target:       $ts_config(product_root)/bin/$remote_arch/qloadsensor"
         set fs_host [fs_config_get_server_for_path $ts_config(product_root) 0]
         if {$fs_host == ""} {
            set fs_host $ts_config(master_host)
         }
         if {$CHECK_ADMIN_USER_SYSTEM == 0} {
            set copy_user "root"
         } else {
            set copy_user $CHECK_USER
         }
         set arguments "$sensor_file $ts_config(product_root)/bin/$remote_arch/qloadsensor"
         set result [start_remote_prog $fs_host $copy_user "cp" "$arguments"]
         ts_log_fine "result: $result"
         ts_log_fine "copy exit state: $prg_exit_state"
      }
   }

   # remove all autoinstall config files
   # build an array of all autoconfig files
   if {[info exists autoconfig_files]} {
      unset autoconfig_files
   }

   foreach exec_host $ts_config(execd_nodes) {
      set autoconfig_file $ts_config(product_root)/autoinst_config_$ts_config(cell)_$exec_host.conf
      set autoconfig_files($exec_host) $autoconfig_file
   }

   # create all autoinstall config files
   foreach exec_host $ts_config(execd_nodes) {
      write_autoinst_config $autoconfig_files($exec_host) $exec_host 1 1 1
   }

   # now do the real installation
   # guestimate possible parallelizing
   # try to keep open some other connections for background work
   global rlogin_max_open_connections
   set parallel_install [expr $rlogin_max_open_connections - 10]
   if {$parallel_install <= 0} {
      set parallel_install 1
   }
   if {$parallel_install > 20} {
      set parallel_install 20
   }

   # initialize statistics
   set finished_install 0
   set running_install 0
   set pending_install $ts_config(execd_nodes)

   if {$CHECK_ADMIN_USER_SYSTEM} {
      set install_user $CHECK_USER
   } else {
      set install_user "root"
   }
   ts_log_fine "starting the installation as user $install_user"
   set error 0
   set monitor_time 0
   while {!$error && $finished_install < [llength $ts_config(execd_nodes)]} {
      # output some statistics
      autoinst_statistics 

      # start installation, when
      # - we have not yet exceeded the parallel install limit
      # - there are hosts to install left
      while {$running_install < $parallel_install && [llength $pending_install] > 0} {
         # output some statistics
         autoinst_statistics 

         # select host to install
         set exec_host [lindex $pending_install 0]
         set pending_install [lrange $pending_install 1 end]
         ts_log_fine "installing execd on host $exec_host ($ts_config(product_type) system) ..."

         # start auto install for this host 
         set install_options "$CHECK_EXECD_INSTALL_OPTIONS $feature_install_options -auto $autoconfig_files($exec_host) -noremote"
         set id [open_remote_spawn_process $exec_host $install_user "./install_execd" "$install_options" 0 $ts_config(product_root) "" 0 15 0 1 1]
         set spawn_id [lindex $id 1]
         lappend spawn_list $spawn_id
         lappend remote_spawn_list $id
         set spawn_host_map($spawn_id) $exec_host
         set remote_spawn_map($spawn_id) $id
         incr running_install
      }

      # monitor running installations
      set timeout 300
      log_user 1
      expect {
         -i $spawn_list full_buffer {
            set error 1
            ts_log_severe "expect full_buffer error (1)"
         }
         -i $spawn_list timeout {
            # we just looked for further messages, this is *not* an error
            # reset the timeout
            if {$timeout == 0} {
               set timeout 300
            } else {
               set error 1
               ts_log_severe "timeout while waiting for remote shell"
            }
         }
         -i $spawn_list "_exit_status_:(*)" {
            # update our counters
            incr finished_install 1
            incr running_install -1

            # close the session
            set spawn_id $expect_out(spawn_id)
            set id $remote_spawn_map($spawn_id)
            close_spawn_process $id

            # remove this session from our lists
            set pos [lsearch -exact $spawn_list $spawn_id]
            set spawn_list [lreplace $spawn_list $pos $pos]
            set pos [lsearch -exact $remote_spawn_list $id]
            set remote_spawn_list [lreplace $remote_spawn_list $pos $pos]
            
            # check exist status
            set exit_status [get_string_value_between "_exit_status_:(" ")" [string trim $expect_out(0,string)]]
            set host_name $spawn_host_map($spawn_id)
            if {$exit_status != 0} {
               ts_log_severe "execd_installation failed on host $host_name with $exit_status\n$expect_out(0,string)"
               set error 1
            } else {
               ts_log_fine "finished installation on host $host_name"
               lappend CORE_INSTALLED $exec_host
               write_install_list
               # stay in expect loop shortly to cleanup further finished installations
               if {[llength $pending_install] > 0} {
                  set timeout 0
                  exp_continue
               }
            }
         }
         -i $spawn_list eof {
            set spawn_id $expect_out(spawn_id)
            set host_name $spawn_host_map($spawn_id)
            set error 1
            ts_log_severe "got eof from host $host_name\n$expect_out(0,string)"
         }
      }
   }

   # if we had an error, close all remaining sessions
   if {$error} {
      foreach elem $remote_spawn_list {
         close_spawn_process $elem
      }
   }
}

