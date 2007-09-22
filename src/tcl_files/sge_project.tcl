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

#****** sge_project/set_project_defaults() *************************************
#  NAME
#     set_project_defaults() -- create version dependent project settings
#
#  SYNOPSIS
#     set_project_defaults {change_array}
#
#  FUNCTION
#     Fills the array change_array with default project attributes for the 
#     specific version of SGE.
#
#  NOTE
#     Project does not exist for sge systems
#
#  INPUTS
#     change_array - the resulting array
#
#*******************************************************************************
proc set_project_defaults {change_array} {
   get_current_cluster_config_array ts_config
   
   upvar $change_array chgar
    
   set chgar(name)        "template"
   set chgar(oticket)     "0"
   set chgar(fshare)      "0"
   set chgar(acl)         "NONE"
   set chgar(xacl)        "NONE"
}

#****** sge_project/add_project() **********************************************
# 
#  NAME
#     add_project -- add a new project configuration object
#
#  SYNOPSIS
#     add_project {project {change_array ""} {fast_add 1} {on_host ""} 
#     {as_user ""} {raise_error 1}}
#
#  FUNCTION
#     Add a project to the Grid Engine cluster.
#     Supports fast (qconf -Aprj) and slow (qconf -aprj) mode.
#
#  INPUTS
#     project           - the name of the project
#     {change_array ""} - the project description
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
#     sge_project/get_project_messages()
#*******************************************************************************
proc add_project {project {change_array ""} {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   get_current_cluster_config_array ts_config

   # project doesn't exist for sge systems
   if {[string compare $ts_config(product_type) "sge"] == 0} {
      add_proc_error "add_project" -1 "not possible for sge systems"
      return -9
   }
   
   upvar $change_array chgar
   set chgar(name) "$project"

   get_project_messages messages "add" "$project" $on_host $as_user
   
   if {$fast_add} {
      puts $CHECK_OUTPUT "Add project $project from file ..."
      set option "-Aprj"
      set_project_defaults old_config
      update_change_array old_config chgar
      set tmpfile [dump_array_to_tmpfile old_config]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]

    } else {
      puts $CHECK_OUTPUT "Add project $project slow ..."
      set option "-aprj"
      set vi_commands [build_vi_command chgar]
      set result [start_vi_edit "qconf" "$option" $vi_commands messages $on_host $as_user]

   }

   return [handle_sge_errors "add_project" "qconf $option" $result messages $raise_error]
}

