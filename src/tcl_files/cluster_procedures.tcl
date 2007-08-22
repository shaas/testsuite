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
#  Copyright: 2007 by Sun Microsystems, Inc.
#
#  All Rights Reserved.
#
##########################################################################
#___INFO__MARK_END__

global module_name
set module_name "cluster_procedures.tcl"

# ts_current_cluster_config is used to store the current number
# of an additional cluster configuration. All sge_procedure procedures
# should use get_current_cluster_config() to get the correct testsuite
# configuraiton. Using global ts_config is depreached!
global ts_current_cluster_config
if { [info exists ts_current_cluster_config] == 0 } {
   set ts_current_cluster_config 0
}

# return current ts_current_cluster_config value
proc get_current_cluster_config_nr { } {
   global ts_current_cluster_config
   return $ts_current_cluster_config
}

# 0 means ts_config
# 1 ... means ($nr-1). additional config array
proc set_current_cluster_config_nr { nr } {
   global ts_current_cluster_config ts_config CHECK_OUTPUT

   if {$ts_config(additional_config) == "none"} {
      set ts_current_cluster_config 0
      if { $nr != 0 } {
         return -1
      }
      return 0
   }

   set nr_of_additional_configs [llength $ts_config(additional_config)]
   if { $nr < 0 || $nr > $nr_of_additional_configs } {
      return -1
   }
   set ts_current_cluster_config $nr
   get_current_cluster_config_array new_config
   puts $CHECK_OUTPUT "\n**************************************************"
   puts $CHECK_OUTPUT "  switched cluster config to nr = $nr"
   puts $CHECK_OUTPUT "  SGE_ROOT=$new_config(product_root)"
   puts $CHECK_OUTPUT "  SGE_CELL=$new_config(cell)"
   puts $CHECK_OUTPUT "**************************************************"
   return 0
}

proc get_current_cluster_config_array { aConfig } {
   global ts_config CHECK_OUTPUT
   upvar $aConfig config

   if {[info exists config]} {
      unset config
   }
   
   set nr [get_current_cluster_config_nr]
   if { $nr == 0 } {
      set nr_of_params 0
      set names [array names ts_config]
      foreach name $names {
         set config($name) $ts_config($name)
         incr nr_of_params 1
      }
      if { $nr_of_params == 0 } {
         # TODO: (CR) we might be able to prevent from this situation if we
         #            make a copy of the ts_config before doing "unset config" and
         #            reset the ts_config
         puts $CHECK_OUTPUT "WARNING! This call to \"get_current_cluster_config_array\" would overwrite the global ts_config variable"
         puts $CHECK_OUTPUT "aborting testsuite!"
         exit 100 
         return
      }
   } else {
      set index $nr
      incr index -1
      set filename [lindex $ts_config(additional_config) $index]
      get_additional_config $filename config
   }

   #puts $CHECK_OUTPUT "returning ts_config id=\"$nr\" for SGE_ROOT=\"$config(product_root)\""
}


#****** cluster_procedures/get_additional_cluster_type() ************************************
#  NAME
#     get_additional_cluster_type() -- find out type of additional cluster config
#
#  SYNOPSIS
#     get_additional_cluster_type { filename additional_config } 
#
#  FUNCTION
#     reads specified cluster configuration and returns its type.
#
#  INPUTS
#     filename          - cluster config file 
#     additional_config - upvar variable where to read config 
#
#  RESULT
#     "" on error, "cell" for cell cluster, "independent" for standalone cluster 
#*******************************************************************************
proc get_additional_cluster_type { filename additional_config } {
   global ts_config
   upvar $additional_config add_config

   # clear previously read config
   if {[info exists add_config]} {
      unset add_config
   }

   # read additional config file
   if {[read_array_from_file $filename "testsuite configuration" add_config] != 0} {
      add_proc_error "get_additional_cluster_type" -1 "cannot read additonal configuration file $filename"
      return ""
   }

   # check whether it is cell cluster or independed cluster
   if { $ts_config(product_root) == $add_config(product_root) &&
        $ts_config(source_dir)   == $add_config(source_dir) } {
      return "cell"
   } else {
      return "independent"
   }
}

proc get_additional_config { filename aConfig } {
   upvar $aConfig add_config

   # clear previously read config
   if {[info exists add_config]} {
      unset add_config
   }
   # read additional config file
   if {[read_array_from_file $filename "testsuite configuration" add_config] != 0} {
      add_proc_error "get_additional_config" -1 "cannot read additonal configuration file $filename"
   }
}

proc get_all_execd_hosts { } {
   global ts_config CHECK_OUTPUT

   set host_list {}
   # 1) ts_config(execd_hosts)
   foreach execd $ts_config(execd_hosts) {
      lappend host_list $execd
   }

   # 2) all additional checktrees
   if {$ts_config(additional_config) != "none"} {
      foreach filename $ts_config(additional_config) {
         get_additional_config $filename add_config
         # check add_config(execd_hosts) (no duplicate entries)
         foreach execd $add_config(execd_hosts) {
            if { [lsearch $host_list $execd] < 0 } {
               lappend host_list $execd
            }
         }
      }
   }
   return $host_list
}

proc get_all_qmaster_hosts { } {
   global ts_config CHECK_OUTPUT

   set host_list {}
   # 1) ts_config(master_host)
   lappend host_list $ts_config(master_host)
  
   # 2) all additional checktrees
   if {$ts_config(additional_config) != "none"} {
      foreach filename $ts_config(additional_config) {
         get_additional_config $filename add_config
         # check add_config(master_host) (no duplicate entries)
         if { [lsearch $host_list $add_config(master_host)] < 0 } {
            lappend host_list $add_config(master_host)
         }
      }
   }
   return $host_list
}


#****** cluster_procedures/get_all_hosts() *************************************
#  NAME
#     get_all_hosts() -- get all configured and used hosts
#
#  SYNOPSIS
#     get_all_hosts { } 
#
#  FUNCTION
#     This procedure returns all hostnames which are used for additional
#     clusters and additional checktrees.
#
#*******************************************************************************
proc get_all_hosts { } {
   global ts_config CHECK_OUTPUT

   set host_list [host_conf_get_cluster_hosts]
   # all additional checktrees
   if {$ts_config(additional_config) != "none"} {
      foreach filename $ts_config(additional_config) {
         get_additional_config $filename add_config

         set hosts "$add_config(master_host) $add_config(execd_hosts) $add_config(execd_nodes) $add_config(submit_only_hosts) $add_config(bdb_server) $add_config(shadowd_hosts)"
         set add_cluster_hosts [lsort -dictionary -unique $hosts]
         set none_elem [lsearch $add_cluster_hosts "none"]
         if {$none_elem >= 0} {
            set add_cluster_hosts [lreplace $add_cluster_hosts $none_elem $none_elem]
         }
         foreach add_host $add_cluster_hosts {
            # check for no duplicate entries
            if { [lsearch $host_list $add_host] < 0 } {
               lappend host_list $add_host
            }
         }
      }
   }

   foreach host [checktree_get_required_hosts] {
      # check for no duplicate entries
      if { [lsearch $host_list $host] < 0 } {
         lappend host_list $host
      }
   }
   return $host_list
}



