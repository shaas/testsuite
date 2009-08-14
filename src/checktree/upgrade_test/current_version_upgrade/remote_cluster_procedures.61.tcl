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
   puts ">>> check that execd has execd_local_spool_dir"
   get_config econf $test_host
   if {[info exists econf(execd_spool_dir)]} {
      set spooldir [get_local_spool_dir $test_host "execd" 0]
      if {$spooldir != $econf(execd_spool_dir)} {
         ts_log_severe "$test_host execd spool dir \"$econf(execd_spool_dir)\" does not match expected spool dir \"$spooldir\"!"
      } else {
         puts ">>> $test_host execd has local spool dir: $econf(execd_spool_dir)"      
      }
   } else {
      # we have to create a local spool dir for this host
      puts ">>> create local spool dir for execd host \"$test_host\" ..."

      # we need root access for starting up execd ...
      if {[have_root_passwd] == -1} {
         set_root_passwd
      }
      set spooldir [get_local_spool_dir $test_host "execd" 1]
      set econf(execd_spool_dir) $spooldir
      set_config econf $test_host
      soft_execd_shutdown $test_host
      startup_execd $test_host
      wait_for_load_from_all_queues 60
      get_config econf $test_host
      if {[info exists econf(execd_spool_dir)]} {
         if {$spooldir != $econf(execd_spool_dir)} {
            ts_log_severe "created \"$test_host\" execd spool dir \"$econf(execd_spool_dir)\" does not match expected spool dir \"$spooldir\"!"
         } else {
            puts ">>> created spool dir for \"$test_host\" execd: $econf(execd_spool_dir)"      
         }
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


