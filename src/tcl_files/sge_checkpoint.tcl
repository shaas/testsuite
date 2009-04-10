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

#****** sge_checkpoint/set_ckpt_defaults() *************************************
#  NAME
#     set_ckpt_defaults() -- create version dependent checkpoint interface settings
#
#  SYNOPSIS
#     set_ckpt_defaults {change_array}
#
#  FUNCTION
#     Fills the array change_array with default checkpoint interface attributes
#     for the specific version of SGE.
#
#  INPUTS
#     change_array - the resulting array
#
#*******************************************************************************
proc set_ckpt_defaults {change_array} {
   get_current_cluster_config_array ts_config
   upvar $change_array chgar

   set chgar(ckpt_name)           "template"          ;# ckpt_name is mandatory
   set chgar(interface)           "userdefined"
   set chgar(ckpt_command)        "none"
   set chgar(migr_command)        "none"
   set chgar(restart_command)     "none"
   set chgar(clean_command)       "none"
   set chgar(ckpt_dir)            "/tmp"
   set chgar(signal)              "none"
   set chgar(when)                "sx"
}

#****** sge_checkpoint/add_ckpt() **********************************************
#
#  NAME
#     add_ckpt -- add new checkpoint interface configuration object
#
#  SYNOPSIS
#     add_ckpt {ckpt_name {change_array ""} {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}}
#
#  FUNCTION
#     Add a new ckpt (checkpoint interface) to the Grid Engine cluster.
#     Supports fast (qconf -Ackpt) and slow (qconf -ackpt) mode.
#
#  INPUTS
#     ckpt_name           - checkpoint interface name
#     {change_array ""} - the checkpoint interface description
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
#     sge_ckpt/get_ckpt_messages()
#*******************************************************************************
proc add_ckpt {ckpt_name {change_array ""} {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   upvar $change_array chgar
   set chgar(ckpt_name) $ckpt_name

   validate_checkpointobj chgar

   get_ckpt_messages messages "add" "$ckpt_name" $on_host $as_user

   if {$fast_add} {
      ts_log_fine "Add checkpoint interface $ckpt_name from file ..."
      set option "-Ackpt"
      set_ckpt_defaults old_config
      update_change_array old_config chgar
      set tmpfile [dump_array_to_tmpfile old_config]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]

   } else {
      ts_log_fine "Add checkpoint interface $ckpt_name slow ..."
      set option "-ackpt"
      set vi_commands [build_vi_command chgar]
      set result [start_vi_edit "qconf" "$option $ckpt_name" $vi_commands messages $on_host $as_user]
   }
   unset chgar(ckpt_name)
   return [handle_sge_errors "add_ckpt" "qconf $option" $result messages $raise_error]
}

#****** sge_checkpoint/get_ckpt() **********************************************
#  NAME
#     get_ckpt() -- get checkpoint configuration information
#
#  SYNOPSIS
#     get_ckpt {ckpt_name {output_var result} {on_host ""} {as_user ""} {raise_error 1}}
#
#  FUNCTION
#     Get the actual configuration settings for the named checkpoint interface
#
#  INPUTS
#     ckpt_obj            - name of the checkpoint interface
#     {output_var result} - name of an array variable that will get set by
#                    get_checkpointobj
#     {on_host ""}      - execute qconf on this host (default: qmaster host)
#     {as_user ""}      - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1}   - raise error condition in case of errors?
#
#  SEE ALSO
#     sge_checkpoint/mod_ckpt()
#     sge_procedures/get_queue() 
#     sge_procedures/set_queue()
#*******************************************************************************
proc get_ckpt {ckpt_name {output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   upvar $output_var out
  get_current_cluster_config_array ts_config

   ts_log_fine "Get checkpoint interface $ckpt_name ... "
   
   get_ckpt_messages messages "get" "$ckpt_name" $on_host $as_user

   return [get_qconf_object "get_ckpt" "-sckpt $ckpt_name" out messages 0 $on_host $as_user $raise_error]
     }

#****** sge_checkpoint/mod_ckpt() **********************************************
#
#  NAME
#     mod_ckpt -- modify existing checkpoint interface configuration object
#
#  SYNOPSIS
#     mod_ckpt {ckpt_name change_array {fast_add 1} {on_host ""} {as_user ""}
#     {raise_error 1}}
#
#  FUNCTION
#     Modify the checkpoint interface $ckpt_name in the Grid Engine cluster.
#     Supports fast (qconf -Mckpt) and slow (qconf -mckpt) mode.
#
#  INPUTS
#     ckpt_name 	     - checkpoint interface we are modifying
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
#     sge_checkpoint/get_ckpt_messages()
#*******************************************************************************
proc mod_ckpt {ckpt_name change_array {fast_add 1} {on_host ""} {as_user ""} {raise_error 1} } {
  get_current_cluster_config_array ts_config

   upvar $change_array chgar
   set chgar(ckpt_name) "$ckpt_name"

   validate_checkpointobj chgar

   get_ckpt_messages messages "mod" "$ckpt_name" $on_host $as_user
     
   if { $fast_add } {
      ts_log_fine "Modify checkpoint interface $ckpt_name from file ..."
      set option "-Mckpt"
      get_ckpt $ckpt_name curr_ckpt $on_host $as_user 0
      if {![info exists curr_ckpt]} {
         set_ckpt_defaults curr_ckpt
      }
      update_change_array curr_ckpt chgar
      set tmpfile [dump_array_to_tmpfile curr_ckpt]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]

   } else {
      ts_log_fine "Modify checkpoint interface $ckpt_name slow ..."
      set option "-mckpt"
      set vi_commands [build_vi_command chgar]
      set result [start_vi_edit "qconf" "$option $ckpt_name" $vi_commands messages $on_host $as_user]
   }

   return [handle_sge_errors "mod_ckpt" "qconf $option" $result messages $raise_error]
}

