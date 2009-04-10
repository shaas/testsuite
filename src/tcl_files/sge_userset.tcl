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

#****** sge_userset/set_userset_defaults() *************************************
#  NAME
#     set_userset_defaults() -- create version dependent userset settings
#
#  SYNOPSIS
#     set_userset_defaults {change_array}
#
#  FUNCTION
#     Fills the array change_array with default userset attributes for the 
#     specific version of SGE.
#
#  INPUTS
#     change_array - the resulting array
#
#*******************************************************************************
proc set_userset_defaults {change_array} {
   get_current_cluster_config_array ts_config
   
   upvar $change_array chgar

   set chgar(name)        "template"
   set chgar(type)        "ACL"
   set chgar(fshare)      "0"
   set chgar(oticket)     "0"
   set chgar(entries)     "NONE"
}

#****** sge_userset/add_userset() **********************************************
#
#  NAME
#     add_userset -- add a userset with qconf -Au
#
#  SYNOPSIS
#     add_userset { name change_array {fast_add 1} {on_host ""} {as_user ""} 
#     {raise_error 1}}
#
#  FUNCTION
#     Add the userset using qconf -au $name
#
#  INPUTS
#     name              - the name of the userset
#     {change_array ""} - the userset description
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
#     sge_userset/get_userset_messages()
#*******************************************************************************
proc add_userset {name change_array {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_USER CHECK_USER
   get_current_cluster_config_array ts_config
 
   if { [ string compare $ts_config(product_type) "sge" ] == 0 } {
     ts_log_config "not possible for sge systems"
     return -9
   }
   
   get_userset_messages messages "add" "$name" $on_host $as_user
  
   if {$fast_add} {
      ts_log_fine "Add userset $name from file ..."
      set option "-Au"
      upvar $change_array chgar
      set chgar(name) $name
      set_userset_defaults old_config
      update_change_array old_config chgar
      set tmpfile [dump_array_to_tmpfile old_config]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]
      unset chgar(name)
      return [handle_sge_errors "add_userset" "qconf $option" $result messages $raise_error]
      
   } else {
      ts_log_fine "Add userset using vi is not supported ..."
      return 0

   }   

}

