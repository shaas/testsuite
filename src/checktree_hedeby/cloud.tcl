#!/vol2/TCL_TK/glinux/bin/tclsh
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
#  Copyright: 2009 by Sun Microsystems, Inc.
#
#  All Rights Reserved.
#
##########################################################################
#___INFO__MARK_END__

#-------------------------------------------------------------------------
# Contains helper method for managing hedeby cloud service
#-------------------------------------------------------------------------

#****** cloud/hedeby_add_cloud_service() ***************************************
#  NAME
#     hedeby_add_cloud_service() -- Add a cloud service to the system
#
#  SYNOPSIS
#     hedeby_add_cloud_service { service_opts {opt ""} } 
#
#  FUNCTION
#
#     This method adds a cloud service to the system. 
#
#  INPUTS
#     service_opts - Option for the new service. The following options are supported:
#
#           service_opts(service_name)  - name of the service (mandatory)
#           service_opts(host)          - name of the host where the service will be started (mandatory)
#           service_opts(cloud_type)    - name of the cloud type (simhost, ec2, ...) (mandatory)
#           service_opts(start)         - if set to true the component will be started (optional)
#           service_opts(maxCloudHostsInSystemLimit) - value for the maxCloudHostsInSystemLimit parameter in
#                                                      the service config (optional)
#           In addition some parameters for the specific cloud type can be contained for service_opts array
#
#     {opt ""}     - parameter for the sdmadm command (see get_hedeby_proc_opt_arg)
#
#  RESULT
#
#     0  --  cloud service added
#     else -- error
#
#  EXAMPLE
#
#   set sopts(cloud_type)   "simhost"
#   set sopts(service_name) $this(service)
#   set sopts(host)         $this(service_host)
#   set sopts(start)        "true"
#   set sopts(maxCloudHostsInSystemLimit) $this(res_count)
#
#   if {[hedeby_add_cloud_service sopts] != 0} {
#      return
#   }
#   
#*******************************************************************************
proc hedeby_add_cloud_service {service_opts {opt ""}} {

   upvar $service_opts sopts

   get_hedeby_proc_opt_arg $opt sdmadm_opts

   set errors {}

   # ---------------------------------------------------------------------------
   # check the sopts array
   # ---------------------------------------------------------------------------
   foreach param { service_name host cloud_type } {
      if {![info exists sopts($param)]} {
         lappend errors "Mandatory service option sopts($param) is missing"
      }
   }

   if {[llength $errors] != 0 } {
      set msg "Found errors in the sopts option array:\n\n"
      foreach error $errors {
         append msg "  o $error\n"
      }
      append msg "\n"
      ts_log_severe $error $opts(raise_error)
      return -1
   }

   if {[info exists sopts(start)] && $sopts(start) == "true"} {
       set start_opt "-start"
   } else {
       set start_opt ""
   }

   set sequence {}
   lappend sequence "[format "%c" 27]" ;# ESC

   if {[info exists sopts(maxCloudHostsInSystemLimit)]} {
      lappend sequence ":%s/maxCloudHostsInSystemLimit=\['\"\]\[0-9\]*\['\"\]/maxCloudHostsInSystemLimit=\"$sopts(maxCloudHostsInSystemLimit)\"/\n"
   }

   set cloud_type_handler "hedeby_create_cloud_service_sequence_for_$sopts(cloud_type)"

   if {[catch { info args $cloud_type_handler }] == 0} {
      ts_log_fine "Setting up vi sequence for cloud type $sopts(cloud_type)"
  
      if {[$cloud_type_handler sopts sequence] != 0} {
         ts_log_severe "Could not create vi sequence for cloud_type $sopts(cloud_type)"
         return -1
      } 
   } else {
      ts_log_finer "No vi sequence for cloud type $sopts(cloud_type) defined"
   }

   # ---------------------------------------------------------------------------
   # Start the sdmadm ags command
   # ---------------------------------------------------------------------------
   ts_log_fine "adding Cloud service \"$sopts(service_name)\" on host \"[get_service_host $sopts(host)]\" ..."
   set ispid [hedeby_mod_setup_opt [format "acs -h %s  -j %s -s %s -ct %s $start_opt" \
                                            [get_service_host $sopts(host)] \
                                            [get_service_jvm] \
                                            $sopts(service_name) \
                                            $sopts(cloud_type)] \
                                   error_text opts] ;# add_cloud_service


   hedeby_mod_sequence $ispid $sequence error_text
   hedeby_mod_cleanup $ispid error_text

   if { $prg_exit_state != 0 } {
      return $prg_exit_state
   }

   if {$start_opt != ""} {
      set esi($sopts(service_name),cstate) "STARTED"
      set esi($sopts(service_name),sstate) "RUNNING"
      set timeout 30
      if {[wait_for_service_info esi $timeout] != 0} {
         return -1
      }

   }
   return 0
}

