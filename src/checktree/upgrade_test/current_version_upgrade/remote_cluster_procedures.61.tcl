####################################################################################
# This procedures are for the remote cluster started by current_version_upgrade test
# NOTICE: errors are reported back to calling testsuite
####################################################################################

#****** remote_cluster_procedures.61/cur_version_upgrade_test_create_additional_settings() ******
#  NAME
#     cur_version_upgrade_test_create_additional_settings() -- TS RPC function
#
#  SYNOPSIS
#     cur_version_upgrade_test_create_additional_settings { } 
#
#  FUNCTION
#     This procedure can be started at testsuite startup by using the testsuite
#     execute_func command line parameter. It is used by the current_version_upgrade
#     test to create additional test settings before upgrading the cluster.
#
#  INPUTS
#     NONE
#
#  RESULT
#     String containing parameter=value lines
#
#        current return values:
#                               job_id=VALUE
#
#*******************************************************************************
proc cur_version_upgrade_test_create_additional_settings {} {
   global ts_config

   set test_host $ts_config(master_host)

   # create subordinate queues
   puts ">>> create subordinate queues"
   # Add queues
   set queueA(load_thresholds)  "np_load_avg=10"
   add_queue "queueA.q" $test_host queueA
   set queueB(load_thresholds)  "np_load_avg=10"
   add_queue "queueB.q" $test_host queueB
   # Make queues subordinate to each other
   set queueA(subordinate_list) "queueB.q"
   set_queue "queueA.q" $test_host queueA
   set queueB(subordinate_list) "queueA.q"
   set_queue "queueB.q" $test_host queueB
   
   # check and assure that execd has execd_local_spool_dir
   puts ">>> check if execd has execd_local_spool_dir"
   get_config econf $test_host
   set spooldir [get_local_spool_dir $test_host "execd" 0]
   if {[info exists econf(execd_spool_dir)]} {
      if {$spooldir != $econf(execd_spool_dir)} {
         ts_log_severe "$test_host execd spool dir \"$econf(execd_spool_dir)\" does not match expected spool dir \"$spooldir\"!"
      } else {
         puts ">>> $test_host execd has local spool dir: $econf(execd_spool_dir)"      
      }
   } else {
      if {$spooldir == ""} {
         puts ">>> no local spool dir configured for execd host \"$test_host\""
      } else {
         ts_log_severe "execd host \"$test_host\" should have local spool dir \"$spooldir\""
      }
   }

   # add resource quotas
   puts ">>> add resource quotas"
   set rqs_data(resource_quotas,description) "TS generated quotas by current_version_upgrade test"
   set rqs_data(resource_quotas,enabled)     "TRUE"
   set rqs_data(resource_quotas,limit)       "{to slots=2}"
   add_rqs rqs_data

   # submit a test job to the test host and return the job id
   set job_id [submit_job "-l h=$test_host $ts_config(product_root)/examples/jobs/sleeper.sh 2"]
   puts ">>> submitted job $job_id"
   set ret_val(job_id) $job_id
   wait_for_end_of_all_jobs

   # we have to give return values back as a string -> report parsable results 
   set return_string ""
   foreach param [array names ret_val] {
      append return_string "$param=$ret_val($param)\n"
   }
   return $return_string
}

