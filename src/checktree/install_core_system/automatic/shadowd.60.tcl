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
#****** install_core_system/install_shadowd() ******
# 
#  NAME
#     install_shadowd -- ??? 
#
#  SYNOPSIS
#     install_shadowd { } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#
#  RESULT
#     ??? 
#
#  EXAMPLE
#     ??? 
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     ???/???
#*******************************
proc install_shadowd {} {
   global CHECK_OUTPUT CHECK_CORE_SHADOWD CORE_INSTALLED
   global check_use_installed_system
   global CHECK_COMMD_PORT CHECK_ADMIN_USER_SYSTEM CHECK_USER
   global CHECK_DEBUG_LEVEL CHECK_EXECD_INSTALL_OPTIONS
   global CHECK_COMMD_PORT
   global CHECK_MAIN_RESULTS_DIR
   global ts_config

   set CORE_INSTALLED "" 
   read_install_list

   if {!$check_use_installed_system} {
      set feature_install_options ""

      if {$ts_config(product_feature) == "csp"} {
         set feature_install_options "-csp"
         set my_csp_host_list $CHECK_CORE_SHADOWD
         foreach shadow_host $my_csp_host_list {
            if {$shadow_host == $ts_config(master_host)} {
               continue
            }
            copy_certificates $shadow_host
         }
      }
   }

   if {$check_use_installed_system} {
      foreach shadow_host $CHECK_CORE_SHADOWD {
         puts $CHECK_OUTPUT "no need to install shadowd on host \"$shadow_host\", noinst parameter is set"
         set info [check_shadowd_settings $shadow_host]
         if {$info != ""} {
            add_proc_error "install_shadowd" -3 "skipping shadowd installation for host $shadow_host:\n$info"
            continue
         }
         if {[startup_shadowd $shadow_host] == 0} {
            lappend CORE_INSTALLED $shadow_host
            write_install_list
            continue
         } else {
            add_proc_error "install_shadowd" -2 "could not startup shadowd on host $shadow_host"
            return
         }
      }
   } else {
      if {[file isfile "$ts_config(product_root)/inst_sge"] != 1} {
         add_proc_error "install_shadowd" "-1" "inst_sge file not found"
         return
      }

      set shadow_host [lindex $CHECK_CORE_SHADOWD 0]
      puts $CHECK_OUTPUT "installing shadowd on hosts: $CHECK_CORE_SHADOWD ($ts_config(product_type) system)..."
      set remote_arch [resolve_arch $shadow_host]    
      set my_timeout 500
      puts $CHECK_OUTPUT "inst_sge -sm"
      if {$CHECK_ADMIN_USER_SYSTEM == 0} { 
         set output [start_remote_prog "$shadow_host" "root"  "./inst_sge" "-sm -auto $ts_config(product_root)/autoinst_config.conf" exit_val $my_timeout 0 $ts_config(product_root)]
      } else {
         puts $CHECK_OUTPUT "--> install as user $CHECK_USER <--" 
         set output [start_remote_prog "$shadow_host" "$CHECK_USER"  "./inst_sge" "-sm -auto $ts_config(product_root)/autoinst_config.conf" exit_val $my_timeout 0 $ts_config(product_root)]
      }
      if {$exit_val == 0} {
         foreach shadow_host $CHECK_CORE_SHADOWD {
            puts $CHECK_OUTPUT "testing shadowd settings for host $shadow_host ..."
            set info [check_shadowd_settings $shadow_host]
            if {$info != ""} {
               add_proc_error "install_shadowd" -3 "skipping shadowd installation for host $shadow_host:\n$info"
               continue
            }
            puts $CHECK_OUTPUT "checking shadowd on host $shadow_host ($ts_config(product_type) system) ..."
            if { [is_daemon_running $shadow_host "sge_shadowd"] == 1 } {
               lappend CORE_INSTALLED $shadow_host
               write_install_list
            } else {
               add_proc_error "install_shadowd" "-2" "install shadowd on host $shadow_host failed\noutput of inst_sge -sm -auto:\n$output"
            }
         }
      } else {
         add_proc_error "install_shadowd" "-2" "install shadowd hosts failed\noutput of inst_sge -sm -auto:\n$output"
      }
   }
}

