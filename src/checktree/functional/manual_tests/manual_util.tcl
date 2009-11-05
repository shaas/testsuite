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

proc manual_select_hosts {host_set {user_selection false}} {
   global ts_config ts_host_config

   set hosts ""
   switch -- $host_set {
      master {
         set hosts $ts_config(master_host)
      }
      cluster {
         set hosts [host_conf_get_cluster_hosts]
      }
      compile {
         foreach host $ts_host_config(hostlist) {
            if {[host_conf_is_compile_host $host]} {
               lappend hosts $host
            }
         }
      }
      supported {
         set hosts_arch [host_conf_get_arch_hosts [host_conf_get_archs \
                                                     $ts_host_config(hostlist)]]
         foreach host $hosts_arch {
            if {[host_conf_is_supported_host $host]} {
               lappend hosts $host
            }
         }
      }
   }

   if {$user_selection} {
      set name host_list
      set my_config($name) $hosts
      set my_config($name,desc) "The test will run on $host_set host(s). \
                                           \nAdjust the host list if necessary:"
      while {true} {
         set hosts [config_generic 0 $name my_config "" host 0 0]
         if {$hosts == -1} {
            set hosts ""
         }
         if {$hosts == ""} {
            puts -nonewline "No host selected. This will only generate the report \
    of completed tests. Is it okay (y), or do you want to choose any hosts (n)?"
         } else {
            puts -nonewline "You have choosed these hosts: $hosts. \
                                                    Is the list correct? (y/n) "
         }
         set result [wait_for_enter 1]
         if {$result == "y"} {
            break
         }
      }
   }

   # TODO: if windows host is available, ask for the password!!!

   return $hosts
}

#****** manual_util/sge_check_host_connection() ********************************
#  NAME
#     sge_check_host_connection() -- check the connection to host
#
#  SYNOPSIS
#     sge_check_host_connection { report_var }
#
#  FUNCTION
#     Check the connection to the host and write the results to the report array.
#
#  INPUTS
#     report_var - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_check_host_connection {report_var} {
   global CHECK_USER
   upvar $report_var report

   set id [register_test check_connection report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   set msg "hallo"
   set output [start_remote_prog $host $CHECK_USER "echo" $msg prg_exit_state 10]
   # TODO: why the connection test sometimes failed first time???
   if {[string trim $output] != $msg} {
      set output [start_remote_prog $host $CHECK_USER "echo" $msg prg_exit_state 10]
   }

   if {[string trim $output] == $msg} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id value $output
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_check_packages() ***************************************
#  NAME
#     sge_check_packages() -- check if the packages are installed
#
#  SYNOPSIS
#     sge_check_packages { report_var }
#
#  FUNCTION
#     Check if the packages for the architecture of host are installed and write
#     the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_check_packages {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   set id [register_test check_binaries report curr_task_nr]

   set host [get_test_host report $curr_task_nr]
   set host_arch [host_conf_get_arch $host]
   set arch [resolve_arch $host]

   set result false
   if {$host_arch != $arch} {
      switch -- $host_arch {
         "lx26-amd64" {
            if {"$arch" == "lx24-amd64"} {
               test_report report $curr_task_nr $id value "Using binaries $arch."
               set result true
            }
         }
         "lx26-x86" {
            if {"$arch" == "lx24-x86"} {
               test_report report $curr_task_nr $id value "Using binaries $arch."
               set result true
            }
         }
      }
      if {!$result} {
         test_report report $curr_task_nr $id value "Wrong architecture setup. \
                  Testsuite configuration: $host_arch x sge resolves as: $arch."
         test_report report $curr_task_nr $id result [get_result_skipped]
         return false
      }
   }

   if {[file isdirectory $ts_config(product_root)/bin/$arch] == 0} {
      test_report report $curr_task_nr $id value "Packages for arch $arch not installed!"
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   } else {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   }
}

