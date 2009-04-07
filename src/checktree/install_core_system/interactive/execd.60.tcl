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
   global ts_config
   global CORE_INSTALLED
   global check_use_installed_system
   global CHECK_COMMD_PORT CHECK_ADMIN_USER_SYSTEM CHECK_USER
   global CHECK_DEBUG_LEVEL CHECK_EXECD_INSTALL_OPTIONS
   global CHECK_COMMD_PORT
   global CHECK_MAIN_RESULTS_DIR

   set CORE_INSTALLED ""
   set INST_VERSION 0 
   set LOCAL_ALREADY_CHECKED 0

   set execd_port [expr $CHECK_COMMD_PORT + 1]
 
   read_install_list

   # does cluster contain windows hosts?
   # if yes, we'll have to copy the certificates, regardless of csp mode or not
   set have_windows_host [host_conf_have_windows]

   set catch_result [catch {eval exec "cat $ts_config(product_root)/inst_sge | grep \"SCRIPT_VERSION\" | cut -d\" -f2"} script_version]
   if {$catch_result == 0} {
      set INST_VERSION $script_version
   }
   ts_log_fine "inst_sge version: $INST_VERSION"

   if {!$check_use_installed_system} {
      set feature_install_options ""
      if {$ts_config(submit_only_hosts) != "none"} {
         foreach elem $ts_config(submit_only_hosts) {
            ts_log_fine "do a qconf -as $elem ..."
            set result [start_sge_bin "qconf" "-as $elem" $ts_config(master_host)]
            ts_log_fine $result
         }
      }
      if {$ts_config(product_feature) == "csp" || $have_windows_host} {
         set feature_install_options "-csp"
         set my_csp_host_list $ts_config(execd_nodes)
         if {$ts_config(submit_only_hosts) != "none"} {
            foreach elem $ts_config(submit_only_hosts) {
              lappend my_csp_host_list $elem
            }
         }
         foreach exec_host $my_csp_host_list {
            if {$exec_host == $ts_config(master_host)} {
               continue
            }
            set result [copy_certificates $exec_host]
            if {$result != 0} {
               # failed copying the certificates
               # copy_certificates() already called ts_log_severe()
               return
            }
         }
      }
   }
 
   foreach exec_host $ts_config(execd_nodes) {
      ts_log_fine "installing execd on host $exec_host ($ts_config(product_type) system) ..."
      if {[lsearch $ts_config(execd_nodes) $exec_host] == -1} {
         ts_log_severe "host $exec_host is not in execd list"
         return 
      }
      if {$check_use_installed_system != 0} {
         puts "no need to install execd on hosts \"$ts_config(execd_nodes)\", noinst parameter is set"
         if {[startup_execd $exec_host] == 0} {
            lappend CORE_INSTALLED $exec_host
            write_install_list
            continue
         } else {
            ts_log_warning "could not startup execd on host $exec_host"
            return
         }
      }

      if {[file isfile "$ts_config(product_root)/install_execd"] != 1} {
         ts_log_severe "install_execd file not found"
         return
      }

      set remote_arch [resolve_arch $exec_host]    
      set sensor_file [get_loadsensor_path $exec_host]
      if {[string compare $sensor_file ""] != 0} {
         ts_log_fine "installing load sensor:"
         ts_log_fine "======================="
         ts_log_fine "architecture: $remote_arch"
         ts_log_fine "sensor file:  $sensor_file"
         ts_log_fine "target:       $ts_config(product_root)/bin/$remote_arch/qloadsensor"
         if {$CHECK_ADMIN_USER_SYSTEM == 0} {
            set copy_user "root"
         } else {
            set copy_user $CHECK_USER
         }
         set arguments "$sensor_file $ts_config(product_root)/bin/$remote_arch/qloadsensor"
         set result [start_remote_prog $ts_config(master_host) $copy_user "cp" "$arguments" prg_exit_state 60 0 "" "" 1 0 0 1 1] 
         ts_log_fine "result: $result"
         ts_log_fine "copy exit state: $prg_exit_state" 
      }

      set HIT_RETURN_TO_CONTINUE       [translate $exec_host 0 1 0 [sge_macro DISTINST_HIT_RETURN_TO_CONTINUE] ]
      set EXECD_INSTALL_COMPLETE       [translate $exec_host 0 1 0 [sge_macro DISTINST_EXECD_INSTALL_COMPLETE] ]
      set PREVIOUS_SCREEN              [translate $exec_host 0 1 0 [sge_macro DISTINST_PREVIOUS_SCREEN] ]
      set CELL_NAME_FOR_EXECD          [translate $exec_host 0 1 0 [sge_macro DISTINST_CELL_NAME_FOR_EXECD] "*"]
      set CELL_NAME_FOR_EXECD_2        [translate $exec_host 0 1 0 [sge_macro DISTINST_CELL_NAME_FOR_EXECD_2]]
      set GET_COMM_SETTINGS            [translate $exec_host 0 1 0 [sge_macro DISTINST_GET_COMM_SETTINGS] "*"]
      set CHANGE_PORT_QUESTION         [translate $exec_host 0 1 0 [sge_macro DISTINST_CHANGE_PORT_QUESTION] ]
      set ANSWER_YES                   [translate $exec_host 0 1 0 [sge_macro DISTINST_ANSWER_YES] ]
      set ANSWER_NO                    [translate $exec_host 0 1 0 [sge_macro DISTINST_ANSWER_NO] ]
      set ADD_DEFAULT_QUEUE_INSTANCE   [translate $exec_host 0 1 0 [sge_macro DISTINST_ADD_DEFAULT_QUEUE_INSTANCE] ]
      set INSTALL_SCRIPT               [translate $exec_host 0 1 0 [sge_macro DISTINST_INSTALL_SCRIPT] "*" ]
      set IF_NOT_OK_STOP_INSTALLATION  [translate $exec_host 0 1 0 [sge_macro DISTINST_IF_NOT_OK_STOP_INSTALLATION] ]
      set LOCAL_CONFIG_FOR_HOST        [translate $exec_host 0 1 0 [sge_macro DISTINST_LOCAL_CONFIG_FOR_HOST] "$exec_host"]
      set MESSAGES_LOGGING             [translate $exec_host 0 1 0 [sge_macro DISTINST_MESSAGES_LOGGING] ]
      set USE_CONFIGURATION_PARAMS     [translate $exec_host 0 1 0 [sge_macro DISTINST_USE_CONFIGURATION_PARAMS] ]
      set CURRENT_GRID_ROOT_DIRECTORY  [translate $exec_host 0 1 0 [sge_macro DISTINST_CURRENT_GRID_ROOT_DIRECTORY] "*" "*" ]
      set CHECK_ADMINUSER_ACCOUNT      [translate $exec_host 0 1 0 [sge_macro DISTINST_CHECK_ADMINUSER_ACCOUNT] "*" "*" "*" "*" ]
      set CHECK_ADMINUSER_ACCOUNT_ANSWER      [translate $exec_host 0 1 0 [sge_macro DISTINST_CHECK_ADMINUSER_ACCOUNT_ANSWER] ]
      set INSTALL_STARTUP_SCRIPT       [translate $exec_host 0 1 0 [sge_macro DISTINST_INSTALL_STARTUP_SCRIPT] ]
      set ENTER_LOCAL_EXECD_SPOOL_DIR  [translate $exec_host 0 1 0 [sge_macro DISTINST_ENTER_LOCAL_EXECD_SPOOL_DIR] ]
      set ENTER_LOCAL_EXECD_SPOOL_DIR_ASK [translate $exec_host 0 1 0 [sge_macro DISTINST_ENTER_LOCAL_EXECD_SPOOL_DIR_ASK] ]
      set ENTER_LOCAL_EXECD_SPOOL_DIR_ENTER [translate $exec_host 0 1 0 [sge_macro DISTINST_ENTER_LOCAL_EXECD_SPOOL_DIR_ENTER] ]
      set HOSTNAME_KNOWN_AT_MASTER [translate $exec_host 0 1 0 [sge_macro DISTINST_HOSTNAME_KNOWN_AT_MASTER] ]
      set DETECT_CHOOSE_NEW_NAME       [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DETECT_CHOOSE_NEW_NAME] ]
      set DETECT_REMOVE_OLD_CLUSTER    [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DETECT_REMOVE_OLD_CLUSTER] ]
      set SMF_IMPORT_SERVICE           [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_SMF_IMPORT_SERVICE] ]
      set REMOVE_OLD_RC_SCRIPT         [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_REMOVE_OLD_RC_SCRIPT] ]

      # windows
      set WINDOWS_HELPER_SERVICE       [translate_macro DISTINST_EXECD_WINDOWS_HELPER_SERVICE]
      
      ts_log_fine "install_execd $CHECK_EXECD_INSTALL_OPTIONS $feature_install_options"

      if {$CHECK_ADMIN_USER_SYSTEM == 0} {
         # wait for act qmaster file
         wait_for_remote_file $exec_host "root" "$ts_config(product_root)/$ts_config(cell)/common/act_qmaster" 90
         set id [open_remote_spawn_process "$exec_host" "root"  "./install_execd" "$CHECK_EXECD_INSTALL_OPTIONS $feature_install_options" 0 $ts_config(product_root) "" 0 15 0 1 1]
      } else {
         ts_log_fine "--> install as user $CHECK_USER <--" 
         wait_for_remote_file $exec_host $CHECK_USER "$ts_config(product_root)/$ts_config(cell)/common/act_qmaster" 90
         set id [open_remote_spawn_process "$exec_host" "$CHECK_USER"  "./install_execd" "$CHECK_EXECD_INSTALL_OPTIONS $feature_install_options" 0 $ts_config(product_root) "" 0 15 0 1 1]
      }

      log_user 1

      set sp_id [ lindex $id 1 ] 

      set timeout 300
     
      set do_stop 0
      while {$do_stop == 0} {
         flush stdout
         if {$CHECK_DEBUG_LEVEL == 2} {
             puts "-->testsuite: press RETURN (main) or enter \"break\" to stop"
             set anykey [wait_for_enter 1]
             if { [string match "*break*" $anykey] } {
                break  
             }
         }
     
         set timeout 600
         log_user 1 
         expect {
            -i $sp_id full_buffer {
               ts_log_warning "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
               close_spawn_process $id
               return
            }

            -i $sp_id eof {
               ts_log_severe "unexpeced eof"
               set do_stop 1
               continue
            }

            -i $sp_id "coredump" {
               ts_log_warning "coredump on host $exec_host"
               set do_stop 1
               continue
            }

            -i $sp_id timeout { 
               ts_log_severe "timeout while waiting for output"
               set do_stop 1
               continue
            }

            -i $sp_id "orry" { 
               ts_log_warning "wrong root password"
               close_spawn_process $id
               return
            }

            -i $sp_id "The installation of the execution daemon will abort now" {
               ts_log_warning "installation error"
               close_spawn_process $id
               return
            }

            -i $sp_id $USE_CONFIGURATION_PARAMS { 
               install_send_answer $sp_id $ANSWER_YES
               continue
            }

            -i $sp_id $ENTER_LOCAL_EXECD_SPOOL_DIR_ASK {
               # If we said yes to the question whether we want to configure a local
               # spooldir, but enter an empty directory path here, inst_sge has
               # to handle this situation.
               # Beginning with INST_VERSION 4, this situation is handled correctly.
               # To test the correct error handling, we send yes here and later on
               # (ENTER_LOCAL_EXECD_SPOOL_DIR_ENTER) we send \"\" as spooldir.
               # inst_sge has to detect the incorrect input and repeat this question.
               if {$INST_VERSION >= 4 && $LOCAL_ALREADY_CHECKED == 0} {
                  install_send_answer $sp_id $ANSWER_YES "11.1"
               } else {
                  set spooldir [get_local_spool_dir $exec_host execd]
                  if {$spooldir == ""} {
                     install_send_answer $sp_id $ANSWER_NO "11.2"
                  } else {
                     install_send_answer $sp_id $ANSWER_YES "11.3"
                  }
               }
               continue
            }

            -i $sp_id $ENTER_LOCAL_EXECD_SPOOL_DIR_ENTER {
               # Second part of inst_sge error handling test (ENTER_LOCAL_EXECD_SPOOL_DIR_ASK):
               # Sending \"\" as spooldir
               if {$INST_VERSION >= 4 && $LOCAL_ALREADY_CHECKED == 0} {
                  set LOCAL_ALREADY_CHECKED 1
                  set spooldir ""
                  ts_log_fine "checking inst_sge error handling, sending \"\" as local spooldir"
               } else {
                  set spooldir [get_local_spool_dir $exec_host execd 0]
                  ts_log_fine "spooldir on host $exec_host is $spooldir"
               }

               install_send_answer $sp_id $spooldir "local spool directory"
               log_user 1
               continue
            }

            -i $sp_id $CELL_NAME_FOR_EXECD {
               install_send_answer $sp_id $ts_config(cell)
               continue
            } 

            -i $sp_id $CELL_NAME_FOR_EXECD_2 {
               install_send_answer $sp_id $ts_config(cell)
               continue
            }

             -i $sp_id $GET_COMM_SETTINGS {
                install_send_answer $sp_id "" "19a"
                continue
             }

            -i $sp_id $CHANGE_PORT_QUESTION {
                install_send_config $sp_id "" "19b"
                continue
             }

            -i $sp_id -- $DETECT_CHOOSE_NEW_NAME {
               install_send_answer $sp_id $ANSWER_YES
               continue
            }

            # Delete detected services for chosen cluster_name
            -i $sp_id -- $DETECT_REMOVE_OLD_CLUSTER {
               install_send_answer $sp_id $ANSWER_NO
               continue
            }

            # Remove conflicting RC files/SMF service
            -i $sp_id -- $REMOVE_OLD_RC_SCRIPT  {
               install_send_answer $sp_id $ANSWER_YES
               continue
            }

            -i $sp_id $MESSAGES_LOGGING {
               install_send_answer $sp_id ""
               continue
            }

            -i $sp_id -- $IF_NOT_OK_STOP_INSTALLATION {
               if {$CHECK_ADMIN_USER_SYSTEM != 0} {
                  install_send_answer $sp_id ""
                  continue
               } else {
                  ts_log_warning "host $exec_host: tried to install not as root"
                  close_spawn_process $id
                  return
               }
            }

            -i $sp_id $INSTALL_SCRIPT { 
               install_send_answer $sp_id $ANSWER_NO
               continue
            }

            -i $sp_id $INSTALL_STARTUP_SCRIPT { 
               install_send_answer $sp_id $ANSWER_NO "12"
               continue
            }

            -i $sp_id $ADD_DEFAULT_QUEUE_INSTANCE { 
               install_send_answer $sp_id $ANSWER_YES "13"
               continue
            }

            # SMF startup is always disabled in testsuite
            -i $sp_id -- $SMF_IMPORT_SERVICE  {
               install_send_answer $sp_id $ANSWER_NO "10"
               continue
            }

            -i $sp_id $CHECK_ADMINUSER_ACCOUNT_ANSWER { 
               install_send_answer $sp_id $ANSWER_YES "13"
               continue
            }


            -i $sp_id "This host is unknown on the qmaster host" {
               ts_log_severe "Hostname resolving problem - use a host alias file for host $exec_host"
               set do_stop 1
               continue
            }

            -i $sp_id "There is still no service for" {
               ts_log_severe "no TCP/IP service available"
               set do_stop 1
               continue
            }

            -i $sp_id "Check again" {
               install_send_answer $sp_id "n" "13"
               continue
            }

            -i $sp_id $PREVIOUS_SCREEN {
               install_send_answer $sp_id $ANSWER_NO "14"
               continue
            }

            -i $sp_id "Error:" {
               ts_log_warning "$expect_out(0,string)"
               close_spawn_process $id
               return
            }
            -i $sp_id "can't resolve hostname*\n" {
               ts_log_warning "$expect_out(0,string)"
               close_spawn_process $id
               return
            }

            -i $sp_id "error:\n" {
               ts_log_warning "$expect_out(0,string)"
               close_spawn_process $id
               return
            }

            -i $sp_id $CURRENT_GRID_ROOT_DIRECTORY {
               install_send_answer $sp_id ""
               continue
            }

            -i $sp_id $EXECD_INSTALL_COMPLETE {
               read_install_list
               lappend CORE_INSTALLED $exec_host
               write_install_list
               set do_stop 1
               # If we compiled with code coverage, we have to
               # wait a little bit before closing the connection.
               # Otherwise the last command executed (infotext)
               # will leave a lockfile lying around.
               if {[coverage_enabled]} {
                  after 2000
               }
               continue
            }

            -i $sp_id $HIT_RETURN_TO_CONTINUE {
               install_send_answer $sp_id ""
               continue
            }
            -i $sp_id $HOSTNAME_KNOWN_AT_MASTER {
               install_send_answer $sp_id ""
               continue
            }

            -i $sp_id $WINDOWS_HELPER_SERVICE {
               install_send_answer $sp_id "" "4"
               continue
            }

            -i $sp_id default {
               ts_log_warning "undefined behaviour: $expect_out(buffer)"
               close_spawn_process $id
               return
            }
         } ;# expect
      } ;# while 1

      # close the connection to inst_sge
      close_spawn_process $id

      # CR: 6609754
      ts_log_fine "Check execd deamon startup on host $exec_host and port $execd_port ..."
      set result [ping_daemon $exec_host $execd_port "execd"]
      if {$result == 0} {
         ts_log_fine "Startup of execd was successful!"
      } else {
         ts_log_severe "Error starting execd!"
      }
   }
}

