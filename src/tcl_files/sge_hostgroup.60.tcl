#!/usr/local/bin/tclsh
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
#****** sge_hostgroup.60/set_hostgroup_defaults() ******************************
#  NAME
#     set_hostgroup_defaults() -- create version dependent hostgroup settings
#
#  SYNOPSIS
#     set_hostgroup_defaults {change_array}
#
#  FUNCTION
#     Fills the array change_array with default hostgroup attributes for the 
#     specific version of SGE.
#
#  INPUTS
#     change_array - the resulting array
#
#*******************************************************************************
proc set_hostgroup_defaults {change_array} {
   get_current_cluster_config_array ts_config
   upvar $change_array chgar
   
   set chgar(group_name)    "@template"
   set chgar(hostlist)      "NONE"
}

#****** sge_hostgroup.60/add_hostgroup() ***************************************
#  NAME
#     add_hostgroup() -- Add a new host group configuration file
#
#  SYNOPSIS
#     add_hostgroup { group {change_array ""} {fast_add 1} {on_host ""} 
#     {as_user ""} {raise_error 1}}
#
#  FUNCTION
#     Add a host group to the Grid Engine cluster.
#     Supports fast (qconf -Ahgrp) and slow (qconf -ahgrp) mode.
#
#  INPUTS
#     group             - the name of the host group
#     {change_array ""} - host group description
#     {fast_add 1}      - use fast mode
#     {on_host ""}      - execute qconf on this host, default is master host
#     {as_user ""}      - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1}   - raise error condition in case of errors?
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_hostgroup/get_hostgroup_messages()
#*******************************************************************************
proc add_hostgroup {group {change_array ""} {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   get_current_cluster_config_array ts_config

   upvar $change_array chgar
   set chgar(group_name) "$group"

   get_hostgroup_messages messages "add" "$group" $on_host $as_user

   if { $fast_add } {
      puts $CHECK_OUTPUT "Add hostgroup $group from file ..."
      set option "-Ahgrp"
      set_hostgroup_defaults old_config
      update_change_array old_config chgar
      set tmpfile [dump_array_to_tmpfile old_config]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]

   } else {
      puts $CHECK_OUTPUT "Add hostgroup $group slow ..."
      set option "-ahgrp"
      set vi_commands [build_vi_command chgar]
      set result [start_vi_edit "qconf" "$option $group" $vi_commands messages$on_host $as_user]

   }

   return [handle_sge_errors "add_hostgroup" "qconf $option" $result messages $raise_error]
}