#****** manual_util/sge_check_version() ****************************************
#  NAME
#     sge_check_version() -- check the gridengine system version
#
#  SYNOPSIS
#     sge_check_version { report_var }
#
#  FUNCTION
#     Check the gridengine system version by calling ./inst_sge -v and write
#     the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_check_version {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   if { $ts_config(gridengine_version) < 61 } {
      ts_log_finest "sge_check_version test not supported."
      return true
   }
   set expected_version [ge_get_gridengine_version]

   set id [register_test check_version report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   set result [string trim \
              [start_remote_prog $host $CHECK_USER "./inst_sge" \
               "-v" prg_exit_state 60 0 $ts_config(product_root)]]
   test_report report $curr_task_nr $id value $result

   if {$prg_exit_state == 0} {
      if {[string match "Software version: $expected_version" $result] == 1} {
         test_report report $curr_task_nr $id result [get_result_ok]
         return true
      } else {
         test_report report $curr_task_nr $id result [get_result_failed]
         return false
      }
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_check_system_running() *********************************
#  NAME
#     sge_check_system_running() -- check if the gridengine cluster is running
#
#  SYNOPSIS
#     sge_check_system_running { report_var }
#
#  FUNCTION
#     Check if the gridengine cluster is running and write the results to the
#     report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_check_system_running {report_var} {
   global ts_config
   upvar $report_var report

   set id [register_test check_system_running report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Check if the system is running."
   set basic_qmaster_pid [get_qmaster_pid $ts_config(master_host)]
   if {$basic_qmaster_pid <= 0} {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "Qmaster is not running."
      return false
   }

   foreach ex_host $ts_config(execd_nodes) {
      set basic_execd_pid [get_execd_pid $ex_host]
      if {$basic_execd_pid <= 0} {
         test_report report $curr_task_nr $id result [get_result_failed]
         test_report report $curr_task_nr $id value "Execd on $ex_host is not running."
         return false
      }
   }

   set result [wait_for_load_from_all_queues 60]
   if { $result == 0 } {
      test_report report $curr_task_nr $id result [get_result_ok]
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "No load values from queue."
      return false
   }

   return true
}

#****** manual_util/sge_qconf_head() *******************************************
#  NAME
#     sge_qconf_head() -- check if the binaries report correct gridengine version
#
#  SYNOPSIS
#     sge_qconf_head { report_var }
#
#  FUNCTION
#     Check if the binaries report correct gridengine version and write the results
#     to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_qconf_head {report_var} {
   global CHECK_USER
   upvar $report_var report

   set expected_version [ge_get_gridengine_version]

   set id [register_test qconf_head report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Call qconf -help | head -1"
   set result [string trim \
              [start_sge_bin "qconf" "-help | head -1" $host $CHECK_USER]]
   test_report report $curr_task_nr $id value $result
   if {$prg_exit_state == 0} {
      if {[string match "* $expected_version*" $result] == 1} {
         test_report report $curr_task_nr $id result [get_result_ok]
         return true
      } else {
         test_report report $curr_task_nr $id result [get_result_failed]
         return false
      }
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_man() **************************************************
#  NAME
#     sge_man() -- check the man pages
#
#  SYNOPSIS
#     sge_man { report_var }
#
#  FUNCTION
#     Check the manual pages of qconf and write the results to the report array.
#     Support of interactive mode.
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#     check/check_is_interactive()
#
#*******************************************************************************
proc sge_man {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   set id [register_test man report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   # TODO: implement interactive mode
   if {[check_is_interactive]} {
      test_report report $curr_task_nr $id value "User check."
      puts -nonewline "Manual pages are okay? (y/n)"
      set result [wait_for_enter 1]
      if {$result == "y"} {
         test_report report $curr_task_nr $id result [get_result_ok]
         return true
      } else {
         test_report report $curr_task_nr $id result [get_result_failed]
         return false
      }
   } else {
      ts_log_fine "Call man qconf"
      set sid [open_remote_spawn_process $ts_config(master_host) $CHECK_USER "man" "qconf"]
      set sp_id [lindex $sid 1]
      set output ""
      set errors 0
      set start_time [clock clicks -milliseconds]
      while {1} {
         set curr_time [clock clicks -milliseconds]
         if {[expr ($curr_time - $start_time) / 1000.0] >= 20.0} {
            append output timeout
            break
         }
         expect {
            -i $sp_id "*More*" {
               ts_send $sp_id " "
               set output $output$expect_out(0,string)
               continue
            }
            -i $sp_id "*Standard input*" {
               ts_send $sp_id " "
               set output $output$expect_out(0,string)
               continue
            }
            -i $sp_id "*Manual page*" {
               ts_send $sp_id " "
               set output $output$expect_out(0,string)
               continue
            }
            -i $sp_id "*(END)*" {
               ts_send $sp_id "q"
               set output $output$expect_out(0,string)
               continue
            }
            -i $sp_id timeout {
               break
            }
            -i $sp_id eof {
               break
            }
            -i $sp_id "_start_mark_*\n" {
               ts_send $sp_id " "
               continue
            }
            -i $sp_id "_exit_status_" {
               break
            }
            -i $sp_id "*:" {
               ts_send $sp_id " "
               set output $output$expect_out(0,string)
               continue
            }
            -i $sp_id "$ts_config(results_dir)*" {
               continue
            }
            -i $sp_id "*$CHECK_USER*" {
               continue
            }
            -i $sp_id "*man_*.sh*" {
               continue
            }
            -i $sp_id "*done*" {
               continue
            }
            -i $sp_id "*$host*" {
               continue
            }
            -i $sp_id "*Reformatting page*" {
               continue
            }
            -i $sp_id "*No manual entry*" {
               set output $output$expect_out(0,string)
               incr errors 1
               continue
            }
             -i $sp_id "*\r" {
               ts_send $sp_id "\n"
               set output $output$expect_out(0,string)
               continue
            }
         }
      }
      close_spawn_process $sid 1 0
      if {$errors == 0} {
         set version ""
         set expected_version [ge_get_gridengine_version]
         foreach line [split $output "\n"] {
            if {[string first "Last change:" $line] >= 0} {
               set version "[lindex $line 1]"
               break
            }
            if {[string first "$expected_version " $line] >= 0} {
               set version $expected_version
               break
            }
         }
         if {$version == $expected_version} {
            set output "$line"
            set result [get_result_ok]
         } else {
            set output "$version doesn't fit the expected version [ge_get_gridengine_version]!"
            set result [get_result_failed]
         }
      } else {
         set result [get_result_failed]
      }
      test_report report $curr_task_nr $id value $output
      test_report report $curr_task_nr $id result $result
      return $result
   }
}

#****** manual_util/sge_qhost() ************************************************
#  NAME
#     sge_qhost() -- check if the cluster is running and load qhost info
#
#  SYNOPSIS
#     sge_qhost { report_var }
#
#  FUNCTION
#     Check if the cluster is running and load qhost info and write the results
#     to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_qhost {report_var} {
   global CHECK_USER
   upvar $report_var report

   set id [register_test qhost report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Call qhost"
   set result [start_sge_bin "qhost" "" $host $CHECK_USER]
   test_report report $curr_task_nr $id value $result
   if {$prg_exit_state == 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }

}

#****** manual_util/sge_schedd_conf() ******************************************
#  NAME
#     sge_schedd_conf() -- enable the scheduler job info messages
#
#  SYNOPSIS
#     sge_schedd_conf { report_var }
#
#  FUNCTION
#     Enable the scheduler job info messages and write the results to the report
#     array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_schedd_conf {report_var} {
   upvar $report_var report

   set id [register_test schedd_conf report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Enable the scheduler job info messages"
   set sched_conf(schedd_job_info) true
   set result [set_schedd_config sched_conf]
   unset sched_conf

   if {$result == 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }

}

#****** manual_util/sge_submit_job() *******************************************
#  NAME
#     sge_submit_job() -- check the job submission
#
#  SYNOPSIS
#     sge_submit_job { report_var }
#
#  FUNCTION
#     Check the job submission and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_submit_job {report_var} {
   global ts_config
   upvar $report_var report

   set id [register_test job_submit report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Test job submission"
   set job_id [submit_job "$ts_config(product_root)/examples/jobs/sleeper.sh"]
   if {$job_id <= 0} {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "Job submission failed."
      return false
   }

   set result [wait_for_jobstart $job_id "Sleeper" 60 1 1]
   if {$result != 0} {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "Job start failed."
      return false
   }

   set result [wait_for_jobend $job_id "Sleeper" 80 0]
   if {$result == 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "Job finish failed."
      return false
   }

}

#****** manual_util/sge_qstat() ************************************************
#  NAME
#     sge_qstat() -- check the qstat output
#
#  SYNOPSIS
#     sge_qstat { report_var }
#
#  FUNCTION
#     Check the qstat output and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_qstat {report_var} {
   global CHECK_USER
   upvar $report_var report

   set id [register_test qstat-f report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Call qstat -f"
   set result [start_sge_bin "qstat" "-f" $host $CHECK_USER]
   test_report report $curr_task_nr $id value $result
   if {$prg_exit_state == 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_job_deletion() *****************************************
#  NAME
#     sge_job_deletion() -- check the job deletion
#
#  SYNOPSIS
#     sge_job_deletion { report_var }
#
#  FUNCTION
#     Check the job deletion and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_job_deletion {report_var} {
   global ts_config
   upvar $report_var report

   set id [register_test job_delete report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Test job deletion"
   set job_id [submit_job "$ts_config(product_root)/examples/jobs/sleeper.sh"]
   after 2000
   set result [delete_job $job_id]
   if {$result == 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_qacct() ************************************************
#  NAME
#     sge_qacct() -- check the job accounting
#
#  SYNOPSIS
#     sge_qacct { report_var }
#
#  FUNCTION
#     Check the job accounting and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_qacct {report_var} {
   global ts_config
   upvar $report_var report

   set id [register_test qacct report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   set job_id [submit_job "$ts_config(product_root)/examples/jobs/sleeper.sh 10"]
   set result [wait_for_jobend $job_id "Sleeper" 80 0]

   ts_log_fine "Accounting for a job $job_id"
   set result [get_qacct $job_id qacct_info $ts_config(master_host)]
   if {$result == 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      set qacct_list ""
      foreach qacct_item [lsort -dictionary [array names qacct_info]] {
         append qacct_list "[format_fixed_width $qacct_item 20][string trim \
                                                    $qacct_info($qacct_item)]\n"
      }
      test_report report $curr_task_nr $id value $qacct_list
      return true
   } else {
      if {[info exists qacct_info]} {
         foreach qacct_item [lsort -dictionary [array names qacct_info]] {
            append qacct_list "[format_fixed_width $qacct_item 20][string trim \
                                                    $qacct_info($qacct_item)]\n"
         }
         test_report report $curr_task_nr $id value $qacct_list
      }
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }

}

#****** manual_util/sge_qsub_sync() ********************************************
#  NAME
#     sge_qsub_sync() -- check qsub waiting for a job finish
#
#  SYNOPSIS
#     sge_qsub_sync { report_var }
#
#  FUNCTION
#     Check qsub waiting for a job finish and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_qsub_sync {report_var} {
   global ts_config
   upvar $report_var report

   set id [register_test qsub_sync report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Test a qsub waiting for a job end"
   set job_id [submit_job "-sync y $ts_config(product_root)/examples/jobs/sleeper.sh 5"]
   if {$job_id > 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }

}

#****** manual_util/sge_mod_queue() ********************************************
#  NAME
#     sge_mod_queue() -- check the queue modification
#
#  SYNOPSIS
#     sge_mod_queue { report_var }
#
#  FUNCTION
#     Check the queue modification and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_mod_queue {report_var} {
   upvar $report_var report

   set id [register_test mod_queue report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Modify a queue attribute"
   set queue_conf(load_thresholds) "np_load_avg=7.0"
   set result [mod_queue all.q $host queue_conf]
   if {$result == 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }

}

#****** manual_util/sge_qmon() *************************************************
#  NAME
#     sge_qmon() -- check qmon
#
#  SYNOPSIS
#     sge_qmon { report_var }
#
#  FUNCTION
#     Check qmon and write the results to the report array.
#     Support of interactive mode.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#     check/check_is_interactive()
#
#*******************************************************************************
proc sge_qmon {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   set id [register_test qmon report curr_task_nr]

   set host [get_test_host report $curr_task_nr]
   set arch [resolve_arch $host]

   if {[string first "win" $arch] == 0} {
      test_report report $curr_task_nr $id result [get_result_skipped]
      return true
   }
   set qmon_bin "$ts_config(product_root)/bin/$arch/qmon"
   ts_log_fine "Start qmon"
   set sp_id [open_remote_spawn_process $host $CHECK_USER $qmon_bin ""]
   if {$sp_id == ""} {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
   after 5000
   if {[check_is_interactive]} {
      puts -nonewline "Qmon seems to be started properly. Click through the qmon, \
                       close it, and check if the test result is okay. (y/n)"
      set result [wait_for_enter 1]
      if {$result == "y"} {
         test_report report $curr_task_nr $id result [get_result_ok]
         return true
      } else {
         test_report report $curr_task_nr $id result [get_result_failed]
         return false
      }
      close_spawn_process $sp_id
   } else {
      after 3000
      set qmon_running false
      set qmon_process_string "qmon"
      set index_list [ps_grep $qmon_process_string $host ps_info]
      if {[string trim $index_list] != ""} {
         foreach elem $index_list {
            if {[string first $qmon_process_string $ps_info(string,$elem)] >= 0 && \
                          [is_pid_with_name_existing $host $ps_info(pid,$elem) \
                                                   $qmon_process_string] == 0} {
               set qmon_running true
            }
         }
      }
      # if $SGE_ROOT path is too long the running process is not necessarilly found
      # close the process and if it return success, report ok result
      set close_status [close_spawn_process $sp_id 1 0]
      if {$qmon_running || $close_status == -1} {
         test_report report $curr_task_nr $id result [get_result_ok]
         return true
      } else {
         test_report report $curr_task_nr $id value "Probably a display problem."
         test_report report $curr_task_nr $id result [get_result_failed]
         return false
      }
   }
}

#****** manual_util/sge_qsh() **************************************************
#  NAME
#     sge_qsh() -- check qsh functionality
#
#  SYNOPSIS
#     sge_qsh { report_var }
#
#  FUNCTION
#     Check qsh functionality and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_qsh {report_var} {
   global CHECK_USER
   upvar $report_var report

   set id [register_test qsh report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Test qsh"
   switch -glob [resolve_arch $host] {
      darwin* {
         set sge_conf(execd_params) "INHERIT_ENV=0,LIB_PATH=0"
         set_config sge_conf
         unset sge_conf
      }
      hp11 {
         set sge_conf(xterm) "/usr/contrib/bin/X11/xterm"
         set_config sge_conf $host
         unset sge_conf
      }
   }
   set job_id [submit_job "-- -bg red" 1 60 $host $CHECK_USER "" 1 "qsh"]
   if {$job_id > 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      delete_job $job_id 1
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_qrsh() *************************************************
#  NAME
#     sge_qrsh() -- check qrsh functionality
#
#  SYNOPSIS
#     sge_qrsh { report_var }
#
#  FUNCTION
#     Check qrsh functionality and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_qrsh {report_var} {
   global CHECK_USER ts_config
   upvar $report_var report

   set id [register_test qrsh report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Test qrsh"
   if { $ts_config(gridengine_version) <= 61} {
      switch -glob [resolve_arch $host] {
         hp11* -
         win* {
            test_report report $curr_task_nr $id result [get_result_skipped]
            return true
         }
      }
   }
   set job_id [submit_wait_type_job qrsh $host $CHECK_USER]
   if {$job_id > 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_qrsh_hostname() ****************************************
#  NAME
#     sge_qrsh_hostname() -- check qrsh hostname functionality
#
#  SYNOPSIS
#     sge_qrsh_hostname { report_var }
#
#  FUNCTION
#     Check qrsh hostname functionality and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_qrsh_hostname {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   set id [register_test qrsh_hostname report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Test qrsh hostname"

   set host_arch [resolve_arch $host]
   if {$ts_config(gridengine_version) < 61 && $host_arch == "hp11-64" } {
      set sge_conf(execd_params) "INHERIT_ENV=0"
      set_config sge_conf
      unset sge_conf
   }

   if {$ts_config(gridengine_version) <= 61 && $host_arch == "win32-x86" } {
      set user "root"
   } else {
      set user $CHECK_USER
   }

   set result [start_sge_bin qrsh hostname $host $user]
   set result [string trim $result]
   test_report report $curr_task_nr $id value [string trim $result]
   if {[qrsh_output_contains $result $host]} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      # here might be a problem with long hostname
      if {[string match ${host}.* $result] == 1} {
         test_report report $curr_task_nr $id result [get_result_ok]
         return true
      } else {
         test_report report $curr_task_nr $id result [get_result_failed]
         return false
      }
   }
}

#****** manual_util/sge_qlogin() ***********************************************
#  NAME
#     sge_qlogin() -- check qlogin functionality
#
#  SYNOPSIS
#     sge_qlogin { report_var }
#
#  FUNCTION
#     Check qlogin functionality and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_qlogin {report_var} {
   global CHECK_USER
   upvar $report_var report

   set id [register_test qlogin report curr_task_nr]

   set host [get_test_host report $curr_task_nr]
   set user $CHECK_USER

   ts_log_fine "Test qlogin"
   set job_id [submit_wait_type_job qlogin $host $user]
   if {$job_id > 0} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_online_usage() *****************************************
#  NAME
#     sge_online_usage() -- check the online usage of a job
#
#  SYNOPSIS
#     sge_online_usage { report_var }
#
#  FUNCTION
#     Check the online usage of a job and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_online_usage {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   set id [register_test online_usage report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   ts_log_fine "Test online usage"
   set job_id [submit_job "$ts_config(product_root)/examples/jobs/worker.sh"]
   if {$job_id < 0} {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "Job submission failed."
      return false
   }

   set job_start [wait_for_jobstart $job_id "worker.sh" 60 1 1]
   if {$job_start != 0} {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "Job start failed."
      return false
   }

   set host_arch [resolve_arch $host]
   set usage ""
   set basic_error 0
   set basic_status [get_result_failed]
   while true {
      set result [get_qstat_j_info $job_id qstat_j_info]
      if {$result == 1} {
         foreach item [array names qstat_j_info] {
            if {[string first "usage" $item] >= 0} {
               set usage $qstat_j_info($item)
               break
            }
         }
         if {$usage != ""} {
            # analyze the usage
            set usage_list [split $usage ","]
            foreach usage_value $usage_list {
               set usage_value [string trim $usage_value]
               switch -glob $usage_value {
                  cpu=* {
                     set cpu_value [string range $usage_value 4 end]
                  }
                  mem=* {
                     set mem_value [string range $usage_value 4 end]
                  }
                  io=* {
                     set io_value [string range $usage_value 3 end]
                  }
                  vmem=* {
                     set vmem_value [string range $usage_value 5 end]
                  }
                  maxvmem=* {
                     set maxvmem_value [string range $usage_value 8 end]
                  }
               }
            }
            if {$cpu_value == "00:00:00"} {
               # if no usage expected, leave the test
               switch -glob $host_arch {
                  aix* -
                  win* {
                     set usage "No usage expected.\n$usage"
                     set basic_status [get_result_ok]
                     break
                  }
                  hp11* -
                  darwin* {
                     if {$ts_config(gridengine_version) < 62} {
                        set usage "No usage expected.\n$usage"
                        set basic_status [get_result_ok]
                        break
                     }
                  }
               }
               if {"$mem_value" != "0.00000 GBs"} {
                  # cpu should be reported
                  set basic_status [get_result_failed]
                  break
               }
               after 1000
               ts_log_progress
               continue
            } else {
               set basic_status [get_result_ok]
               break
            }
         } else {
            after 1000
            continue
         }
         set qacct [get_qacct $job_id qacct_info $ts_config(master_host)]
         if {$qacct == 0} {
            # job already finished
            break
         }
      } else {
         if {$usage == ""} {
            set usage "$usage"
            incr basic_error 1
            break
         }
      }
   }

   if {$usage == ""} {
      set usage "No usage displayed."
      incr basic_error 1
   }

   delete_job $job_id 0 0 0

   test_report report $curr_task_nr $id value $usage
   if {$basic_error == 0} {
      test_report report $curr_task_nr $id result $basic_status
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_drmaa() ************************************************
#  NAME
#     sge_drmaa() -- perform a short DRMAA test
#
#  SYNOPSIS
#     sge_drmaa { report_var }
#
#  FUNCTION
#     Perform a short DRMAA test and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_drmaa {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   if { $ts_config(gridengine_version) < 61 } {
      ts_log_finest "basic_drmaa test not supported."
      return
   }

   if {$ts_config(source_dir) == "none"} {
      ts_log_config "source directory is set to \"none\" - cannot run test"
      return
   }

   set id [register_test drmaa report curr_task_nr]

   set host [get_test_host report $curr_task_nr]
   set host_arch [resolve_arch $host]

   if {[string first "win" $host_arch] == 0} {
      ts_log_finest "basic_drmaa test not supported."
      test_report report $curr_task_nr $id result [get_result_skipped]
      return
   }

   set arch_32 [manual_arch32_mapping $host_arch]
   if {"$arch_32" != ""} {
      lappend host_arch $arch_32
   }

   set err_tests 0
   set output ""
   foreach b_arch $host_arch {
      set err_count 0
      set skipped_count 0

      ts_log_fine "Perform a drmaa test with $b_arch binaries"
      append output "$b_arch:\n"
      set compile_arch [start_remote_prog $host $CHECK_USER \
                        $ts_config(source_dir)/scripts/compilearch "-c $b_arch"]
      set compile_arch [string trim $compile_arch]

      if {$compile_arch == ""} {
         set compile_arch [start_remote_prog $host $CHECK_USER \
                        $ts_config(source_dir)/scripts/compilearch "-b $b_arch"]
         set compile_arch [string trim $compile_arch]
      }
      if {$compile_arch == ""} {
         append output "Unknown compilearch! "
         incr err_count 1
      } else {
         set drmaa_bin $ts_config(source_dir)/$compile_arch/test_drmaa_perf
         if {[file isfile $drmaa_bin] != 1} {
            set drmaa_bin "/vol2/SW/$b_arch/bin/test_drmaa_perf"
            }
         if {[file isfile $drmaa_bin] != 1} {
            append output "$drmaa_bin not found! "
            #incr err_count 1
             incr skipped_count 1
         } else {
            # set the shared library variable
            set shared_lib_var [get_shared_lib_path_variable_name $b_arch]
            set env($shared_lib_var) $ts_config(product_root)/lib/$b_arch
            set result [start_remote_prog $host $CHECK_USER $drmaa_bin \
                                              "-jobs 2 -threads 2 -wait yes \
                       $ts_config(product_root)/examples/jobs/sleeper.sh 5" \
                                                 prg_exit_state 120 0 "" env]
            if {[string trim "$result"] == ""} {
               append output "No output! "
               incr err_count 1
            } else {
               append output "$result "
               if {$prg_exit_state != 0} {
                  incr err_count 1
               }
            }
         }
      }
      append output "\n"
      if {$err_count > 0} {
         incr err_tests 1
      }
      set err_count 0
   }

   if {$err_tests == 0} {
      if {$skipped_count == 0} {
         set result [get_result_ok]
      } else {
         set result [get_result_skipped]
      }
   } else {
      set result [get_result_failed]
   }
   test_report report $curr_task_nr $id value "$output"
   test_report report $curr_task_nr $id result $result
   return $result
}

#****** manual_util/sge_jdrmaa() ***********************************************
#  NAME
#     sge_jdrmaa() -- perform a short java DRMAA test
#
#  SYNOPSIS
#     sge_jdrmaa { report_var }
#
#  FUNCTION
#     Perform a short java DRMAA test and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_jdrmaa {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   set id [register_test jdrmaa report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   set host_arch [resolve_arch $host]
   # TODO: the path to the script is hard coded
   # in future we might compile the java drmaa test code and use it directly from
   # the gridengine source code directory
   set jdrmaa_bin "/vol2/SW/$host_arch/bin/test_java_drmaa_perf.sh"

   if {[file isfile $jdrmaa_bin] != 1} {
      test_report report $curr_task_nr $id result [get_result_skipped]
      test_report report $curr_task_nr $id value "$jdrmaa_bin not found!"
      return
   }

   ts_log_fine "Perform a jdrmaa test"
   set java_path [get_java_home_for_host $host 1.5+ 0]
   if {"$java_path" == ""} {
      set java_path [get_java_home_for_host $host 1.4]
   } else {
      if {$host_arch == "aix51" || $host_arch == "irix65"} {
         set java_path [get_java_home_for_host $host 1.4]
      }
   }
   switch -exact $host_arch {
      hp11-64 {
         set env(SHLIB_PATH) "$ts_config(product_root)/lib/hp11"
      }
   }
   set env(PATH) "$java_path/bin"
   set result [start_remote_prog $host $CHECK_USER $jdrmaa_bin "" prg_exit_state 900 0 "" env]
   test_report report $curr_task_nr $id value $result
   if {"$result" == ""} {
      test_report report $curr_task_nr $id result [get_result_failed]
      return
   }
   # TODO: adjust jdrmaa test to return !=0 exit status
   if {$prg_exit_state == 0} {
      if {[string first "Error" $result] >= 0 || [string first "Exception" $result] >= 0} {
         test_report report $curr_task_nr $id result [get_result_failed]
         return false
      }
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_jsv() **************************************************
#  NAME
#     sge_jsv() -- check server jsv functionality
#
#  SYNOPSIS
#     sge_jsv { report_var }
#
#  FUNCTION
#     Check server jsv functionality and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_jsv {report_var} {
   global ts_config
   upvar $report_var report

   set expected_version [ge_get_gridengine_version]

   if {$expected_version <= "6.2u2"} {
      ts_log_finest "basic_jsv test not supported."
      return true
   }

   set id [register_test jsv report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   set jsv_bin $ts_config(product_root)/util/resources/jsv/jsv.sh

   if {![file isfile $jsv_bin]} {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "File $jsv_bin not found!"
      return false
   }

   ts_log_fine "Test server JSV functionality"
   set jsv_conf(jsv_url) $jsv_bin
   set_config jsv_conf

   set job_id [submit_job "-b y sleep 1" 0]
   # revert jsv setup
   set jsv_conf(jsv_url) none
   set_config jsv_conf

   if {$job_id == -38} {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      return false
   }
}

#****** manual_util/sge_qmaster_log() ******************************************
#  NAME
#     sge_qmaster_log() -- check the qmaster log file
#
#  SYNOPSIS
#     sge_qmaster_log { report_var }
#
#  FUNCTION
#     Check the qmaster log file and write the results to the report array.
#     Support of interactive mode.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#     check/check_is_interactive()
#
#*******************************************************************************
proc sge_qmaster_log {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   set id [register_test qmaster_log report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   set output [start_remote_prog $ts_config(master_host) $CHECK_USER "cat" \
                                             "[get_qmaster_spool_dir]/messages"]
   test_report report $curr_task_nr $id value $output

   set ignore_errors ""
   lappend ignore_errors "*|E|error opening file * for reading: No such file or directory"
   lappend ignore_errors "*|E|adminhost * already exists"
   lappend ignore_errors "*|E|There are no jobs registered"

   if {$prg_exit_state == 0} {
      if {[check_is_interactive]} {
         puts $output\n
         puts -nonewline "Qmaster log is okay? (y/n)"
         set result [wait_for_enter 1]
         if {$result == "y"} {
            set result true

         } else {
            set result false
         }
      } else {
         set result true
         foreach line [split $output "\n"] {
            set line [string trim $line]
            if {[string first "|C|" $line] >= 0} {
               set result false
               break
            }
            if {[string first "|E|" $line] >= 0} {
               set is_error true
               foreach err $ignore_errors {
                  if {[string match "$err" "$line"] == 1} {
                     set is_error false
                     break
                  }
               }
               if {$is_error} {
                  set result false
                  break
               }
            }
         }
      }
   } else {
      set result false
   }
   if {$result} {
      test_report report $curr_task_nr $id result [get_result_ok]
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
   }
   return $result
}

#****** manual_util/sge_reject_other_binaries() ********************************
#  NAME
#     sge_reject_other_binaries() -- verify other binaries are rejected by qmaster
#
#  SYNOPSIS
#     sge_reject_other_binaries { report_var }
#
#  FUNCTION
#     Verify other binaries are rejected by qmaster and do not crash qmaster
#     and write the results to the report array.
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_reject_other_binaries {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   set id [register_test reject_binaries report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   set host_arch [resolve_arch $host]
   # TODO: the path to the script is hard coded
   # for the upgrade test we will have packages setup, then we can take
   # the binaries from these packages
   set alien_bin "/gridware/InhouseSystems/prod612/bin/$host_arch/qsub"
#   set alien_bin "/cod_home/ap199581/space/sge61/bin/$host_arch/qsub"

   if {![file isfile $alien_bin]} {
      ts_log_config "File $alien_bin not found!"
      test_report report $curr_task_nr $id result [get_result_skipped]
      test_report report $curr_task_nr $id value "File $alien_bin not found"
      return true
   }

   set args "$ts_config(product_root)/examples/jobs/sleeper.sh"
   set output [start_remote_prog $host $CHECK_USER $alien_bin $args]
   set messages(0) "*[translate_macro MSG_JOB_SUBMITJOB_US "*" "*"]*"
   set ret [handle_sge_errors "submit_job" "$alien_bin $args" $output messages 0]
   if {$ret == 0} {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "$alien_bin $args should be rejected!"
      return false
   }

   if {[is_qmaster_alive $ts_config(master_host) [get_qmaster_spool_dir]] } {
      test_report report $curr_task_nr $id result [get_result_ok]
      return true
   } else {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "Qmaster crashed after \
                                          submitting a job with wrong binaries!"
      return false
   }
}

#****** manual_util/sge_check_auto_install_logs() ******************************
#  NAME
#     sge_check_auto_install_logs() -- check the auto installation logs
#
#  SYNOPSIS
#     sge_check_auto_install_logs { report_var }
#
#  FUNCTION
#     Check the auto installation logs located at $SGE_ROOT/$SGE_CELL/common/install_logs
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_check_auto_install_logs {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   set id [register_test check_logs report curr_task_nr]

   set host [get_test_host report $curr_task_nr]

   set log_files "$ts_config(product_root)/$ts_config(cell)/common/install_logs"
   set fs_host [fs_config_get_server_for_path $log_files 0]
   if {$fs_host == ""} {
      set fs_host $host
   }
   set output ""
   set files [start_remote_prog $fs_host $CHECK_USER "ls" "$log_files"]
   foreach f $files {
      if {[file isfile $log_files/$f] == 1} {
         set content [start_remote_prog $fs_host $CHECK_USER "cat" "$log_files/$f"]
         append output "$f\n[report_table_line 100]\n$content\n"
      }
   }
   if {$output == ""} {
      test_report report $curr_task_nr $id result [get_result_failed]
      test_report report $curr_task_nr $id value "No logs found in $log_files."
   } else {
      set failures "error failed critical denied"
      set result [get_result_ok]
      foreach line [split $output "\n"] {
         set line [string trim $line]
         foreach ff $failures {
            if {[string first "$ff" "$line"] >= 0} {
               set result [get_result_failed]
               break
            }
         }
         if {"$result" == [get_result_failed]} {
            break
         }
      }
      test_report report $curr_task_nr $id result $result
      test_report report $curr_task_nr $id value $output
   }

}

#****** manual_util/sge_check_win_gui() ****************************************
#  NAME
#     sge_check_win_gui() -- check the win gui job submission
#
#  SYNOPSIS
#     sge_check_win_gui { report_var }
#
#  FUNCTION
#     check the win gui job submission
#
#  INPUTS
#     report - the report object
#
#  SEE ALSO
#     report_procedures/get_test_host()
#
#*******************************************************************************
proc sge_check_win_gui {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   ts_log_fine "Check the win gui job submission"

   set id [register_test win_gui_job report curr_task_nr]

   set host [get_test_host report $curr_task_nr]
   set arch [resolve_arch $host]

#   set notepad "/dev/fs/C/WINDOWS/notepad.exe"
#   if {[check_is_interactive]} {
#      puts -nonewline "Enter the path to notepad.exe"
#      set notepad [wait_for_enter 1]
#   }

   set notepad "/dev/fs/C/WINDOWS/notepad.exe"
   while {true} {
      set is_remote [is_remote_file $host $CHECK_USER $notepad]
      if {$is_remote} {
         break
      }
      if {[check_is_interactive]} {
         puts -nonewline "Enter the path to win gui job, \
                                         or \"exit\" for skipping the test: "
         set notepad [wait_for_enter 1]
         if {$notepad == "exit"} {
            test_report report $curr_task_nr $id value "User decision."
            test_report report $curr_task_nr $id result [get_result_skipped]
            return true
         }
      } else {
         test_report report $curr_task_nr $id value "$notepad not found."
         test_report report $curr_task_nr $id result [get_result_skipped]
         return true
      }
   }

   if {$ts_config(gridengine_version) >= 61} {
      set args "-l display_win_gui=true"
   } else {
      set args "-v SGE_GUI_MODE=TRUE -l a=$arch"
   }
   append args " -b yes -shell no $notepad"
   set job_id [submit_job $args 1 60 $host]

   trigger_scheduling
   after 1000

   if {$job_id < 0} {
      test_report report $curr_task_nr $id value "GUI job submission failed."
      set result [get_result_failed]
   } else {
      if {[check_is_interactive]} {
         puts -nonewline "win_gui_job was submitted. Open vncviewer ${host}:0, \
              log in as user $CHECK_USER, and check if the notepad is running. \
                                                Then close the notepad window. \
                                                       Is the test okay? (y/n) "
         set result [wait_for_enter 1]
         if {$result == "y"} {
            set result [get_result_ok]
         } else {
            set result [get_result_failed]
         }
      } else {
         after 4000
         delete_job $job_id
         test_report report $curr_task_nr $id value "win_gui_job seems to be \
                              working. Use interactive mode for complete check."
         set result [get_result_ok]
      }
   }
   if {$result == [get_result_ok]} {
      after 2000
      set output [get_qacct $job_id qacct_info $ts_config(master_host)]
      if {$output == 0} {
         set qacct_list ""
         foreach qacct_item [lsort -dictionary [array names qacct_info]] {
            append qacct_list "[format_fixed_width $qacct_item 20][string trim \
                                                    $qacct_info($qacct_item)]\n"
         }
         test_report report $curr_task_nr $id value $qacct_list
      } else {
         test_report report $curr_task_nr $id value "Accounting for a job \
                                                            $job_id is missing!"
         set result [get_result_failed]
      }
   }
   test_report report $curr_task_nr $id result $result
}

#****** manual_util/sge_check_32bit_binaries() *********************************
#  NAME
#     sge_check_32bit_binaries() -- check the 32-bit binaries
#
#  SYNOPSIS
#     sge_check_32bit_binaries { report_var }
#
#  FUNCTION
#     Check the functionality of 32-bit binaries on 64-bit hosts.
#
#  INPUTS
#     report - the report object
#
#  NOTES
#     Issue 301: add option to run 32bit binaries on 64bit platform
#     TODO: when it's implemented, this check can be removed and we can run the
#           whole basic_test with 32bit binaries
#
#  SEE ALSO
#     report_procedures/get_test_host()
#     manual_util/manual_arch32_mapping()
#
#*******************************************************************************
proc sge_check_32bit_binaries {report_var} {
   global ts_config CHECK_USER
   upvar $report_var report

   ts_log_fine "Check 32-bit binaries"

   set id [register_test 32-bit report curr_task_nr]

   set host [get_test_host report $curr_task_nr]
   set arch [resolve_arch $host]

   set arch_32 [manual_arch32_mapping $arch]

   if {"$arch_32" == ""} {
      test_report report $curr_task_nr $id result [get_result_skipped]
      return
   }

   set fs_host [fs_config_get_server_for_path $ts_config(product_root) 0]
   if {$fs_host == ""} {
      set fs_host $host
   }
   if {[remote_file_isdirectory $fs_host $ts_config(product_root)/bin/$arch_32] == 0} {
      test_report report $curr_task_nr $id value "binaries $arch_32 not installed."
      test_report report $curr_task_nr $id result [get_result_skipped]
      return
   }

   set shared_lib_var [get_shared_lib_path_variable_name $arch_32]
   set env($shared_lib_var) $ts_config(product_root)/lib/$arch_32

   array set args {}
   set args(qstat) "-f"
   set args(qhost) ""
   set args(qconf) "-help | head -1"
   set args(qsub) "$ts_config(product_root)/examples/jobs/sleeper.sh 5"
   set args(qacct) ""
   set cmd_errors 0
   set output ""
   foreach cmd [array names args] {
      set res [start_remote_prog $host $CHECK_USER \
                      "$ts_config(product_root)/bin/$arch_32/$cmd" $args($cmd) \
                                                     prg_exit_state 60 0 "" env]
      if {$prg_exit_state != 0} {
         incr cmd_errors 1
      }
      append output "$cmd $args($cmd)\n$res\n"
   }

   test_report report $curr_task_nr $id value $output
   if {$cmd_errors > 0} {
      test_report report $curr_task_nr $id result [get_result_failed]
   } else {
      test_report report $curr_task_nr $id result [get_result_ok]
   }

}

proc manual_cluster_parameters {} {
   return "master_host shadowd_hosts execd_hosts commd_port jmx_port reserved_port \n
   product_root product_feature cell cluster_name spooling_method bdb_server bdb_dir"
}

proc manual_arch32_mapping {arch} {
   global ts_config

   set arch_32 ""
   switch -- $arch {
      "hp11-64" {
         set arch_32 "hp11"
      }
      "lx24-amd64" -
      "lx24-ia64" {
         set arch_32 "lx24-x86"
      }
      "lx26-amd64" {
         set arch_32 "lx26-x86"
      }
      "sol-amd64" {
         set arch_32 "sol-x86"
      }
      "sol-sparc64" {
         # sol-sparc not supported for versions 6.2 and higher
         if {$ts_config(gridengine_version) < 62} {
            set arch_32 "sol-sparc"
         }
      }
   }
   return $arch_32
}
