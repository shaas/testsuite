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
#****** sge_ar/submit_ar() ******
# 
#  NAME
#     submit_ar -- submit a AR with qrsub
#
#  SYNOPSIS
#     submit_ar { args {on_host ""} {as_user ""} {raise_error 1}}
#
#  FUNCTION
#     This procedure will submit a AR.
#
#  INPUTS
#     args                - a string of qrsub arguments/parameters
#     {on_host ""}        - execute on different host
#     {as_user ""}        - execute as user
#     {raise_error 1}     - create error message if something failes
#
#  RESULT
#     This procedure returns:
#     
#     ar_id   of array or ar_id if submit was successfull (value > 1)
#        -1   general error
#        -2   if usage was printed on -help or commandfile argument
#        -3   if usage was printed NOT on -help or commandfile argument
#        -8   unknown resource - error
#        -9   can't resolve hostname - error
#       -10   resource not requestable - error
#       -13   unkown option - error
#
#      -100   on error 
#     
#
#*******************************
proc submit_ar {args {on_host ""} {as_user ""} {raise_error 1}} {
   # failure messages from jobs common valiation part:
   set messages(-3)       "*[translate_macro MSG_GDI_USAGE_USAGESTRING] qrsub*"
   set messages(-8)       "*[translate_macro MSG_SGETEXT_UNKNOWN_RESOURCE_S "*"]*"
   set messages(-9)       "*[translate_macro MSG_SGETEXT_CANTRESOLVEHOST_S "*"]*"
   set messages(-10)      "*[translate_macro MSG_SGETEXT_RESOURCE_NOT_REQUESTABLE_S "*"]*"

   set messages(-12)      "*[translate_macro MSG_SGETEXT_NO_ACCESS2PRJ4USER_SS "*" "*"]*"
   set messages(-13)      "*[translate_macro MSG_ANSWER_UNKOWNOPTIONX_S "*"]*"
   set messages(-16)      "*[translate_macro MSG_FILE_ERROROPENINGXY_SS "*" "*"]*"
   set messages(-17)      "*[translate_macro MSG_GDI_KEYSTR_MIDCHAR_SC [translate_macro MSG_GDI_KEYSTR_COLON] ":"]*"
   set messages(-18)      "*[translate_macro MSG_QCONF_ONLYONERANGE]*"
   set messages(-21)      "*[translate_macro MSG_GDI_INITIALPORTIONSTRINGNODECIMAL_S "*"] *"
   set messages(-23)      "*[translate_macro MSG_CPLX_WRONGTYPE_SSS "*" "*" "*"]*"
   set messages(-30)      "*[translate_macro MSG_GDI_KEYSTR_MIDCHAR_SC "*" "*"]*"
   set messages(-31)      "*[translate_macro MSG_ANSWER_INVALIDOPTIONARGX_S "*"]*"
   set messages(-32)      "*[translate_macro MSG_PARSE_INVALIDOPTIONARGUMENT]*"
   set messages(-33)      "*[translate_macro MSG_STREE_USERTNOACCESS2PRJ_SS "*" "*"]*"
   set messages(-36)      "*[translate_macro MSG_PARSE_NOOPTIONARGUMENT]*"
   set messages(-37)      "*[translate_macro MSG_PARSE_WRONGTIMEFORMATXSPECTODLOPTION_S "*"]*"
   set messages(-38)      "*[translate_macro MSG_ANSWER_WRONGTIMEFORMATEXSPECIFIEDTOAOPTION_S "*"]*"
   set messages(-39)      "*[translate_macro MSG_PARSE_INVALIDDAY]*"
   set messages(-40)      "*[translate_macro MSG_ANSWER_WRONGTIMEFORMATEXSPECIFIEDTODOPTION_S "*"]*"

   # failure messages from AR specific valiation part:
   set messages(-51)      "*[translate_macro MSG_AR_QUEUEDISABLEDINTIMEFRAME "*"]*"
   set messages(-52)      "*[translate_macro MSG_AR_QUEUEDNOPERMISSIONS "*"]*"
   set messages(-53)      "*[translate_macro MSG_AR_MAXARSPERCLUSTER_U "*"]*"
   set messages(-54)      "*[translate_macro MSG_AR_RESERVEDQUEUEHASERROR_SS "*" "*"]*"
   set messages(-55)      "*[translate_macro MSG_AR_MISSING_VALUE_S "*"]*"
   set messages(-56)      "*[translate_macro MSG_AR_START_END_DURATION_INVALID]*"
   set messages(-57)      "*[translate_macro MSG_AR_START_LATER_THAN_END]*"
   set messages(-58)      "*[translate_macro MSG_AR_START_IN_PAST]*"
   set messages(-59)      "*[translate_macro MSG_AR_XISINVALIDARID_U "*"]*"

   # success messages:
   set messages(0)        "*[translate_macro MSG_AR_GRANTED_U "*"]*"
   set messages(1)        "*[translate_macro MSG_JOB_VERIFYFOUNDQ]*"

   set messages(index) ""
   foreach idx [lsort [array names messages]] {
      append messages(index) "$idx "
   }
   
   set output [start_sge_bin "qrsub" $args $on_host $as_user]

   set ret [handle_sge_errors "submit_ar" "qrsub $args" $output messages $raise_error]
   set ret_code $ret

   # some special handling
   switch -exact -- $ret {
      0 {
         set ret_code [submit_ar_parse_ar_id output $messages($ret)]
      }

      -3 {
         if {[string first "help" $args] >= 0 } {
            set ret_code -2
         }
      }
      default {
         set ret_code $ret
      }
   }

   # return job id or error code
   return $ret_code
}


