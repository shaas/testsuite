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
#
#****** version/ts_source() ******
#  NAME
#     ts_source() -- get testsuite internal version number for product 
#
#  SYNOPSIS
#     ts_source {filebase {extension tcl}} 
#
#  FUNCTION
#     This function sources a tclfile named by filebase and extension.
#     It will first source a version independent file (if it exists) and
#     then a version dependent file.
#
#     It will check if the following files exist, and source them:
#        $filebase.$extension
#        $filebase.$ts_config(gridengine_version).$extension
#
#  INPUTS
#     filebase  - filename without extension, e.g. tcl_files/version
#     extension - extension, e.g. "tcl" or "ext", default "tcl"
#
#  RESULT
#     1 on success, else 0
#
#  SEE ALSO
#*******************************
#
proc ts_source {filebase {extension tcl}} {
   global ts_config

   set sourced 0
   # suppress warnings when testsuite tries to resource some files
   if {[string first "not in testmode" $filebase] != -1} {
      return $sourced
   }

   # we need a testsuite config before sourcing files
   if {![info exists ts_config] || ![info exists ts_config(gridengine_version)]} {
      ts_log_severe "can't source version specific files before knowing the version"
   } else {
      # read a version independent file first, then the version dependent
      set version $ts_config(gridengine_version)
      set filename "${filebase}.${extension}"
      if {[file exists $filename]} {
         ts_log_finest "reading file $filename"
         set time_now [timestamp]
         uplevel source $filename
         set time_after [timestamp]
         set source_time [expr $time_after - $time_now]
         if { $source_time > 5 } {
            ts_log_info "sourcing $filename took $source_time!"
         }
         incr sourced
      }

      if { $version != "" } {
         set major [string index $version 0]
         set minor [string index $version 1]

         for {set i 0} {$i <= $minor} {incr i} {
            set filename "${filebase}.${major}${i}.${extension}"
            if {[file exists $filename]} {
               ts_log_finest "reading version specific file $filename"
               set time_now [timestamp]
               uplevel source $filename
               set time_after [timestamp]
               set source_time [expr $time_after - $time_now]
               if { $source_time > 5 } {
                  ts_log_info "sourcing $filename took $source_time!"
               }
               incr sourced
            }
         }
      }
   }

   if {$sourced == 0} {
      ts_log_finest "no files sourced for filename \"$filebase.*\""
   }

   return $sourced
}

#****** sge_procedures/get_version_info() *********************************************
#  NAME
#     get_version_info() -- get version number of the cluster software
#
#  SYNOPSIS
#     get_version_info { } 
#
#  FUNCTION
#     This procedure will return the version string
#
#  INPUTS
#
#  RESULT
#     returns the first line of "qconf -help" (this is the version number of 
#     the SGEEE/SGE system).
#
#  SEE ALSO
#*******************************************************************************
proc get_version_info {} {
   global sge_config
   global CHECK_PRODUCT_VERSION_NUMBER
   global CHECK_PRODUCT_TYPE CHECK_USER

   get_current_cluster_config_array ts_config


   if { [info exists ts_config(product_root)] != 1 } {
      set CHECK_PRODUCT_VERSION_NUMBER "system not running"
      return $CHECK_PRODUCT_VERSION_NUMBER
   }
 
   set master_arch [resolve_arch $ts_config(master_host)]  
   if { [file isfile "$ts_config(product_root)/bin/$master_arch/qconf"] } {
      # We don't use start_sge_bin since we don't want to call this over JGDI
      set result [start_remote_prog [host_conf_get_suited_hosts] $CHECK_USER "qconf" "-sh"]
      set qmaster_running $prg_exit_state
      set result [start_remote_prog [host_conf_get_suited_hosts] $CHECK_USER "qconf" "-help"]
      set help [ split $result "\n" ] 
      if { ([ string first "fopen" [ lindex $help 0] ] >= 0)        || 
           ([ string first "error" [ lindex $help 0] ] >= 0)        || 
           ([ string first "product_mode" [ lindex $help 0] ] >= 0) ||   
           ($qmaster_running != 0) } {
          set CHECK_PRODUCT_VERSION_NUMBER "system not running"
          return $CHECK_PRODUCT_VERSION_NUMBER
      }
      set CHECK_PRODUCT_VERSION_NUMBER [ lindex $help 0]
      set CHECK_PRODUCT_VERSION_NUMBER [string trim $CHECK_PRODUCT_VERSION_NUMBER]
      if { [ string first "exit" $CHECK_PRODUCT_VERSION_NUMBER ] >= 0 } {
         set CHECK_PRODUCT_VERSION_NUMBER "system not running"
      } else {
         if {$ts_config(gridengine_version) == 53} {
            # SGE(EE) 5.x: we have a product mode file
            set product_mode "unknown"
            if { [file isfile $ts_config(product_root)/$ts_config(cell)/common/product_mode ] == 1 } {
               set product_mode_file [ open $ts_config(product_root)/$ts_config(cell)/common/product_mode "r" ]
               gets $product_mode_file product_mode
               close $product_mode_file
            } else {
               # SGE(EE) 6.x: product mode is in bootstrap file
               set product_mode $sge_config(product_mode)
            }
            if { $ts_config(product_feature) == "csp" } {
                if { [ string first "csp" $product_mode ] < 0 } {
                    ts_log_info "get_version_info - product feature is not csp ( secure )"
                    ts_log_info "testsuite setup error - stop"
                    testsuite_shutdown 1
                } 
            } else {
                if { [ string first "csp" $product_mode ] >= 0 } {
                    ts_log_info "get_version_info - product feature is csp ( secure )"
                    ts_log_info "testsuite setup error - stop"
                    testsuite_shutdown 1
                } 
            }
            if { $CHECK_PRODUCT_TYPE == "sgeee" } {
                if { [ string first "sgeee" $product_mode ] < 0 } {
                    ts_log_info "get_version_info - no sgeee system"
                    ts_log_info "please remove the file"
                    ts_log_info "\n$ts_config(product_root)/$ts_config(cell)/common/product_mode"
                    ts_log_info "\nif you want to install a new sge system"
                    ts_log_info "testsuite setup error - stop"
                    testsuite_shutdown 1
                } 
            } else {
                if { [ string first "sgeee" $product_mode ] >= 0 } {
                    ts_log_info "get_version_info - this is a sgeee system"
                    ts_log_info "testsuite setup error - stop"
                    testsuite_shutdown 1
                } 
            }
         }
      }  
      return $CHECK_PRODUCT_VERSION_NUMBER
   }
   set CHECK_PRODUCT_VERSION_NUMBER "system not installed"
   return $CHECK_PRODUCT_VERSION_NUMBER
}


