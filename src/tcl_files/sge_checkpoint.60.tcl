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

# JG: TODO: Change the assign/unassign procedures.
# The current implemtation using aattr/dattr is destroying the default
# settings in all.q

proc unassign_queues_with_ckpt_object { ckpt_obj {on_host ""} {as_user ""} {raise_error 1}} {
   get_current_cluster_config_array ts_config

   ts_log_fine "searching for references in cluster queues ..."
   get_queue_list queue_list $on_host $as_user $raise_error
   foreach elem $queue_list {
      ts_log_finer "queue: $elem"
      start_sge_bin "qconf" "-dattr queue ckpt_list $ckpt_obj $elem" $on_host $as_user
   }
   ts_log_fine "searching for references in queue instances ..."
   set queue_list [get_qinstance_list "" $on_host $as_user $raise_error]
   foreach elem $queue_list {
      ts_log_finer "queue: $elem"
      start_sge_bin "qconf" "-dattr queue ckpt_list $ckpt_obj $elem" $on_host $as_user
   }
}

proc assign_queues_with_ckpt_object { qname hostlist ckpt_obj } {
   get_current_cluster_config_array ts_config

   set queue_list {}
   # if we have no hostlist: change cluster queue
   if {[llength $hostlist] == 0} {
      set queue_list $qname
   } else {
      foreach host $hostlist {
         lappend queue_list "${qname}@${host}"
      }
   }

   foreach queue $queue_list {
      ts_log_finer "queue: $queue"
      set result [start_sge_bin "qconf" "-aattr queue ckpt_list $ckpt_obj $queue"]
      if {$prg_exit_state != 0} {
         # if command fails: output error
         ts_log_severe "error changing ckpt_list: $result"
      }
   }
}

proc validate_checkpointobj { change_array } {
   upvar $change_array chgar

  if { [info exists chgar(queue_list)] } {
     ts_log_fine "this qconf version doesn't support queue_list for ckpt objects"
     ts_log_config "this Grid Engine version doesn't support a queue_list for ckpt objects,\nuse assign_queues_with_ckpt_object() after adding checkpoint\nobjects and don't use queue_list parameter."
     unset chgar(queue_list)
  }
}