#                                                             max. column:     |
#****** sge_ar/delete_all_ars() ******
# 
#  NAME
#     delete_all_ars -- delete_all_ars
#
#  SYNOPSIS
#     delete_all_ars
#
#  FUNCTION
#     delete_all_ars
#
#*******************************
proc delete_all_ars {} {
   global CHECK_USER

   ts_log_fine "deleting all ar"
   set output [start_sge_bin "qrdel" "-f -u '*' "]

   if {$prg_exit_state == 0} {
      set ret 1
   } else {
      set ret 0
   }

   return $ret
}

#****** sge_ar.62/delete_ar() **************************************************
#  NAME
#     delete_ar() -- ??? 
#
#  SYNOPSIS
#     delete_ar { ar_id {wait_for_end 0} {all_users 0} {on_host ""} 
#     {as_user ""} {raise_error 1} } 
#
#  FUNCTION
#     deletes a advance reservation
#
#  INPUTS
#     ar_id            - advance reservation to delete
#     {wait_for_end 0} - wait for end of ar
#     {all_users 0}    - delete for all users
#     {on_host ""}     - execute qrdel on host
#     {as_user ""}     - execute qrdel as user
#     {raise_error 1}  - send error message
#
#  RESULT
#      -2   general error
#      -1   id does not exist
#      0    deleted advance reservation 
#      1    tagged advance reservation as deleted
#
#  SEE ALSO
#     delete_job
#*******************************************************************************
proc delete_ar {ar_id {wait_for_end 0} {all_users 0} {on_host ""} {as_user ""} {raise_error 1}} {
   set ret 0
   set args ""

   if {$all_users} {
      set args "-u '*'"
   }

   set messages(index) "-3 -2 -1 0 1"
   set messages(-3) [translate_macro MSG_DELETEPERMS_SSU "*" "advance_reservation" $ar_id]
   set messages(-2) [translate_macro MSG_SGETEXT_SPECIFYUSERORID_S "advance_reservation"]
   set messages(-1) [translate_macro MSG_SGETEXT_DOESNOTEXIST_SS "advance_reservation" $ar_id]
   set messages(0) [translate_macro MSG_JOB_DELETEX_SSU "*" "advance_reservation" $ar_id]
   set messages(1) [translate_macro MSG_JOB_REGDELX_SSU "*" "advance_reservation" $ar_id]

   set output [start_sge_bin "qrdel" "$args $ar_id" $on_host $as_user]

   set ret [handle_sge_errors "delete_ar" "qrdel $args $ar_id" $output messages $raise_error]

   if {($prg_exit_state != 0 && $ret >= 0) || ($prg_exit_state == 0 && $ret < 0)} {
      ts_log_severe "qrdel return value and output does not match\nmessage:$output\nreturn_code: $prg_exit_state"
   }

   if {$wait_for_end != 0 && $ret >= 0} {
      ts_log_fine "waiting for end of ar $ar_id"
      set timeout 60
      while {[parse_qrstat $ar_id] == 0} {
         after 1000
         incr timeout -1
         if {$timeout == 0} {
            ts_log_severe "timout waiting for ar end" $raise_error
            set ret -999
            break;
         }
      }
   }
   return $ret
}

