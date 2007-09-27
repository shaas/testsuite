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

#****** sge_calendar/set_calendar_defaults() ***********************************
#  NAME
#     set_calendar_defaults() -- create version dependent calendar settings
#
#  SYNOPSIS
#     set_calendar_defaults {change_array}
#
#  FUNCTION
#     Fills the array change_array with default calendar attributes for the 
#     specific version of SGE.
#
#  INPUTS
#     change_array - the resulting array
#
#*******************************************************************************
proc set_calendar_defaults { change_array } {
   upvar $change_array chgar
   
   set chgar(calendar_name) "template"          ;# calendar_name is mandatory
   set chgar(year)          "NONE"
   set chgar(week)          "NONE"       
}

#****** sge_calendar/add_calendar() ********************************************
# 
#  NAME
#     add_calendar -- add a new calendar configuration object
#
#  SYNOPSIS
#     add_calendar { calendar {change_array ""} {fast_add 1} {on_host ""} 
#     {as_user ""} {raise_error 1}} 
#
#  FUNCTION
#     Add a calendar to the Grid Engine cluster.
#     Supports fast (qconf -Acal) and slow (qconf -acal) mode.
#
#  INPUTS
#     calendar          - calendar name
#     {change_array ""} - name of an array variable
#     {fast_add 1}      - if not 0 the add_calendar procedure will use a file 
#                         for adding a calendar
#     {on_host ""}      - execute qconf on this host, default is master host
#     {as_user ""}      - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1}   - raise an error condition on error (default), or just
#                         output the error message to stdout
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_calendar/get_calendar_messages()
#*******************************************************************************
proc add_calendar {calendar {change_array ""} {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   get_current_cluster_config_array ts_config

   upvar $change_array chgar
   set chgar(calendar_name) "$calendar"

   get_calendar_messages messages "add" "$calendar" $on_host $as_user

   if {$fast_add} {
      puts $CHECK_OUTPUT "Add calendar $calendar from file ..."
      set option "-Acal"
      set_calendar_defaults old_config
      update_change_array old_config chgar
      set tmpfile [dump_array_to_tmpfile old_config]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]
     
   } else {
      puts $CHECK_OUTPUT "Add calendar $calendar slow ..."
      set option "-acal"
      set vi_commands [build_vi_command chgar]
      set result [start_vi_edit "qconf" "$option $calendar" $vi_commands messages $on_host $as_user]

  }

  return [handle_sge_errors "add_calendar" "qconf $option" $result messages $raise_error]
}

