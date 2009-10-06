#!/vol2/TCL_TK/glinux/bin/expect
# expect script 
# test SGE/SGEEE System
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


#****** report/report_create() **************************************************
#  NAME
#    report_create() -- Create a report object
#
#  SYNOPSIS
#    report_create { name } 
#
#  FUNCTION
#     Creates a report object
#
#  INPUTS
#    name           -- name of the report object
#    a_report_array -- the report object
#    send_email     -- should a email send at the end of the report
#    write_html     -- should the html version of the report be written
#
#  RESULT
#     the id of the report object
#
#  EXAMPLE
#
#   array set report {}
#   report_create "Test report" report
#
#   report_add_message report "a foo message"
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#     report/report_finish
#*******************************************************************************
proc report_create { name a_report_array { send_email 1 } { write_html 1 } } {
   upvar $a_report_array report_array
   set report_array(name) $name
   set report_array(start) [clock seconds]
   set report_array(task_count) 0
   set report_array(messages) {}
   
   set report_array(handler) {}
   set report_array(task_progress_handler) {}
   
   if { $send_email == 1 } {
      lappend report_array(handler) report_send_mail
   }
   if { $write_html == 1 } {
      lappend report_array(handler) report_write_html
      lappend report_array(task_progress_handler) report_write_html
   }
}

#****** report_set_html_parameters**********************************************
#  NAME
#    report_set_html_parameters() -- Change the html report parameters
#
#  SYNOPSIS
#    report_set_html_parameters { report_array handler }
#
#  FUNCTION
#     Change the html report handler procedure and set the filename where to store
#     the html results.
#
#  INPUTS
#    report_array -- the report object
#    handler      -- the name of procedure which will generate the html report
#    filename     -- the name of html file report
#
#  EXAMPLE
#
#   array set report {}
#   report_create "Test report" report
#   report_set_html_handler report_write_html
#
#   report_add_message report "a foo message"
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#     report/report_create
#*******************************************************************************
proc report_set_html_parameters {report_array handler filename} {
    upvar $report_array report
   set report(handler) $handler
   set report(task_progress_handler) $handler
   set report(filename) $filename
}

#****** report_procedures/report_add_message() **************************************************
#  NAME
#    report_add_message() -- add a message to the report
#
#  SYNOPSIS
#    report_add_message { report message } 
#
#  FUNCTION
#     adds a message to the report. 
#
#  INPUTS
#    a_report  -- the report object
#    message   -- the message
#
#  RESULT
#
#  EXAMPLE
#
#   array set report {}
#   report_create "Test report" report
#
#   report_add_message report "a foo message"
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc report_add_message { a_report message } {
   global CHECK_USE_HUDSON
   upvar $a_report report_array
   lappend report_array(messages)  $message
   
   #Do not report this when doing XMLs for Hudson we get the report at send_report
   if {$CHECK_USE_HUDSON == 0} {
      ts_log_fine $message
   }
}

#****** report_procedures/report_clear_messages() **************************************************
#  NAME
#    report_clear_messages() -- clear all messages of a report
#
#  SYNOPSIS
#    report_clear_messages { report } 
#
#  FUNCTION
#
#   The method removes all messages of a report
#
#  INPUTS
#    report -- the report object
# 
#  RESULT
#
#  EXAMPLE
#
#   array set report {}
#   report_create "Test report report
#
#   report_add_message report "a foo message"
# 
#   report_write_html report
#
#   report_clear_messages report
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc report_clear_messages { report } {
   upvar $report report_array
   set report_array(messages) {}
}


#****** report_procedures/report_create_task() *********************************
#  NAME
#    report_create_task() -- create a task of a report
#
#  SYNOPSIS
#    report_create_task { report name host {link ""} {spooling ""}}
#
#  FUNCTION
#    Creates a task for a report. All tasks of a report will be shown in
#    a table. 
#
#  INPUTS
#    report    --  the report object
#    name      --  Name of the tasks
#    host      --  Host where the task is running
#    {link ""} --  add a link
#    {spooling ""} -- spooling method
#
#  RESULT
#
#  EXAMPLE
#
#  array set report {}
#  report_create "Test Report" report
#  ...
#  set task_nr [report_create_task report "test_task" "foo.bar"]
#  ...
#  set result ....
#  report_finish_task report $task_nr $result
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc report_create_task { report name host {link ""} {spooling ""}} {
   global CHECK_HTML_DIRECTORY CHECK_PROTOCOL_DIR CHECK_USER

   upvar $report report_array
   set task_nr $report_array(task_count)
   incr report_array(task_count) 1

   set report_array(task_$task_nr,name)   $name
   set report_array(task_$task_nr,host)   $host
   set report_array(task_$task_nr,status) started
   set report_array(task_$task_nr,date)   [clock seconds]
   set report_array(task_$task_nr,test_count) 0
   if {"$spooling" != ""} {
      set report_array(task_$task_nr,spooling) $spooling
   }
   if {$spooling == ""} {
      set relative_filename "${host}_${name}.txt"
   } else {
      set relative_filename "${host}_${spooling}_${name}.txt"
   }
   if {[info exists report_array(filename)]} {
      set myfilename "[file dirname $report_array(filename)]/$relative_filename"
   } elseif { $CHECK_HTML_DIRECTORY != "" } {
      set myfilename "$CHECK_HTML_DIRECTORY/$relative_filename"
   } else {
      set myfilename "$CHECK_PROTOCOL_DIR/$relative_filename"
   }
   set fs_host [fs_config_get_server_for_path $myfilename 0]
   if {$fs_host == ""} {
      set fs_host [gethostname]
   }
   delete_remote_file $fs_host $CHECK_USER $myfilename

   set report_array(task_$task_nr,filename) $myfilename
   set report_array(task_$task_nr,relative_filename) $relative_filename
   set report_array(task_$task_nr,file) [open $myfilename w]

   if { $link != "" } {
      set report_array(task_$task_nr,link) $link
   }

   foreach handler $report_array(task_progress_handler) { 
      debug_puts "starting \"$handler\" with report_array ..."
      $handler report_array
   }
   return $task_nr
}