#****** sge_userset/get_userset() **********************************************
#
#  NAME
#     get_userset -- Get userset configuration information
#                    Represents qconf -sprj command in sge
#
#  SYNOPSIS
#     get_userset {name change_array {on_host ""} {as_user ""} {raise_error 1}}
#
#  FUNCTION
#     Get the actual configuration settings for the named userset
#
#  INPUTS
#     name                - name of the userset
#     {output_var result} - name of an array variable set by get_config
#     {on_host ""}        - execute qconf on this host (default: qmaster host)
#     {as_user ""}        - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1}     - raise error condition in case of errors?
#
#  RESULT
#     0 on success, an error code on error.
#     For a list of error codes, see sge_procedures/get_sge_error().
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_userset/get_userset_messages()
#*******************************************************************************
proc get_userset {name {output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   upvar $output_var out
  
   ts_log_fine "Get userset $name ..."
   
   get_userset_messages messages "get" "$name" $on_host $as_user

   return [get_qconf_object "get_userset" "-su $name" out messages 0 $on_host $as_user $raise_error]
}

#****** sge_userset/del_userset() **********************************************
#
#  NAME
#     del_userset -- Delete an userset 
#
#  SYNOPSIS
#     del_userset { name {on_host ""} {as_user ""} {raise_error 1} } 
#
#  FUNCTION
#     Deletes an userset using qconf -du
#
#  INPUTS
#     name                -  Name of the userset
#     {on_host ""}        - execute qconf on this host (default: qmaster host)
#     {as_user ""}        - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1}     - raise error condition in case of errors?
#
#  RESULT
#     0 - on success
#    <0 - on error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_userset/get_userset_messages()
#*******************************************************************************
proc del_userset { name {on_host ""} {as_user ""} {raise_error 1} } {
   global CHECK_USER
   get_current_cluster_config_array ts_config
   
   ts_log_fine "Delete userset $name ..."

   get_userset_messages messages "del" "$name" $on_host $as_user
   
   set output [start_sge_bin "qconf" "-dul $name" $on_host $as_user]

   return [handle_sge_errors "del_userset" "qconf -dul $name" $output messages $raise_error]

}

#****** sge_userset/get_userset_list() *****************************************
#  NAME
#    get_userset_list () -- get the list of usersets
#
#  SYNOPSIS
#     get_userset_list { {output_var result} {on_host ""} {as_user ""} {raise_error 1}  }
#
#  FUNCTION
#     Calls qconf -sul to retrieve the userset list
#
#  INPUTS
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
#     sge_userset/get_userset_messages()
#*******************************************************************************
proc get_userset_list {{output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   upvar $output_var out

   ts_log_fine "Get userset list ..."

   get_userset_messages messages "list" "" $on_host $as_user 
   
   return [get_qconf_object "get_userset_list" "-sul" out messages 1 $on_host $as_user $raise_error]

}

#****** sge_userset/mod_userset() **********************************************
#
#  NAME
#     mod_userset -- modify the userset
#
#  SYNOPSIS
#     mod_userset {attribute value change_array {fast_add 1} {on_host ""} 
#     {as_user ""} raise_error}
#
#  FUNCTION
#     Calls qconf -M(m)prj to modify userset
#
#  INPUTS
#     userset 	   - userset we are modifying
#     change_array - the array of attributes and it's values
#     {fast_add 1} - 0: modify the attribute using qconf -mckpt,
#                  - 1: modify the attribute using qconf -Mckpt, faster
#     {on_host ""} - execute qconf on this host, default is master host
#     {as_user ""} - execute qconf as this user, default is $CHECK_USER
#     raise_error  - raise error condition in case of errors
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_userset/get_userset_messages()
#*******************************************************************************
proc mod_userset {userset change_array {fast_add 1} {on_host ""} {as_user ""} {raise_error 1} } {
   get_current_cluster_config_array ts_config
     
   # userset doesn't exist for sge systems
   if {[string compare $ts_config(product_type) "sge"] == 0} {
      ts_log_config "not possible for sge systems"
      return -9
   }
   
   upvar $change_array chgar
   set chgar(name) "$userset"
  
   get_userset_messages messages "mod" "$userset" $on_host $as_user
     
   if { $fast_add } {
      ts_log_fine "Modify userset $userset from file ..."
      set option "-Mu"
      get_userset $userset curr_uset $on_host $as_user 0
      if {![info exists curr_uset]} {
         set_userset_defaults curr_uset
   }
      update_change_array curr_uset chgar
      set tmpfile [dump_array_to_tmpfile curr_uset]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]
  
   } else {
      ts_log_fine "Modify userset $userset slow ..."
      set option "-mu"
      set vi_commands [build_vi_command chgar]
      # BUG: a different message for mod userset slow when userset does not exist
      set uset_exist 0
      get_userset_list arr "" "" 0
      if {[info exists arr]} {
         foreach elem $arr {
            if {[string compare $elem $userset] == 0} {
               set uset_exist 1
               break
            }
         }
      }
      if {$uset_exist == 0} {
         set ADDED [translate_macro MSG_SGETEXT_ADDEDTOLIST_SSSS "*" "*" "$userset" "userset"]
         ts_log_fine "Change the expected message for the case userset doesn't exist -> $ADDED"
         add_message_to_container messages 0 $ADDED
      }
      set result [start_vi_edit "qconf" "$option $userset" $vi_commands messages $on_host $as_user]

   }

   return [handle_sge_errors "mod_userset" "qconf $option" $result messages $raise_error]
   }

#****** sge_procedures/add_access_list() ***************************************
#  NAME
#     add_access_list() -- add user access list
#
#  SYNOPSIS
#     add_access_list { user_array list_name } 
#
#  FUNCTION
#     This procedure starts the qconf -au command to add a new user access list.
#
#  INPUTS
#     user_array - tcl array with user names
#     list_name  - name of the new list
#
#  RESULT
#     -1 on error, 0 on success
#
#  SEE ALSO
#     sge_procedures/del_access_list()
#
#*******************************************************************************
proc add_access_list { user_array list_name } {
  get_current_cluster_config_array ts_config

 # aja: TODO: format arguments
  set arguments ""
  foreach elem $user_array {
     append arguments "$elem,"
   }
  append arguments " $list_name"

  set result [start_sge_bin "qconf" "-au $arguments"]

  set ADDED [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_GDI_ADDTOACL_SS ] $user_array $list_name]
  if { [string first "added" $result ] < 0 && [string first $ADDED $result ] < 0 } {
     ts_log_severe "could not add access_list $list_name"
     return -1
   }
     return 0
   }