proc cur_version_upgrade_test_verify_additional_settings { test_job_id expected_version orig_config_file install_mode features_setup spooling_method } {
   global ts_config

#   install_mode:      standard, csp
#   features_setup:    no_jmx_no_ijs, jmx, ijs
#   spooling_method:   classic_NFS, classic_local, bdb_NFS4, bdb_local, bdb_rpc

   # we need root access for starting up execd ...
   if {[have_root_passwd] == -1} {
      set_root_passwd
   }

   set error_text ""

   set test_host $ts_config(master_host)

   puts ">>> startup all execds ..."
   foreach ex_host $ts_config(execd_nodes) {
      startup_execd $ex_host
   }

   puts ">>> await load from all queues ..."
   wait_for_load_from_all_queues 60

   puts ">>> verify settings ..."

   # Check that execd on master host has a local spool dir
   get_config econf $test_host
   set spooldir [get_local_spool_dir $test_host "execd" 0]
   if {[info exists econf(execd_spool_dir)]} {
      if {$spooldir != $econf(execd_spool_dir)} {a
         append error_text "$test_host execd spool dir \"$econf(execd_spool_dir)\" does not match expected spool dir \"$spooldir\"!\n"
      } else {
         puts ">>> $test_host execd has local spool dir: $econf(execd_spool_dir)"      
      }
   } else {
      if {$spooldir == ""} {
         puts ">>> no local spool dir configured for execd host \"$test_host\""
      } else {
         append error_text "execd host \"$test_host\" should have local spool dir \"$spooldir\"!\n"
      }
   }


   # check version of updated cluster 
   get_version_info version_array
   puts ">>> cluster version is $version_array(detected_version)"
   if {$version_array(detected_version) != $expected_version} {
      append error_text "Cluster version \"$version_array(detected_version)\" does not match expected version \"$expected_version\"\n"
   }   

   # submit a test job 
   set job_id [submit_job "-l h=$test_host $ts_config(product_root)/examples/jobs/sleeper.sh 2"]
   puts ">>> submitted job $job_id"
   if {$job_id != 2000} {
      append error_text "expected that next job id is 2000, but it is $job_id\n"
   }
   wait_for_end_of_all_jobs
   get_qacct $job_id qacct_info
   ts_log_fine [format_array qacct_info]
   if {$qacct_info(exit_status) != 0} {
      append error_text "exit status of job $job_id is not 0\n"
   }
   
   # verify that qacct -j $add_settings_result(job_id) is displayed correctly (runtime 2 ???)
   puts ">>> check qacct for job $test_job_id"
   get_qacct $test_job_id qacct_info
   ts_log_fine [format_array qacct_info]
   if {$qacct_info(exit_status) != 0} {
      append error_text "exit status of job $test_job_id is not 0\n"
   }


   # check the settings done by cur_version_upgrade_test_create_additional_settings() procedure
   get_rqs rqs_data
   if {$rqs_data(resource_quotas,description) != "TS generated quotas by current_version_upgrade test"} {
      append error_text "expected resource_quotas description set to \"TS generated quotas by current_version_upgrade test\" but it is \"$rqs_data(resource_quotas,description)\"\n"
   }
 
   if {$rqs_data(resource_quotas,enabled) != "TRUE" } {
      append error_text "expected resource_quotas enabled set to \"TRUE\" but it is \"$rqs_data(resource_quotas,enabled)\"\n"

   }

   if {$rqs_data(resource_quotas,limit) != "{to slots=2}" } {
      append error_text "expected resource_quotas limit set to \"{to slots=2}\" but it is \"$rqs_data(resource_quotas,limit)\"\n"
   }

   ts_log_fine [format_array rqs_data]

   get_queue "queueA.q" queueA_array

   if {![string match "*${test_host}*=queueB.q*" $queueA_array(subordinate_list)]} {
      append error_text "expected queueA.q to have subordinate_list \"queueB.q\", but it is set to \"$queueA_array(subordinate_list)\"\n"
      ts_log_fine [format_array queueA_array]
   }

   get_queue "queueB.q" queueB_array
   if {![string match "*${test_host}*=queueA.q*" $queueB_array(subordinate_list)]} {
      append error_text "expected queueB.q to have subordinate_list \"queueA.q\", but it is set to \"$queueB_array(subordinate_list)\"\n"
      ts_log_fine [format_array queueB_array]
   }

   puts ">>> check global config"
   read_array_from_file $orig_config_file "global_config" orig_global_config
   get_config cur_global_config "global"
   cur_version_upgrade_test_compare_arrays "global config" error_text orig_global_config cur_global_config $features_setup $spooling_method
   

   puts ">>> check qmaster config"
   read_array_from_file $orig_config_file "qmaster_config" orig_qmaster_config
   get_config cur_qmaster_config $ts_config(master_host)
   cur_version_upgrade_test_compare_arrays "qmaster config" error_text orig_qmaster_config cur_qmaster_config $features_setup $spooling_method


   set report_error ""
   if {$error_text != ""} {
      append report_error "Found errors for following settings:\n"
      append report_error "   install_mode:    \"$install_mode\"\n"
      append report_error "   features_setup:  \"$features_setup\"\n"
      append report_error "   spooling_method: \"$spooling_method\"\n"
      append report_error $error_text
      ts_log_severe $report_error
   }
   return $report_error
}