#****** report_procedures/report_add_task() ************************************
#  NAME
#    report_add_task() -- add an existing task to the report
#
#  SYNOPSIS
#    report_create_task { report name host {link ""} {spooling ""}}
#
#  FUNCTION
#    Adds and existing task to the report. All tasks of a report will be shown in
#    a table.
#
#  INPUTS
#    report    --  the report object
#    name      --  Name of the tasks
#    host      --  Host where the task is running
#    {link ""} --  not implemented
#
#  RESULT
#
#  EXAMPLE
#
#  array set report {}
#  report_create "Test Report" report
#  ...
#  set task_nr [report_add_task report "test_task" "foo.bar"]
#  ...
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc report_add_task {report name host {link ""} {spooling ""}} {
   upvar $report report_array

   if {$spooling == ""} {
      set relative_filename "${host}_${name}.txt"
   } else {
      set relative_filename "${host}_${spooling}_${name}.txt"
   }
   if {[info exists report_array(filename)]} {
      set myfilename "[file dirname $report_array(filename)]/$relative_filename"
   } elseif { $CHECK_HTML_DIRECTORY != "" } {
      set myfilename "$CHECK_HTML_DIRECTORY/$relative_filename"
   } else {
      set myfilename "$CHECK_PROTOCOL_DIR/$relative_filename"
   }

   if {[file isfile $myfilename] == 0} {
      return ""
   }

   set task_nr $report_array(task_count)
   incr report_array(task_count) 1
   set report_array(task_$task_nr,name)   $name
   set report_array(task_$task_nr,host)   $host
   if {"$spooling" != ""} {
      set report_array(task_$task_nr,spooling) $spooling
   }

   set report_array(task_$task_nr,filename) $myfilename
   set report_array(task_$task_nr,relative_filename) $relative_filename
   set report_array(task_$task_nr,file) "--"
   set report_array(task_$task_nr,test_count) \
            [get_test_count report_array task_$task_nr test_errors test_skipped]
   set fp [open $myfilename r]
   #STATUS ok|STARTED: time|FINISHED: time
   set report_array(task_$task_nr,status) unknown
   set report_array(task_$task_nr,date)   0
   set report_array(task_$task_nr,finish) 0
   foreach line [split [read $fp] "\n"] {
      if {[string match "STATUS:*|STARTED:*|FINISHED:*" $line] >= 0} {
         foreach item [split $line "|"] {
            set value [lindex $item 1]
            switch -glob $item {
               "STATUS:*" {
                  set param status
               }
               "STARTED:*" {
                  set param date
               }
               "FINISHED:*" {
                  set param finish
               }
            }
            set report_array(task_$task_nr,$param) $value
         }
      }
      break
   }
   close $fp

   return $task_nr
}

#****** report_procedures/report_task_add_message() ****************************
#  NAME
#    report_task_add_message() -- add a message to a task
#
#  SYNOPSIS
#    report_task_add_message { report task_nr message  } 
#
#  FUNCTION
#     
#     Add a message to a task
#     The message is written into the task file
#     and logged
#
#  INPUTS
#    report    --  the report object
#    task_nr   --  the number of the task
#    message   --  the message
#
#  RESULT
#
#  EXAMPLE
#  set task_nr [report_create_task report "test_task" "foo.bar"
#  ...
#  set result ....
#  report_task_add_message report $task_nr "foo_bar returned $result"
#
#  report_finish_task report $task_nr $result
#
#  NOTES
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc report_task_add_message { report task_nr message } {
   
   upvar $report report_array
   if {[info exists report_array(task_$task_nr,filename)]} {
      puts $report_array(task_$task_nr,file) $message
      flush $report_array(task_$task_nr,file)
   } else {
      # TODO: implement it when used
   }
}

#****** report_procedures/report_finish_task() **************************************************
#  NAME
#    report_finish_task() -- Mark a report task as finished
#
#  SYNOPSIS
#    report_finish_task { report task_nr result } 
#
#  FUNCTION
#     Mark a report task as finished.
#     The report task file will be flushed and closed
#     The result of the task is set

#  INPUTS
#    report    -- the report object 
#    task_nr   -- the task_nr
#    result    -- the result of the task
#
#  RESULT
#
#
#  EXAMPLE
#  set task_nr [report_create_task report "test_task" "foo.bar"
#  ...
#  set result ....
#  report_task_add_message report $task_nr "foo_bar returned $result"
#
#  report_finish_task report $task_nr $result
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc report_finish_task { report task_nr result } {
   
   upvar $report report_array

   set report_array(task_$task_nr,status) [get_result $result]
   if {[info exists report_array(task_$task_nr,filename)]} {
      flush $report_array(task_$task_nr,file)
      close $report_array(task_$task_nr,file)
      set report_array(task_$task_nr,file) "--"
   }

   set report_array(task_$task_nr,finish) [clock seconds]

   foreach handler $report_array(task_progress_handler) { 
      $handler report_array
   }
}

#****** report_procedures/report_finish() **************************************************
#  NAME
#    report_finish() -- Mark a report as finished
#
#  SYNOPSIS
#    report_finish { report result } 
#
#  FUNCTION
#     Mark a report as finished
#     A email with the content of the report is send
#     A html file with the content of the report is written
#
#  INPUTS
#    report    --  the report object
#    result    --  the result of the report (numeric error code)
#
#  RESULT
#
#  EXAMPLE
#
#   array set report {}
#   report_create "Test report" report
#   ...
#   report_finish report 0
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc report_finish { report result } {
   
   upvar $report report_array
   
   set report_array(result) [get_result $result]
   set report_array(end)    [clock seconds]
 
   foreach handler $report_array(handler) {
      $handler report_array
   }
}

