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

#****** arco_queries/arco_job_to_string() **************************************
#  NAME
#    arco_job_to_string() -- get a human readable string representation of a job object
#
#  SYNOPSIS
#    arco_job_to_string { job_object } 
#
#  FUNCTION
#     get a human readable string representation of a job object
#
#  INPUTS
#    job_object -- the job object
#
#  RESULT
#     The human readable string 
#
#  EXAMPLE
#   set job(j_job_number)  15
#   set job(j_task_number) 1
#   set job(j_job_name)    "sleeper"
#
#   puts "Job [arco_job_to_string job]"
#*******************************************************************************
proc arco_job_to_string { job_object } {
   upvar $job_object job
   set job_str "("
   if { [info exists job(j_job_number)] } {
      append job_str "$job(j_job_number)"
   }
   if { [info exists job(j_task_number)] && $job(j_task_number) != -1 } {
      append job_str ".$job(j_task_number)"
   }
   if { [info exists job(j_job_name)] } {
      append job_str " \"$job(j_job_name)\""
   }
   append job_str ")"
   return $job_str
}

#****** arco_queries/arco_job_run() ********************************************
#  NAME
#    arco_job_run() -- submit a job
#
#  SYNOPSIS
#    arco_job_run { job_object { start_timeout 10 } { end_timeout 120 } 
#                   {on_host ""} {as_user ""} }
#
#  FUNCTION
#    Submit a job which is specifed by a job object
#
#  INPUTS
#    job_object    --  the job object (elements j_job_name and args must be set)
#    {start_timeout 10} --  Max. waiting time in seconds for job start
#    {end_timeout 100}  --  Max. waiting time in seconds for job end
#    {on_host ""} -- host which the command will be called from
#    {as_user ""} -- user who will call the command
#
#  RESULT
#     0 --   job successfully ran (j_job_number stored in job_jobject)
#     else -- error
#
#  EXAMPLE
#
#   set job(j_job_name)    "blubber"
#   set job(args)          "-o /dev/null -e /dev/null $SGE_ROOT/examples/jobs/sleeper 10"
#
#   set res [arco_job_run job 10 20]
#*******************************************************************************
proc arco_job_run { job_object { start_timeout 20 } { end_timeout 120 } {on_host ""} {as_user ""} } {
   
   upvar $job_object job
   
   if { [info exists job(j_job_name)] != 1 } {
      ts_log_severe "Missing element j_job_name in job object"
      return -1
   }
   if { [info exists job(args)] != 1 } {
      ts_log_severe "Missing element args in job object"
      return -1
   }

   set res [submit_job "-N $job(j_job_name) $job(args)" 1 60 $on_host $as_user]
   
   if { $res < 0 } {
      ts_log_severe "submission of job [arco_job_to_string job] failed"
      return -1
   }
   set job(j_job_number) $res
   
   if {[wait_for_jobstart $job(j_job_number) "" $start_timeout 1 1] != 0} {
      return -1
   }
   
   if {[wait_for_jobend $job(j_job_number) "" $end_timeout 0 1] == -1} {
      return -1
   }
   
   return 0
}


