#!/usr/local/bin/tclsh
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

#****** sge_pe/set_pe_defaults() ***********************************************
#  NAME
#     set_pe_defaults() -- create version dependent parallel environment settings
#
#  SYNOPSIS
#     set_pe_defaults {change_array}
#
#  FUNCTION
#     Fills the array change_array with default parallel environment attributes 
#     for the specific version of SGE.
#
#  INPUTS
#     change_array - the resulting array
#
#*******************************************************************************
proc set_pe_defaults { change_array } {
   get_current_cluster_config_array ts_config
   upvar $change_array chgar

   set chgar(pe_name)           "template"          ;# pe_name is mandatory
   set chgar(slots)             "0"       
   set chgar(user_lists)        "NONE"
   set chgar(xuser_lists)       "NONE"
   set chgar(start_proc_args)   "NONE"
   set chgar(stop_proc_args)    "NONE"
   set chgar(allocation_rule)   "\$pe_slots"
   set chgar(control_slaves)    "FALSE"
   set chgar(job_is_first_task) "TRUE"
   
   # SGE version dependent defaults
   if {$ts_config(gridengine_version) == 53} {
      set chgar(queue_list) "all"   
   }

   if {$ts_config(gridengine_version) >= 60} {
      set chgar(urgency_slots) "min"
   }

   if {$ts_config(gridengine_version) >= 62} {
      set chgar(accounting_summary) "FALSE"
   }
}

#****** sge_pe/add_pe() ********************************************************
#
#  NAME
#     add_pe -- add new parallel environment configuration object
#
#  SYNOPSIS
#     add_pe { change_array { version_check 1 } }
#
#  FUNCTION
#     Add a new pe (parallel environemnt) to the Grid Engine cluster.
#     Supports fast (qconf -Ap) and slow (qconf -ap) mode. 
#
#  INPUTS
#     pe_name           - parallel environment name
#     {change_array ""} - the parallel environment description
#     {fast_add 1}      - use fast mode
#     {on_host ""}      - execute qconf on this host (default: qmaster host)
#     {as_user ""}      - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1}   - raise error condition in case of errors?
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_pe/get_pe_messages()
#*******************************************************************************
proc add_pe { pe_name {change_array ""} {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   upvar $change_array chgar
   set chgar(pe_name) $pe_name

   if { $ts_config(gridengine_version) >= 60 && [info exists chgar(queue_list) ]} {
      if { [ info exists chgar(queue_list) ] } {
         ts_log_fine "this qconf version doesn't support queue_list for pe objects"
         ts_log_config "this qconf version doesn't support queue_list for pe objects,\nuse assign_queues_with_pe_object() after adding pe\nobjects and don't use queue_list parameter.\nyou can call get_pe_ckpt_version() to test pe version"
         unset chgar(queue_list)
      }
   }

   get_pe_messages messages "add" "$pe_name" $on_host $as_user

   if {$fast_add} {
      ts_log_fine "Add parallel environment $pe_name from file ..."
      set option "-Ap"
      set_pe_defaults old_config
      update_change_array old_config chgar
      set tmpfile [dump_array_to_tmpfile old_config]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]

   } else {
      ts_log_fine "Add parallel environment $pe_name slow ..."
      set option "-ap"
      set vi_commands [build_vi_command chgar]
      set result [start_vi_edit "qconf" "$option $pe_name" $vi_commands messages $on_host $as_user]
   }

   return [handle_sge_errors "add_pe" "qconf $option" $result messages $raise_error]
}

#****** sge_pe/get_pe() ********************************************************
# 
#  NAME
#     get_pe -- get parallel environment configuration object
#
#  SYNOPSIS
#     get_pe {pe_name {output_var result} {on_host ""} {as_user ""}
#     {raise_error 1}}
#
#  FUNCTION
#     Get the actual configuration settings for the named parallel environment
#     Represents qconf -sp command in SGE
#
#  INPUTS
#     pe_name             - name of the parallel environment
#     {output_var result} - result will be placed here
#     {on_host ""}        - execute qconf on this host (default: qmaster host)
#     {as_user ""}        - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1}     - raise error condition in case of errors?
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_pe/get_pe_messages()
#*******************************************************************************
proc get_pe {pe_name {output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   upvar $output_var out
   get_current_cluster_config_array ts_config

   ts_log_fine "Get parallel environment $pe_name ... "

   get_pe_messages messages "get" "$pe_name" $on_host $as_user

   return [get_qconf_object "get_pe" "-sp $pe_name" out messages 0 $on_host $as_user $raise_error]
}

#****** sge_pe/mod_pe() ********************************************************
#
#  NAME
#     mod_pe -- modify existing parallel environment configuration object
#
#  SYNOPSIS
#     mod_pe {pe_name change_array {fast_add 1} {on_host ""} {as_user ""} 
#     {raise_error 1}}
#
#  FUNCTION
#     Modify the parallel environment $pe_name in the Grid Engine cluster.
#     Supports fast (qconf -Mp) and slow (qconf -mp) mode.
#
#  INPUTS
#     pe_name 	       - parallel environment we are modifying
#     change_array     - the array of attributes and it's values
#     {fast_add 1}     - use fast mode
#     {on_host ""}     - execute qconf on this host, default is master host
#     {as_user ""}     - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1}  - raise error condition in case of errors
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_pe/get_pe_messages()
#*******************************************************************************
proc mod_pe {pe_name change_array {fast_add 1} {on_host ""} {as_user ""} {raise_error 1} } {
   global DISABLE_ADD_PROC_ERROR
   get_current_cluster_config_array ts_config

   upvar $change_array chgar
   set chgar(pe_name) "$pe_name"

   get_pe_messages messages "mod" "$pe_name" $on_host $as_user
     
   if { $fast_add } {
      ts_log_fine "Modify parallel environment $pe_name from file ..."
      set option "-Mp"
      get_pe $pe_name curr_pe $on_host $as_user 0
      if {![info exists curr_pe]} {
         set_pe_defaults curr_pe
      }
      update_change_array curr_pe chgar
      set tmpfile [dump_array_to_tmpfile curr_pe]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]

   } else {
      ts_log_fine "Modify parallel environment $pe_name slow ..."
      set option "-mp"
      set vi_commands [build_vi_command chgar]
      # BUG: different message for "vi" from fastadd ...
      set NOT_EXISTS [translate_macro MSG_PARALLEL_XNOTAPARALLELEVIRONMENT_S "$pe_name"]
      add_message_to_container messages -1 $NOT_EXISTS
      set result [start_vi_edit "qconf" "$option $pe_name" $vi_commands messages $on_host $as_user]
   }
   return [handle_sge_errors "mod_pe" "qconf $option" $result messages $raise_error]
}
 