#****** report_procedures/report_send_mail() ***********************************
#  NAME
#     report_send_mail() -- writes a report email 
#
#  SYNOPSIS
#     report_send_mail { report } 
#
#  FUNCTION
#     writes an report email 
#
#  INPUTS
#     report - the report object 
#
#*******************************************************************************
proc report_send_mail { report } {
   global CHECK_USE_HUDSON CHECK_HUDSON_OUTPUT
   upvar $report report_array
   
   if {$CHECK_USE_HUDSON == 1} {
      report_hudson_xml $report
      return
   }
   
   set mail_subject "testsuite - $report_array(name) -- "
   set mail_body    "testsuite - $report_array(name)\n"
   append mail_body "------------------------------------------\n\n"
   append mail_body " started: [clock format $report_array(start)]\n"
   if { [info exists report_array(result)] } {
      append mail_subject $report_array(result)
      append mail_body "finished: [clock format $report_array(end)]\n"
      append mail_body "  result: $report_array(result)\n"
   } else {
      append mail_subject "yet not finished"
      
   }
   append mail_body "------------------------------------------\n"
   
   if { [info exists report_array(task_0,name)] } {
      append mail_body "\nTasks:\n"
      
      set line [format "  %26s %12s %8s %s" "Name" "Host" "Status" "Details"]
      append mail_body "$line\n\n"
      
      for { set task_nr 0 } { [info exists report_array(task_$task_nr,name)] } { incr task_nr 1 } {
         
         set line [format "  %26s %12s %8s %s" $report_array(task_$task_nr,name) \
                                                $report_array(task_$task_nr,host) \
                                                $report_array(task_$task_nr,status) \
                                                "file://$report_array(task_$task_nr,filename)" ]
         append mail_body "$line\n"
      }
   }
   append mail_body "\n------------------------------------------\n"
   
   foreach message $report_array(messages) {
      append mail_body "$message\n"
   }
   append mail_body "------------------------------------------\n"
   
   mail_report $mail_subject $mail_body
}

#****** report_procedures/report_hudson_xml() ***********************************
#  NAME
#     report_hudson_xml() -- writes a report email
#
#  SYNOPSIS
#     report_hudson_xml { report }
#
#  FUNCTION
#     writes an report email 
#
#  INPUTS
#     report - the report object 
#
#*******************************************************************************
proc report_hudson_xml { report } {
   global CHECK_USE_HUDSON CHECK_HUDSON_OUTPUT
   upvar $report report_array
   
   if { $CHECK_USE_HUDSON == 1} {
      append CHECK_HUDSON_OUTPUT "===== REPORT_START =====\n"
   }
   
   if { [info exists report_array(task_0,name)] } {
      for { set task_nr 0 } { [info exists report_array(task_$task_nr,name)] } { incr task_nr 1 } {
         
         set line [format "  %26s %12s %8s %s" $report_array(task_$task_nr,name) \
                                               $report_array(task_$task_nr,host) \
                                               $report_array(task_$task_nr,status) \
                                               "file://$report_array(task_$task_nr,filename)" ]
         append CHECK_HUDSON_OUTPUT "$report_array(task_$task_nr,status)\n"
         append CHECK_HUDSON_OUTPUT "$report_array(task_$task_nr,status): $report_array(name) - $report_array(task_$task_nr,name) @ $report_array(task_$task_nr,host)\n"
         append CHECK_HUDSON_OUTPUT "$report_array(task_$task_nr,status)\n"
         set f [open $report_array(task_$task_nr,filename) "r"]
         append CHECK_HUDSON_OUTPUT "[read $f]\n"
         close $f
      }
   }
   
   append CHECK_HUDSON_OUTPUT "Messages:\n"  
   foreach message $report_array(messages) {
      append CHECK_HUDSON_OUTPUT "$message\n"
   }
   append CHECK_HUDSON_OUTPUT "=====  REPORT_END  =====\n"
}

#****** report_procedures/report_write_html() **********************************
#  NAME
#     report_write_html() -- report handler which write a html report
#
#  SYNOPSIS
#     report_write_html { report } 
#
#  FUNCTION
#     This report handler writes a html report into  CHECK_HTML_DIRECTORY
#
#  INPUTS
#     report - the report object
#
#*******************************************************************************
proc report_write_html { report } {
   global CHECK_HTML_DIRECTORY
   
   if { $CHECK_HTML_DIRECTORY == "" } {
      return
   }
   upvar $report report_array
   
   set html_body   [ create_html_text "started:   [clock format $report_array(start)]" 1 ]
   
   if { [info exists report_array(result)] } {
      append html_body [ create_html_text "finished: [clock format $report_array(end)]" 1 ]
      append html_body [ create_html_text "result: $report_array(result)" 1 ]
   } else {
      append html_body [ create_html_text "yet not finished" 1 ]
   }
   
   if { [info exists report_array(task_0,name)] } {
      append html_body [ create_html_text "<H1>Tasks:</H1>" 1 ]
      
      set html_table(1,BGCOLOR) "#3366FF"
      set html_table(1,FNCOLOR) "#66FFFF"
   
      set html_table(COLS) 5
      set html_table(1,1) "Name"
      set html_table(1,2) "Host"
      set html_table(1,3) "Arch"
      set html_table(1,4) "State"
      set html_table(1,5) "Details"
      
      set row_count 1
      for { set task_nr 0 } { [info exists report_array(task_$task_nr,name)] } { incr task_nr 1 } {
         incr row_count 1
         
         if { $report_array(task_$task_nr,status) == "error" } {
            set html_table($row_count,BGCOLOR) "#CC0000"
            set html_table($row_count,FNCOLOR) "#FFFFFF"
         } else {
            set html_table($row_count,BGCOLOR) "#009900"
            set html_table($row_count,FNCOLOR) "#FFFFFF"
         }
         if { [info exists report_array(task_$task_nr,link)] } {
            set html_table($row_count,1) [create_html_link $report_array(task_$task_nr,name) $report_array(task_$task_nr,link)]
         } else {
            set html_table($row_count,1) $report_array(task_$task_nr,name)
         }
         set html_table($row_count,2) $report_array(task_$task_nr,host)
         set html_table($row_count,3) [resolve_arch $report_array(task_$task_nr,host)]
         set html_table($row_count,4) $report_array(task_$task_nr,status)
         set html_table($row_count,5) [ create_html_link $report_array(task_$task_nr,relative_filename) "./$report_array(task_$task_nr,relative_filename)"]
      }
      set html_table(ROWS) $row_count

      append html_body [ create_html_table html_table ]
   }  else {
      append html_body [ create_html_text "No Tasks available" 1 ]
   }
   
   foreach message $report_array(messages) {
      append html_body [ create_html_text "$message" 0 ]
   }
   
   update_compile_html_output $html_body
   
}

