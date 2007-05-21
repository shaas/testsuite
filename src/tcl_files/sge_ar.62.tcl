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
#     submit_ar { args {do_error_check 1} }
#
#  FUNCTION
#     This procedure will submit a AR.
#
#  INPUTS
#     args                - a string of qrsub arguments/parameters
#     {do_error_check 1}  - if 1 (default): add global errors (add_proc_error) when error occured
#                           if 0: do not add errors at all
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
proc submit_ar {args {do_error_check 1} } {
   global ts_config CHECK_OUTPUT

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
#   puts $CHECK_OUTPUT $messages(index)

   set output [start_sge_bin "qrsub" $args "" "" prg_exit_state]

   set ret [handle_sge_errors "submit_ar" "qrsub $args" $output messages $do_error_check]
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
   global ts_config CHECK_OUTPUT CHECK_USER

   puts $CHECK_OUTPUT "deleting all ar"
   set output [start_sge_bin "qrdel" "-u '*' "]
   puts $CHECK_OUTPUT $output

   if {$prg_exit_state == 0} {
      set ret 1
   } else {
      set ret 0
   }

   return $ret
}



#****** sge_ar/submit_ar_parse_ar_id() *******************************
#  NAME
#     submit_ar_parse_ar_id() -- parse job id from qsub output
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
   global ts_config CHECK_OUTPUT

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
      add_proc_error "submit_ar_parse_ar_id" -1 "couldn't find qrsub success message\n$message\nin qrsub output\n$output"
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
proc parse_qrstat { ar_id output } {
   global ts_config
   global CHECK_OUTPUT

   upvar $output out

   set result [start_sge_bin qrstat "-ar $ar_id"]
   if {$prg_exit_state != 0} {
      add_proc_error "submit_qrstat" -1 "couldn't find qrstat or AR $ar_id does not exists"
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
   global CHECK_OUTPUT

   parse_qrstat $ar_id arinfo
   foreach name [array names arinfo] {
      puts $CHECK_OUTPUT "$name\t<$arinfo($name)>"
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
   global CHECK_OUTPUT
   upvar $match_values val

   parse_qrstat $ar_id arinfo

   set ret 0
   foreach name [array names val] {
      set pattern "$val($name)"
      set skip [catch { set value   "$arinfo($name)" }]
      if { $skip } {
        add_proc_error "parse_qrstat_check" -1 "The expected attribute $name is missing in the result"
        set ret -2
        continue
      }     

      if {[string match $pattern $value]} {
         puts $CHECK_OUTPUT "SUCCESSFUL MATCH for attribute $name:\tvalue: $value"         
      } else {
         add_proc_error "parse_qrstat_check" -1 "Attribute: $name\tvalue: $value\t DOES NOT MATCH pattern: $pattern"
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
   global CHECK_OUTPUT
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
   puts $CHECK_OUTPUT "qrsub with $args\n"

   set ar_id [submit_ar "$args"]
   if {$ar_id < 0} {
      puts $CHECK_OUTPUT "qrsub $args failed:\n"
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


   puts $CHECK_OUTPUT "qrstat -ar $ar_id\n"
   parse_qrstat_check $ar_id val

   puts $CHECK_OUTPUT "qrdel -u *\n"
   set result [start_sge_bin qrdel "-u '*'"]
   if {$prg_exit_state != 0} {
      puts $CHECK_OUTPUT "couldn't execute qrdel -u *"
      return
   }
}

