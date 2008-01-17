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


#****** sge_checkpoint/assign_queues_with_ckpt_object() ************************
#  NAME
#     assign_queues_with_ckpt_object() -- setup queue <-> ckpt connection
#
#  SYNOPSIS
#     assign_queues_with_ckpt_object { queue_list ckpt_obj }
#
#  FUNCTION
#     This procedure will setup the queue - ckpt connections.
#
#  INPUTS
#     queue_list - queue list for the ckpt object
#     ckpt_obj   - name of ckpt object
#
#  SEE ALSO
#     sge_procedures/assign_queues_with_pe_object()
#*******************************************************************************

#****** sge_checkpoint/get_checkpointobj() *************************************
#  NAME
#     get_checkpointobj() -- get checkpoint configuration information
#
#  SYNOPSIS
#     get_checkpointobj { ckpt_obj change_array } 
#
#  FUNCTION
#     Get the actual configuration settings for the named checkpoint object
#
#  INPUTS
#     ckpt_obj     - name of the checkpoint object
#     change_array - name of an array variable that will get set by 
#                    get_checkpointobj
#
#  SEE ALSO
#     sge_checkpoint/mod_checkpointobj()
#     sge_procedures/get_queue() 
#     sge_procedures/set_queue()
#*******************************************************************************
proc get_checkpointobj { ckpt_obj change_array } {
  get_current_cluster_config_array ts_config
  upvar $change_array chgar

   
  set result [start_sge_bin "qconf" "-sckpt $ckpt_obj"]
  if {$prg_exit_state != 0} {
     ts_log_severe "qconf -sckpt $ckpt_obj failed\n$result"
     return
  } 

  # split each line as list element
  set help [split $result "\n"]
  foreach elem $help {
     set id [lindex $elem 0]
     set value [lrange $elem 1 end]
     if { [string compare $value ""] != 0 } {
       set chgar($id) $value
     }
  }
}

#****** sge_checkpoint/mod_checkpointobj() *************************************
#  NAME
#     mod_checkpointobj() -- Modify checkpoint object configuration
#
#  SYNOPSIS
#     mod_checkpointobj { ckpt_obj change_array }
#
#  FUNCTION
#     Modify a checkpoint configuration corresponding to the content of the
#     change_array.
#
#  INPUTS
#     ckpt_obj     - name of the checkpoint object to configure
#     change_array - name of array variable that will be set by
#                    mod_checkpointobj()
#
#  RESULT
#     0  : ok
#     -1 : timeout
#
#  SEE ALSO
#     sge_checkpoint.53/mod_checkpointobj()
#     sge_checkpoint.60/mod_checkpointobj()
#*******************************************************************************
#                                                             max. column:     |
#****** sge_checkpoint/del_checkpointobj() ******
#
#  NAME
#     del_checkpointobj -- delete checkpoint object definition
#
#  SYNOPSIS
#     del_checkpointobj { checkpoint_name }
#
#  FUNCTION
#     This procedure will delete a checkpoint object definition by its name.
#
#  INPUTS
#     checkpoint_name - name of the checkpoint object
#     raise_error     - raise error condition in case of errors
#
#  RESULT
#      0  - ok
#     <0  - error
#
#  SEE ALSO
#     sge_checkpoint/add_checkpointobj()
#*******************************
proc del_checkpointobj {checkpoint_name {on_host ""} {as_user ""} {raise_error 1}} {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   unassign_queues_with_ckpt_object $checkpoint_name $on_host $as_user $raise_error

   set messages(index) "0 -1"
   set messages(0) [translate_macro MSG_SGETEXT_REMOVEDFROMLIST_SSSS $CHECK_USER "*" $checkpoint_name "*"]
   set messages(-1) [translate_macro MSG_SGETEXT_DOESNOTEXIST_SS "*" $checkpoint_name]
   
   set output [start_sge_bin "qconf" "-dckpt $checkpoint_name" $on_host $as_user]

   set ret [handle_sge_errors "del_checkpointobj" "qconf -dckpt $checkpoint_name" $output messages $raise_error $prg_exit_state]
   return $ret
}

#                                                             max. column:     |
#****** sge_procedures/add_checkpointobj() ******
# 
#  NAME
#     add_checkpointobj -- add a new checkpoint definiton object
#
#  SYNOPSIS
#     add_checkpointobj { change_array } 
#
#  FUNCTION
#     This procedure will add a new checkpoint definition object 
#
#  INPUTS
#     change_array - name of an array variable that will be set by 
#                    add_checkpointobj
#
#  NOTES
#     The array should look like follows:
#     
#     set myarray(ckpt_name) "myname"
#     set myarray(queue_list) "big.q"
#     ...
#
#     Here the possbile change_array values with some typical settings:
# 
#     ckpt_name          test
#     interface          userdefined
#     ckpt_command       none
#     migr_command       none
#     restart_command    none
#     clean_command      none
#     ckpt_dir           /tmp
#     queue_list         NONE
#     signal             none
#     when               sx
#
#  RESULT
#      0  - ok
#     -1  - timeout error
#     -2  - object already exists
#     -3  - queue reference does not exist
# 
#  SEE ALSO
#     sge_checkpoint/del_checkpointobj()
#*******************************
proc add_checkpointobj { change_array } {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   upvar $change_array chgar

   validate_checkpointobj chgar

   set vi_commands [build_vi_command chgar]

   set ckpt_name $chgar(ckpt_name)
   set args "-ackpt $ckpt_name"
 
   set ALREADY_EXISTS [translate_macro MSG_SGETEXT_ALREADYEXISTS_SS "*" $ckpt_name]
   set ADDED [translate_macro MSG_SGETEXT_ADDEDTOLIST_SSSS $CHECK_USER "*" $ckpt_name "checkpoint interface" ]

   set master_arch [resolve_arch $ts_config(master_host)]
   if { $ts_config(gridengine_version) == 53 } {
      set REFERENCED_IN_QUEUE_LIST_OF_CHECKPOINT [translate_macro MSG_SGETEXT_UNKNOWNQUEUE_SSSS "*" "*" "*" "*"] 
      set result [ handle_vi_edit "$ts_config(product_root)/bin/$master_arch/qconf" $args $vi_commands $ADDED $ALREADY_EXISTS $REFERENCED_IN_QUEUE_LIST_OF_CHECKPOINT ] 
   } else {
      set result [ handle_vi_edit "$ts_config(product_root)/bin/$master_arch/qconf" $args $vi_commands $ADDED $ALREADY_EXISTS ] 

   }

   # check result
   if { $result == -1 } { ts_log_severe "timeout error" }
   if { $result == -2 } { ts_log_severe "already exists" }
   if { $result == -3 } { ts_log_severe "queue reference does not exist" }
   if { $result != 0  } { ts_log_severe "could not add checkpoint object" }

   return $result
}