#****** report_procedures/get_result_*() ***************************************
#  NAME
#     get_result_*() -- string representation of test result
#
#  SYNOPSIS
#     get_result_* { }
#
#  FUNCTION
#     Return the string representation of test result.
#
#  SEE
#     get_result_ok()
#     get_result_failed()
#     get_result_skipped()
#
#  SEE ALSO
#     get_color_ok()
#     get_color_failed()
#     get_color_skipped()
#
#*******************************************************************************
proc get_result_failed {} {
   return "error"
}

proc get_result_ok {} {
   return "success"
}

proc get_result_skipped {} {
   return "skipped"
}

#****** report_procedures/get_color_*() ****************************************
#  NAME
#     get_color_*() -- color which represents a test result
#
#  SYNOPSIS
#     get_color_* { }
#
#  FUNCTION
#     Return the color representation of test result. (green x red x yellow)
#
#  SEE
#     get_color_ok()
#     get_color_failed()
#     get_color_skipped()
#
#  SEE ALSO
#     get_result_ok()
#     get_result_failed()
#     get_result_skipped()
#
#*******************************************************************************
proc get_color_failed {} {
   return "CC0000"
}

proc get_color_ok {} {
   return "00CC00"
}

proc get_color_skipped {} {
   return "CCCC00"
}

#****** report_procedures/get_result() *****************************************
#  NAME
#     get_result() -- get the test result
#
#  SYNOPSIS
#     get_result { result }
#
#  INPUTS
#     result -- ok:       0, [get_result_ok]
#            -- failed:   <> 0, [get_result_failed]
#            -- skipped:  [get_result_skipped]
#
#  FUNCTION
#     Return the test result
#
#  SEE ALSO
#     get_result_ok()
#     get_result_failed()
#     get_result_skipped()
#
#*******************************************************************************
proc get_result {result} {
   if {$result == [get_result_ok]} {
   } elseif {$result == [get_result_failed]} {
   } elseif {$result == [get_result_skipped]} {
   } elseif {$result == 0} {
      set result [get_result_ok]
   } else {
      set result [get_result_failed]
   }
   return $result
}

#****** report_procedures/register_test() **************************************
#  NAME
#     register_test() -- register test which belongs to the currently run task
#
#  SYNOPSIS
#     register_test { name report_array task_nr }
#
#  FUNCTION
#     Register test $name which belongs to the currently run task
#
#  INPUTS
#     name           -- the name of the test
#     report_array   -- report object
#     task_nr_var    -- variable name where the procedure store the number of
#                       currently running task
#
#  RESULT
#      test id
#
#  SEE ALSO
#     test_report()
#
#*******************************************************************************
proc register_test {name report_array task_nr_var} {
   upvar $report_array report
   upvar $task_nr_var curr_task_nr

   set curr_task_nr ""
   if {![info exists report]} {
      return ""
   }

   set curr_task_nr [expr $report(task_count) - 1]
   set test_id $report(task_$curr_task_nr,test_count)
   incr report(task_$curr_task_nr,test_count) 1
   if {[string length $test_id] == 1} {
      set test_id_print 0$test_id
   } else {
      set test_id_print $test_id
   }
   set report(task_$curr_task_nr,$test_id_print,name) $name
   return $test_id_print
}

#****** report_procedures/test_report() ****************************************
#  NAME
#     test_report() -- report the result/value of the test
#
#  SYNOPSIS
#     test_report { report_array curr_task_nr task_test_id type value }
#
#  FUNCTION
#     Report the $value of $type
#     type -> name
#             result
#             value
#
#  INPUTS
#     report_array   -- report object
#     *curr_task_nr  -- the number of currently running task
#     *task_test_id  -- test id
#     type           -- result x value
#     value          -- reported value
#     * returned by register_test()
#
#  SEE ALSO
#     register_test()
#
#*******************************************************************************
proc test_report {report_array curr_task_nr task_test_id type value} {
   upvar $report_array report
   if {[info exists report]} {
      set task_nr task_$curr_task_nr
      switch -- $type {
         value {
            if {[info exists report($task_nr,$task_test_id,$type)]} {
               append report($task_nr,$task_test_id,$type) "\n$value"
            } else {
               set report($task_nr,$task_test_id,$type) $value
            }
         }
         result {
            if {[check_is_interactive]} {
               if {"$value" == "[get_result_failed]"} {
                  set name [get_test_name report $task_nr $task_test_id]
                  set help_info { "Test failed. Repeat the test manually"
                                  "and report the result:" }
                  set config($name) "[get_result_failed]"
                  set config($name,desc) "Test name: $name"
                  array set res {}
                  set res([get_result_ok]) ""
                  set res([get_result_failed]) ""
                  set res([get_result_skipped]) ""
                  set param(screen_clear) 0
                  set value [config_generic 0 $name config $help_info "choice" 0 1 res param]
                  if {![info exists report($task_nr,$task_test_id,value)]} {
                     set report($task_nr,$task_test_id,value) ""
                  }
                  append report($task_nr,$task_test_id,value) "\nUser check."
               }
            }
            set report($task_nr,$task_test_id,$type) $value
         }
      }
   }
}