#****** arco_queries/arco_query_job() **************************************************
#  NAME
#    arco_query_job() -- Get information  about job from the ARCO database
#
#  SYNOPSIS
#    arco_query_job arco_query_job { sqlutil_sp_id job_array { expected_count 1 }  { timeout 120 } }
#
#  FUNCTION
#     The method queries all information about a job from the table sge_job from
#     the ARCO database.
#
#  INPUTS
#    sqlutil_sp_id --  spawn id of the sql util
#    job_array     --  Array with the elements j_job_number, j_job_name (optional) and
#                      j_task_number (option).
#                      If a job is found, the fields j_id, j_open, j_group, j_owner, 
#                      j_account, j_priority, j_submission_time, j_project and
#                      j_department are stored in this array
#    expected_count -- Expected count
#    timeout --        timeout for the query in seconds
#
#  RESULT
#     >0  --   Number of entries which has been found
#     -1  --   Timeout error
#     -2  --   Fatal error, sql query could not be executed
#
#  EXAMPLE
#   set sqlutil_id [sqlutil_create $CHECK_USER]
#   set sqlutil_sp_id [ lindex $sqlutil_id 1 ]
#
#   set job(j_job_number)  15
#   set job(j_task_number) 1
#   set job(j_job_name)    "sleeper"
#   set res [arco_query_job $sqlutil_sp_id job]
#
#   if { $res > 0 } {
#      for { set i 0 } { $i < $res } { incr i } { 
#         puts "j_id = $job($i,j_id)"
#         puts "j_job_number = $job($i,j_job_number)"
#         puts "j_task_number = $job($i,j_task_number)"
#         puts "j_job_name = $job($i,j_job_name)"
#         puts "j_group = $job($i,j_group)"
#         puts "j_owner = $job($i,j_owner)"
#         puts "j_account = $job($i,j_account)"
#         puts "j_priority = $job($i,j_priority)"
#         puts "j_submission_time = $job($i,j_submission_time)"
#         puts "j_project = $job($i,j_project)"
#         puts "j_department = $job($i,j_department)"
#     }
#   } else if { $res == -1 } {
#      puts "job was not found in the ARCo database
#   } else {
#      puts "sql error in method arco_query_job"
#   }
#
#  SEE ALSO
#     sql_util/sqlutil_create
#*******************************************************************************
proc arco_query_job {sqlutil_sp_id job_array {expected_count 1} {timeout 300}} {
   global CHECK_DEBUG_LEVEL
   
   upvar $job_array job
   
   set job_str [arco_job_to_string job]
   
   ts_log_fine "Searching job $job_str in table sge_job "
   
   set sql "select j_id, j_job_number, j_task_number, j_job_name, j_group, "
   append sql " j_owner, j_account, j_priority, j_submission_time, j_project, j_department"
   append sql " from sge_job"
   append sql " where j_job_number = $job(j_job_number)"
   if { [info exists job(j_job_name) ] } {      
      append sql " and j_job_name = '$job(j_job_name)'"
   }
   if { [info exists job(task_id)] } {
      append sql " and j_task_id = '$job(j_task_number)'"
   }

   set end_time [ expr [clock seconds] + $timeout ]
   
   while { 1 } {
      if { [clock seconds] > $end_time } {
         ts_log_severe "Timeout while waiting for job $job_str in table sge_job"
         return -1
      }
      array set result {}
      set columns {}
      set res [sqlutil_query $sqlutil_sp_id $sql result columns]
      if { $res < 0 } {
         ts_log_severe "Can not execute sql query"
         return -2
      } 
      ts_log_progress
      if {$res >= $expected_count} {
         puts " ok ($res Tasks)"
         set job(task_count) $res
         set col_count [llength $columns]
         for {set i 0} {$i < $res} {incr i} {
            set col 0
            foreach col_name $columns {
               set job($i,$col_name) $result($i,$col)
               incr col
            }
         }
         return $res
      }
      after 1000
   }
}


#****** arco_queries/arco_query_job_log() **************************************************
#  NAME
#    arco_query_job_log() -- query the job log information in the ARCo database
#
#  SYNOPSIS
#    arco_query_job_log { sqlutil_sp_id job_array { timeout 120 } }
#
#  FUNCTION
#     Query the job log information if a job in the table sge_job_log in the 
#     ARCo database
#
#  INPUTS
#    sqlutil_sp_id --  spawnid of the sqlutil
#    job_array     --  Array with the elements j_job_number, j_job_name (optional) and
#                      j_task_number (optional).
#                      The found number of entries for each event is stored in this array
#    timeout       --  timeout in seconds
#
#  RESULT
#     0   --   All events for the job has been found in the table sge_job_log
#     -1  --   Timeout error
#     -2  --   Fatal error, sql query could not be executed
#
#  EXAMPLE
#   set sqlutil_id [sqlutil_create $CHECK_USER]
#   set sqlutil_sp_id [ lindex $sqlutil_id 1 ]
#
#   set job(j_job_number)  15
#   set job(j_task_number) 1
#   set job(j_job_name)    "sleeper"
#
#   arco_query_job $sqlutil_sp_id job
#   arco_query_job_log $sqlutil_sp_id job
#
#  SEE ALSO
#     sql_util/sqlutil_create
#*******************************************************************************
proc arco_query_job_log {sqlutil_sp_id job_array {timeout 300}} {
   global CHECK_DEBUG_LEVEL
   
   upvar $job_array job
   
   set end_time [expr [clock seconds] + $timeout ]
   
   set task_count $job(task_count)
   
   for { set task_index 0 } { $task_index < $task_count } { incr task_index } {
      array set task {}
      set task(j_job_number)  $job($task_index,j_job_number)
      set task(j_task_number) $job($task_index,j_task_number)
      set task(j_job_name)    $job($task_index,j_job_name)
      if { $task_count > 1 } {
         # we have an array task
         if { $task(j_task_number) == "-1" } {
            set events { pending }
         } else {
            set events { sent delivered finished  deleted }
         }
      } else {
         set events { pending sent delivered finished  deleted }
      }

      set job_str [arco_job_to_string task]

      puts "Searching events for job $job_str in table sge_job_log"
      
      foreach event $events {
         set    sql "select count(jl_parent) from sge_job_log "
         append sql "where jl_parent in ("
         append sql "    select j_id from sge_job "
         append sql "     where j_job_number = $job(j_job_number) "
         if { [info exists job(j_task_number)] } {
            append sql "    and j_task_number = $job(j_task_number)"
         }
         if { [info exists job(j_job_name)] } {
            append sql "    and j_job_name = '$job(j_job_name)'"
         }
         append sql ")  and jl_event = '$event'"
   
         set msg [format "    -> %10s "   $event]
         if { $CHECK_DEBUG_LEVEL == 0 } {
            puts -nonewline $msg
         } else {
            puts $msg
         }
         while { 1 } {
            if { [clock seconds] > $end_time } {
               ts_log_severe "timeout error while waiting for job_log entries of job $job_str"
               return -1
            }
            
            array set result {}
            set columns {}
            set count [sqlutil_query $sqlutil_sp_id $sql result columns]
            if { $count < 0 } {
               ts_log_severe "Can not execute query --------\n$sql\n --------------------"
               return -2
            } 
            set count $result(0,0)
            if { $CHECK_DEBUG_LEVEL == 0 } {
               ts_log_progress
            }
            if { $count >= 1 } {
               # we have found entries for the current event
               puts " ok"
               set job($event) $count
               break
            }
            after 1000
         }
      }
   }
   return 0
}