#****** sge_procedures/del_user_from_access_list() ***************************************
#  NAME
#     del_user_from_access_list() -- delete a user from an access list
#
#  SYNOPSIS
#     del_user_from_access_list { user_name list_name } 
#
#  FUNCTION
#     This procedure starts the qconf -du command to delete a user from a 
#     access list
#
#  INPUTS
#     user_name - name of the user
#     list_name - name of access list
#     {on_host ""}    - execute qconf on host
#     {as_user ""}    - execute qconf as user
#     {raise_error 1} - send error mails
#
#  RESULT
#      1  User was not in the access_list
#      0  User deleted from the access_list
#     -1 on error
#
#  EXAMPLE
#
#    set result [ del_user_from_access_list "codtest1" "deadlineusers" ]
#
#    if { $result == 0 } {
#       ts_log_fine "user codtest1 deleted from access list deadlineusers"
#    } elseif { $result == 1 } {
#       ts_log_fine "user codtest1 did not exist on the access list deadlineusers"
#    } else {
#       ts_log_severe "Can not delete user codtest1 from access list deadlineusers"
#    }
# 
#  SEE ALSO
# 
#*******************************************************************************
proc del_user_from_access_list { user_name list_name {on_host ""} {as_user ""} {raise_error 1}} {
   get_current_cluster_config_array ts_config

   get_userset_messages messages "del_user" "$user_name $list_name" $on_host $as_user

   set result [start_sge_bin "qconf" "-du $user_name $list_name" $on_host $as_user]

   return [handle_sge_errors "del_user_from_access_list" "-du $user_name $list_name" $result messages $raise_error]

   }

#****** sge_procedures/add_user_to_access_list() *******************************
#  NAME
#     add_user_to_access_list() -- add a user to an access list
#
#  SYNOPSIS
#     add_user_to_access_list { user_name list_name {on_host ""} {as_user ""} 
#     {raise_error 1} } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     user_name       - name of the user
#     list_name       - name of the user set
#     {on_host ""}    - execute qconf on host
#     {as_user ""}    - execute qconf as user
#     {raise_error 1} - send error mails
#
#  RESULT
#      0  User added to the access_list
#     -1  User is already in the access_list
#*******************************************************************************
proc add_user_to_access_list { user_name list_name {on_host ""} {as_user ""} {raise_error 1}} {
   # aja: TODO: handle messages for multiple users/usersets
   set ret 0

   set result [start_sge_bin "qconf" "-au $user_name $list_name" $on_host $as_user]

   set messages(index) "0 -1"
   set messages(0) [translate_macro MSG_GDI_ADDTOACL_SS $user_name $list_name]
   set messages(-1) [translate_macro MSG_GDI_USERINACL_SS $user_name $list_name]

   set ret [handle_sge_errors "add_user_to_access_list" "-au $user_name $list_name" $result messages $raise_error]

   if {($prg_exit_state != 0 && $ret >= 0) || ($prg_exit_state == 0 && $ret < 0)} {
      add_prog_error "add_user_to_access_list" -1 "qconf -au return value and message does not match together"
}

   return $ret
}


#****** sge_procedures/del_access_list() ***************************************
#  NAME
#     del_access_list() -- delete user access list
#
#  SYNOPSIS
#     del_access_list {{ list_name } {raise_error 1}}
#
#  FUNCTION
#     This procedure starts the qconf -dul command to delete a user access
#     list.
#
#  INPUTS
#     list_name - name of access list to delete
#     raise_error - raise error condition in case of errors
#
#  RESULT
#     -1 on error, 0 on success
#
#  SEE ALSO
#     sge_procedures/add_access_list()
# 
#*******************************************************************************
proc del_access_list { list_name {on_host ""} {as_user ""} {raise_error 1}} {

   return [del_userset $list_name $on_host $as_user $raise_error]

}

#****** sge_users/get_ulist() ******************************************
#  NAME
#     get_ulist() -- Get template user list array
#
#  SYNOPSIS
#     get_ulist { userlist array   {raise_error 1}}
#
#  FUNCTION
#     Create user in userlist
#
#  INPUTS
#     userlist     - user name to be modifies
#     array        - array containing the changed attributes.
#     {fast_add 1} - 0: modify the attribute using qconf -mckpt,
#                  - 1: modify the attribute using qconf -Mckpt, faster
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - raise an error condition on error (default), or just
#                       output the error message to stdout
#
#  RESULT
#
#  COMMENT 
#   Use this construct due to some issues with using get_qconf_list
#
#*******************************************************************************

proc get_ulist { userlist change_array {raise_error 1}} {
   upvar $change_array chgar
   get_userset $userlist chgar "" "" $raise_error
}

