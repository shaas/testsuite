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

#****** sge_job.60/delete_all_jobs() *******************************************
#  NAME
#     delete_all_jobs() -- delete all jobs
#
#  SYNOPSIS
#     delete_all_jobs { {clear_queues 1} {do_force 0} } 
#
#  FUNCTION
#     This procedure is deleting all jobs in the GE system.
#
#  INPUTS
#     {clear_queues 1} - optional: clear all queues
#     {do_force 0}     - optional: do a forced qdel instead of standard qdel
#
#  RESULT
#     1 on success, 0 on error !!!
#*******************************************************************************
proc delete_all_jobs {{clear_queues 1} {do_force 0}} {
   get_current_cluster_config_array ts_config

   ts_log_fine "deleting all jobs"

   if {$do_force == 0} {
      start_sge_bin "qdel" "-u '*' '*'"
   } else {
      start_sge_bin "qdel" "-f -u '*' '*'"
   }

   if {$prg_exit_state == 0} {
      set ret 1
   } else {
      set ret 0
   }

   if {$clear_queues} {
      ts_log_fine "do a qmod -c \"*\" ..."
      start_sge_bin "qmod" "-c \"*\""
   }

   return $ret
}