proc cur_version_upgrade_test_compare_arrays { name eText orig cur features_setup spooling_method } {
   upvar $eText error_text
   upvar $orig orig_array_not_modified
   upvar $cur  cur_array
   global ts_config

   set errors ""

   # remove some settings
   set remove_params {}
   switch -exact $features_setup {
      "no_jmx_no_ijs" {
         if {$name == "global config"} {
            # global configs
            lappend remove_params "additional_jvm_args"
            lappend remove_params "libjvm_path"
            lappend remove_params "qlogin_command"
            lappend remove_params "rlogin_command"
            lappend remove_params "rlogin_daemon"
            lappend remove_params "rsh_command"
            lappend remove_params "rsh_daemon"
         } else {
            # local configs
            lappend remove_params "additional_jvm_args"
            lappend remove_params "libjvm_path"
         }
      }
      "jmx" {
         if {$name == "global config"} {
            # global configs
            lappend remove_params "qlogin_command"
            lappend remove_params "rlogin_command"
            lappend remove_params "rlogin_daemon"
            lappend remove_params "rsh_command"
            lappend remove_params "rsh_daemon"
         } else {
            # local configs
         }
      }
      "ijs" {
         if {$name == "global config"} {
            # global configs
            lappend remove_params "additional_jvm_args"
            lappend remove_params "libjvm_path"
            lappend remove_params "qlogin_command"
            lappend remove_params "rlogin_command"
            lappend remove_params "rlogin_daemon"
            lappend remove_params "rsh_command"
            lappend remove_params "rsh_daemon"
         } else {
            # local configs
            lappend remove_params "additional_jvm_args"
            lappend remove_params "libjvm_path"
            lappend remove_params "qlogin_command"
            lappend remove_params "qlogin_daemon"
            lappend remove_params "rlogin_command"
            lappend remove_params "rlogin_daemon"
            lappend remove_params "rsh_command"
            lappend remove_params "rsh_command"
         }
      }
      default {
         append errors "unexpected feature setup \"$features_setup\""
      }
   }

   switch -exact $spooling_method {
      "classic_NFS" {
         if {$name == "global config"} {
         } else {
            lappend remove_params "execd_spool_dir"
         } 
      }
      "classic_local" {
      }
      "bdb_NFS4" {
      }
      "bdb_local" {
      }
      "bdb_rpc" {
      }
      default {
         append errors "unexpected feature setup \"$spooling_method\""
      }
   }
 
   # only copy needed settings from original config
   foreach elem [array names orig_array_not_modified] {
      if {[lsearch -exact $remove_params $elem] != -1} {
         ts_log_fine "removeing param \"$elem\" from expected entries in \"$name\""
         continue
      }
      set orig_array($elem) $orig_array_not_modified($elem)
   }


   # correct some settings
   switch -exact $features_setup {
      "no_jmx_no_ijs" {
         if {$name != "global config"} {
            set orig_array(qlogin_daemon) "/usr/sbin/in.telnetd"
            set orig_array(rlogin_daemon) "/usr/sbin/in.rlogind"
         }
         if {$name == "global config"} {
            set orig_array(qlogin_daemon)  "/usr/sbin/in.telnetd"
            set orig_array(rlogin_daemon)  "/usr/sbin/in.rlogind"
            set orig_array(qlogin_command) "telnet"
         }
      }

      "jmx" {
         if {$name != "global config"} {
            set orig_array(qlogin_daemon) "/usr/sbin/in.telnetd"
            set orig_array(rlogin_daemon) "/usr/sbin/in.rlogind"
         }
         if {$name == "global config"} {
            if {![info exists orig_array(additional_jvm_args)]} {
               set orig_array(additional_jvm_args) "-Xmx256m"
            }
            if {![info exists orig_array(libjvm_path)]} {
               set orig_array(libjvm_path) [get_jvm_lib_path_for_host $ts_config(qmaster_host) "1.5+"]
            }
            set orig_array(qlogin_daemon)  "/usr/sbin/in.telnetd"
            set orig_array(rlogin_daemon)  "/usr/sbin/in.rlogind"
            set orig_array(qlogin_command) "telnet"
         }
      }
      "ijs" {
         if {$name == "global config"} {
            set orig_array(qlogin_command)  "builtin"
            set orig_array(qlogin_daemon)   "builtin"
            set orig_array(rlogin_command)  "builtin"
            set orig_array(rlogin_daemon)   "builtin"
            set orig_array(rsh_command)     "builtin"
            set orig_array(rsh_daemon)      "builtin"
         }
      }
      default {
         append errors "unexpected feature setup \"$features_setup\""
      }
   }

   switch -exact $spooling_method {
      "classic_NFS" {
         if {$name == "global config"} {
            set orig_array(execd_spool_dir) "$ts_config(product_root)/$ts_config(cell)/spool"
         }
      }
      "classic_local" {
      }
      "bdb_NFS4" {
      }
      "bdb_local" {
      }
      "bdb_rpc" {
      }
      default {
         append errors "unexpected feature setup \"$spooling_method\""
      }
   }

   set len_orig [llength [array names orig_array]]
   set len_cur  [llength [array names cur_array ]]

   if {$len_orig != $len_cur} {
      append errors "Expected $len_orig entries for \"$name\", but got $len_cur after update!\n"
   }

   # check for missing elements
   foreach elem [array names orig_array] {
      if {![info exists cur_array($elem)]} {
         append errors "Expected entry \"$elem\" for \"$name\" not found after update!\n"
      } else {
         if {$cur_array($elem) != $orig_array($elem)} {
            append errors "Entry value for \"$elem\" in \"$name\" is set to \"$cur_array($elem)\" after update, but it should be set to \"$orig_array($elem)\" (missing check)\n"
         }
      }
   }

   # check for additional elements
   foreach elem [array names cur_array] {
      if {![info exists orig_array($elem)]} {
         append errors "Not expected entry \"$elem\" for \"$name\" after update!\n"
      } else {
         if {$cur_array($elem) != $orig_array($elem)} {
            append errors "Entry value for \"$elem\" in \"$name\" is set to \"$cur_array($elem)\" after update, but it should be set to \"$orig_array($elem)\" (additional check)\n"
         }
      }
   }
 
   if {$errors != ""} {
      append error_text ""
      append error_text "Got following ERRORS for object \"$name\":\n"
#      append errors "\n"
#      append errors "feature: \"$features_setup\" - spooling: \"$spooling_method\""
#      append errors "\n"
#      append errors "Expected settings for \"$name\":\n"
#      append errors [format_array orig_array]
#      append errors "\n"
#      append errors "Settings after upgrade for \"$name\":\n"
#      append errors [format_array cur_array]
#      append errors "\n"
   }

   append error_text $errors
}