#****** sge_ar/submit_ar_parse_ar_id() *******************************
#  NAME
#     submit_ar_parse_ar_id() -- parse ar id from qrsub output
#
#  SYNOPSIS
#     submit_ar_parse_ar_id { output_var } 
#
#  FUNCTION
#     Analyzes qrsub output and parsed the ar id from this output.
#     The qrsub output may contain additional warning messages.
#
#  INPUTS
#     output_var - qrsub output (pass by reference)
#     message    - expected message
#
#  RESULT
#     the job id, or -1 on error
#
#  SEE ALSO
#     sge_ar/submit_ar()
#*******************************************************************************
proc submit_ar_parse_ar_id {output_var message} {
   upvar $output_var output

   set ret -1
   set AR_SUBMITTED_DUMMY [translate_macro MSG_AR_GRANTED_U "*" ]
   set pos [lsearch -exact $AR_SUBMITTED_DUMMY "*"]

   # output might contain multiple lines, e.g. with additional warning messages
   # we have to find the right one
   foreach line [split $output "\n"] {
     if {[string match $message $line]} {
         # read ar id from line
         set ret [lindex $line $pos]
         break
      }
   }

   # we didn't find the expected job start message in qsub output
   # should never happen, as message has been matched before by handle_sge_errors
   if {$ret == -1} {
      ts_log_severe "couldn't find qrsub success message\n$message\nin qrsub output\n$output"
   }

   return $ret
}


#                                                             max. column:     |
#****** sge_ar/parse_qrstat() ***************************************
#
#  NAME
#     parse_qrstat -- parse output of a qrstat -ar ar_id command
#
#  SYNOPSIS
#     parse_qrstat input output 
#
#  FUNCTION
#     Parses the output of a qrstat -ar command. 
#     This parser is capable to parse just output for sigular AR (qrstat with -ar ar_id)
#  
#
#  INPUTS
#     ar_id   - AR id to analyze
#     output  - name of the array in which to return results
#
#  RESULT
#     The TCL array output is filled with the processed data.
#     the arrays index consists of the columnnames (e.g. id, name)
#
#***************************************************************************
#
proc parse_qrstat {ar_id {output qrstat_info}} {
   upvar $output out

   set result [start_sge_bin qrstat "-u '*' -ar $ar_id"]
   if {$prg_exit_state != 0} {
      return -1
   }

   set    match_text(id)                id*
   set    match_text(name)              name*
   set    match_text(owner)             owner* 
   set    match_text(state)             state*
   set    match_text(start_time)        start_time*
   set    match_text(end_time)          end_time*
   set    match_text(duration)          duration*
   set    match_text(submission_time)   submission_time*
   set    match_text(group)             group*
   set    match_text(account)           account*
   set    match_text(resource_list)     resource_list*
   set    match_text(granted_slots_list)   granted_slots_list*
   set    match_text(granted_parallel_environment)   granted_parallel_environment*
   set    match_text(checkpoint_name)   checkpoint_name*
   set    match_text(mail_options)      mail_options*
   set    match_text(mail_list)         mail_list*
   set    match_text(acl_list)          acl_list*
   set    match_text(xacl_list)         xacl_list*
   set    match_text(error_handling)    error_handling*
   set    match_text(master_hard_queue_list)    "master hard queue_list*"
   set    match_text(message)           message*

   set lines [split $result "\n"]
   foreach line $lines {
      foreach name [array names match_text] {
         set pattern "$match_text($name)"

         if {[string match $pattern $line]} {
            set pos [string length $pattern]
            set len [string length $line]
            set value [string trimright [string trimleft [string range $line $pos $len]]]
            set out($name) $value
         }  
      }
   }
   return 0
}

#****** sge_ar/test_parse_qrstat() **********************************************
#  NAME
#     test_parse_qrstat() -- test the parse_qstat function
#
#  SYNOPSIS
#     test_parse_qrstat { ar_id }
#
#  FUNCTION
#     Test function for parse_qrstat.
#     Execute test_parse_qrstat in your testsuite, e.g. by executing
#
#     expect check.exp file <config file> execute_func test_parse_qstat 2 
#
#  INPUTS
#     ar_id - AR id to analyze
#
#
#  SEE ALSO
#     sge_ar/parse_qrstat()
#*******************************************************************************
proc test_parse_qrstat { ar_id } {
   parse_qrstat $ar_id arinfo
   foreach name [array names arinfo] {
      ts_log_fine "$name\t<$arinfo($name)>"
   }
}