#****** arco_queries/arco_query_job_usage() ************************************
#  NAME
#    arco_query_job_usage() -- get a usage of a job
#
#  SYNOPSIS
#    arco_query_job_usage { sqlutil_sp_id job_array { timeout 60 } } 
#
#  FUNCTION
#    This function reads the job usage of a job from the table sge_job_usage
#    and store the values of the columns ju_ru_wallclock and ju_exit_status in
#    the task entries of a job
#
#  INPUTS
#    sqlutil_sp_id --  spawn id of the sqlutil
#    job_array     --  job object
#    timeout       --   timeout in seconds (default 60s)
#
#  RESULT
#     0 -- found for all tasks of the job a job usage entry
#     else -- error
#
#  EXAMPLE
#
#   set sqlutil_id [sqlutil_create $CHECK_USER]
#   set sqlutil_sp_id [ lindex $sqlutil_id 1 ]
#
#   set job(j_job_number)  15
#   set job(j_task_number) 1
#   set job(j_job_name)    "sleeper"
#
#   arco_query_job $sqlutil_sp_id job
#   arco_query_job_usage$sqlutil_sp_id job
#
#
#    for { set task_index 0 } { $task_index < $job(task_count) } { incr task_index } {
#       puts "task $task_index: wallclock = $job($task_index,ju_ru_wallclock), exit_status = $job($task_index,ju_exit_status)"
#    }
#
#
#  SEE ALSO
#     arco_queries/arco_query_job
#*******************************************************************************
proc arco_query_job_usage {sqlutil_sp_id job_array {timeout 300}} {
   global CHECK_DEBUG_LEVEL
   
   upvar $job_array job
   
   set end_time [expr [clock seconds] + $timeout ]
   
   set task_count $job(task_count)
   
   for { set task_index 0 } { $task_index < $task_count } { incr task_index } {
      array set task {}
      set task(j_job_number)  $job($task_index,j_job_number)
      set task(j_task_number) $job($task_index,j_task_number)
      set task(j_job_name)    $job($task_index,j_job_name)
      if { $task_count > 1 && $task(j_task_number) == "-1" } {
         # the task with task_number -1 does not have a usage record
         continue
      }

      set job_str [arco_job_to_string task]

      ts_log_fine "Searching for job $job_str in table sge_job_usage "
      
      set    sql "select ju_ru_wallclock, ju_exit_status from sge_job_usage "
      append sql "where ju_parent in ("
      append sql "    select j_id from sge_job "
      append sql "     where j_job_number = $task(j_job_number) "
      append sql "       and j_task_number = $task(j_task_number)"
      append sql "       and j_job_name = '$task(j_job_name)'"
      append sql ")"

      while { 1 } {
         
         if { [clock seconds] > $end_time } {
            ts_log_severe "timeout error while waiting for job_usage entries of job $job_str"
            return -1
         }
         
         array set result {}
         set columns {}
         set count [sqlutil_query $sqlutil_sp_id $sql result columns]
         if { $count < 0 } {
            ts_log_severe "Can not execute query --------\n$sql\n --------------------"
            return -2
         } 
         if { $CHECK_DEBUG_LEVEL == 0 } {
            ts_log_progress
         }
         
         if { $count >= 1 } {
            # we have found entries for current task
            puts " ok"
            
            set col_count [llength $columns]
            for { set col 0 } { $col < $col_count } { incr col } {
               set job($task_index,[lindex $columns $col]) $result(0,$col)
            }
            break
         }
         after 1000
      }
   }

   return 0
}