#****** sge_pe/del_pe() ********************************************************
#
#  NAME
#     del_pe -- delete parallel environment configuration object
#
#  SYNOPSIS
#     del_pe { pe_name {on_host ""} {as_user ""} {raise_error 1} }
#
#  FUNCTION
#     Delete the parallel environment configuration object
#     Represents qconf -dp command in SGE
#
#  INPUTS
#     pe_name          - name of parallel environment to delete
#     {on_host ""}     - execute qconf on this host (default: qmaster host)
#     {as_user ""}     - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1}  - raise error condition in case of errors?
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/sge_client_messages()
#     sge_pe/get_pe_messages()
#*******************************************************************************
proc del_pe {pe_name {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   ts_log_fine "Delete parallel environment $pe_name ..."
   
   unassign_queues_with_pe_object $pe_name $on_host $as_user $raise_error

   get_pe_messages messages "del" "$pe_name" $on_host $as_user

   set output [start_sge_bin "qconf" "-dp $pe_name" $on_host $as_user]

   return [handle_sge_errors "del_pe" "qconf -dp $pe_name" $output messages $raise_error]
   
}

#****** sge_pe/get_pe_list() ***************************************************
#  NAME
#    get_pe_list () -- get the list of all parallel environments
#
#  SYNOPSIS
#     get_pe_list { {output_var result} {on_host ""} {as_user ""} 
#     {raise_error 1}  }
#
#  FUNCTION
#     Calls qconf -sp to retrieve the list of all parallel environments in SGE
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
#     sge_pe/get_pe_messages()
#*******************************************************************************
proc get_pe_list {{output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   upvar $output_var out
   
   ts_log_fine "Get parallel environment list ..."

   get_pe_messages messages "list" "" $on_host $as_user 
   
   return [get_qconf_object "get_pe_list" "-spl" out messages 1 $on_host $as_user $raise_error]
}

#****** sge_pe/get_pe_messages() ***********************************************
#  NAME
#     get_pe_messages() -- returns the set of messages related to action 
#                              on parallel env., i.e. add, modify, delete, get
#
#  SYNOPSIS
#     get_pe_messages {msg_var action obj_name result {on_host ""} {as_user ""}} 
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
proc get_pe_messages {msg_var action obj_name {on_host ""} {as_user ""}} {
   get_current_cluster_config_array ts_config

   upvar $msg_var messages
   if {[info exists messages]} {
     unset messages
   }

   set OBJ_PE [translate_macro MSG_OBJ_PE]

   # set the expected client messages
   sge_client_messages messages $action $OBJ_PE $obj_name $on_host $as_user
   
   # the place for exceptions: # VD version dependent  
   #                           # CD client dependent
   # see sge_procedures/sge_client_messages

   switch -exact $action {
      "add" {
         if {$ts_config(gridengine_version) == 53} {
            set USET_NOT_EXISTS [translate_macro MSG_SGETEXT_UNKNOWNUSERSET_SSSS "*" "*" "*" "*" ]
         } else {
            set USET_NOT_EXISTS [translate_macro MSG_CQUEUE_UNKNOWNUSERSET_S "*"]
         }
         add_message_to_container messages -3 $USET_NOT_EXISTS
         add_message_to_container messages -4 "error: [translate_macro MSG_ULONG_INCORRECTSTRING "*"]"
         add_message_to_container messages -5 [translate_macro MSG_GDI_APATH_S "*"]
      }
      "get" {
         set NOT_EXISTS [translate_macro MSG_PARALLEL_XNOTAPARALLELEVIRONMENT_S "$obj_name"]
         add_message_to_container messages -1 $NOT_EXISTS
     }
      "mod" {
         add_message_to_container messages -6 [translate_macro MSG_CQUEUE_UNKNOWNUSERSET_S "*"]
         add_message_to_container messages -7 "error: [translate_macro MSG_ULONG_INCORRECTSTRING "*"]"
         if {$ts_config(gridengine_version) >= 62} {
            set REJECTED_DUE_TO_AR_PE_SLOTS_U [translate_macro MSG_PARSE_MOD_REJECTED_DUE_TO_AR_PE_SLOTS_U "*"]
         } else {
            set REJECTED_DUE_TO_AR_PE_SLOTS_U "MSG_PARSE_MOD_REJECTED_DUE_TO_AR_PE_SLOTS_U message only in 6.2 or higher"
         }
         add_message_to_container messages -8 $REJECTED_DUE_TO_AR_PE_SLOTS_U
         add_message_to_container messages -9 [translate_macro MSG_GDI_APATH_S "*"]
      }
      "del" {
         add_message_to_container messages -2 [translate_macro MSG_PEREFINQUEUE_SS "$obj_name" "*"]
      }
      "list" {
      }
   } 
}