#****** sge_calendar/get_calendar() *******************************************
#  NAME
#     get_calendar() -- get calendar configuration object
#
#  SYNOPSIS
#     get_calendar { calendar  {output_var result} {on_host ""} {as_user ""}  
#     {raise_error 1}}
#
#  FUNCTION
#     Get the actual configuration settings for the named calendar
#     Represents qconf -scal command in SGE
#
#  INPUTS
#     calendar            - name of calendar we wish to see
#     {output_var result} - result will be placed here
#     {on_host ""}        - execute qconf on this host, default is master host
#     {as_user ""}        - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1}     - raise an error condition on error (default), or just
#                           output the error message to stdout
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_calendar/get_calendar_messages()
#*******************************************************************************
proc get_calendar {calendar {output_var result}  {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   upvar $output_var out

   puts $CHECK_OUTPUT "Get calendar $calendar ..."

   get_calendar_messages messages "get" "$calendar" $on_host $as_user

   return [get_qconf_object "get_calendar" "-scal $calendar" out messages 0 $on_host $as_user $raise_error]
 
}

#****** sge_calendar/get_calender_list() ***************************************
#  NAME
#     get_calender_list() -- get the list of all calendars
#
#  SYNOPSIS
#     get_calender_list {{output_var result} {on_host ""} {as_user ""} 
#     {raise_error 1}}
#
#  FUNCTION
#     Calls qconf -scall to retrieve the list of all calendars in SGE
#
#  INPUTS
#     {output_var result}  - result will be placed here
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - raise an error condition on error (default), or just
#                       output the error message to stdout
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_calendar/get_calendar_messages()
#*******************************************************************************
proc get_calendar_list {{output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   upvar $output_var out
   
   puts $CHECK_OUTPUT "Get calendar list ..."

   get_calendar_messages messages "list" "" $on_host $as_user 
   
   return [get_qconf_object "get_calendar_list" "-scall" out messages 1 $on_host $as_user $raise_error]
}

#****** sge_calendar/mod_calendar() ********************************************
#
#  NAME
#     mod_calendar -- modify existing calendar configuration object
#
#  SYNOPSIS
#     mod_calendar {calendar change_array {fast_add 1} {on_host ""} {as_user ""} }
#
#  FUNCTION
#     Modify the calendar $calendar in the Grid Engine cluster.
#     Supports fast (qconf -Mcal) and slow (qconf -mcal) mode.
#
#  INPUTS
#     calendar     - the name of the calendar we are modifying
#     change_array - name of an array variable that will be set by mod_calendar
#     {fast_add 1} - if not 0 the add_calendar procedure will use a file for
#                    adding a calendar
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - do add_proc_error in case of errors
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_calendar/get_calendar_messages()
#*******************************************************************************
proc mod_calendar {calendar change_array {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
  global CHECK_OUTPUT DISABLE_ADD_PROC_ERROR
  get_current_cluster_config_array ts_config
 
  upvar $change_array chgar
  set chgar(calendar_name) $calendar
  
  get_calendar_messages messages "mod" "$calendar" $on_host $as_user

  if { $fast_add != 0 } {
      puts $CHECK_OUTPUT "Modify calendar $calendar from file ..."
      set option "-Mcal"
      set DISABLE_ADD_PROC_ERROR 1
      get_calendar $calendar curr_cal $on_host $as_user
      set DISABLE_ADD_PROC_ERROR 0
      if {![info exists curr_cal]} {
         set_calendar_defaults curr_cal
      }
      update_change_array curr_cal chgar
      set tmpfile [dump_array_to_tmpfile curr_cal]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]
      
   } else {
      puts $CHECK_OUTPUT "Modify calendar $calendar slow ..."
      set option "-mcal"
      # BUG: different message for "vi" from fastadd ...
      set NOT_EXISTS [translate_macro MSG_CALENDAR_XISNOTACALENDAR_S "$calendar"]
      add_message_to_container messages -1 $NOT_EXISTS
      set vi_commands [build_vi_command chgar]
      set result [start_vi_edit "qconf" "$option $calendar" $vi_commands messages $on_host $as_user]

  }

   return [handle_sge_errors "mod_calendar" "qconf $option" $result messages $raise_error]
}

#****** sge_calendar/del_calendar() *******************************************
#  NAME
#     del_calendar() -- delete calendar configuration object
#
#  SYNOPSIS
#     del_calendar { calendar {on_host ""} {as_user ""}  {raise_error 1}}
#
#  FUNCTION
#     Delete the calendar configuration object
#     Represents qconf -dcal command in SGE
#
#  INPUTS
#     calendar        - value of calendar we wish to delete;
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - raise an error condition on error (default), or just
#                       output the error message to stdout
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_calendar/get_calendar_messages()
#*******************************************************************************
proc del_calendar {calendar {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   puts $CHECK_OUTPUT "Delete calendar $calendar ..."

   get_calendar_messages messages "del" "$calendar" $on_host $as_user
   
   set output [start_sge_bin "qconf" "-dcal $calendar" $on_host $as_user]
   
   return [handle_sge_errors "del_calendar" "qconf -dcal $calendar" $output messages $raise_error]
   
}

#****** sge_calendar/get_calendar_messages() *************************************
#  NAME
#     get_calendar_messages() -- returns the set of messages related to action 
#                              on calendar, i.e. add, modify, delete, get
#
#  SYNOPSIS
#     get_calendar_messages {msg_var action obj_name result {on_host ""} {as_user ""}} 
#
#  FUNCTION
#     Returns the set of messages related to action on sge object. This function
#     is a wrapper of sge_object_messages which is general for all types of objects
#
#  INPUTS
#     msg_var       - array of messages (the pair of message code and message value)
#     action        - action examples: add, modify, delete,...
#     obj_name      - sge object name
#     {on_host ""}  - execute on this host, default is master host
#     {as_user ""}  - execute qconf as this user, default is $CHECK_USER
#
#  SEE ALSO
#     sge_procedures/sge_client_messages()
#*******************************************************************************
proc get_calendar_messages {msg_var action obj_name {on_host ""} {as_user ""}} {
   get_current_cluster_config_array ts_config

   upvar $msg_var messages
   if {[info exists messages]} {
     unset messages
   }

  # set CALENDAR [translate_macro SGE_OBJ_CALENDAR]
   set CALENDAR "calendar"

   # set the expected client messages
   sge_client_messages messages $action $CALENDAR $obj_name $on_host $as_user
   
   # the place for exceptions: # VD version dependent  
   #                           # CD client dependent
   # see sge_procedures/sge_client_messages
   switch -exact $action {
      "add" {
         set DISABLED_YEAR [translate_macro MSG_ANSWER_ERRORINDISABLYEAROFCALENDARXY_SS "*" "$obj_name"]
         add_message_to_container messages -4 $DISABLED_YEAR
         set DISABLED_WEEK [translate_macro MSG_PARSE_ERRORINDISABLEDWEEKOFCALENDAR_SS "$obj_name" "*"]
         add_message_to_container messages -5 $DISABLED_WEEK
      }
      "get" {
         # CD: not expected generic message
         set NOT_EXISTS [translate_macro MSG_CALENDAR_XISNOTACALENDAR_S "$obj_name"]
         add_message_to_container messages -1 $NOT_EXISTS     
      }
      "mod" {
         set DISABLED_YEAR [translate_macro MSG_ANSWER_ERRORINDISABLYEAROFCALENDARXY_SS "*" "$obj_name"]
         add_message_to_container messages -6 $DISABLED_YEAR
         set DISABLED_WEEK [translate_macro MSG_PARSE_ERRORINDISABLEDWEEKOFCALENDAR_SS "$obj_name" "*"]
         add_message_to_container messages -7 $DISABLED_WEEK
         if {$ts_config(gridengine_version) >= 62} {
            set AR_REJECTED [translate_macro MSG_PARSE_MOD2_REJECTED_DUE_TO_AR_SSU "*" "*" "*"]
            add_message_to_container messages -8 $AR_REJECTED
         }
      }
      "del" {
         # references: queue
         set STILL_REF [translate_macro MSG_SGETEXT_USERSETSTILLREFERENCED_SSSS "$obj_name" "*" "*" "*"]
         add_message_to_container messages -2 $STILL_REF

         set REFINQUEUE [translate_macro MSG_CALENDAR_REFINQUEUE_SS $obj_name  "*"]
         add_message_to_container messages -2 $REFINQUEUE
      }
      "list" {
      }
   } 
}
