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


#****** sge_job/tight_integration_monitor() ************************************
#  NAME
#     tight_integration_monitor() -- monitor a tightly integrated job
#
#  SYNOPSIS
#     tight_integration_monitor {id master_node started_var finished_var 
#                                jobid_var info_var {iz_578 0}}
#
#  FUNCTION
#     Monitoring for a tightly integrated job using
#     scripts/pe_job.sh as job script and
#     scripts/pe_task.sh as task script.
#
#  INPUTS
#     id           - spawn id returned from open_remote_spawn_process
#     master_node  - host name of the master node (from -masterq switch)
#     started_var  - call by reference: the number of started tasks
#     finished_var - call by reference: the number of finished tasks
#     jobid_var    - call by reference: the job id
#     info_var     - call by reference: array containing info about the tasks
#     {iz_578 0}   - check for issue 578?
#
#  RESULT
#     string describing the current status of the pe job:
#     "unknown"
#     "timeout"
#     "error"
#     "eof"
#     "task started"
#     "task running"
#     "task finished"
#     "master started"
#     "master submitted"
#     "master finished"
#     "unexpected job output"
#     
#
#  EXAMPLE
#     set id [submit_with_method "qsub" "-pe tight 4 -masterq $master_queue -cwd -N tight" \
#                                "$ts_config(testsuite_root_dir)/scripts/pe_job.sh" \
#                                "$ts_config(testsuite_root_dir)/scripts/pe_task.sh 1 60" $master_node]
#     while {$job_finished == 0} {
#        set job_state [tight_integration_monitor $id $master_node started finished jobid info]
#        ts_log_fine "job state: $job_state"
#        set job_finished [tight_integration_job_finished $job_state]
#     }
#
#  SEE ALSO
#     sge_job/tight_integration_job_finished()
#     bugs/issuezilla/2822/check.61.exp
#     functional/tight_integration
#*******************************************************************************
proc tight_integration_monitor {id master_node started_var finished_var jobid_var info_var {iz_578 0}} {
   upvar $started_var  started
   upvar $finished_var finished
   upvar $jobid_var    jobid
   upvar $info_var     job_info

   set job_info(tasks) {}

   set ret "unknown"

   set sp_id [lindex $id 1]
   set timeout 180

   set unexpected_output ""
   
   expect_user {
      -i $sp_id timeout {
         ts_log_severe "timeout waiting for tasks output (tight integration)"
         set ret "timeout"
      }
      -i $sp_id full_buffer {
         ts_log_severe "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
         set ret "error"
      }
      -i $sp_id eof {
         set ret "eof"
      }
      # workaround for a feature lacking in expect:
      # We have to parse complete lines.
      # expect_user ensures only that expect will parse input up to a newline,
      # but there seems to be no way to tell expect we want to examine each
      # individual line.
      -i $sp_id "?*\n" {
         #ts_log_fine "entered default branch, data: $expect_out(0,string)"
         foreach line [string trim [split $expect_out(0,string) "\n"]] {
            set line [string trim $line]
            if {[string length $line] > 0} {
               #ts_log_fine "processing line: $line"
               switch -glob $line {
                  "petask ??? with pid ???????? started on host*" {
                     set task [lindex $line 1]
                     lappend job_info(tasks) $task
                     set job_info($task,pid) [lindex $line 4]
                     set job_info($task,host) [lindex $line 8]
                     incr started
                     ts_log_fine "task $task started, total started: $started"
                     set ret "task started"
                  }
                  "petask ??? with pid ???????? finished*" {
                     set task [lindex $line 1]
                     incr finished
                     ts_log_fine "task $task finished, total finished: $finished"
                     set ret "task finished"
                  }
                  "master task started with job id ?????? and pid*" {
                     set jobid [lindex $line 6]
                     lappend job_info(tasks) master
                     set job_info(master,pid) [lindex $line 9]
                     set job_info(master,host) $master_node
                     ts_log_fine "job $jobid started"
                     set ret "master started"
                  }
                  "master task submitted all sub tasks*" {
                     ts_log_fine "master task submitted all tasks"
                     set ret "master submitted"
                  }
                  "master task exiting*" {
                     ts_log_fine "job $jobid exited"
                     set ret "master finished"
                  }
                  "NSLOTS ??? NHOSTS ??? NQUEUES*" {
                     if {$iz_578} {
                        set nslots  [lindex $line 1]
                        set nhosts  [lindex $line 3]
                        set nqueues [lindex $line 5]
                        ts_log_fine "nslots = $nslots, nhosts = $nhosts, nqueues = $nqueues"
                        if {$nslots == 0 || $nhosts == 0 || $nqueues == 0} {
                           ts_log_severe "invalid environment setting for NSLOTS, NHOSTS, NQUEUES for pe task (Issue 578 present): $line"
                           set ret "error"
                           break
                        }
                     }
                     set ret "task running"
                  }

                    
                  "_start_mark_:(*)*" {
                     ts_log_fine "got start mark from remote prog shell script"
                  }
                  "_exit_status_:(*)*" {
                     ts_log_fine "got exit status from remote prog shell script"
                  }
                  "script done.*" {
                     ts_log_fine "got \"script done.\" from remote prog shell script"
                  }
                  default {
                     # something we didn't expect.
                     # store all unexpected lines and send them in one mail
                     # at the end
                     if {$unexpected_output != ""} {
                        append unexpected_output "\n"
                     }
                     append unexpected_output $line
                     set ret "unexpected job output"
                  }
               }
            }
         }
      }
   }

   # send unexpected output
   if {$unexpected_output != ""} {
      ts_log_info "unexpected job output:\n---\n$unexpected_output\n---\nPlease check our \".*\" login scripts for output lines!"
   }

   return $ret
}

#****** sge_job/tight_integration_job_finished() *******************************
#  NAME
#     tight_integration_job_finished() -- tightly integrated job finished?
#
#  SYNOPSIS
#     tight_integration_job_finished {job_state} 
#
#  FUNCTION
#     Checks if a tightly integrated job monitored by 
#     tight_integration_monitor() has finished.
#
#  INPUTS
#     job_state - the current job state delivered by tight_integration_monitor()
#
#  RESULT
#     1: it finished, else 0
#
#  SEE ALSO
#     sge_job/tight_integration_monitor()
#*******************************************************************************
proc tight_integration_job_finished {job_state} {
   switch -exact $job_state {
      "unknown" -
      "timeout" -
      "eof" -
      "master finished" -
      "error" {
         set job_finished 1
      }
      
      "task started" -
      "task running" -
      "task finished" -
      "master started" -
      "master submitted" -
      "unexpected job output" {
         set job_finished 0
      }

      default {
         set job_finished 1
      }
   }

   return $job_finished
}

