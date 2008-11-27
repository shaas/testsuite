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

# install qmaster check 
#                                                             max. column:     |
#****** install_core_system/install_qmaster() ******
# 
#  NAME
#     install_qmaster -- ??? 
#
#  SYNOPSIS
#     install_qmaster { } 
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
proc install_qmaster {} {
   global CHECK_USER
   global CORE_INSTALLED CORE_INSTALLED
   global env CHECK_COMMD_PORT local_master_spool_set
   global check_use_installed_system CHECK_ADMIN_USER_SYSTEM CHECK_DEFAULT_DOMAIN
   global CHECK_DEBUG_LEVEL CHECK_QMASTER_INSTALL_OPTIONS CHECK_COMMD_PORT
   global CHECK_REPORT_EMAIL_TO CHECK_MAIN_RESULTS_DIR CHECK_FIRST_FOREIGN_SYSTEM_USER
   global CHECK_SECOND_FOREIGN_SYSTEM_USER CHECK_REPORT_EMAIL_TO CHECK_DNS_DOMAINNAME
   global CHECK_PROTOCOL_DIR
 
   global ts_config

   ts_log_fine "install qmaster ($ts_config(product_type) system) on host $ts_config(master_host) ..."

   if {$check_use_installed_system != 0} {
      puts "no need to install qmaster on host $ts_config(master_host), noinst parameter is set"
      set CORE_INSTALLED "" 
      if {[startup_qmaster] == 0} {
         lappend CORE_INSTALLED $ts_config(master_host)
         write_install_list
      }
      return
   }

   set CORE_INSTALLED ""
   write_install_list

   if {[file isfile "$ts_config(product_root)/install_qmaster"] != 1} {
      ts_log_severe "install_qmaster file not found"
      return
   }

   # dump hostlist to file
   set admin_hosts "$ts_config(all_nodes) $ts_config(shadowd_hosts)"
   set admin_hosts [lsort -unique $admin_hosts]

   set host_file_name "$CHECK_PROTOCOL_DIR/hostlist"
   set f [open $host_file_name w]
   foreach host $admin_hosts {
      puts $f $host
   }
   close $f

   # does cluster contain windows hosts?
   # install_qmaster will ask us about this
   set have_windows_host [host_conf_have_windows]

   set LICENSE_AGREEMENT            [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_LICENSE_AGREEMENT] ]
   set HIT_RETURN_TO_CONTINUE       [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_HIT_RETURN_TO_CONTINUE] ]
   set CURRENT_GRID_ROOT_DIRECTORY  [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CURRENT_GRID_ROOT_DIRECTORY] "*" "*" ]
   set CELL_NAME_FOR_QMASTER        [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CELL_NAME_FOR_QMASTER] "*"]
   set GET_COMM_SETTINGS            [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_GET_COMM_SETTINGS] "*"]
   set CHANGE_PORT_QUESTION         [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CHANGE_PORT_QUESTION] ]
   set VERIFY_FILE_PERMISSIONS1      [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_VERIFY_FILE_PERMISSIONS1] ]
   set VERIFY_FILE_PERMISSIONS2      [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_VERIFY_FILE_PERMISSIONS2] ]
   set WILL_NOT_VERIFY_FILE_PERMISSIONS [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_WILL_NOT_VERIFY_FILE_PERMISSIONS] ]
   set DO_NOT_VERIFY_FILE_PERMISSIONS [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DO_NOT_VERIFY_FILE_PERMISSIONS] ]
   set NOT_COMPILED_IN_SECURE_MODE  [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_NOT_COMPILED_IN_SECURE_MODE] ] 
   set ENTER_HOSTS                  [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ENTER_HOSTS] ]
   set MASTER_INSTALLATION_COMPLETE [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_MASTER_INSTALLATION_COMPLETE] ]
   set ENTER_A_RANGE                [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ENTER_A_RANGE] ]
   set PREVIOUS_SCREEN              [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_PREVIOUS_SCREEN] ]
   set FILE_FOR_HOSTLIST            [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_FILE_FOR_HOSTLIST] ]
   set FINISHED_ADDING_HOSTS        [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_FINISHED_ADDING_HOSTS] ]
   set FILENAME_FOR_HOSTLIST        [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_FILENAME_FOR_HOSTLIST] ]
   set CREATE_NEW_CONFIGURATION     [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CREATE_NEW_CONFIGURATION] ]
   set INSTALL_SCRIPT               [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_INSTALL_SCRIPT] "*" ]
   set ANSWER_YES                   [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ANSWER_YES] ]
   set ANSWER_NO                    [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ANSWER_NO] ]
   set ENTER_DEFAULT_DOMAIN         [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ENTER_DEFAULT_DOMAIN] ]
   set CONFIGURE_DEFAULT_DOMAIN     [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CONFIGURE_DEFAULT_DOMAIN] ] 
   set PKGADD_QUESTION              [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_PKGADD_QUESTION] ]
   set MESSAGES_LOGGING             [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_MESSAGES_LOGGING] ]
   set OTHER_SPOOL_DIR              [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_OTHER_SPOOL_DIR] ]
   set OTHER_USER_ID_THAN_ROOT      [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_OTHER_USER_ID_THAN_ROOT] ]
   set INSTALL_AS_ADMIN_USER        [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_INSTALL_AS_ADMIN_USER] "$CHECK_USER" ]
   set ADMIN_USER_ACCOUNT           [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ADMIN_USER_ACCOUNT] "$CHECK_USER\r\n" ]
   set USE_CONFIGURATION_PARAMS     [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_USE_CONFIGURATION_PARAMS] ]
   set INSTALL_GE_NOT_AS_ROOT       [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_INSTALL_GE_NOT_AS_ROOT] ]
   set IF_NOT_OK_STOP_INSTALLATION  [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_IF_NOT_OK_STOP_INSTALLATION] ]
   set DNS_DOMAIN_QUESTION          [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DNS_DOMAIN_QUESTION] ] 
   set SERVICE_TAGS_SUPPORT         [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_SERVICE_TAGS_SUPPORT] ]
   set ENTER_SPOOL_DIR   [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ENTER_SPOOL_DIR] "*"]
   set USING_GID_RANGE_HIT_RETURN   [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_USING_GID_RANGE_HIT_RETURN] "*"]
   set CREATING_ALL_QUEUE_HOSTGROUP [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ALL_QUEUE_HOSTGROUP] ]
   set EXECD_SPOOLING_DIR_NOROOT_NOADMINUSER           [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_EXECD_SPOOLING_DIR_NOROOT_NOADMINUSER]]
   set EXECD_SPOOLING_DIR_NOROOT           [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_EXECD_SPOOLING_DIR_NOROOT] "*"]
   set EXECD_SPOOLING_DIR_DEFAULT   [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_EXECD_SPOOLING_DIR_DEFAULT] "*"]
   set ENTER_ADMIN_MAIL             [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ENTER_ADMIN_MAIL] "*"]
   set SHOW_CONFIGURATION           [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_SHOW_CONFIGURATION] "*" "*"]
   set ACCEPT_CONFIGURATION         [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ACCEPT_CONFIGURATION] ]
   set INSTALL_STARTUP_SCRIPT       [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_INSTALL_STARTUP_SCRIPT] ]
   set ENTER_SCHEDLUER_SETUP        [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ENTER_SCHEDLUER_SETUP] ]
   set DELETE_DB_SPOOL_DIR          [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DELETE_DB_SPOOL_DIR] ]
   set CELL_NAME_EXISTS             [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CELL_NAME_EXISTS] ]
   set CELL_NAME_OVERWRITE          [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CELL_NAME_OVERWRITE] ]
   set ADD_SHADOWHOST_ASK           [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ADD_SHADOWHOST_ASK] ]
   set ADD_SHADOWHOST_FROM_FILE_ASK [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ADD_SHADOWHOST_FROM_FILE_ASK] ]
   set WE_CONFIGURE_WITH_X_SETTINGS [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_WE_CONFIGURE_WITH_X_SETTINGS] "*" ]

   # dynamic spooling
   set CHOOSE_SPOOLING_METHOD [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CHOOSE_SPOOLING_METHOD] "*"]

   # berkeley db
   set DATABASE_LOCAL_SPOOLING     [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DATABASE_LOCAL_SPOOLING]]
   set ENTER_DATABASE_SERVER       [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ENTER_DATABASE_SERVER] "*"]
   set ENTER_DATABASE_DIRECTORY_LOCAL_SPOOLING    [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ENTER_DATABASE_DIRECTORY_LOCAL_SPOOLING] "*"]
   set ENTER_DATABASE_SERVER_DIRECTORY    [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ENTER_SERVER_DATABASE_DIRECTORY] "*"]
   set DATABASE_DIR_NOT_ON_LOCAL_FS [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DATABASE_DIR_NOT_ON_LOCAL_FS] "*"]
   set STARTUP_RPC_SERVER [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_STARTUP_RPC_SERVER]]
   set DONT_KNOW_HOW_TO_TEST_FOR_LOCAL_FS [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DONT_KNOW_HOW_TO_TEST_FOR_LOCAL_FS]]

   # csp
   set CSP_COPY_CERTS [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CSP_COPY_CERTS]]
   set CSP_COPY_CMD [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CSP_COPY_CMD]]
   set CSP_COPY_FAILED [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CSP_COPY_FAILED]]
   set CSP_COPY_RSH_FAILED [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_CSP_COPY_RSH_FAILED]]

   # windows
   set WINDOWS_SUPPORT              [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_WINDOWS_SUPPORT]]
   set WINDOWS_DOMAIN_USER          [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_QMASTER_WINDOWS_DOMAIN_USER]]
   set WINDOWS_MANAGER              [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_QMASTER_WINDOWS_MANAGER]]

   # java
   set JMX_JAVA_HOME                [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_JAVA_HOME] "*" ]
   set JMX_ADD_JVM_ARGS             [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_ADD_JVM_ARGS] "*"]
   set JMX_PORT_QUESTION            [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_JMX_PORT]]
   set JMX_SSL_QUESTION             [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_JMX_SSL]]
   set JMX_SSL_CLIENT_QUESTION      [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_JMX_SSL_CLIENT]]
   set JMX_SSL_KEYSTORE_QUESTION    [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_JMX_SSL_KEYSTORE] "*" ]
   set JMX_SSL_KEYSTORE_PW_QUESTION [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_JMX_SSL_KEYSTORE_PW]]
   set JMX_USE_DATA                 [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_JMX_USE_DATA]]

   set UNIQUE_CLUSTER_NAME          [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_UNIQUE_CLUSTER_NAME]]
   set DETECT_CHOOSE_NEW_NAME       [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DETECT_CHOOSE_NEW_NAME]]
   set DETECT_REMOVE_OLD_CLUSTER    [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DETECT_REMOVE_OLD_CLUSTER]]
   set DETECT_BDB_KEEP_CELL         [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_DETECT_BDB_KEEP_CELL]]
   set SMF_IMPORT_SERVICE           [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_SMF_IMPORT_SERVICE]]
   set REMOVE_OLD_RC_SCRIPT         [translate $ts_config(master_host) 0 1 0 [sge_macro DISTINST_REMOVE_OLD_RC_SCRIPT]]

   set feature_install_options ""
   if {$ts_config(product_feature) == "csp"} {
      append feature_install_options "-csp"
   }

   if {$ts_config(jmx_port) == 0} {
      append feature_install_options " -no-jmx"
   } elseif {$ts_config(jmx_port) > 0} {
      append feature_install_options " -jmx"
   }

   ts_log_fine "install_qmaster $CHECK_QMASTER_INSTALL_OPTIONS $feature_install_options"

   set set_ld_library_path 0
   set arch [resolve_arch $ts_config(master_host)]
   # hack - on our SuSE 9.0 lx26-x86 host, ORIGIN does not work
   if {$arch == "lx26-x86"} {
      ts_log_config "have to set LD_LIBRARY_PATH for \"$arch\" compilations!"
      set set_ld_library_path 1
   }

   if {$CHECK_ADMIN_USER_SYSTEM == 0} {
      set install_user "root"
   } else {
      set install_user $CHECK_USER
      ts_log_fine "--> install as user $CHECK_USER <--" 
   }
   set id [open_remote_spawn_process "$ts_config(master_host)" $install_user "./install_qmaster" "$CHECK_QMASTER_INSTALL_OPTIONS $feature_install_options" 0 $ts_config(product_root) env_list 0 15 $set_ld_library_path 1 1]
   set sp_id [lindex $id 1] 

   set hostcount 0
   set do_stop 0
   set found_darwin_more 0
   while {!$do_stop} {
      log_user 1
      flush stdout
      if {$CHECK_DEBUG_LEVEL == 2} {
         puts "-->testsuite: press RETURN (main) or type \"break\""
         set anykey [wait_for_enter 1]
         if {[string match "*break*" $anykey]} {
            break  
         }
      }

      set timeout 300
      expect {
         -i $sp_id full_buffer {
            ts_log_severe "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
            close_spawn_process $id
            return
         }

         -i $sp_id eof {
            ts_log_severe "unexpected eof"
            close_spawn_process $id
            return
         }

         -i $sp_id "coredump" {
            ts_log_warning "coredump"
            close_spawn_process $id
            return
         }

         -i $sp_id timeout {
            ts_log_warning "timeout while waiting for output"
            close_spawn_process $id
            return
         }

         -i $sp_id "orry" {
            ts_log_severe "wrong root password"
            close_spawn_process $id
            return
         }

         -i $sp_id "issing" {
            ts_log_severe "missing binary error"
            close_spawn_process $id
            return
         }

         -i $sp_id "xit." {
            ts_log_severe "installation failed"
            close_spawn_process $id
            return
         }

         -i $sp_id $ADMIN_USER_ACCOUNT {
            set real_admin_user $expect_out(0,string)
            set real_help [split $real_admin_user "="]
            set real_admin_user [string trim [lindex $real_help 1]]

            ts_log_newline FINER ; ts_log_finer "-->testsuite: admin user is \"$real_admin_user\""
            if {[string compare $real_admin_user $CHECK_USER] != 0} {
               ts_log_severe "admin user \"$real_admin_user\" is different from CHECK_USER \"$CHECK_USER\"" 
               close_spawn_process $id
               return
            }
            continue
         }

# TODO: This entry is duplicited later with different implementation on line 375
         -i $sp_id $DNS_DOMAIN_QUESTION {
            ts_send $sp_id "\n"
            continue
         }

         -i $sp_id "o you want to recreate your SGE CA infrastructure" {
            install_send_answer $sp_id "y" "1"
            continue
         }

         -i $sp_id "enter your two letter country code" {
            install_send_answer $sp_id "DE"
            continue
         }

         -i $sp_id "lease enter your state" {
            install_send_answer $sp_id "Bavaria"
            continue
         }
 
         -i $sp_id "lease enter your location" {
            install_send_answer $sp_id "Regensburg"
            continue
         }

         -i $sp_id "lease enter the name of your organization" {
            install_send_answer $sp_id "Sun Microsystems"
            continue
         }

         -i $sp_id "lease enter your organizational unit" {
            install_send_answer $sp_id "Testsystem at port $CHECK_COMMD_PORT"
            continue
         }

         -i $sp_id "lease enter the email address of the CA administrator" {
            if {$CHECK_REPORT_EMAIL_TO == "none"} {
               install_send_answer $sp_id "${CHECK_USER}@${CHECK_DNS_DOMAINNAME}"
            } else {
               install_send_answer $sp_id $CHECK_REPORT_EMAIL_TO
            }
            continue
         }

         -i $sp_id "o you want to use these data" { 
            install_send_answer $sp_id "y" "2"
            continue
         }
       
         -i $sp_id $JMX_JAVA_HOME {
            # For the JMX MBean Server we need java 1.5
            set java_home [get_java_home_for_host $ts_config(master_host) "1.5"]
            if {$java_home == ""} {
               ts_log_warning "Cannot install qmaster with JMX MBean Server on host $ts_config(master_host). java15 is not defined in host configuration"
               close_spawn_process $id
               return
            }
            install_send_answer $sp_id $java_home "sending java_home"
            continue
         }

         -i $sp_id $JMX_ADD_JVM_ARGS {
            install_send_answer $sp_id "" "additional_jvm_args"
            continue
         }

         -i $sp_id $JMX_PORT_QUESTION {
            install_send_answer $sp_id $ts_config(jmx_port) "jmx port"
            continue
         }

         -i $sp_id $JMX_SSL_QUESTION {
            if { $ts_config(jmx_ssl) == "true" } {
               install_send_answer $sp_id $ANSWER_YES "jmx ssl"
            } else {
               install_send_answer $sp_id $ANSWER_NO "jmx ssl"
            }
            continue
         }

         -i $sp_id $JMX_SSL_CLIENT_QUESTION {
            if {$ts_config(jmx_ssl_client) == "true"} {
               install_send_answer $sp_id $ANSWER_YES "jmx ssl client"
            } else {
               install_send_answer $sp_id $ANSWER_NO "jmx ssl client"
            }
            continue
         }

         -i $sp_id $JMX_SSL_KEYSTORE_QUESTION {
            install_send_answer $sp_id "" "jmx ssl keystore"
            continue
         }

         -i $sp_id $JMX_SSL_KEYSTORE_PW_QUESTION {
            install_send_answer $sp_id $ts_config(jmx_ssl_keystore_pw) "jmx ssl keystore pw"
            continue
         }

         -i $sp_id $JMX_USE_DATA {
            install_send_answer $sp_id "y"
            continue
         }

         -i $sp_id $DNS_DOMAIN_QUESTION { 
            install_send_answer $sp_id $ANSWER_YES "4"
            continue
         }

         -i $sp_id $SERVICE_TAGS_SUPPORT { 
            install_send_answer $sp_id $ANSWER_YES "6"
            continue
         }

         -i $sp_id $INSTALL_AS_ADMIN_USER { 
            install_send_answer $sp_id $ANSWER_YES "5"
            continue
         }

         -i $sp_id $CELL_NAME_EXISTS { 
            install_send_answer $sp_id $ANSWER_NO "5.1"
            continue
         }

         -i $sp_id $CELL_NAME_OVERWRITE { 
            if {$ts_config(bdb_server) == "none"} {
               install_send_answer $sp_id $ANSWER_NO "5.2.1"
            } else {
               install_send_answer $sp_id $ANSWER_YES "5.2.2"
            }
            continue
         }

         # BDB was installed first, we have a new question
         -i $sp_id -- $DETECT_BDB_KEEP_CELL { 
            install_send_answer $sp_id $ANSWER_YES "5.2"
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

         #Delete detected services for chosen cluster_name
         -i $sp_id -- $DETECT_REMOVE_OLD_CLUSTER {
            install_send_answer $sp_id $ANSWER_NO
            continue
         }

         #Remove conflicting RC files/SMF service
         -i $sp_id -- $REMOVE_OLD_RC_SCRIPT  {
            install_send_answer $sp_id $ANSWER_YES
            continue
         }

         -i $sp_id -- $VERIFY_FILE_PERMISSIONS1 {
            if {$ts_config(package_type) == "tar" || $ts_config(package_type) == "create_tar"} {
               # try to set file permissions on the fileserver.
               # it is faster, and will work on root=nobody mounted filesystems
               set fileserver [fs_config_get_server_for_path $ts_config(product_root) 0]
               if {$fileserver != ""} {
                  ts_log_newline
                  ts_log_fine "starting setfileperm.sh on fileserver $fileserver"
                  set output [start_remote_prog $fileserver "root" "$ts_config(product_root)/util/setfileperm.sh" "-auto $ts_config(product_root)" prg_exit_state 120 0 $ts_config(product_root)]
                  if {$prg_exit_state != 0} {
                     ts_log_warning "setfileperm.sh on host $fileserver failed:\n$output"
                     close_spawn_process $id
                     return
                  } else {
                     ts_log_fine "done"
                  }
                  install_send_answer $sp_id $ANSWER_NO "verify_file 1"
               } else {
                  install_send_answer $sp_id $ANSWER_YES "verify_file 1"
               }
            } else {
               install_send_answer $sp_id $ANSWER_NO "verify_file 1"
            }
            continue
         }
         -i $sp_id -- $VERIFY_FILE_PERMISSIONS2 { 
            if {$ts_config(package_type) == "tar" || $ts_config(package_type) == "create_tar"} {
               install_send_answer $sp_id $ANSWER_NO "verify_file 2"
            } else {
               install_send_answer $sp_id $ANSWER_YES "verify_file 2"
            }
            continue
         }

         -i $sp_id $WILL_NOT_VERIFY_FILE_PERMISSIONS {
            install_send_answer $sp_id "" "21"
            continue
         }
         -i $sp_id $DO_NOT_VERIFY_FILE_PERMISSIONS {
            install_send_answer $sp_id "" "21"
            continue
         }

         -i $sp_id $USE_CONFIGURATION_PARAMS {
            install_send_answer $sp_id $ANSWER_NO "1"
            continue
         }

         -i $sp_id "Please hit <RETURN> to continue once you set your file permissions" {
            install_send_answer $sp_id "" "1"
            continue
         }

         -i $sp_id -- $IF_NOT_OK_STOP_INSTALLATION {
            if {$CHECK_ADMIN_USER_SYSTEM != 0} {
               install_send_answer $sp_id "" "2"
               continue
            } else {
               ts_log_warning "tried to install not as root"
               close_spawn_process $id
               return
            }
         }

         -i $sp_id $INSTALL_GE_NOT_AS_ROOT {
            install_send_answer $sp_id $ANSWER_NO "4"
            continue
         }

         -i $sp_id $WINDOWS_SUPPORT {
            if {$have_windows_host} {
               install_send_answer $sp_id $ANSWER_YES "4"
            } else {
               install_send_answer $sp_id $ANSWER_NO "4"
            }
            continue
         }

         -i $sp_id $WINDOWS_DOMAIN_USER {
            install_send_answer $sp_id $ANSWER_YES "4"
            continue
         }

         -i $sp_id $WINDOWS_MANAGER {
            install_send_answer $sp_id "" "4"
            continue
         }

         -i $sp_id $OTHER_USER_ID_THAN_ROOT {
            install_send_answer $sp_id $ANSWER_NO "4"
            continue
         }

         -i $sp_id $OTHER_SPOOL_DIR {
            set spooldir [get_local_spool_dir $ts_config(master_host) qmaster]
            if {$spooldir != ""} {
               install_send_answer $sp_id $ANSWER_YES "5"
            } else {
               install_send_answer $sp_id $ANSWER_NO "5"
            }
            continue
         }

         -i $sp_id $MESSAGES_LOGGING {
            install_send_answer $sp_id "" "3"
            continue
         }

         -i $sp_id $PKGADD_QUESTION {
            install_send_answer $sp_id $ANSWER_NO "6"
            continue
         }

         -i $sp_id $ENTER_SPOOL_DIR {
            set spooldir [get_local_spool_dir $ts_config(master_host) qmaster]
            if {$spooldir != ""} {
               # use local spool dir
               install_send_answer $sp_id $spooldir
               set local_master_spool_set 1
            } else {
               # use default spool dir
               install_send_answer $sp_id ""
            }
            continue
         }       
       
         -i $sp_id $EXECD_SPOOLING_DIR_NOROOT_NOADMINUSER {
            set spooldir [get_local_spool_dir $ts_config(master_host) execd 0]
            if {$spooldir != ""} {
               # use local spool dir
               install_send_answer $sp_id $spooldir
               set local_execd_spool_set 1
            } else {
               # use default spool dir
               install_send_answer $sp_id ""
            }
            continue
         }

         -i $sp_id $EXECD_SPOOLING_DIR_NOROOT {
            set spooldir [get_local_spool_dir $ts_config(master_host) execd 0]
            if {$spooldir != ""} {
               # use local spool dir
               install_send_answer $sp_id $spooldir
               set local_execd_spool_set 1
            } else {
               # use default spool dir
               install_send_answer $sp_id ""
            }
            continue
         }

         -i $sp_id $CONFIGURE_DEFAULT_DOMAIN {
            install_send_answer $sp_id $ANSWER_NO "7"
            continue
         }

         -i $sp_id $ENTER_DEFAULT_DOMAIN {
            install_send_answer $sp_id $CHECK_DEFAULT_DOMAIN
            continue
         }

         -i $sp_id $INSTALL_SCRIPT {
            install_send_answer $sp_id $ANSWER_NO "9"
            continue
         }

         -i $sp_id $CREATE_NEW_CONFIGURATION {
            install_send_answer $sp_id $ANSWER_YES "9"
            continue
         }

         -i $sp_id $FILENAME_FOR_HOSTLIST {
            install_send_answer $sp_id ${host_file_name}
            continue
         }
   
         -i $sp_id $FINISHED_ADDING_HOSTS {
            install_send_answer $sp_id "" "7"
            continue
         }
   
         -i $sp_id $FILE_FOR_HOSTLIST {
            install_send_answer $sp_id "" "10"
            continue
         }

         -i $sp_id $PREVIOUS_SCREEN {
            install_send_answer $sp_id $ANSWER_NO "10"
            continue
         }
  
         -i $sp_id $ENTER_A_RANGE {
            set myrange [get_gid_range $CHECK_USER $CHECK_COMMD_PORT]
            install_send_answer $sp_id ${myrange}
            continue
         }

         -i $sp_id $MASTER_INSTALLATION_COMPLETE {
            read_install_list
            lappend CORE_INSTALLED $ts_config(master_host)
            write_install_list
            set do_stop 1
            # If we compiled with code coverage, we have to 
            # wait a little bit before closing the connection.
            # Otherwise the last command executed (infotext)
            # will leave a lockfile lying around.
            if {[coverage_enabled]} {
               sleep 1
               # inst_sge expects a RETURN
               install_send_answer $sp_id ""
               sleep 5
            }
            continue
         }

         -i $sp_id $ENTER_HOSTS {
            if {$hostcount >= [llength $admin_hosts]} {
               install_send_answer $sp_id "" "8"
            } else {
               set admin_host [lindex $admin_hosts $hostcount]
               incr hostcount
               install_send_answer $sp_id $admin_host
            }
            continue
         }

         -i $sp_id $ENTER_ADMIN_MAIL { 
            if {$CHECK_REPORT_EMAIL_TO == "none" } {
               install_send_answer $sp_id "${CHECK_USER}@${CHECK_DNS_DOMAINNAME}"
            } else {
               install_send_answer $sp_id $CHECK_REPORT_EMAIL_TO
            }
            continue
         }

         -i $sp_id $ACCEPT_CONFIGURATION {
            install_send_answer $sp_id $ANSWER_NO "10"
            continue
         }

         -i $sp_id $INSTALL_STARTUP_SCRIPT {
            install_send_answer $sp_id $ANSWER_NO "10"
            continue
         }

         #SMF startup is always disabled in testsuite
         -i $sp_id -- $SMF_IMPORT_SERVICE  {
            install_send_answer $sp_id $ANSWER_NO
            continue
         }

         # 
         # SGE 6.0 Dynamic Spooling 
         #
         -i $sp_id $CHOOSE_SPOOLING_METHOD {
            install_send_answer $sp_id $ts_config(spooling_method)
            continue
         }

         # 
         # SGE 6.0 Berkeley DB Spooling
         #
         -i $sp_id $DATABASE_LOCAL_SPOOLING {
            if {$ts_config(bdb_server) == "none"} {
               install_send_answer $sp_id $ANSWER_NO "9"
            } else {
               install_send_answer $sp_id $ANSWER_YES "9"
            }
            continue
         }

         -i $sp_id $ENTER_DATABASE_SERVER {
            install_send_answer $sp_id $ts_config(bdb_server)
            continue
         }

         -i $sp_id $DELETE_DB_SPOOL_DIR {
            install_send_answer $sp_id $ANSWER_YES
            continue
         }

         -i $sp_id $ENTER_SCHEDLUER_SETUP {
            install_send_answer $sp_id "" "9"
            continue
         }


         -i $sp_id $ENTER_DATABASE_SERVER_DIRECTORY {
            if {$ts_config(bdb_server) != "none"} {
               set spooldir [get_bdb_spooldir $ts_config(bdb_server) 0]
            } else {
               set spooldir [get_bdb_spooldir $ts_config(bdb_server) 1]
            }
            install_send_answer $sp_id $spooldir "11"
            continue
         }
   
         -i $sp_id $ENTER_DATABASE_DIRECTORY_LOCAL_SPOOLING {
            set spooldir [get_bdb_spooldir $ts_config(master_host) 0]
            install_send_answer $sp_id $spooldir "12"
            continue
         }

         -i $sp_id $DATABASE_DIR_NOT_ON_LOCAL_FS {
            ts_log_warning "configured database directory not on y local disk\nPlease run testsuite setup and configure Berkeley DB server and/or directory"
            close_spawn_process $id
            return
         }

         -i $sp_id $STARTUP_RPC_SERVER {
            install_send_answer $sp_id ""
            continue
         }

         -i $sp_id $DONT_KNOW_HOW_TO_TEST_FOR_LOCAL_FS {
            ts_log_warning "not yet ported for this platform"
            close_spawn_process $id
            return
         }

         #
         # adding a shdowhost to the list of admin hosts,
         # during qmaster install. currently no shadowhost will be added
         #
         -i $sp_id $ADD_SHADOWHOST_ASK {
            install_send_answer $sp_id "" "13"
            continue
         }

         -i $sp_id $ADD_SHADOWHOST_FROM_FILE_ASK {
            install_send_answer $sp_id "" "14"
            continue
         }

         -i $sp_id $ENTER_HOSTS {
            install_send_answer $sp_id "" "15"
            continue
         }

         #
         # end SGE 6.0 Berkeley DB Spooling
         #

         -i $sp_id "More" {
            ts_log_newline FINER ; ts_log_finer "-->testsuite: sending >space<"
            ts_send $sp_id " "
            continue
         }

         #  This is for More license output on darwin
         -i $sp_id "LICENSE ??%" {
            set found_darwin_more 1
            ts_log_newline FINER ; ts_log_finer "-->testsuite: sending >space< (darwin)"
            ts_send $sp_id " "
            continue
         }

         # Also for darwin: First "more" will print file name, second only percentage of file
         -i $sp_id "\[0-9\]%" {
            if {$found_darwin_more} {
               ts_log_newline FINER ; ts_log_finer "-->testsuite: sending >space< (darwin)"
               ts_send $sp_id " "
            }
            continue
         }

         -i $sp_id "Error:" {
            ts_log_warning "$expect_out(0,string)"
            close_spawn_process $id
            return
         }

         -i $sp_id -- $NOT_COMPILED_IN_SECURE_MODE {
            ts_log_warning "sge_qmaster binary is not compiled in secure mode"
            close_spawn_process $id
            return
         }

         -i $sp_id "ommand failed*\n" {
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
            ts_log_severe "$expect_out(0,string)"
            continue
         }
 
         -i $sp_id $USING_GID_RANGE_HIT_RETURN {
            install_send_answer $sp_id "" "17"
            continue
         }

         -i $sp_id $HIT_RETURN_TO_CONTINUE {
            install_send_answer $sp_id "" "18"
            continue
         }

         -i $sp_id $CURRENT_GRID_ROOT_DIRECTORY {
            install_send_answer $sp_id "" "19"
            continue
         }

         -i $sp_id $CELL_NAME_FOR_QMASTER {
            install_send_answer $sp_id $ts_config(cell)
            continue
         }

         -i $sp_id $GET_COMM_SETTINGS {
            install_send_answer $sp_id "" "19a"
            continue
         }

         -i $sp_id $CHANGE_PORT_QUESTION {
            install_send_answer $sp_id "" "19b"
            continue
         }

         -i $sp_id $WE_CONFIGURE_WITH_X_SETTINGS {
            install_send_answer $sp_id "" "20"
            continue
         }

         -i $sp_id "BINARY CODE LICENSE" {
            ts_send $sp_id "q"
            continue
         }

         -i $sp_id $LICENSE_AGREEMENT { 
            install_send_answer $sp_id $ANSWER_YES
            continue
         }

         -i $sp_id $CSP_COPY_CERTS {
            # On windows hosts, rcp / scp doesn't work.
            # So if we have windows hosts in the cluster, testsuite has to copy the certificates itself
            if {$have_windows_host} {
               install_send_answer $sp_id $ANSWER_NO "14"
            } else {
               install_send_answer $sp_id $ANSWER_YES "14"
            }
            continue
         }
         -i $sp_id $CSP_COPY_CMD {
            install_send_answer $sp_id $ANSWER_YES "15"
            continue
         }
         -i $sp_id $CSP_COPY_FAILED {
            ts_log_config "We received a failure during copy of certificates. This appears, when the\nrcp/scp command fails!"
            continue
         }
         -i $sp_id $CSP_COPY_RSH_FAILED {
            ts_log_config "We received a rsh/ssh failure. This error happends, if the rsh/ssh connection\nto any execution host was not possible, due to the missing permissions for user\nroot to connect via rsh/ssh without entering a password. This warning shows,\nthat the tested error handling code is working. To prevent this warning make\nsure the you qmaster host allows rsh/ssh connction for root without asking for\na password." 
            continue
         }
         -i $sp_id default {
            ts_log_warning "undefined behaviour: $expect_out(buffer)"
            close_spawn_process $id
            return
         }
      } ;# expect
   } ;# while

   # close the connection to inst_sge
   log_user 0
   close_spawn_process $id
}