#****** sge_project/add_prj() **************************************************
# @deprecated
proc add_prj {change_array {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
   upvar $change_array chgar
   set prj_name $chgar(name)
   return [add_project $prj_name chgar $fast_add $on_host $as_user $raise_error]
}

#****** sge_project/get_project() **********************************************
# 
#  NAME
#     get_project -- get project configuration object
#
#  SYNOPSIS
#     get_project {project {output_var result} {on_host ""} {as_user ""}
#     {raise_error 1}}
#
#  FUNCTION
#     Get the actual configuration settings for the named project
#     Represents qconf -sprj command in SGE
#
#  INPUTS
#     project             - name of the project
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
#     sge_project/get_project_messages()
#*******************************************************************************
proc get_project {project {output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   get_current_cluster_config_array ts_config
     
   # project doesn't exist for sge systems
   if {[string compare $ts_config(product_type) "sge"] == 0} {
      add_proc_error "get_project" -1 "not possible for sge systems"
      return -9
   }
   puts $CHECK_OUTPUT "Get project $project ..."

   upvar $output_var out

   get_project_messages messages "get" "$project" $on_host $as_user
   
   return [get_qconf_object "get_project" "-sprj $project" out messages 0 $on_host $as_user $raise_error]
   
}

#****** sge_project/get_prj() **************************************************
# @deprecated
proc get_prj { prj_name change_array } {
   upvar $change_array chgar
   return [get_project $prj_name chgar]
}

#****** sge_project/del_project() **********************************************
# 
#  NAME
#     del_project -- delete project configuration object
#
#  SYNOPSIS
#     del_project { project {on_host ""} {as_user ""} {raise_error 1} } 
#
#  FUNCTION
#     Delete the project configuration object
#     Represents qconf -dprj command in SGE
#
#  INPUTS
#     project         - name of the project
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
#     sge_project/get_project_messages()
#*******************************************************************************
proc del_project { project {on_host ""} {as_user ""} {raise_error 1} } {
   global CHECK_OUTPUT
   get_current_cluster_config_array ts_config
   
    # project doesn't exist for sge systems
   if {[string compare $ts_config(product_type) "sge"] == 0} {
      add_proc_error "del_project" -1 "not possible for sge systems"
      return -9
   }
   
   puts $CHECK_OUTPUT "Delete project $project ..."

   get_project_messages messages "del" "$project" $on_host $as_user
   
   set output [start_sge_bin "qconf" "-dprj $project" $on_host $as_user]
   
   return [handle_sge_errors "del_project" "qconf -dprj $project" $output messages $raise_error]

}

#****** sge_project/del_prj() **************************************************
# @deprecated
proc del_prj { prj_name {raise_error 1} } {
   return [del_project $prj_name "" "" $raise_error]
}

#****** sge_project/get_project_list() *****************************************
#  NAME
#    get_project_list () -- get the list of all projects
#
#  SYNOPSIS
#     get_project_list { {output_var result} {on_host ""} {as_user ""} 
#     {raise_error 1}  }
#
#  FUNCTION
#     Calls qconf -sprjl to retrieve the list of all projects in SGE
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
#     sge_project/get_project_messages()
#*******************************************************************************
proc get_project_list {{output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_OUTPUT
   get_current_cluster_config_array ts_config
     
   # project doesn't exist for sge systems
   if {[string compare $ts_config(product_type) "sge"] == 0} {
      add_proc_error "get_project_list" -1 "not possible for sge systems"
      return -9
   }
   
   puts $CHECK_OUTPUT "Get project list ..."

   upvar $output_var out
   
   get_project_messages messages "list" "" $on_host $as_user 
   
   return [get_qconf_object "get_project_list" "-sprjl" out messages 1 $on_host $as_user $raise_error]

}

#****** sge_project/mod_project() **********************************************
#
#  NAME
#     mod_project -- modify existing project configuration object
#
#  SYNOPSIS
#     mod_project {project change_array {fast_add 1} {on_host ""} {as_user ""} 
#     {raise_error 1}}
#
#  FUNCTION
#     Modify the project $project in the Grid Engine cluster.
#     Supports fast (qconf -Mprj) and slow (qconf -mprj) mode.
#
#  INPUTS
#     project 	       - project we are modifying
#     change_array     - the array of attributes and it's values
#     {fast_add 1}     - use fast mode
#     {on_host ""}     - execute qconf on this host, default is master host
#     {as_user ""}     - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1}  - do add_proc_error in case of errors
#
#  RESULT
#       0 - success
#     < 0 - error
#
#  SEE ALSO
#     sge_procedures/handle_sge_error()
#     sge_project/get_project_messages()
#*******************************************************************************
proc mod_project {project change_array {fast_add 1} {on_host ""} {as_user ""} {raise_error 1} } {
   global CHECK_OUTPUT DISABLE_ADD_PROC_ERROR
   get_current_cluster_config_array ts_config
     
   # project doesn't exist for sge systems
   if {[string compare $ts_config(product_type) "sge"] == 0} {
      add_proc_error "mod_project" -1 "not possible for sge systems"
      return -9
   }
   
   upvar $change_array chgar
   set chgar(name) "$project"
   
   get_project_messages messages "mod" "$project" $on_host $as_user
     
   if { $fast_add } {
      puts $CHECK_OUTPUT "Modify project $project from file ..."
      set option "-Mprj"
      set DISABLE_ADD_PROC_ERROR 1
      get_project $project curr_prj $on_host $as_user
      set DISABLE_ADD_PROC_ERROR 0
      if {![info exists curr_prj]} {
         set_project_defaults curr_prj
      }
      update_change_array curr_prj chgar
      set tmpfile [dump_array_to_tmpfile curr_prj]
      set result [start_sge_bin "qconf" "$option $tmpfile" $on_host $as_user]

   } else {
      puts $CHECK_OUTPUT "Modify project $project slow ..."
      set option "-mprj"
      set vi_commands [build_vi_command chgar]
      set result [start_vi_edit "qconf" "$option $project" $vi_commands messages $on_host $as_user]

   }

   return [handle_sge_errors "mod_project" "qconf $option" $result messages $raise_error]
}

#****** sge_project/get_project_messages() *************************************
#  NAME
#     get_project_messages() -- returns the set of messages related to action 
#                              on project, i.e. add, modify, delete, get
#
#  SYNOPSIS
#     get_project_messages {msg_var action obj_name result {on_host ""} {as_user ""}} 
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
proc get_project_messages {msg_var action obj_name {on_host ""} {as_user ""}} {
   global CHECK_OUTPUT
   get_current_cluster_config_array ts_config

   upvar $msg_var messages
   if { [info exists messages]} {
      unset messages
   }
     
   set PROJECT [translate_macro MSG_PROJECT]

   sge_client_messages messages $action $PROJECT $obj_name $on_host $as_user

   # the place for exceptions: # VD version dependent  
   #                           # CD client dependent
   # see sge_procedures/sge_client_messages
   switch -exact $action {
      "add" {
         # VD: SGE 5.3 doesn't output anything on success
         if {$ts_config(gridengine_version) == 53} {
            add_message_to_container messages 0 ""
         }
         # when acl,xacl parameters set incorrectly
         add_message_to_container messages -4 [translate_macro MSG_CQUEUE_UNKNOWNUSERSET_S "*"]
         # when oticket,fshare parameters set incorrectly
         # BUG: returns: error parsing unsigned long value from string "xxx"
         #                cant read project
         # should return: MSG_OBJECT_VALUENOTULONG_S (already among the messages)
         add_message_to_container messages -5 "error: [translate_macro MSG_ULONG_INCORRECTSTRING "*"]"
      }
      "get" {
         # CD: not expected generic message
         set NOT_EXISTS [translate_macro MSG_PROJECT_XISNOKNWOWNPROJECT_S "$obj_name"]
         add_message_to_container messages -1 $NOT_EXISTS
      }
      "mod" {
         set NOT_EXISTS [translate_macro MSG_PROJECT_XISNOKNWOWNPROJECT_S "$obj_name"]
         add_message_to_container messages -6 $NOT_EXISTS
         # when acl,xacl parameters set incorrectly
         add_message_to_container messages -7 [translate_macro MSG_CQUEUE_UNKNOWNUSERSET_S "*"]
         # when oticket,fshare parameters set incorrectly
         # BUG: returns: error parsing unsigned long value from string "xxx"
         #                cant read project
         # should return: MSG_OBJECT_VALUENOTULONG_S (already among the messages)
         add_message_to_container messages -8 "error: [translate_macro MSG_ULONG_INCORRECTSTRING "*"]"
      }
      "del" {
         # references: queue, user
         set STILL_REF [translate_macro MSG_SGETEXT_USERSETSTILLREFERENCED_SSSS "$obj_name" "*" "*" "*"]
         add_message_to_container messages -2 $STILL_REF
      }
      "list" {
         # CD: should be project instead of project list
         set NOT_DEFINED [translate_macro MSG_QCONF_NOXDEFINED_S "project list"]
         add_message_to_container messages -1 $NOT_DEFINED
      }
   } 
}
