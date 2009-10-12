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
   global CORE_INSTALLED
   global check_use_installed_system
   global CHECK_COMMD_PORT CHECK_ADMIN_USER_SYSTEM CHECK_USER
   global CHECK_DEBUG_LEVEL CHECK_EXECD_INSTALL_OPTIONS
   global CHECK_COMMD_PORT
   global CHECK_MAIN_RESULTS_DIR
   global ts_config

   set CORE_INSTALLED ""

   set shadowd_hosts [replace_string $ts_config(shadowd_hosts) "none" ""]
   if {[string trim $shadowd_hosts] == ""} {
      return
   }

   foreach shadow_host $shadowd_hosts  {
      is_remote_file $shadow_host $CHECK_USER "$ts_config(product_root)/$ts_config(cell)/common/settings.sh"
   }
   read_install_list

   if {!$check_use_installed_system} {
      set feature_install_options ""
      set my_csp_host_list ""

      # support jmx ssl testsuite keystore and certificate creation
      if {$ts_config(gridengine_version) >= 62 && $ts_config(jmx_ssl) == "true" && $ts_config(jmx_port) != 0} {
         set my_csp_host_list $shadowd_hosts
      }

      # are we installing secure grid engine?
      if {$ts_config(product_feature) == "csp"} {
         set feature_install_options "-csp"
         set my_csp_host_list $shadowd_hosts
      }

      # if $my_csp_host_list != "" we copy certificates
      foreach shadow_host $my_csp_host_list {
         if {$shadow_host == $ts_config(master_host)} {
            continue
         }
         copy_certificates $shadow_host
      }
   }

   if {$check_use_installed_system} {
      foreach shadow_host $shadowd_hosts {
         ts_log_fine "no need to install shadowd on host \"$shadow_host\", noinst parameter is set"
         set info [check_shadowd_settings $shadow_host]
         if {$info != ""} {
            ts_log_severe "skipping shadowd installation for host $shadow_host:\n$info"
            continue
         }
         if {[startup_shadowd $shadow_host] == 0} {
            lappend CORE_INSTALLED $shadow_host
            write_install_list
            continue
         } else {
            ts_log_warning "could not startup shadowd on host $shadow_host"
            return
         }
      }
   } else {
      if {[file isfile "$ts_config(product_root)/inst_sge"] != 1} {
         ts_log_severe "inst_sge file not found"
         return
      }
      foreach shadow_host $shadowd_hosts {
         ts_log_fine "installing shadowd on hosts: $shadow_host ($ts_config(product_type) system)..."
         set my_timeout 500
         if {$CHECK_ADMIN_USER_SYSTEM == 0} { 
            set install_user "root"
         } else {
            set install_user $CHECK_USER
         }
         
         set autoinst_config_file "$ts_config(product_root)/autoinst_config_$ts_config(cell)_shadowd_${shadow_host}.conf"
         write_autoinst_config $autoinst_config_file $shadow_host 0 1 0 0 1

         set inst_sge_param "-sm -auto $autoinst_config_file -noremote"
         ts_log_fine "$shadow_host as $install_user: inst_sge $inst_sge_param"
         set output [start_remote_prog "$shadow_host" $install_user  "./inst_sge" $inst_sge_param exit_val $my_timeout 0 $ts_config(product_root) "" 0 15 0 1 1]
         if {$exit_val != 0} {
            ts_log_warning "install shadowd hosts failed\n$shadow_host as $install_user: inst_sge $inst_sge_param:\n$output"
         }
      }

      foreach shadow_host $shadowd_hosts {
         ts_log_fine "testing shadowd settings for host $shadow_host ..."
         set info [check_shadowd_settings $shadow_host]
         if {$info != ""} {
            ts_log_severe "skipping shadowd installation for host $shadow_host:\n$info"
            continue
         }
         ts_log_fine "checking shadowd on host $shadow_host ($ts_config(product_type) system) ..."
         
         set my_timeout [timestamp]
         incr my_timeout 60
         set is_running 0
         while {[timestamp] < $my_timeout} {
            if {[is_daemon_running $shadow_host "sge_shadowd"] != 1} {
               ts_log_fine "waiting for running shadowd on host $shadow_host ..."
            } else {
               set is_running 1
               break
            }
         }
         if { $is_running == 1 } {
            lappend CORE_INSTALLED $shadow_host
            write_install_list
         } else {
            ts_log_warning "install shadowd on host $shadow_host failed!\n\"is_daemon_running $shadow_host sge_shadowd\" returned $running_return_value!"
            break
         }
      }
   }
}