#****** report_procedures/get_test_id() ****************************************
#  NAME
#     get_test_id() -- get the test id
#
#  SYNOPSIS
#     get_test_id { item }
#
#  FUNCTION
#     Get the test id from the reported item
#     task_$task_id,$task_test_id,*
#                   --------------
#
#  INPUTS
#     item
#
#  RESULT
#     test id
#
#  SEE ALSO
#     register_test()
#     test_report()
#
#*******************************************************************************
proc get_test_id {item} {
   set beg_ind [string first , $item]
   set help_item [string range $item [incr beg_ind 1] end]
   set end_ind [string first , $help_item]
   set result [string range $item $beg_ind [expr $end_ind + [incr beg_ind -1]]]
   return $result
}

#****** report_procedures/get_test_host() **************************************
#  NAME
#     get_test_host() -- get the host for the currently running task
#
#  SYNOPSIS
#     get_test_host { report_array curr_task_id }
#
#  FUNCTION
#     Get the host for the currently running task
#
#  INPUTS
#     report_array  -- report object
#     curr_task_id  -- currently running task id
#
#  RESULT
#     test host
#
#  SEE ALSO
#     register_test()
#     test_report()
#
#*******************************************************************************
proc get_test_host {report_array curr_task_id} {
   upvar $report_array report
   if {[info exists report]} {
      return $report(task_$curr_task_id,host)
   } else {
      return ""
   }
}

#****** report_procedures/get_test_name() **************************************
#  NAME
#     get_test_name() -- get the test name
#
#  SYNOPSIS
#     get_test_name { report_array curr_task_id test_id }
#
#  FUNCTION
#     Get the test name
#
#  INPUTS
#     report_array  -- report object
#     curr_task_id  -- currently running task id
#     test_id       -- test id
#
#  RESULT
#     test name
#
#  SEE ALSO
#     register_test()
#     test_report()
#
#*******************************************************************************
proc get_test_name {report_array curr_task_id test_id} {
   upvar $report_array report

   if {[string length $test_id] == 1} {
      set test_id 0$test_id
   }
   set test_name "unknown"
   if {[info exists report($curr_task_id,$test_id,name)]} {
      set test_name $report($curr_task_id,$test_id,name)
   }
   return $test_name
}

#****** report_procedures/report_table_line() **********************************
#  NAME
#     report_table_line() -- line
#
#  SYNOPSIS
#     report_table_line { lng }
#
#  FUNCTION
#     Return a line of length $lng for report
#
#  INPUTS
#     lng    -- line length
#
#*******************************************************************************
proc report_table_line {lng} {
   set line ""
   for {set i 0} {$i <= $lng} {incr i 1} {
      append line "-"
   }
   return $line
}

#****** report_procedures/format_fixed_width() *********************************
#  NAME
#     format_fixed_width() -- fixed width text
#
#  SYNOPSIS
#     format_fixed_width { text max_length }
#
#  FUNCTION
#     Return a text with the fixed length
#
#  INPUTS
#     text       -- text to format
#     max_length -- the length of text
#
#  RESULT
#     formated text
#*******************************************************************************
proc format_fixed_width {text max_length} {

   set lng [string length $text]
   if {$lng < $max_length} {
      for {set i $lng} {$i < $max_length} {incr i} {
         append text " "
      }
   }
   return $text
}

#****** report_procedures/get_task_result() ************************************
#  NAME
#     get_task_result() -- get the result of tests
#
#  SYNOPSIS
#     get_task_result { report_array task_nr {full true} }
#
#  FUNCTION
#     Get the result of tests of task $task_nr
#
#  INPUTS
#     report_array -- report object
#     task_nr      -- task identifier (task_$task_id)
#
#  RESULT
#     test_name1               [get_result_ok]/[get_result_failed]/[get_result_skipped]
#     place for the test result
#     ...
#*******************************************************************************
proc get_task_result {report_array task_nr} {
   upvar $report_array report

   set output ""
   set filename $report($task_nr,filename)
   set fp [open $filename r]
   set output [string trim [read $fp]]
   close $fp
   if {$output == ""} {
      set test_count $report($task_nr,test_count)
      if {$test_count == 0} {
         return $output
      }
      for {set i 0} {$i < $test_count} {incr i 1} {
         if {$i < 10} {
            set id 0$i
         } else {
            set id $i
         }
         append output [format_fixed_width $report($task_nr,$id,name) 25]
         append output $report($task_nr,$id,result)\n
         if {[info exists report($task_nr,$id,value)]} {
            append output $report($task_nr,$id,value)\n
         }
      }
   }

   return $output
}