#****** sge_ar/parse_qrstat_check() **********************************************
#  NAME
#     parse_qrstat_check() -- test the parse_qstat function
#
#  SYNOPSIS
#     parse_qrstat_check { ar_id, match_values }
#
#  FUNCTION
#     Check function for parse_qrstat.
#
#  INPUTS
#     ar_id - AR id to analyze
#     match_values - an associative array of expected match patterns
#
#  RESULT
#     The  0 .... success in check
#         -1      could not find the AR by input ar_id
#         -2      expected attribute is missing in the qrstat output
#         -3      attribute value does no match expected pattern 
#
#  SEE ALSO
#     sge_ar/parse_qrstat()
#*******************************************************************************
proc parse_qrstat_check { ar_id match_values } {
   upvar $match_values val

   parse_qrstat $ar_id arinfo

   set ret 0
   foreach name [array names val] {
      set pattern "$val($name)"
      set skip [catch { set value   "$arinfo($name)" }]
      if { $skip } {
        ts_log_severe "The expected attribute $name is missing in the result"
        set ret -2
        continue
      }     

      if {[string match $pattern $value]} {
         ts_log_fine "SUCCESSFUL MATCH for attribute $name:\tvalue: $value"         
      } else {
         ts_log_severe "Attribute: $name\tvalue: $value\t DOES NOT MATCH pattern: $pattern"
         set ret -3
      } 
   }
   return $ret 
}


#****** sge_ar/test_parse_qrstat_check() **********************************************
#  NAME
#     test_parse_qrstat_check() -- test the parse_qstat_check function
#
#  SYNOPSIS
#     test_parse_qrstat_check
#
#  FUNCTION
#     Test function for parse_qrstat.
#     Execute test_parse_qrstat in your testsuite, e.g. by executing
#
#     expect check.exp file <config file> execute_func test_parse_qstat_check 
#
#
#  SEE ALSO
#     sge_ar/parse_qrstat()
#*******************************************************************************
proc test_parse_qrstat_check {} {
   global CHECK_USER

   set    args "-a 0801010101 "
   append args "-e 0901010101 "
   append args "-A test_ar_account "
   append args "-ckpt test_ar_ckpt "
   append args "-he yes "
   append args "-l 'h_rt=200,arch=sol*' "
   append args "-m ab "
   append args "-masterq all.q "
   append args "-M sgetest1@sun.com,@deadlineusers "
   append args "-N test_ar_name "
   append args "-w e "
   append args "-pe mytestpe 3 "
   append args "-q all.q "
   append args "-u '!sgetest1,sgetest2,!root' "
   ts_log_fine "qrsub with $args"

   set ar_id [submit_ar "$args"]
   if {$ar_id < 0} {
      ts_log_fine "qrsub $args failed:"
      return
   }
   set val(id)                             "$ar_id"
   set val(name)                           "test_ar_name"
   set val(owner)                          "$CHECK_USER"  
   set val(checkpoint_name)                "test_ar_ckpt"
   set val(start_time)                     "01/01/2008 01:01:00"
   set val(end_time)                       "01/01/2009 01:01:00"
   set val(duration)                       "8784:00:00"
   set val(group)                          "staff"
   set val(account)                        "test_ar_account"
   set val(resource_list)                  "h_rt=200, arch=sol*"
   set check_values(error_handling)        "true"
   set val(granted_slots_list)             "all.q@es-ergb01-01=3"
   set val(granted_parallel_environment)   "mytestpe slots 3"
   set val(checkpoint_name)                "test_ar_ckpt"
   set val(mail_options)                   "ab"
   set val(mail_list)                      "sgetest1@sun.com,deadlineusers@NONE"
   set val(acl_list)                       "sgetest2"
   set val(xacl_list)                      "sgetest1,root"


   ts_log_fine "qrstat -ar $ar_id"
   parse_qrstat_check $ar_id val

   ts_log_fine "qrdel -u *"
   set result [start_sge_bin qrdel "-u '*'"]
   if {$prg_exit_state != 0} {
      ts_log_fine "couldn't execute qrdel -u *"
      return
   }
}

