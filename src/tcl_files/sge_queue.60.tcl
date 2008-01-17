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
#****** sge_queue.60/get_queue_instance() **************************************
#  NAME
#     get_queue_instance () -- get the queue instance name
#
#  SYNOPSIS
#     get_queue_instance {queue host}
#
#  FUNCTION
#     Returns the name of the queue instance which is constructed by given queue 
#     name and the hostname.
#
#  INPUTS
#     queue - the name of the queue
#     host  - the hostname
#
#*******************************************************************************
proc get_queue_instance {queue host} {
   set resolved_host [resolve_host $host 1]
   return "${queue}@${resolved_host}"
}

#                                                             max. column:     |
#****** sge_queue/vdep_validate_queue() *********************************************
#  NAME
#     vdep_validate_queue() -- validate the default queue settings for sge 60.
#
#  SYNOPSIS
#     vdep_validate_queue {change_array}
#
#  FUNCTION
#     Validate the queue configuration values. Adjust the queue settings
#     according to sge version 60 systems.
#
#  INPUTS
#     change_array - the resulting array
#
#*******************************************************************************
proc vdep_validate_queue { change_array } {
   get_current_cluster_config_array ts_config
   upvar $change_array chgar

   if {[info exists chgar(qtype)]} {
      if { [string match "*CHECKPOINTING*" $chgar(qtype)] ||
           [string match "*PARALLEL*" $chgar(qtype)] } { 

         set new_chgar_qtype ""
         foreach elem $chgar(qtype) {
            if { [string match "*CHECKPOINTING*" $elem] } {
               ts_log_fine "queue type CHECKPOINTING is set by assigning a checkpointing environment to the queue"
            } else {
               if { [string match "*PARALLEL*" $elem] } {
                  ts_log_fine "queue type PARALLEL is set by assigning a parallel environment to the queue"
               } else {
                  append new_chgar_qtype "$elem "
               }
            }
         }
         set chgar(qtype) [string trim $new_chgar_qtype]
         ts_log_fine "using qtype=$chgar(qtype)" 
      }
   }
}

proc vdep_set_queue_values { hostlist change_array } {
   upvar $change_array chgar

   if {[info exists curr_arr]} {
      if {[llength $hostlist] == 0} {
         set_cqueue_default_values curr_arr chgar
      } else {
         set_cqueue_specific_values curr_arr chgar $hostlist
      }
      }
   }

# this won't be needed
proc qinstance_to_cqueue { change_array } {
   upvar $change_array chgar

   if { [info exists $chgar(hostname)] } {
      unset chgar(hostname)
   }

}

proc set_cqueue_default_values { current_array change_array } {
   upvar $current_array currar
   upvar $change_array chgar
   ts_log_finer "calling set_cqueue_default_values"

   # parse each attribute to be changed and set the queue default value
   foreach attribute [array names chgar] {
      ts_log_finest "--> setting queue default value for attribute $attribute"
      ts_log_finest "--> old_value = $currar($attribute)"
      # set the default
      set new_value $chgar($attribute)
      ts_log_finest "--> new_value = $new_value"

      # get position of host(group) specific values and append them 
      set comma_pos [string first ",\[" $currar($attribute)]
      ts_log_finest "--> comma pos = $comma_pos"
      if {$comma_pos != -1} {
         append new_value [string range $currar($attribute) $comma_pos end]
      }

      ts_log_finest "--> new queue default value = $new_value"
      # write back to chgar
      set chgar($attribute) $new_value
   }
}

proc set_cqueue_specific_values {current_array change_array hostlist} {
   upvar $current_array currar
   upvar $change_array chgar
   ts_log_finer "calling set_cqueue_specific_values"

   # parse each attribute to be changed
   foreach attribute [array names chgar] {
      if {[string compare $attribute qname] == 0} {
         continue
      }

      ts_log_finest "--> setting queue default value for attribute $attribute"
      ts_log_finest "--> old_value = $currar($attribute)"
     
      # split old value and store host specific values in an array
      if {[info exists host_values]} {
         unset host_values
      }

      # split attribute value into default and host specific components
      set value_list [split $currar($attribute) "\["]

      # copy the default value
      if {$hostlist == ""} {
         # use the new value for the cluster queue
         set new_value $default_value
      } else {
         # use old cqueue value as default, set new host specific
         set default_value [string trimright [lindex $value_list 0] ","]
         ts_log_finest "--> default value = $default_value"

         # copy host specific values to array
         for {set i 1} {$i < [llength $value_list]} {incr i} {
            set host_value [lindex $value_list $i]
            set first_equal_position [string first "=" $host_value]
            incr first_equal_position -1
            set host [string range $host_value 0 $first_equal_position]
            set host [resolve_host $host]
            incr first_equal_position 2
            set value [string range $host_value $first_equal_position end]
            set value [string trimright $value ",\]\\"]
            ts_log_finest "--> \"$host\" = \"$value\""
            set host_values($host) $value
         }
      
         # change (or set) host specific values from chgar
         foreach unresolved_host $hostlist {
            set host [resolve_host $unresolved_host]
            ts_log_finest "--> setting host_values($host) = $chgar($attribute)"
            set host_values($host) $chgar($attribute)
         }

         # dump host specific values to new_value
         set new_value $default_value
         foreach host [array names host_values] {
            if {[string compare -nocase $default_value $host_values($host)] != 0} {
               append new_value ",\[$host=$host_values($host)\]"
            }
         }
      }

      ts_log_finest "--> new queue value = $new_value"

      # write back to chgar
      set chgar($attribute) $new_value
   }

   # check if all hosts / hostgroups are in the hostlist attribute
#   if { $hostlist != "" } {
#      set new_hosts {}
#      foreach host $hostlist {
#         if { [lsearch -exact $currar(hostlist) $host] == -1 } {
#            lappend new_hosts $host
#            ts_log_finest "--> host $host is not yet in hostlist"
#         }
#      }
#
#      if { [llength $new_hosts] > 0 } {
#         set chgar(hostlist) "$currar(hostlist) $new_hosts"
#      }
#   }
}