#****** report_procedures/get_test_count() *************************************
#  NAME
#     get_test_count() -- get the result of tests
#
#  SYNOPSIS
#     get_test_count { report_array task_nr {err_var errs} {skipped_var skipps} }
#
#  FUNCTION
#     Get the result of tests of task $task_nr.
#
#  INPUTS
#     report_array         -- report object
#     task_nr              -- task identifier (task_$task_id)
#     {err_var errs}       -- variable for failed tests
#     {skipped_var skipps} -- variable for skipped tests
#
#  RESULT
#     test count
#
#*******************************************************************************
proc get_test_count {report_array task_nr {err_var errs} {skipped_var skipps}} {
   upvar $report_array report
   upvar $err_var test_errors
   upvar $skipped_var test_skipped

   set test_errors ""
   set test_skipped ""

   set test_count 0
   set output ""
   set filename $report($task_nr,filename)
   if {[file isfile $filename] && [file size $filename] != 0} {
      set fp [open $filename r]
      set output [string trim [read $fp]]
      close $fp
      foreach line [split $output "\n"] {
         if {[string match "*[get_result_failed]" $line] == 1} {
            incr test_count 1
            lappend test_errors [lindex $line 0]
         } elseif {[string match "*[get_result_skipped]" $line] == 1} {
            incr test_count 1
            lappend test_skipped [lindex $line 0]
         } elseif {[string match "*[get_result_ok]" $line] == 1} {
            incr test_count 1
         }
      }
   } else {
      if {[info exists report($task_nr,test_count)]} {
         set test_count $report($task_nr,test_count)
         if {$test_count != 0} {
            for {set i 0} {$i < $test_count} {incr i 1} {
               if {$i < 10} {
                  set id 0$i
               } else {
                  set id $i
               }
               set result $report($task_nr,$id,result)
               if {$result == [get_result_failed]} {
                  lappend test_errors [get_test_name report $task_nr $id]
               } elseif {$result == [get_result_skipped]} {
                  lappend test_skipped [get_test_name report $task_nr $id]
               }
            }
         }
      }
   }

   return $test_count
}

#****** report_procedures/print_task_report() **********************************
#  NAME
#     print_task_report() -- print the task report
#
#  SYNOPSIS
#     print_task_report { report_array task_id }
#
#  FUNCTION
#     Print the result of tests of task $task_nr.
#
#  INPUTS
#     report_array         -- report object
#     task_id              -- task identifier
#
#  SEE ALSO
#     get_task_result()
#
#*******************************************************************************
proc print_task_report {report_array task_id} {
   upvar $report_array report

   set task_nr task_$task_id
   set result [get_task_result report $task_nr]
   set host [get_test_host report $task_id]

   ts_log_frame
   ts_log_fine "Report for basic test on $host/[resolve_arch $host]:"
   ts_log_fine "Number of tests ran: [get_test_count report $task_nr test_errors test_skipped]"
   ts_log_fine "Number of failed tests: [llength $test_errors]"
   ts_log_fine "Number of skipped tests: [llength $test_skipped]"
   ts_log_frame
   ts_log_fine $result
}

#****** report_procedures/get_all_tasks_result() *******************************
#  NAME
#     get_all_tasks_result() -- get the result of all tasks
#
#  SYNOPSIS
#     get_all_tasks_result { report_array }
#
#  FUNCTION
#     Get the result of all tasks
#
#  INPUTS
#     report_array -- report object
#
#  RESULT
#     Host F|T <Failed tests list>
#     ...
#*******************************************************************************
proc get_all_tasks_result {report_array} {
   upvar $report_array report

   set result ""
   set host_count 0
   set hosts ""
   for {set i 0} {$i < $report(task_count)} {incr i 1} {
      set task_nr task_$i
      set host $report($task_nr,host)
      append result "$host "
      set total_count [get_test_count report $task_nr test_errors test_skipped]
      append result "[llength $test_errors]|[llength $test_skipped]|$total_count \
                                                   [string trim $test_errors]\n"
   }

   return $result
}

#****** report_procedures/print_all_tasks_report() *****************************
#  NAME
#     print_all_tasks_report() -- print all tasks report
#
#  SYNOPSIS
#     print_all_tasks_report { report_array }
#
#  FUNCTION
#     Print all tasks report
#
#  INPUTS
#     report_array -- report object
#
#  RESULT
#     -------------------------------------------
#     Hostname | F|S|T  | Failed tests
#     -------------------------------------------
#     hostname1| 0|2|22 |-
#     -------------------------------------------
#     hostname2| 1|0|2  |install
#     ...
#*******************************************************************************
proc print_all_tasks_report {report_array} {
   upvar $report_array report

   set test_host_list [report_get_host_list report]

   ts_log_frame
   ts_log_fine "$report(name):"
   ts_log_fine "Number of available tasks: $report(task_count)"
   ts_log_fine "Task list: [join $test_host_list ", "]"
   ts_log_frame
   set header "[format_fixed_width Task 20] | [format_fixed_width F|S|T 10] | Failed tests"
   ts_log_fine $header
   ts_log_frame FINE [report_table_line 85]

   set result [get_all_tasks_result report]
   foreach res [split $result "\n"] {
      set host [lindex $res 0]
      set status [lindex $res 1]
      set res [replace_string $res $host "[format_fixed_width $host 20] |"]
      set res [replace_string $res $status "[format_fixed_width $status 10] |"]
      ts_log_fine $res
      ts_log_frame FINE [report_table_line 85]
      append result "\n"
   }

}

#****** report_procedures/print_all_tasks_report() *****************************
#  NAME
#     report_get_host_list() -- get the list of all hosts
#
#  SYNOPSIS
#     report_get_host_list { report_array }
#
#  FUNCTION
#     Get the list of all hosts corresponding to report tasks
#
#  INPUTS
#     report_array -- report object
#
#  RESULT
#     host list
#
#*******************************************************************************
proc report_get_host_list {report_array} {
   upvar $report_array report

   set host_list ""
   for {set i 0} {$i < $report(task_count)} {incr i 1} {
      lappend host_list $report(task_$i,host)
   }
   return $host_list
}

