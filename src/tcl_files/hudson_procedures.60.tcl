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
#  Copyright: 2009 by Sun Microsystems, Inc.
#
#  All Rights Reserved.
#
##########################################################################
#___INFO__MARK_END__


proc unicode2ascii { unicode_text } {
   set res ""
   foreach char [split $unicode_text ""] {
      scan $char %c acsii_ord
      #Only basic chars (\u001b causes problems for Junit xml parser)
      if {$acsii_ord > 31 && $acsii_ord < 128 || $acsii_ord == 10 || $acsii_ord == 13} {
         append res $char
      } else {
         set replacement ";u[format %4.4X $acsii_ord];"
         append res $replacement
      }
   }
   return $res
}

#Seems that the failure tag parsing is more strict!
proc failure2ascii { unicode_text } {
   set res ""
   foreach char [split $unicode_text ""] {
      switch -- $char {
         "<" {
            append res "&lt;"
            continue
         }
         ">" {
            append res "&gt;"
            continue
         }
         "&" {
            append res ";AND;"
            continue
         }
      }
      scan $char %c acsii_ord
      #Only basic chars (\u001b causes problems for Junit xml parser)
      if {$acsii_ord > 31 && $acsii_ord < 128 || $acsii_ord == 10 || $acsii_ord == 13} {
         append res $char
      } else {
         set replacement ";u[format %4.4X $acsii_ord];"
         append res $replacement
      }
   }
   return $res
}


proc generate_xml_junit_report_private { file_name package_name test_name duration output failure failure_type {skipped 0} } {
   global CHECK_ACT_LEVEL ts_config
   
   #Generate the report
   set report "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
   append report "<testsuite>\n"
   append report "<testcase classname=\"RUNLEVEL($CHECK_ACT_LEVEL)_${package_name}\" name=\"$test_name\" time=\"$duration\">\n"
   if {[string length $failure] > 0} {
      append report "<failure type=\"$failure_type\">[failure2ascii $failure]</failure>\n"
   }
   if {$skipped == 1} {
      append report "<skipped/>\n"
   }
   append report "</testcase>\n"
   append report "<system-out><!\[CDATA\[[unicode2ascii $output]\]\]></system-out>\n"
   append report "<system-err><!\[CDATA\[\]\]></system-err>\n"
   append report "</testsuite>\n"

   #ts_log_info "File is: $file_name"
   #ts_log_info "Generating XML report: $package_name $test_name $duration"
   
   set cur_line 1
   foreach line [split $report "\n"] {
      #Ensure the line is has really only UTF-8 characters (sometimes it's not e.g.:'^[')
      #But really we accept only ASSCI and reformat enything else
      set report_array($cur_line) $line
      incr cur_line 1
   }
   incr cur_line -1
   set report_array(0) $cur_line
   
   #Write it to the result file
   save_file $file_name report_array
}


proc generate_xml_junit_report { package_name test_name duration output failure failure_type {skipped 0} } {
   global CHECK_ACT_LEVEL ts_config
   global ts_log_config
   global env
   
   #Check what logging level you are running, more than 3 (INFO) we generate reports per level as well
   set log_level $ts_log_config(logging)
   
   #Setup the target XML report file name
   set res_file_prefix $ts_config(results_dir)/TEST-$package_name.${test_name}_Level-$CHECK_ACT_LEVEL

   #Set the retry index
   set retry_index 0
   if {[info exists env(TS_RUN_REPEAT_INDEX)]} {
      set retry_index $env(TS_RUN_REPEAT_INDEX)
      ts_log_info "FINISHED $package_name.${test_name} TS_RUN_REPEAT_INDEX=$retry_index"
   }

   #Setup which lines of what level to remove
   set to_remove {}                       ;#{FINE| FINER| FINEST|}
   for {set i 4} {$i <= $log_level} {incr i} {
      lappend to_remove "[ts_log_get_level_name $i]|"
   }
   
   set original_test_name $test_name
   
   #Generating per level skipped reports is useless , but it will keep the total number of tests constant
   #if {$skipped == 0} {
      #Generate reports per INFO to CURRENT_LOG_LEVEL-1 levels for convinience
      for {set lev 3} {$lev < $log_level} {incr lev} {
         set test_name ${original_test_name}
         set lev_str [ts_log_get_level_name $lev]
         if {$retry_index > 0} {
            set test_name ${original_test_name}_RETRY-${retry_index}
         }
         set test_name ${test_name}_${lev_str}
         set level_output ""
         foreach out_line [split $output "\n"] {
            set skip 0
            foreach remove_level $to_remove {          
               if {[string first $remove_level $out_line] != -1} {            
                  set skip 1
                  break
               }
            }
            if {$skip == 1} {
               continue
            } else {
               append level_output "${out_line}\n"
            }
         }
         #The "helper" reports will always succeed, so that the number of fialed tests is the exact number of failures
         generate_xml_junit_report_private ${res_file_prefix}_${lev_str}_${retry_index}.xml $package_name $test_name 0 $level_output $failure $failure_type $skipped
         set to_remove [lrange $to_remove 1 end]
      }
   #}
   #Finally the original report (CURRENT_LOG_LEVEL)
   set res_file ${res_file_prefix}_[ts_log_get_level_name $log_level]
   set test_name ${original_test_name}
   if {$retry_index > 0} {
      set test_name ${test_name}_RETRY-${retry_index}
      #TODO LP: Comment out once we don't need all runs (keep just the last one)
      set res_file ${res_file}_${retry_index}
   }
   generate_xml_junit_report_private ${res_file}.xml $package_name ${test_name}_[ts_log_get_level_name $log_level] $duration $output $failure $failure_type $skipped
}

proc generate_skipped_xml_junit_report { package_name test_name } {
   generate_xml_junit_report $package_name $test_name 0 "" "" "" 1
}
