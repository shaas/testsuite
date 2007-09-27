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
   global CHECK_OUTPUT CORE_INSTALLED
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

   set catch_result [catch {eval exec "cat $ts_config(product_root)/inst_sge | grep \"SCRIPT_VERSION\" | cut -d\" -f2"} INST_VERSION]
   puts $CHECK_OUTPUT "inst_sge version: $INST_VERSION"

   if {!$check_use_installed_system} {
      set feature_install_options ""
      if { $ts_config(submit_only_hosts) != "none" } {
         foreach elem $ts_config(submit_only_hosts) {
            puts $CHECK_OUTPUT "do a qconf -as $elem ..."
            set result [start_sge_bin "qconf" "-as $elem"]
            puts $CHECK_OUTPUT $result
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
 
   foreach exec_host $ts_config(execd_nodes) {
      puts $CHECK_OUTPUT "installing execd on host $exec_host ($ts_config(product_type) system) ..."
      if {[lsearch $ts_config(execd_nodes) $exec_host] == -1} {
         add_proc_error "install_execd" "-1" "host $exec_host is not in execd list"
         return 
      }
#      wait_for_remote_file $exec_host $CHECK_USER "$ts_config(product_root)/$ts_config(cell)/common/configuration"
      if {$check_use_installed_system != 0} {
         puts "no need to install execd on hosts \"$ts_config(execd_nodes)\", noinst parameter is set"
         if {[startup_execd $exec_host] == 0} {
            lappend CORE_INSTALLED $exec_host
            write_install_list
            continue
         } else {
            add_proc_error "install_execd" -2 "could not startup execd on host $exec_host"
            return
         }
      }

      if {[file isfile "$ts_config(product_root)/install_execd"] != 1} {
         add_proc_error "install_execd" "-1" "install_execd file not found"
         return
      }

      set remote_arch [resolve_arch $exec_host]    
      set sensor_file [get_loadsensor_path $exec_host]
      if {[string compare $sensor_file ""] != 0} {
         puts $CHECK_OUTPUT "installing load sensor:"
         puts $CHECK_OUTPUT "======================="
         puts $CHECK_OUTPUT "architecture: $remote_arch"
         puts $CHECK_OUTPUT "sensor file:  $sensor_file"
         puts $CHECK_OUTPUT "target:       $ts_config(product_root)/bin/$remote_arch/qloadsensor"
         if {$CHECK_ADMIN_USER_SYSTEM == 0} { 
            set arguments "$sensor_file $ts_config(product_root)/bin/$remote_arch/qloadsensor"
            set result [start_remote_prog $ts_config(master_host) "root" "cp" "$arguments"] 
            puts $CHECK_OUTPUT "result: $result"
            puts $CHECK_OUTPUT "copy exit state: $prg_exit_state" 
         } else {
            puts $CHECK_OUTPUT "can not copy this file as user $CHECK_USER"
            puts $CHECK_OUTPUT "please copy this file manually!!"
            puts $CHECK_OUTPUT "if not, you will get no load values from this host (=$exec_host)"
            puts $CHECK_OUTPUT "installation will continue in 15 seconds!!"
            sleep 15
         }
      }


      set autoconfig_file $ts_config(product_root)/autoinst_config_$exec_host.conf
     
      write_autoinst_config $autoconfig_file $exec_host 0
  
      puts $CHECK_OUTPUT "install_execd $CHECK_EXECD_INSTALL_OPTIONS $feature_install_options -auto $ts_config(product_root)/autoinst_config.conf -noremote"

      set install_options "$CHECK_EXECD_INSTALL_OPTIONS $feature_install_options -auto $autoconfig_file -noremote"
      if {$CHECK_ADMIN_USER_SYSTEM == 0} {
         set id [open_remote_spawn_process $exec_host "root" "./install_execd" "$install_options" 0 $ts_config(product_root)]
      } else {
         puts $CHECK_OUTPUT "--> install as user $CHECK_USER <--" 
         set id [open_remote_spawn_process $exec_host "$CHECK_USER" "./install_execd" "$install_options" 0 $ts_config(product_root)]
      }
      set spawn_id [lindex $id 1]
      lappend spawn_list $spawn_id
      lappend remote_spawn_list $id
      set spawn_host_map($spawn_id) $exec_host
      set remote_spawn_map($spawn_id) $id
   }

   log_user 1
   set finished_install 0
   set timeout 300
   set error 0
   while { $finished_install < [llength $ts_config(execd_nodes)]} {
      expect {
         -i $spawn_list full_buffer {
            set error 1
            add_proc_error "install_execd" -1 "expect full_buffer error (1)"
         }
         -i $spawn_list timeout {
            set error 1
            add_proc_error "install_execd" -1 "timeout while waiting for remote shell"
         }
         -i $spawn_list "_exit_status_:(*)" {
            set exit_status [get_string_value_between "_exit_status_:(" ")" [string trim $expect_out(0,string)]]
            incr finished_install 1
            set spawn_id $expect_out(spawn_id)
            set id $remote_spawn_map($spawn_id)
            close_spawn_process $id

            if {$exit_status != 0} {
               set host_name $spawn_host_map($spawn_id)
               add_proc_error "install_exec" -1 "execd_installation failed on host $host_name with $exit_status\n$expect_out(0,string)"
            } else {
               lappend CORE_INSTALLED $exec_host
               write_install_list
            }
         }
         -i $spawn_list eof {
            set spawn_id $expect_out(spawn_id)
            set host_name $spawn_host_map($spawn_id)
            set error 1
            add_proc_error "install_execd" -1 "got eof from host $host_name\n$expect_out(0,string)"
         }
      }

      if {$error == 1} {
         foreach elem $remote_spawn_list {
            close_spawn_process $elem
         }
         set finished_install [llength $ts_config(execd_nodes)]
      }
   }

   return
}