#****** report_procedures/generate_html_report() *******************************
#  NAME
#     generate_html_report() -- generate html report of test
#
#  SYNOPSIS
#     generate_html_report { report_array }
#
#  FUNCTION
#     Generate html report of test and save ot to the file $report(filename)
#
#  INPUTS
#     report_array -- report object
#
#  RESULT
#     report name:
#     =============
#     header
#
#    cluster configuration

#    table of results

#    task result (for each host)
#    -----------
#    ----------------------------------
#    host1:               arch1
#    Test count:          test_count
#    Failed tests:        test_errors
#    Skipped tests:       test_skipped
#    -----------------------------------
#    test_name1               [get_result_ok]/[get_result_failed]/[get_result_skipped]
#    place for the test result
#    ...
#    ----------------------------------
#    host2:               arch2
#    ...

# *test_result($task_nr,status) [get_result_ok]/[get_result_failed]/[get_result_skipped]
# *test_result($task_nr,host) hostname
#  test_result($task_nr,spooling) spooling_method
# *test_result($task_nr,$test_id,name) name
# *test_result($task_nr,$test_id,result) [get_result_ok]/[get_result_failed]/[get_result_skipped]
#  test_result($task_nr,$test_id,value) result
# * ... always reported
#
#  SEE ALSO
#     report_procedures/generate_html_report_header()
#     report_procedures/generate_html_report_table()
#     report_procedures/generate_html_report_task()
#
#*******************************************************************************
proc generate_html_report {report_array} {
   global ts_config CHECK_HTML_DIRECTORY

   if {$CHECK_HTML_DIRECTORY == ""} {
      return
   }
   upvar $report_array report
   set filename $report(filename)

   # we don't want to center report
   set center false

   set content ""
   append content [generate_html_report_header report]
   append content [generate_html_report_table report]
   append content [create_html_text "\n"]
   append content [generate_html_report_task report]

   set headliner $report(name)
   generate_html_file $filename $headliner $content 0 0 false

}

#****** report_procedures/generate_html_report_header() ************************
#  NAME
#     generate_html_report_header() -- generate html header
#
#  SYNOPSIS
#     generate_html_report_header { report_array }
#
#  FUNCTION
#     Generate html header for report
#
#  INPUTS
#     report_array -- report object
#
#  RESULT
#    Start time:          $start_time
#    End time:            $end_time
#    *arch1:              host1 host2 host3
#    *arch2:              host4 host5
#    ...
#    * color depends on status
#
#*******************************************************************************
proc generate_html_report_header {report_array} {
   global ts_config
   upvar $report_array report

   # we don't want to center report
   set center false

   set content ""
   set header_list ""
   if {[info exists report(end)]} {
      lappend header_list "Last Updated: [clock format $report(end)]"
      lappend header_list "Status: finished"
   } else {
      lappend header_list "Last Updated: [clock format $report(start)]"
      lappend header_list "Status: running"
      set cur_task_id [expr $report(task_count) - 1]
      if {[info exists report(task_$cur_task_id,spooling)]} {
         lappend header_list "Current host: $report(task_$cur_task_id,host), $report(task_$cur_task_id,spooling)"
      } else {
         lappend header_list "Current host: $report(task_$cur_task_id,host)"
      }
   }

   if {"$report(messages)" != ""} {
      set msg $report(messages)
      set msg [replace_string $msg "{" ""]
      set msg [replace_string $msg "}" ""]
      lappend header_list $msg
   }
   append content [generate_html_report_formated_text $header_list]

   if {[info exists report(result)]} {
      if {$report(result) == [get_result_ok]} {
         set color [get_color_ok]
      } else {
         set color [get_color_failed]
      }
   }
   append content [create_html_line 2 30% left]

   return $content
}

#****** report_procedures/generate_html_report_formated_text() *****************
#  NAME
#     generate_html_report_formated_text() -- generate html formatted text
#
#  SYNOPSIS
#     generate_html_report_header { report_array }
#
#  FUNCTION
#     Generate html formatted text
#
#  INPUTS
#     sge_info_list -- the list of values
#
#  RESULT
#     parameter1:         value1
#     parameter2:         value2
#     ...
#
#*******************************************************************************
proc generate_html_report_formated_text {sge_info_list} {
   global ts_config

   # we don't want to center report
   set center false

   set content ""
   foreach sge_info $sge_info_list {
      set ind [string first ":" $sge_info]
      if {$ind >=0} {
         set sge_param [string range $sge_info 0 $ind]
         set sge_value [string range $sge_info [incr ind 1] end]
      } else {
         set sge_param $sge_info
         set sge_value ""
      }
      append content [create_html_non_formated_text \
                        "[format_fixed_width $sge_param 21] $sge_value" $center]
   }
   return $content
}