#****** cloud/hedeby_create_cloud_service_sequence_for_ec2() *******************
#  NAME
#     hedeby_create_cloud_service_sequence_for_ec2() -- get the vi sequence for ec2 cloud type
#
#  SYNOPSIS
#     hedeby_create_cloud_service_sequence_for_ec2 { service_opts } 
#
#  FUNCTION
#
#     TODO 
#
#  INPUTS
#     service_opts - the service options
#     sequence     - upvar, the additional vi commands are added to this list
#
#  RESULT
#
#    0 -  all vi commands added to sequence
#    else error
#
#*******************************************************************************
proc hedeby_create_cloud_service_sequence_for_ec2 { service_opts sequence } {

   upvar $service_opts sopts
   upvar $sequence seq

   # TODO add ec2 specific vi commands

   return 0
}


#****** cloud/hedeby_change_gef_action() *******************
#  NAME
#     hedeby_change_gef_action() -- get the vi sequence for ec2 cloud type
#
#  SYNOPSIS
#     hedeby_change_gef_action { service_opts } 
#
#  FUNCTION
#     Modifies the configuration of the given service, updates the
#     configuration and waits until the service is running again.
#
#     The action_type decides which action in the configuration is
#     changed/replaced. The action_type must already exist in the
#     configuration, otherwise the vi sequence fails.
#
#
#  INPUTS
#     service        - the name of the service to modify
#     action_type    - the type of the action (startupAction, shutdownAction, etc.)
#     action_content - the new content of the action XML element (without
#                      surrounding xxxAction element)
#
#  RESULT
#    0 -  on success
#    else error
#
#  EXAMPLE
#
#    set new_content    "<gef:step xsi:type=\"gef:ScriptingStepConfig\" name=\"fail\">\n"
#    append new_content "  <gef:script>\n"
#    append new_content "    <gef:file>$ts_config(testsuite_root_dir)/scripts/gef_failing_step.sh</gef:file>\n"
#    append new_content "  </gef:script>\n"
#    append new_content "</gef:step>\n"
#    if {[hedeby_change_gef_action $this(cloud,service) "startupAction" $new_content] != 0} {
#       return
#    }
#
#*******************************************************************************
proc hedeby_change_gef_action { service action_type action_content {opt ""} } {

   get_hedeby_proc_opt_arg $opt opts

   set ispid [hedeby_mod_setup_opt "mc -c $service" error_text opts]
   if { $error_text != "" } {
      ts_log_severe "Could not start sdmadm mc: $error_text"
      return -1
   }
   ts_log_fine "Changing $action_type of service $service..."

   set new_action    "<cloud_adapter:$action_type>\n"
   append new_action "$action_content\n"
   append new_action "</cloud_adapter:$action_type>\n"
   ts_log_finer "New action:\n$new_action"

   set seq {}
   lappend seq "/$action_type\n"        ;# Search for action start tag
   lappend seq "ma"                     ;# mark line
   lappend seq "n"                      ;# Search for action end tag
   lappend seq ":'a,.change\n"          ;# Change the lines
   lappend seq $new_action              ;# insert action
   lappend seq ".\n"                    ;# end insert mode with . line

   hedeby_mod_sequence $ispid $seq error_text
   hedeby_mod_cleanup $ispid error_text
   if { $prg_exit_state != 0 } {
      return $prg_exit_state
   }

   # update component
   set output [sdmadm_command_opt "uc -c $service" opts]
   if { $prg_exit_state != 0 } {
      return $prg_exit_state
   }

   # and wait for component startup
   set exp_serv_info($service,cstate) "STARTED"
   return [wait_for_service_info exp_serv_info 60 $opts(raise_error)]
}