#****** sge_hostgroup.60/get_hostgroup() ***************************************
#  NAME
#     get_hostgroup() -- get host group configuration object
#
#  SYNOPSIS
#     get_hostgroup { group {output_var result} {on_host ""} {as_user ""} 
#     {raise_error 1}}
#
#  FUNCTION
#     Get the actual configuration settings for the named project
#     Represents qconf -shgrp command in SGE
#
#  INPUTS
#     group               - name of the host group
#     {output_var result} - result will be placed here
#     {on_host ""}        - execute qconf on this host, default is master host
#     {as_user ""}        - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1}     - raise an error condition on error (default), or just
#                            output the error message to stdout
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_hostgroup/get_project_messages()
#*******************************************************************************
proc get_hostgroup {group {output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   upvar $output_var out

   puts $CHECK_OUTPUT "Get hostgroup $group ..."

   get_hostgroup_messages messages "get" "$group" $on_host $as_user

   return [get_qconf_object "get_hostgroup" "-shgrp $group" out messages 0 $on_host $as_user $raise_error]
}

#****** sge_hostgroup.60/del_hostgroup() ***************************************
#  NAME
#     del_hostgroup() -- delete host group configuration object
#
#  SYNOPSIS
#     del_hostgroup { group {on_host ""} {as_user ""} {raise_error 1} } 
#
#  FUNCTION
#     Delete the host group configuration object
#     Represents qconf -dhgrp command in SGE
#
#  INPUTS
#     group            - name of the hostgroup
#     {on_host ""}     - execute qconf on this host (default: qmaster host)
#     {as_user ""}     - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1}  - raise error condition in case of errors?
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_errors
#     sge_hostgroup.60/sge_hostgroup_messages
#*******************************************************************************
proc del_hostgroup {group {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT

   puts $CHECK_OUTPUT "Delete hostgroup $group ..."

   get_hostgroup_messages messages "del" "$group" $on_host $as_user
         puts $CHECK_OUTPUT $messages(0)
   set output [start_sge_bin "qconf" "-dhgrp $group" $on_host $as_user]

   return [handle_sge_errors "del_hostgroup" "qconf -dhgrp $group" $output messages $raise_error]

}

#****** sge_hostgroup.60/get_hostgroup_list() **********************************
#  NAME
#    get_hostgroup_list () -- get the list of all host groups
#
#  SYNOPSIS
#     get_hostgroup_list { {output_var result} {on_host ""} {as_user ""} 
#     {raise_error 1}  }
#
#  FUNCTION
#     Calls qconf -shgrpl to retrieve the list of all host groups in SGE
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
#     sge_hostgroup/get_hostgroup_messages()
#*******************************************************************************
proc get_hostgroup_list {{output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
     
   puts $CHECK_OUTPUT "Get hostgroup list ..."

   upvar $output_var out
   
   get_hostgroup_messages messages "list" "" $on_host $as_user 
   
   return [get_qconf_object "get_hostgroup_list" "-shgrpl" out messages 1 $on_host $as_user $raise_error]
}

#****** sge_hostgroup.60/mod_hostgroup() ***************************************
#  NAME
#     mod_hostgroup() -- Modify existing host group configuration object
#
#  SYNOPSIS
#     mod_hostgroup { group change_array {fast_add 1}  {on_host ""} {as_user ""} 
#     {raise_error 1}}
#
#  FUNCTION
#     Modify the host group $group in the Grid Engine cluster.
#     Supports fast (qconf -Mhgrp) and slow (qconf -mhgrp) mode.
#
#  INPUTS
#     group           - host group we wish to modify
#     change_array    - the array of attributes and it's values
#     {fast_add 1}    - use fast mode
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1}  - do add_proc_error in case of errors
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_hostgroup/get_hostgroup_messages()
#*******************************************************************************
proc mod_hostgroup { group change_array {fast_add 1} {on_host ""} {as_user ""}  {raise_error 1} } {
   global CHECK_OUTPUT DISABLE_ADD_PROC_ERROR
   get_current_cluster_config_array ts_config

   upvar $change_array chgar
   set chgar(group_name) "$group"

   get_hostgroup_messages messages "mod" "$group" $on_host $as_user

   if { $fast_add } {
      puts $CHECK_OUTPUT "Modify hostgroup $group from file ..."
      set option "-Mhgrp"
      set DISABLE_ADD_PROC_ERROR 1
      get_hostgroup $group curr_grp $on_host $as_user
      set DISABLE_ADD_PROC_ERROR 0
      update_change_array curr_grp chgar
      set tmpfile [dump_array_to_tmpfile curr_grp]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]

   } else {
      puts $CHECK_OUTPUT "Modify hostgroup $group slow ..."
      set option "-mhgrp"
      # BUG: different message for "vi" from fastadd ...
      add_message_to_container messages -1 [translate_macro MSG_HGROUP_NOTEXIST_S "$group"]
      set vi_commands [build_vi_command chgar]
      set result [start_vi_edit "qconf" "$option $group" $vi_commands messages $on_host $as_user]

   }

   return [handle_sge_errors "mod_hostgroup" "qconf $option" $result messages $raise_error]
}

#****** sge_hostgroup.60/get_hostgroup_tree() **********************************
#  NAME
#     get_hostgroup_tree() -- get tree like structure of host group
#
#  SYNOPSIS
#     get_hostgroup_tree { group {output_var result}  {on_host ""} {as_user ""} 
#     {raise_error 1}}
#     
#
#  FUNCTION
#     Calls qconf -shgrp_tree @allhosts to retrieve tree like structure of @allhosts group
#
#  INPUTS
#     group        - value of host group we wish to see 
#     {output_var result} - result will be placed here
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - raise an error condition on error (default), or just
#                       output the error message to stdout
#
#  RESULT
#     0 on success, an error code on error.
#     For a list of error codes, see sge_procedures/get_sge_error().
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_hostgroup/get_hostgroup_messages()
#*******************************************************************************
proc get_hostgroup_tree {group {output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   upvar $output_var out

   puts $CHECK_OUTPUT "Get tree for hostgroup $group ..."
   
   get_hostgroup_messages messages "get_tree" "" $on_host $as_user 

   return [get_qconf_object "get_hostgroup_tree" "-shgrp_tree $group" out messages 0 $on_host $as_user $raise_error]

}

#****** sge_hostgroup.60/get_hostgroup_resolved() ******************************
#  NAME
#     get_hostgroup_resolved() -- get list of host group
#
#  SYNOPSIS
#     get_hostgroup_resolved { group {output_var result} {on_host ""} {as_user ""} {raise_error 1}
#     
#
#  FUNCTION
#     Calls qconf -shgrp_resolved $group to retrieve list of host group
#
#  INPUTS
#     group           - value of host group we wish to see
#     output_var      - result will be placed here
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - raise an error condition on error (default), or just
#                       output the error message to stdout
#
#  RESULT
#     0 on success, an error code on error.
#     For a list of error codes, see sge_procedures/get_sge_error().
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_hostgroup/get_hostgroup_messages()
#*******************************************************************************
proc get_hostgroup_resolved {group {output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   upvar $output_var out

   puts $CHECK_OUTPUT "Get resolved for host group $group ..."

   get_hostgroup_messages messages "get_resolved" "" $on_host $as_user 

   return [get_qconf_object "get_hostgroup_resolved" "-shgrp_resolved $group" out messages 0 $on_host $as_user $raise_error]

}

#****** sge_hostgroup.60/get_hostgroup_messages() ******************************
#  NAME
#     get_hostgroup_messages() -- returns the set of messages related to action 
#                              on hostgroup, i.e. add, modify, delete, get
#
#  SYNOPSIS
#     get_hostgroup_messages {msg_var action obj_name result {on_host ""} {as_user ""}} 
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
proc get_hostgroup_messages {msg_var action obj_name {on_host ""} {as_user ""}} {
   global CHECK_OUTPUT
   get_current_cluster_config_array ts_config

   upvar $msg_var messages
   if { [info exists messages]} {
      unset messages
   }
     
   set GROUP "host group"

   sge_client_messages messages $action $GROUP $obj_name $on_host $as_user

   # the place for exceptions: # VD version dependent  
   #                           # CD client dependent
   # see sge_procedures/sge_client_messages
   switch -exact $action {
      "add" {
         add_message_to_container messages -4 [translate_macro MSG_GDI_KEYSTR_KEYWORD_SS "*" "$obj_name"]
         add_message_to_container messages -5 [translate_macro MSG_HGRP_INVALIDHOSTGROUPNAME_S "$obj_name"]
         add_message_to_container messages -6 [translate_macro MSG_HGRP_UNKNOWNHOST "*"]
      }
      "get" {
         # BUG: rather use the generic message, see sge_procedures/sge_client_messages
         add_message_to_container messages -1 [translate_macro MSG_HGROUP_NOTEXIST_S "$obj_name"]
      }
      "mod" {
         add_message_to_container messages -6 [translate_macro MSG_HGRP_UNKNOWNHOST "*" ]
      }
      "del" {
         add_message_to_container messages -2 [translate_macro MSG_HGROUP_REFINHGOUP_SS "$obj_name" "*"]
         add_message_to_container messages -3 [translate_macro MSG_CQUEUE_REFINHGOUP_SS "$obj_name" "*"]
         # BUG: group entry instead of host group
         # set up the values of host and user for macro messages, if not set
         if {$on_host == ""} {
            set on_host "*"
         }
         if {$as_user == ""} {
            set as_user "*"
         } 
         set REMOVED [translate_macro MSG_SGETEXT_REMOVEDFROMLIST_SSSS "$as_user" "$on_host" "$obj_name" "$GROUP entry"]
         add_message_to_container messages 0 $REMOVED        
      }
      "list" {
         # BUG: group list instead of host group
         set NOT_DEFINED [translate_macro MSG_QCONF_NOXDEFINED_S "$GROUP list"]
         add_message_to_container messages -1 $NOT_DEFINED
      }
      "get_tree" {
         add_message_to_container messages -1 [translate_macro MSG_HGROUP_NOTEXIST_S $GROUP]
      }
      "get_resolved" {
         add_message_to_container messages -1 [translate_macro MSG_HGROUP_NOTEXIST_S $GROUP]
      }
   } 
}