#****** report_procedures/generate_html_report_table() *************************
#  NAME
#     generate_html_report_table() -- generate html task report table
#
#  SYNOPSIS
#     generate_html_report_table { report_array }
#
#  FUNCTION
#     Generate html task report table
#
#  INPUTS
#     report_array -- report object
#
#  RESULT
#     Host     | Arch  | F|T  | Failed tests
#     -------------------------------------------
#     hostname1| arch1 | 0|22 |-
#     -------------------------------------------
#     hostname2| arch2 | 1|2  |install
#     ...
#
#*******************************************************************************
proc generate_html_report_table {report_array} {
   global ts_config
   upvar $report_array report

   # we don't want to center report
   set center false

   set content ""

   set host_table(COLS)       5
   set host_table(ROWS)       [expr $report(task_count) + 1]
   set host_table(1,BGCOLOR)  "#3366FF"
   set host_table(1,FNCOLOR)  "#66FFFF"
   set host_table(1,1)        "Host"
   set host_table(1,2)        "Arch"
   set host_table(1,3)        "Failed|Skipped|Total"
   set host_table(1,4)        "Failed tests"
   set host_table(1,5)        "Duration/Started"
   set ind 1
   for {set i 0} {$i < $report(task_count)} {incr i 1} {
      incr ind 1
      set task_nr task_$i
      set host $report($task_nr,host)
      set status $report($task_nr,status)
      set host_display $host
      if {[info exists report($task_nr,spooling)]} {
         append host_display "_$report($task_nr,spooling)"
      }
      set test_count [get_test_count report $task_nr test_errors test_skipped]
      if {$status == [get_result_ok]} {
         set host_table($ind,BGCOLOR)  [get_color_ok]
      } elseif {$status == [get_result_failed]} {
         set host_table($ind,BGCOLOR)  [get_color_failed]
      } elseif {$status == [get_result_skipped]} {
         set host_table($ind,BGCOLOR)  [get_color_skipped]
      } else {
         set host_table($ind,BGCOLOR)  "#FFFFFF"
      }
      set host_table($ind,FNCOLOR)  "#000000"
      set host_table($ind,1)   [create_html_link $host_display "#${host_display}_label"]
      set arch [resolve_arch $host]
      set arch_config [host_conf_get_arch $host]
      if {"$arch" == "$arch_config"} {
         set host_table($ind,2) "$arch"
      } else {
         set host_table($ind,2) "$arch_config/$arch"
      }
      set host_table($ind,3)   "[llength $test_errors]|[llength $test_skipped]|$test_count"
      set err_links ""
      foreach err $test_errors {
         append err_links "[create_html_link $err #${host_display}_label_${err}] "
      }
      set host_table($ind,4)   $err_links
      if {[info exists report($task_nr,finish)]} {
         set host_table($ind,5) "[format %.2f \
           [expr ($report($task_nr,finish) - $report($task_nr,date))/60.0]] min"
      } else {
         set host_table($ind,5) [clock format \
                              $report($task_nr,date) -format "%D %H:%M:%S"]
      }
   }

   append content [create_html_table host_table 0 LEFT false]
   unset host_table

   return $content
}

#****** report_procedures/generate_html_report_task() **************************
#  NAME
#     generate_html_report_task() -- generate html report for all tasks
#
#  SYNOPSIS
#     generate_html_report_task { report_array }
#
#  FUNCTION
#     Generate html report for all tasks
#
#  INPUTS
#     report_array -- report object
#
#  RESULT
#     ----------------------------------
#     host1:               arch1
#     Started:             start time
#     Test count:          test_count
#     Failed tests:        test_errors
#     Skipped tests:       test_skipped
#     -----------------------------------
#     test result
#     ----------------------------------
#     host2:               arch2
#     ...
#
#*******************************************************************************
proc generate_html_report_task {report_array} {
   global ts_config
   upvar $report_array report

   set filename $report(filename)

   # we don't want to center report
   set center false

   set content ""
   # Test reports for each host
   for {set i 0} {$i < $report(task_count)} {incr i 1} {
      set task_nr task_$i
      set host $report($task_nr,host)
      set status $report($task_nr,status)
      set test_count [get_test_count report $task_nr test_errors test_skipped]
      if {$test_count == 0} {
         continue
      }
      if {[info exists report($task_nr,spooling)]} {
         set spooling $report($task_nr,spooling)
         append content [create_html_target ${host}_${spooling}_label]
      } else {
         append content [create_html_target ${host}_label]
      }
      append content [create_html_line 2 80% left]

      set host_info_list ""
      if {[info exists report($task_nr,spooling)]} {
         set spooling $report($task_nr,spooling)
         lappend host_info_list "<b>$host, $spooling: [resolve_arch $host]</b>"
      } else {
         lappend host_info_list "<b>$host: [resolve_arch $host]</b>"
      }
      lappend host_info_list "Started: [clock format \
                            $report($task_nr,date) -format "%D %H:%M:%S"]"
      lappend host_info_list "Finished: [clock format \
                          $report($task_nr,finish) -format "%D %H:%M:%S"]"
      lappend host_info_list "Duration: [format %.2f \
           [expr ($report($task_nr,finish) - $report($task_nr,date))/60.0]] min"
      lappend host_info_list "Test count: $test_count"
      lappend host_info_list "Failed tests: [llength $test_errors]"
      lappend host_info_list "Skipped tests: [llength $test_skipped]"
      if {$status == [get_result_ok]} {
         set color [get_color_ok]
      } elseif {$status == [get_result_skipped]} {
         set color [get_color_skipped]
      } else {
         set color [get_color_failed]
      }
      lappend host_info_list "<b>Result: $status</b>"
      append content [generate_html_report_formated_text $host_info_list]
      append content [create_html_line 1 20% left]
      # test_name1               [get_result_ok]/[get_result_failed]/[get_result_skipped]
      # place for the test result
      # ...
      set result [get_task_result report $task_nr]
      foreach line [split $result "\n"] {
         set line [string trim $line]
         if {[string match "STATUS:*|STARTED:*|FINISHED:*" $line]} {
            continue
         }
         if {[string match "*[get_result_ok]" $line]} {
            set color [get_color_ok]
         } elseif {[string match "*[get_result_failed]" $line]} {
            set err [replace_string [lindex $line 0] ":" ""]
            if {[info exists report($task_nr,spooling)]} {
               set spooling $report($task_nr,spooling)
               append content [create_html_target ${host}_${spooling}_label_${err}]
            } else {
               append content [create_html_target ${host}_label_${err}]
            }
            append content [create_html_link "Back to the top" "[file tail $filename]"]
            set color [get_color_failed]
         } elseif {[string match "*[get_result_skipped]" [string trim $line]]} {
            set color [get_color_skipped]
         } else {
            set color ""
         }
         append content [create_html_non_formated_text $line false $color]
      }
      append content [create_html_link "Back to the top" "[file tail $filename]"]
   }

   return $content
}