#****** sge_procedures.60/queue/set_queue() ******************************************
#  NAME
#     set_queue() -- set queue attributes
#
#  SYNOPSIS
#     set_queue { qname hostlist change_array {fast_add 1} {on_host ""} {as_user ""} {raise_error 1}} 
#
#  FUNCTION
#     Sets the attributes given in change_array in the cluster queue qname.
#     If hostlist is an empty list, the cluster queue global values are set.
#     If a list of hosts or host groups is specified, the attributes for these
#     hosts or host groups are set.
#
#  INPUTS
#     qname        - name of the (cluster) queue
#     hostlist     - list of hosts / host groups. 
#     change_array - array containing the changed attributes.
#     {fast_add 1} - 0: modify the attribute using qconf -mq,
#                  - 1: modify the attribute using qconf -Mq, faster
#     {on_host ""} - execute qconf on this host, default is master host
#     {as_user ""} - execute qconf as this user, default is $CHECK_USER
#     raise_error  - raise error condition in case of errors
#
#  RESULT
#
#*******************************************************************************
proc set_queue {qname hostlist change_array {fast_add 1}  {on_host ""} {as_user ""} {raise_error 1}} {
   upvar $change_array chgar
   return [mod_queue $qname $hostlist chgar $fast_add $on_host $as_user $raise_error]
}

#                                                             max. column:     |
#****** sge_queue.60/del_queue() ***********************************************
# 
#  NAME
#     del_queue -- Delete a queue
#
#  SYNOPSIS
#     del_queue { qname {on_host ""} {as_user ""} {raise_error 1} } 
#
#  FUNCTION
#     Deletes a queue using qconf -dq
#
#  INPUTS
#     qname -  Name of the queue
#     {on_host ""}        - execute qconf on this host (default: qmaster host)
#     {as_user ""}        - execute qconf as this user (default: CHECK_USER)
#     {raise_error 1}     - raise error condition in case of errors?
#
#  RESULT
#     0 - on success
#    <0 - on error

#
#  SEE ALSO
#     sge_procedures/handle_sge_errors
#     sge_procedures/sge_object_messages
#*******************************************************************************

proc del_queue { q_name hostlist {ignore_hostlist 0} {del_cqueue 0} {on_host ""} {as_user ""} {raise_error 1}} {
  global CHECK_USER
  get_current_cluster_config_array ts_config

   if {!$ignore_hostlist} {
      # delete individual queue instances or queue domaines
      foreach host $hostlist {
         set result [start_sge_bin "qconf" "-dattr queue hostlist $host $q_name"]
         if { $prg_exit_state != 0 } {
            ts_log_severe "could not delete queue instance or queue domain: $result"
         }
      }
   }

   if {$ignore_hostlist || $del_cqueue} {
      ts_log_fine "Delete queue $q_name ..."
      get_queue_messages messages "del" "$q_name" $on_host $as_user
      set output [start_sge_bin "qconf" "-dq $q_name" $on_host $as_user]
      return [handle_sge_errors "del_queue" "qconf -dq $q_name" $output messages $raise_error]
      } 

   return 0
}

proc get_qinstance_list {{filter ""} {on_host ""} {as_user ""} {raise_error 1}} {
   # try to get qinstance list
   if { $filter != "" } {
      set arg1 [lindex $filter 0]
      set arg2 [lindex $filter 1]
      set result [start_sge_bin "qselect" "$arg1 $arg2" $on_host $as_user]
      set command_line "qselect $arg1 $arg2"
   } else {
      set result [start_sge_bin "qselect" "" $on_host $as_user]
      set command_line "qselect"
   }
   if {$prg_exit_state != 0} {
      # command failed because queue list is empty
      set messages(index) "-1"
      set messages(-1) "*[translate_macro MSG_QSTAT_NOQUEUESREMAININGAFTERXQUEUESELECTION_S "*"]"

      # this is no error
      set ret [handle_sge_errors "get_qinstance_list" "$command_line" $result messages 0]
      set result ""
   }

   return $result
}