#****** sge_checkpoint/del_ckpt() **********************************************
#
#  NAME
#     del_ckpt -- delete checkpoint interface configuration object
#
#  SYNOPSIS
#     del_ckpt { ckpt_name {on_host ""} {as_user ""} {raise_error 1} }
#
#  FUNCTION
#     Delete the checkpoint interface configuration object
#     Represents qconf -dckpt command in SGE
#
#  INPUTS
#     ckpt_name        - name of checkpoint interface to delete
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
#     sge_ckpt/get_ckpt_messages()
#*******************************************************************************
proc del_ckpt {ckpt_name {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   ts_log_fine "Delete checkpoint interface $ckpt_name ..."
   
   unassign_queues_with_ckpt_object $ckpt_name $on_host $as_user $raise_error

   get_ckpt_messages messages "del" "$ckpt_name" $on_host $as_user

   set output [start_sge_bin "qconf" "-dckpt $ckpt_name" $on_host $as_user]

   return [handle_sge_errors "del_ckpt" "qconf -dckpt $ckpt_name" $output messages $raise_error]

}

#****** sge_checkpoint/get_ckpt_list() *****************************************
#  NAME
#    get_ckpt_list () -- get the list of all checkpoint interfaces
#
#  SYNOPSIS
#     get_ckpt_list { {output_var result} {on_host ""} {as_user ""}
#     {raise_error 1}  }
#
#  FUNCTION
#     Calls qconf -sckptl to retrieve the list of all checkpoint interfaces in SGE
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
#     sge_ckpt/get_ckpt_messages()
#*******************************************************************************
proc get_ckpt_list {{output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   upvar $output_var out

   ts_log_fine "Get checkpoint interface list ..."

   get_ckpt_messages messages "list" "" $on_host $as_user

   return [get_qconf_object "get_ckpt_list" "-sckptl" out messages 1 $on_host $as_user $raise_error]
}

#****** sge_checkpoint/get_ckpt_messages() *************************************
#  NAME
#     get_ckpt_messages() -- returns the set of messages related to action
#                              on checkpoint interface, i.e. add, modify, delete, get
#
#  SYNOPSIS
#     get_ckpt_messages {msg_var action obj_name result {on_host ""} {as_user ""}}
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
proc get_ckpt_messages {msg_var action obj_name {on_host ""} {as_user ""}} {
   get_current_cluster_config_array ts_config

   upvar $msg_var messages
   if {[info exists messages]} {
     unset messages
   }
   if { $action == "del"} {
      set OBJ_CKPT "checkpointing environment"
   } else {
      set OBJ_CKPT "checkpoint interface"
   }

   # set the expected client messages
   sge_client_messages messages $action $OBJ_CKPT $obj_name $on_host $as_user

   # the place for exceptions: # VD version dependent
   #                           # CD client dependent
   # see sge_procedures/sge_client_messages

   switch -exact $action {
      "add" {
   if { $ts_config(gridengine_version) == 53 } {
      set REFERENCED_IN_QUEUE_LIST_OF_CHECKPOINT [translate_macro MSG_SGETEXT_UNKNOWNQUEUE_SSSS "*" "*" "*" "*"] 
            add_message_to_container messages -3 $REFERENCED_IN_QUEUE_LIST_OF_CHECKPOINT
   }
}
      "get" {
         set NOT_EXISTS [translate_macro MSG_PARALLEL_XNOTAPARALLELEVIRONMENT_S "$obj_name"]
         add_message_to_container messages -1 $NOT_EXISTS
     }
      "mod" {
         add_message_to_container messages -3 [translate_macro MSG_CKPT_XISNOTCHKPINTERFACEDEF_S "$obj_name"]
      }
      "del" {
         add_message_to_container messages -2 [translate_macro MSG_CKPTREFINQUEUE_SS "$obj_name" "*"]
      }
      "list" {
      }
   }
}
