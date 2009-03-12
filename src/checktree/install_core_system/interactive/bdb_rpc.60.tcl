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
#****** install_core_system/install_bdb_rpc() ******
# 
#  NAME
#     install_bdb_rpc -- ??? 
#
#  SYNOPSIS
#     install_bdb_rpc { } 
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
proc install_bdb_rpc {} {
   global ts_config
   global check_use_installed_system
   global CHECK_COMMD_PORT CHECK_ADMIN_USER_SYSTEM CHECK_USER
   global CHECK_DEBUG_LEVEL
   global CHECK_MAIN_RESULTS_DIR

   set CORE_INSTALLED "" 

   read_install_list

   if {$ts_config(bdb_server) == "none"} {
      ts_log_fine "there is no rpc server configured - returning"
      return
   }

   set bdb_host $ts_config(bdb_server)
   ts_log_fine "installing BDB RPC Server on host $bdb_host ($ts_config(product_type) system) ..."
   if {$check_use_installed_system != 0} {
      puts "no need to install BDB RPC Server on hosts \"$ts_config(bdb_server)\", noinst parameter is set"
      if {[startup_bdb_rpc $bdb_host] == 0} {
         lappend CORE_INSTALLED $bdb_host
         write_install_list
      } else {
         ts_log_warning "could not startup BDB RPC Server on host $bdb_host"
      }
      return
   }

   if {[file isfile "$ts_config(product_root)/inst_sge"] != 1} {
      ts_log_severe "inst_sge file not found"
      return
   }

   set remote_arch [resolve_arch $bdb_host]    

   set ANSWER_YES                   [translate $bdb_host 0 1 0 [sge_macro DISTINST_ANSWER_YES] ]
   set ANSWER_NO                    [translate $bdb_host 0 1 0 [sge_macro DISTINST_ANSWER_NO] ]
   set RPC_HIT_RETURN_TO_CONTINUE   [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_HIT_RETURN_TO_CONTINUE] ]
   set RPC_WELCOME                  [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_WELCOME] ]
   set RPC_INSTALL_AS_ADMIN         [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_INSTALL_AS_ADMIN] "*" ]
   set RPC_SGE_ROOT                 [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_SGE_ROOT] "*" ]
   set RPC_SGE_CELL                 [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_SGE_CELL] "*"]
   set RPC_SERVER                   [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_SERVER] "*" ]
   set RPC_DIRECTORY                [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_DIRECTORY] "*" ]
   set RPC_DIRECTORY_EXISTS         [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_DIRECTORY_EXISTS] ]
   set RPC_START_SERVER             [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_START_SERVER] ]
   set RPC_SERVER_STARTED           [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_SERVER_STARTED] ]
   set RPC_INSTALL_RC_SCRIPT        [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_INSTALL_RC_SCRIPT] ]
   set RPC_SERVER_COMPLETE          [translate $bdb_host 0 1 0 [sge_macro DISTINST_RPC_SERVER_COMPLETE] ]
   set HIT_RETURN_TO_CONTINUE       [translate $bdb_host 0 1 0 [sge_macro DISTINST_HIT_RETURN_TO_CONTINUE] ]
   set INSTALL_SCRIPT               [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_INSTALL_SCRIPT] "*" ]
   set DNS_DOMAIN_QUESTION          [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DNS_DOMAIN_QUESTION] ]
   set HIT_RETURN_TO_CONTINUE_BDB_RPC [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_HIT_RETURN_TO_CONTINUE_BDB_RPC] ]
   set UNIQUE_CLUSTER_NAME          [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_UNIQUE_CLUSTER_NAME] ]
   set DETECT_CHOOSE_NEW_NAME       [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DETECT_CHOOSE_NEW_NAME] ]
   set DETECT_REMOVE_OLD_CLUSTER    [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DETECT_REMOVE_OLD_CLUSTER] ]
   set SMF_IMPORT_SERVICE           [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_SMF_IMPORT_SERVICE] ]
   set REMOVE_OLD_RC_SCRIPT         [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_REMOVE_OLD_RC_SCRIPT] ]

   # bdb server can spool on any filesystem, no need to request a local one
   set spooldir [get_bdb_spooldir $ts_config(bdb_server) 0]
   if {$spooldir == ""} {
      ts_log_severe "no spooldir for host $bdb_host found"
      return
   }

   if {[file isfile "$ts_config(product_root)/$ts_config(cell)/common/sgebdb"] == 1} {
      ts_log_fine "--> shutting down BDB RPC Server <--"
      start_remote_prog "$bdb_host" "root" "$ts_config(product_root)/$ts_config(cell)/common/sgebdb" "stop" prg_exit_state 60 0 "" "" 1 0 0 1 1
   }

   start_remote_prog "$bdb_host" "root" "rm" "-fR $spooldir" prg_exit_state 60 0 "" "" 1 0 0 1 1
   if {$CHECK_ADMIN_USER_SYSTEM == 0} {
      set inst_user "root"
   } else {
      set inst_user $CHECK_USER
      ts_log_fine "--> install as user $CHECK_USER <--" 
   }
   set id [open_remote_spawn_process $bdb_host $inst_user "./inst_sge" "-db" 0 $ts_config(product_root) "" 0 15 0 1 1]
   set sp_id [ lindex $id 1 ] 

   log_user 1
   set timeout 30
   set do_stop 0
   while {$do_stop == 0} {
      flush stdout
      if {$CHECK_DEBUG_LEVEL == 2} {
          puts "press RETURN"
          set anykey [wait_for_enter 1]
      }
  
      set timeout 300
      log_user 1 
      expect {
         -i $sp_id full_buffer {
            ts_log_warning "inst_sge -db - buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
            close_spawn_process $id
            return
         }

         -i $sp_id eof {
            ts_log_severe "inst_sge -db - unexpeced eof"
            set do_stop 1
            continue
         }

         -i $sp_id "coredump" {
            ts_log_warning "inst_sge -db - coredump on host $bdb_host"
            set do_stop 1
            continue
         }

         -i $sp_id timeout {
            ts_log_severe "inst_sge -db - timeout while waiting for output"
            set do_stop 1
            continue
         }

         -i $sp_id $RPC_HIT_RETURN_TO_CONTINUE {
            install_send_answer $sp_id ""
            continue
         }

         -i $sp_id $RPC_WELCOME { 
            install_send_answer $sp_id ""
            continue
         }

         -i $sp_id $RPC_INSTALL_AS_ADMIN { 
            install_send_answer $sp_id ""
            continue
         }

         -i $sp_id $RPC_SGE_ROOT {
            install_send_answer $sp_id $ts_config(product_root)
            continue
         }

         -i $sp_id $RPC_SGE_CELL {
            install_send_answer $sp_id $ts_config(cell)
            continue
         }

         -i $sp_id -- $UNIQUE_CLUSTER_NAME {
            install_send_answer $sp_id $ts_config(cluster_name) "cluster name"
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
         -i $sp_id -- $REMOVE_OLD_RC_SCRIPT {
            install_send_answer $sp_id $ANSWER_YES
            continue
         }

         -i $sp_id $RPC_SERVER {
            install_send_answer $sp_id $ts_config(bdb_server)
            continue
         } 

         -i $sp_id $DNS_DOMAIN_QUESTION { 
            install_send_answer $sp_id $ANSWER_YES
            continue
         }

         -i $sp_id $RPC_DIRECTORY {
            install_send_answer $sp_id $spooldir
            continue
         }

         -i $sp_id $RPC_DIRECTORY_EXISTS { 
            install_send_answer $sp_id $ANSWER_YES
            continue
         }


         -i $sp_id $RPC_START_SERVER { 
            install_send_answer $sp_id ""
            continue
         }

         -i $sp_id $RPC_SERVER_STARTED { 
            install_send_answer $sp_id ""
            continue
         }

         -i $sp_id $RPC_INSTALL_RC_SCRIPT { 
            install_send_answer $sp_id $ANSWER_NO
            continue
         }
          
         # SMF startup is always disabled in testsuite
         -i $sp_id -- $SMF_IMPORT_SERVICE {
            install_send_answer $sp_id $ANSWER_NO
            continue
         }

         -i $sp_id $INSTALL_SCRIPT { 
            install_send_answer $sp_id $ANSWER_NO
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

         -i $sp_id $RPC_SERVER_COMPLETE {
            read_install_list
            lappend CORE_INSTALLED $bdb_host
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

         -i $sp_id $HIT_RETURN_TO_CONTINUE_BDB_RPC {
            install_send_answer $sp_id ""
            continue
         }

         -i $sp_id default {
            ts_log_warning "inst_sge -db - undefined behaviour: $expect_out(buffer)"
            close_spawn_process $id
            return
         }
      } ;# expect
   } ;# while

   # close the connection to inst_sge
   close_spawn_process $id
}