# queue for -q request or as subordinate queue
# is the 6.0 cluster queue
proc get_requestable_queue { queue host } {
   return $queue
}

proc get_cluster_queue {queue_instance} {
   set cqueue $queue_instance

   if {$queue_instance != "" } {
      set at [string first "@" $queue_instance]
      if {$at > 0} {
         set cqueue [string range $queue_instance 0 [expr $at - 1]]
      }
   }

   ts_log_fine "queue instance $queue_instance is cluster queue $cqueue"

   return $cqueue
}

proc get_clear_queue_error_vdep {messages_var host} {
   upvar $messages_var messages

   #lappend messages(index) "-3"
   #set messages(-3) [translate_macro MSG_XYZ_S $host] #; another exechost specific error message
   #set messages(-3,description) "a highlevel description of the error"    ;# optional parameter
   #set messages(-3,level) WARNING  ;# optional parameter: we only want to raise a warning
}

#****** sge_queue.60/purge_queue() *****************************************
#  NAME
#     purge_queue() -- purge queue instance or queue domain
#
#  SYNOPSIS
#     purge_queue { queue object {on_host ""} {as_user ""} {raise_error 1}}
#
#  FUNCTION
#     Calls qconf -purge queue attribute queue_instance|queue_domain.
#
#  INPUTS
#     queue           - queue instance or queue domain to purge
#     object          - attribute to be purged: hostlist, load_threshold, ...
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
#     sge_calendar/get_calendar()
#     sge_calendar/get_calendar_error()
#*******************************************************************************
proc purge_queue {queue object {on_host ""} {as_user ""} {raise_error 1}} {
   set ret 0

   set result [start_sge_bin "qconf" "-purge queue $object $queue" $on_host $as_user]
   set ret [purge_queue_error $result $queue $object $raise_error]

   return $ret

}
#****** sge_queue.60/purge_queue_error() ***************************************
#  NAME
#     purge_queue_error() -- error handling for purge_queue
#
#  SYNOPSIS
#     purge_queue_error { result queue host object raise_error }
#
#  FUNCTION
#     Does the error handling for purge_queue.
#     Translates possible error messages of qconf -purge,
#     builds the datastructure required for the handle_sge_errors
#     function call.
#
#     The error handling function has been intentionally separated from
#     purge_queue. While the qconf call and parsing the result is
#     version independent, the error messages (macros) usually are version
#     dependent.
#
#  INPUTS
#     queue       - queue intance or queue domain for which qconf -purge 
#                   has been called
#     object      - object  which queue will be purged
#     raise_error - raise error condition in case of errors
#
#  RESULT
#     Returncode for purge_queue function:
#        0: the queue was modified
#       -1: a cluster queue name was passed to purge_queue (handled in purge_queue)
#       -2: cluster queue entry "queue" does not exist
#     -999: other error
#
#  SEE ALSO
#     sge_calendar/get_calendar
#     sge_procedures/handle_sge_errors
#*******************************************************************************
proc purge_queue_error {result queue object raise_error} {
   global CHECK_USER

   set pos [string first "@" $queue]
   if {$pos < 0} {
      set cqueue $queue
      set host_or_group ""
   } else {
      set cqueue [string range $queue 0 [expr $pos -1]]
      set host_or_group [string range $queue [expr $pos + 1] end]
   }

   # recognize certain error messages and return special return code
   set messages(index) 0
   set messages(0) [translate_macro MSG_SGETEXT_MODIFIEDINLIST_SSSS $CHECK_USER "*" $cqueue "*"]

   lappend messages(index) -1
   set messages(-1) "*[translate_macro MSG_CQUEUE_DOESNOTEXIST_S $cqueue]"

   lappend messages(index) -2
   set messages(-2) [translate_macro MSG_PARSE_ATTR_ARGS_NOT_FOUND $object $host_or_group]

   lappend messages(index) -3
   set messages(-3) [translate_macro MSG_QCONF_MODIFICATIONOFOBJECTNOTSUPPORTED_S]

   lappend messages(index) -4
   set messages(-4) "*[translate_macro MSG_QCONF_NOATTRIBUTEGIVEN]*"

   lappend messages(index) -5
   set messages(-5) "*[translate_macro MSG_QCONF_GIVENOBJECTINSTANCEINCOMPLETE_S "*"]*"

   lappend messages(index) -6
   set messages(-6) [translate_macro MSG_QCONF_MODIFICATIONOFHOSTNOTSUPPORTED_S "*"]

   lappend messages(index) -7
   set messages(-7) "*[translate_macro MSG_PARSE_NOOPTIONARGPROVIDEDTOX_S "*"]*"

   # we might have version dependent, queue specific error messages
   get_clear_queue_error_vdep messages $queue

   set ret 0
   # now evaluate return code and raise errors
   set ret [handle_sge_errors "purge_queue" "qconf -purge $object $queue" $result messages $raise_error]

   return $ret
}

