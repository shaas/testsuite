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

#****** sge_limit_rules.65/get_lirs() ******************************************
#  NAME
#     get_lirs() -- get limitation rule set config
#
#  SYNOPSIS
#     get_lirs { output_var {lirs ""} {on_host ""} {as_user ""} {raise_error 1} 
#     } 
#
#  FUNCTION
#     Execute 'qconf -slrs (name)' to get one or more limitation rule sets
#
#  INPUTS
#     output_var      - result
#     {lirs ""}       - limitation rule set name(s)
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - do add_proc_error in case of errors
#
#  RESULT
#     0 on success, an error code on error
#*******************************************************************************
proc get_lirs {output_var {lirs ""} {on_host ""} {as_user ""} {raise_error 1}} {
   global ts_config
   upvar $output_var out

   # clear output variable
   if {[info exists out]} {
      unset out
   }

   set ret 0
   set result [start_sge_bin "qconf" "-slrs $lirs" $on_host $as_user]

   # parse output or raise error
   if {$prg_exit_state == 0} {
      parse_lirs_record result out
   } else {
      set ret [get_lirs_error $result $lirs $raise_error]
   }

   return $ret
}

#****** sge_limit_rules.65/get_lirs_list() *************************************
#  NAME
#     get_lirs_list() -- get a list of all configured limitation rule sets
#
#  SYNOPSIS
#     get_lirs_list { {output_var result} {on_host ""} {as_user ""} 
#     {raise_error 1} } 
#
#  FUNCTION
#     Executes 'qconf -slrsl' to get a list of all limitation rule sets
#
#  INPUTS
#     {output_var result} - result output
#     {on_host ""}        - execute qconf on this host, default is master host
#     {as_user ""}        - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1}       - do add_proc_error in case of errors
#
#  RESULT
#     0 on success, the error or qconf on failure
#*******************************************************************************
proc get_lirs_list {{output_var result} {on_host ""} {as_user ""} {raise_error 1}} {
   upvar $output_var out

   return [get_qconf_list "get_lirs_list" "-slrsl" out $on_host $as_user $raise_error]
}

#****** sge_limit_rules.65/get_lirs_error() ************************************
#  NAME
#     get_lirs_error() -- error handling for get_lirs
#
#  SYNOPSIS
#     get_lirs_error { result lirs raise_error } 
#
#  FUNCTION
#     Does the error handling for get_lirs.
#     Translate possible error massages of qconf -slrs, builds the datastructure
#     required for the handle_sge_error function call.
#
#  INPUTS
#     result      - qconf output
#     lirs        - name for which qconf -slrs has been called
#     raise_error - do add_proc_error in case of errors
#
#  RESULT
#     Returncode for the get_lirs function:
#
#*******************************************************************************
proc get_lirs_error {result lirs raise_error } {

   # recognize certain error messages and return special return code
   set messages(index) "-1"
   set messages(-1) [translate_macro MSG_NOLIRSFOUND]

   # now evaluate return code and raise errors
   set ret [handle_sge_errors "get_lirs" "qconf -slrs $lirs" $result messages $raise_error]

   return $ret
}

#****** sge_limit_rules.65/add_lirs() ******************************************
#  NAME
#     add_lirs() -- Add limitation rule set(s)
#
#  SYNOPSIS
#     add_lirs { change_array {fast_add 1} {on_host ""} {as_user ""} 
#     {raise_error 1} } 
#
#  FUNCTION
#     Calls qconf -alrs/-Alrs to add a new limitation rule set
#
#  INPUTS
#     change_array    - array that contains new limitation rule set(s)
#     {fast_add 1}    - add fast with -Alrs or slow from CLI with -alrs
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - do add_proc_error in case of errors
#
#  RESULT
#     0 on success, an error code on error.
#*******************************************************************************
proc add_lirs {change_array {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
   global ts_config CHECK_OUTPUT CHECK_USER
   global env CHECK_ARCH
   global CHECK_CORE_MASTER

   upvar $change_array chgar

   # localize messages
   # JG: TODO: object name is taken from c_gdi object structure - not I18Ned!!
   set ADDED [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_SGETEXT_ADDEDTOLIST_SSSS] $CHECK_USER "*" "*" "limitation rule" ]
   set ALREADY_EXISTS [ translate $ts_config(master_host) 1 0 0 [sge_macro MSG_SGETEXT_ALREADYEXISTS_SS] "limitation rule" "*"]

   set lirs_names ""
   set old_name ""

   foreach elem [lsort [array names chgar]] {
      set help [split $elem ","]
      set name [lindex $help 0]
      if { $old_name != $name } {
         set old_name "$name"
         if { $lirs_names == "" } {
            set lirs_names "$name"
         } else {
            set lirs_names "$lirs_names,$name"
         }
      }
   }

   # Add lirs from file?
   if { $fast_add } {
      set tmpfile [dump_lirs_array_to_tmpfile chgar]
      set result [start_sge_bin "qconf" "-Alrs $tmpfile" $on_host $as_user ]

      if { [string match "*$ADDED*" $result ] } {
         set result 0
      } else {
         add_proc_error "add_lirs" "-1" "qconf error or binary not found (error: $result)" $raise_error
         set result -2
      }
   } else {
   # Use vi
      set vi_commands [build_lirs_vi_array chgar]

      set result [handle_vi_edit "$ts_config(product_root)/bin/$CHECK_ARCH/qconf" "-alrs $lirs_names" $vi_commands $ADDED $ALREADY_EXISTS]
      if { $result != 0 } {
         add_proc_error "add_lirs" -1 "could not add limitation rule set (error: $result)" $raise_error
      }
   }
  return $result
}

