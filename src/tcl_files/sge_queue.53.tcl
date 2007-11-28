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
#****** sge_queue.53/get_queue_instance() **************************************
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
#  SEE ALSO
#     sge_procedures/queue/set_queue_defaults()
#*******************************************************************************
proc get_queue_instance {queue host} {
   set resolved_host [resolve_host $host 1]
   return "${queue}_${resolved_host}"
   }
}

#                                                             max. column:     |
#****** sge_queue/vdep_validate_queue() *********************************************
#  NAME
#     vdep_validate_queue() -- validate the default queue settings for sge 53.
#
#  SYNOPSIS
#     vdep_validate_queue {change_array}
#
#  FUNCTION
#     Validate the queue configuration values. Adjust the queue settings
#     according to sge version 53 systems.
#
#  INPUTS
#     change_array - the resulting array
#
#*******************************************************************************
proc vdep_validate_queue {change_array} {
   # nothing special to do
}

proc vdep_set_queue_values {hostlist change_array} {
   # nothing special to do
   }

#****** sge_procedures.53/queue/set_queue() ************************************
#  NAME
#     set_queue() -- set queue attributes
#
#  SYNOPSIS
#     set_queue { qname hostlist change_array } 
#
#  FUNCTION
#     Sets the attributes given in change_array in the queues specified by
#     qname and hostlist.
#     Queuenames are built as $qname_$hostname.
#
#  INPUTS
#     qname        - name of the (cluster) queue
#     hostlist     - list of hosts. If "@allhosts" or an empty list is given, the attributes are changed
#                    for all hosts. 
#                    built from the qname parameter.
#     change_array - array containing the changed attributes.
#
#  RESULT
#
#*******************************************************************************
proc set_queue { qname hostlist change_array } {
   global CHECK_OUTPUT CHECK_USER
   get_current_cluster_config_array ts_config

   upvar $change_array chgar

   # queue_type is version dependent
   validate_queue chgar

   # non cluster queue: set queue and hostnames
   if { $hostlist == "@allhosts" || $hostlist == "" } {
      set hostlist $ts_config(execd_nodes)
   }

   foreach host $hostlist {
      set cqname [get_queue_instance ${qname} ${host}]
      set result [set_queue_work $cqname chgar]
   }

   return $result
}

proc del_queue { q_name hostlist {ignore_hostlist 0} {del_cqueue 0} {on_host ""} {as_user ""} {raise_error 1}} {
  global CHECK_USER CHECK_OUTPUT
  get_current_cluster_config_array ts_config

   # we just get one queue name (queue instance)
   set queue_list {}
   if { $ignore_hostlist } {
      lappend queue_list $q_name
   } else {
      # we get a cluster queue name and a hostlist
      if { $hostlist == "" || $hostlist == "@allhosts" } {
         set hostlist $ts_config(execd_nodes)
      }
      foreach host $hostlist {
         lappend queue_list [get_queue_instance $q_name $host]
      }
   }

   foreach queue $queue_list {
      puts $CHECK_OUTPUT "Delete queue $q_name ..."
      get_queue_messages messages "del" "$q_name" $on_host $as_user
      set output [start_sge_bin "qconf" "-dq $q_name" $on_host $as_user]
      return [handle_sge_errors "del_queue" "qconf -dq $q_name" $output messages $raise_error]
      } 

  return 0
}

# queue for -q request or as subordinate queue
# is the 5.3 queue
proc get_requestable_queue { queue host } {
   return [get_queue_instance $queue $host]
}

# queue instance has the form <qname>_<hostname>.
# we assume there are no underscores in hostname.
proc get_cluster_queue {queue_instance} {
   set cqueue $queue_instance

   set pos [string last "_" $queue_instance]
   if {$pos > 0} {
      set cqueue [string range $queue_instance 0 [expr $pos -1]]
   }

   puts $CHECK_OUTPUT "queue instance $queue_instance is cluster queue $cqueue"

   return $cqueue
}

proc get_clear_queue_error_vdep {messages_var host} {
   upvar $messages_var messages

   #lappend messages(index) "-3"
   #set messages(-3) [translate_macro MSG_XYZ_S $host] #; another exechost specific er
ror message
   #set messages(-3,description) "a highlevel description of the error"    ;# optional
 parameter
   #set messages(-3,level) -2  ;# optional parameter: we only want to raise a warning
}