#****** sge_userset/get_userset_messages() *************************************
#  NAME
#     get_userset_messages() -- returns the set of messages related to action 
#                              on userset, i.e. add, modify, delete, get
#
#  SYNOPSIS
#     get_userset_messages {msg_var action obj_attr result {on_host ""} {as_user ""}} 
#
#  FUNCTION
#     Returns the set of messages related to action on sge object. This function
#     is a wrapper of sge_object_messages which is general for all types of objects
#S
#  INPUTS
#     msg_var       - array of messages (the pair of message code and message value)
#     action        - action examples: add, modify, delete,...
#     obj_attr      - any object attribute you want to pass to the function 
#                     i.e. sge object name,...
#     {on_host ""}  - execute on this host, default is master host
#     {as_user ""}  - execute qconf as this user, default is $CHECK_USER
#
#  SEE ALSO
#     sge_procedures/sge_client_messages()
#*******************************************************************************
proc get_userset_messages {msg_var action obj_attr {on_host ""} {as_user ""}} {
   get_current_cluster_config_array ts_config

   upvar $msg_var messages
   if {[info exists messages]} {
      unset messages
   }
   
   set USERSET [translate_macro MSG_OBJ_USERSET]

   sge_client_messages messages $action $USERSET $obj_attr $on_host $as_user

   # the place for exceptions: # VD version dependent  
   #                           # CD client dependent
   # see sge_procedures/sge_client_messages
   switch -exact $action {
      "add" {
         # when oticket,fshare parameters set incorrectly
         # BUG: returns: error parsing unsigned long value from string "xxx"
         #                cant read project
         # should return: MSG_OBJECT_VALUENOTULONG_S (already among the messages)
         add_message_to_container messages -4 "error: [translate_macro MSG_ULONG_INCORRECTSTRING "*"]"
         add_message_to_container messages -5 "error: [translate_macro MSG_GDI_READCONFIGFILEUNKNOWNSPEC_SS "*" $USERSET]"
         add_message_to_container messages -6 [translate_macro MSG_QMASTER_ACLNOSHARE]
         add_message_to_container messages -7 [translate_macro MSG_QMASTER_ACLNOTICKET]
         add_message_to_container messages -11 [translate_macro MSG_GDI_READCONFIGFILEEMPTYSPEC_S "*"]
         if {$ts_config(gridengine_version) >= 61 && ![is_61AR]} {
            add_message_to_container messages -12 [translate_macro MSG_MUST_BE_POSITIVE_VALUE_S "*"]
         }
      }
      "get" {
         set NOT_EXISTS [translate_macro MSG_SGETEXT_DOESNOTEXIST_SS "access list" "$obj_attr"]
         add_message_to_container messages -1 $NOT_EXISTS
      }
      "list" {
         set NOT_DEFINED [translate_macro MSG_QCONF_NOXDEFINED_S "$USERSET list"]
         add_message_to_container messages -1 $NOT_DEFINED
      }
      "del" {
         #set NOT_EXISTS [translate_macro MSG_SGETEXT_DOESNOTEXIST_SS "access list" "$obj_attr"]
         # references: project, pe, queue
         set STILL_REF [translate_macro MSG_SGETEXT_USERSETSTILLREFERENCED_SSSS "$obj_attr" "*" "*" "*"]
         add_message_to_container messages -2 $STILL_REF
      }
      "mod" {
         # when oticket,fshare parameters set incorrectly
         # BUG: returns: error parsing unsigned long value from string "xxx"
         #                cant read project
         # should return: MSG_OBJECT_VALUENOTULONG_S (already among the messages)
         add_message_to_container messages -6 "error: [translate_macro MSG_ULONG_INCORRECTSTRING "*"]"
         add_message_to_container messages -7 "error: [translate_macro MSG_GDI_READCONFIGFILEUNKNOWNSPEC_SS "*" $USERSET]"
         add_message_to_container messages -8 [translate_macro MSG_QMASTER_ACLNOSHARE]
         add_message_to_container messages -9 [translate_macro MSG_QMASTER_ACLNOTICKET]
         add_message_to_container messages -11 [translate_macro MSG_GDI_READCONFIGFILEEMPTYSPEC_S "*"]
         if {$ts_config(gridengine_version) >= 61} {
            add_message_to_container messages -12 [translate_macro MSG_MUST_BE_POSITIVE_VALUE_S "*"]
         }
      }
      "add_user" {
         # aja: TODO: foreach user, foreach userset, build the expected. message
         add_message_to_container messages 0 [translate_macro MSG_GDI_ADDTOACL_SS "*" "*"]
         add_message_to_container messages -1 [translate_macro MSG_GDI_USERINACL_SS "*" "*"]
      }
      "del_user" {
         # aja: TODO: foreach user, foreach userset, build the expected. message
         add_message_to_container messages 0 [translate_macro MSG_GDI_DELFROMACL_SS "*" "*"]
         add_message_to_container messages -1 [translate_macro MSG_GDI_USERNOTINACL_SS "*" "*"]
         #add_message_to_container messages -2 [translate_macro MSG_GDI_DELFROMACL_SS "*" "*"]
         if {$ts_config(gridengine_version) >= 62} {
            add_message_to_container messages -3 [translate_macro MSG_PARSE_MOD3_REJECTED_DUE_TO_AR_SU "*" "*"]
         }
         add_message_to_container messages -4 [translate_macro MSG_GDI_ACLDOESNOTEXIST_S "*"] 
      }
   } 
}