#****** sge_limit_rules.65/mod_lirs() ******************************************
#  NAME
#     mod_lirs() -- Modify limitation rule set(s)
#
#  SYNOPSIS
#     mod_lirs { change_array {name ""} {fast_add 1} {on_host ""} {as_user ""} 
#     {raise_error 1} } 
#
#  FUNCTION
#     Calls qconf -Mlrs $file to modify limitation örule sets, or -mlrs
#
#  INPUTS
#     change_array    - array that contains limitation rule set(s) to be modified
#     {name ""}       - names of the limitation rule sets that should be modified
#     {fast_add 1}    - add fast with -Mlrs or slow from CLI with -mlrs
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - do add_proc_error in case of errors
#
#  RESULT
#     0 on success, an error code on error.
#*******************************************************************************
proc mod_lirs {change_array {name ""} {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} {
   global ts_config CHECK_OUTPUT CHECK_USER
   global env CHECK_ARCH
   global CHECK_CORE_MASTER
   
   upvar $change_array chgar

   set MODIFIED [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_SGETEXT_MODIFIEDINLIST_SSSS] $CHECK_USER "*" "*" "limitation rule" ]
   set ADDED [translate $ts_config(master_host) 1 0 0 [sge_macro MSG_SGETEXT_ADDEDTOLIST_SSSS] $CHECK_USER "*" "*" "limitation rule" ]
   set NOT_MODIFIED [translate_macro MSG_FILE_NOTCHANGED ]


   # Modify lirs from file?
   if { $fast_add } {
      set tmpfile [dump_lirs_array_to_tmpfile chgar]
      set result [start_sge_bin "qconf" "-Mlrs $tmpfile $name" $on_host $as_user]

      if { [string match "*$MODIFIED*" $result ] || [string match "*$ADDED*" $result ]} {
         set result 0
      } else {
         add_proc_error "mod_lirs" "-1" "qconf error or binary not found (error: $result)" $raise_error
         set result -2
      }
   } else {
      # Use vi
      set vi_commands [build_lirs_vi_array chgar]

      if { $name != "" } {
         set result [handle_vi_edit "$ts_config(product_root)/bin/$CHECK_ARCH/qconf" "-mlrs $name" $vi_commands $MODIFIED $ADDED $NOT_MODIFIED]
      } else {
         set result [handle_vi_edit "$ts_config(product_root)/bin/$CHECK_ARCH/qconf" "-mlrs $name" $vi_commands $ADDED $MODIFIED $NOT_MODIFIED]
      }
      if { $result != 0 } {
         add_proc_error "mod_lirs" -1 "could not modify limitation rule set (error: $result)" $raise_error
      }
   }
}

#****** sge_limit_rules.65/del_lirs() ******************************************
#  NAME
#     del_lirs() -- Deletes limitation rule set(s)
#
#  SYNOPSIS
#     del_lirs { lirs_name {on_host ""} {as_user ""} {raise_error 1} } 
#
#  FUNCTION
#     Deletes the given limitation rule sets
#
#  INPUTS
#     lirs_name       - name of the limitation rule set
#     {on_host ""}    - execute qconf on this host, default is master host
#     {as_user ""}    - execute qconf as this user, default is $CHECK_USER
#     {raise_error 1} - do add_proc_error in case of errors
#
#  RESULT
#     0 on success, an error code on error.
#*******************************************************************************
proc del_lirs {lirs_name {on_host ""} {as_user ""} {raise_error 1}} {
   global ts_config CHECK_USER
   
   set messages(index) "0"
   set messages(0) [translate_macro MSG_SGETEXT_REMOVEDFROMLIST_SSSS $CHECK_USER "*" $lirs_name "*"]

   set output [start_sge_bin "qconf" "-dlrs $lirs_name" $on_host $as_user ]

   set ret [handle_sge_errors "del_lirs" "qconf -dlrs $lirs_name" $output messages $raise_error]
   return $ret
}
