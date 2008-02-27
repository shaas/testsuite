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
#  Copyright: 2001 by Sun Microsystems, Inc.
#
#  All Rights Reserved.
#
##########################################################################
#___INFO__MARK_END__

# Functions
###########
#     system specific:
#     ================
#     util/get_hedeby_system_name()
#     util/get_hedeby_pref_type()
#     util/get_hedeby_admin_user()
#     util/get_hedeby_startup_user()
#     util/get_hedeby_cs_url()
#     util/get_hedeby_local_spool_dir()
#     util/cleanup_hedeby_local_spool_dir()
#     util/get_all_hedeby_managed_hosts()
#     util/is_hedeby_process_running()
#     util/kill_hedeby_process()
#     util/shutdown_hedeby_hosts()
#     util/startup_hedeby_hosts()
#     util/remove_hedeby_preferences()
#     util/remove_prefs_on_hedeby_host()
#     util/shutdown_hedeby()
#     util/startup_hedeby()
#
#     output parsing specific:
#     ========================
#     util/parse_show_component_output()
#
#     file specific:
#     ==============
#     util/get_hedeby_binary_path()
# 
#     L10N - messages specific:
#     =========================
#     util/read_bundle_properties_cache()
#     util/parse_bundle_properties_files()
#     util/get_properties_messages_file_name()
#     util/get_bundle_string()
#     util/create_bundle_string()
#     util/parse_bundle_string_params()
#

#****** util/remove_hedeby_preferences() ***************************************
#  NAME
#     remove_hedeby_preferences() -- remove all preferences entries
#
#  SYNOPSIS
#     remove_hedeby_preferences { {raise_error 1} } 
#
#  FUNCTION
#     This procedure is used to remove all hedeby preferences entries for
#     the testsuite hedeby system. 
#
#  INPUTS
#     {raise_error 1} - optional parameter which allows to switch of error
#                       reporting when error occurs. Default value is 
#                       1(=report errors) if set to 0 no errors are reported.
#
#  RESULT
#     none
#
#  SEE ALSO
#     util/remove_hedeby_preferences()
#     util/remove_prefs_on_hedeby_host()
#*******************************************************************************
proc remove_hedeby_preferences {{raise_error 1}} {
   global hedeby_config
   # first step: remove preferences for all managed hosts

   set pref_type [get_hedeby_pref_type]
   set sys_name [get_hedeby_system_name]
   set remove_user [get_hedeby_startup_user]

   if { $pref_type == "system" } {
      # the user installation is shared in home directory, don't remove them on the remote
      # host, because they will disapear when master host preferences are deleted
      set host_list [get_all_hedeby_managed_hosts]
      foreach host $host_list {
         set task_info($host,expected_output) ""
         set task_info($host,sdmadm_command) "-p $pref_type -s $sys_name rbc"      
      }
      set error_text [start_parallel_sdmadm_command host_list $remove_user task_info $raise_error]
      
      foreach host $host_list {
         set exit_state $task_info($host,exit_status)
         set output $task_info($host,output)
         debug_puts "----------------------------------"
         debug_puts "host: $host"
         debug_puts "exit status: $exit_state"
         debug_puts "output:\n$output"
         debug_puts "----------------------------------"
      }
      if { $error_text != "" } {
         add_proc_error "remove_hedeby_preferences" -1 $error_text $raise_error
      }
   }

   # second step: remove preferences for hedeby master host
   remove_prefs_on_hedeby_host $hedeby_config(hedeby_master_host) $raise_error
}

#****** util/shutdown_hedeby() *************************************************
#  NAME
#     shutdown_hedeby() -- Shutdown running hedeby system
#
#  SYNOPSIS
#     shutdown_hedeby { { only_raise_cannot_kill_error 0 } } 
#
#  FUNCTION
#     This procedure is used to shutdown the complete hedeby system. The system
#     must be completely configured by the testsuite. This is done by the
#     "hedeby_install" test.
#
#     The "hedeby_install" tests is setting up the hedeby sytem and already
#     starting it up. So this procedure is usefule when the system should be
#     completely shutdown.
#
#     In order to re-start the system the procedure startup_hedeby() might be
#     called.
#
#  INPUTS
#     { only_raise_cannot_kill_error 0 } - if 1 the procedure only reports
#                                          error if process cannot be killed
#                                          other problems are reported as 
#                                          warnings
#
#  RESULT
#     0 - on success
#     1 - on error
#
#  SEE ALSO
#     util/startup_hedeby()
#     util/shutdown_hedeby()
#     util/reset_hedeby()
#*******************************************************************************
proc shutdown_hedeby { { only_raise_cannot_kill_error 0 } } {
   global hedeby_config

   set ret_val 0
   set shutdown_user [get_hedeby_startup_user]

   # first step: shutdown all managed hosts
   set managed_hosts [get_all_hedeby_managed_hosts]
   set val [shutdown_hedeby_hosts "managed" $managed_hosts $shutdown_user $only_raise_cannot_kill_error]
   if { $val != 0 } {
      set ret_val 1
   }

   # second step: shutdown hedeby master host
   set val [shutdown_hedeby_hosts "master" $hedeby_config(hedeby_master_host) $shutdown_user $only_raise_cannot_kill_error]
   if { $val != 0 } {
      set ret_val 1
   }
   return $ret_val
}


#****** util/startup_hedeby() **************************************************
#  NAME
#     startup_hedeby() -- Startup installed and configured hedeby system
#
#  SYNOPSIS
#     startup_hedeby { } 
#
#  FUNCTION
#     This procedure is used to startup the complete hedeby system. The system
#     must be completely configured by the testsuite. This is done by the
#     "hedeby_install" test.
#     
#     The "hedeby_install" tests is setting up the hedeby sytem and already
#     starting it up. So this procedure is usefule when the system was shutdown
#     with shutdown_hedeby().
#
#     The procedure will first startup the hedeby master host components and
#     after that all managed hedeby host resources.
#
#  INPUTS
#
#  RESULT
#     0 - on success
#     1 - on error
#
#  SEE ALSO
#     util/startup_hedeby()
#     util/shutdown_hedeby()
#     util/reset_hedeby()
#*******************************************************************************
proc startup_hedeby {} {
   global hedeby_config

   set ret_val 0
   set startup_user [get_hedeby_startup_user]

   # first step: startup hedeby master host
   set val [startup_hedeby_hosts "master" $hedeby_config(hedeby_master_host) $startup_user]
   if { $val != 0 } {
      set ret_val 1
   }

   # second step: startup all managed hosts
   set val [startup_hedeby_hosts "managed" [get_all_hedeby_managed_hosts] $startup_user]
   if { $val != 0 } {
      set ret_val 1
   }
   return $ret_val
}

#****** util/get_hedeby_binary_path() ******************************************
#  NAME
#     get_hedeby_binary_path() -- Get the full path name to a hedeby cli binary
#
#  SYNOPSIS
#     get_hedeby_binary_path { binary_name {user_name ""} {hostname ""} } 
#
#  FUNCTION
#     Get the full path name of a hedeby cli binary. The procedure returns
#     the full path to the specified hedeby binary. Currently only "sdmadm"
#     is supported.
#
#  INPUTS
#     binary_name    - name of the hedeby binary. 
#                      Currently supported names: "sdmadm"
#     {user_name ""} - optional: User name which should have access to the
#                      binary if not used the hedeby admin user performs the
#                      directory commands.
#     {hostname ""}  - optional: Hostname on which the binary path should be
#                      created. If not used the hedeby master host is used
#                      to perform the directory commands.
#
#  RESULT
#     Full path to the hededby binary 
#
#  SEE ALSO
#     util/get_hedeby_binary_path()
#*******************************************************************************
proc get_hedeby_binary_path { binary_name {user_name ""} {hostname ""}} {
   global hedeby_config
   
   get_current_cluster_config_array ts_config


   if { $hostname == "" } {
      set hostname $hedeby_config(hedeby_master_host)
   }
   if { $user_name == "" } {
      set user_name [get_hedeby_admin_user]
   }

   set path ""

   switch -exact -- $binary_name {
      "sdmadm" {
         set path $hedeby_config(hedeby_product_root)/bin/sdmadm
      }
      default {
         add_proc_error "get_hedeby_binary_path" -1 "unexpected binary name: $binary_name"
      }
   }

   if { ![is_remote_file $hostname $user_name $path 1]} {
      add_proc_error "get_hedeby_binary_path" -1 "file \"$path\" not existing on host \"$hostname\" for user \"$user_name\""
   }
   return $path
}

#****** util/add_host_resource() ***********************************************
#  NAME
#     add_host_resource() -- add a host resource to hedeby
#
#  SYNOPSIS
#     add_host_resource { host_resource { service "" } { on_host "" } { as_user ""} 
#     {raise_error 1} } 
#
#  FUNCTION
#     This procedure is used to add host resources to the hedeby system. 
#
#  INPUTS
#     host_resource   - hostname of the host resource 
#     { on_host "" }  - optional: host where sdmadm should be started 
#                       if not set the hedeby master host is used
#     { as_user ""}   - optional: user name which starts sdmadm command 
#                       if not set the hedeby admin user is used
#     { service ""}   - optional: name of the service which will be the owner
#                       of the resource
#     {raise_error 1} - if set to 1 testsuite reports errors on failure 
#
#  RESULT
#     the prg_exit_state of the sdmadm command
#
#*******************************************************************************
proc add_host_resource { host_resource { service "" } { on_host "" } { as_user ""} {raise_error 1} } {
   global hedeby_config
   global CHECK_USER

   if { $on_host == "" } {
      set exec_host $hedeby_config(hedeby_master_host)
   } else {
      set exec_host $on_host
   }
   if { $as_user == "" } {
      set exec_user [get_hedeby_admin_user]
   } else {
      set exec_user $as_user
   }

   # write resource property file on the execution host
   set file_name [get_tmp_file_name $exec_host]
   set osArch [resolve_arch $host_resource]
   
   get_hedeby_ge_complex_mapping $osArch
   set cur_line 1
   foreach prop [array names res_prop] {
      set data($cur_line) $prop=$res_prop($prop)
      incr cur_line 1
   }

   # in case we have no mapping ...
   if {$cur_line == 1 } {
      # ... we simply use uname info
      set osName [string trim [start_remote_prog $host_resource $exec_user uname -s]]
      set data($cur_line) "operatingSystemName=$osName"
      incr cur_line 1
      set osRel  [string trim [start_remote_prog $host_resource $exec_user uname -r]]
      set data($cur_line) "operatingSystemRelease=$osRel"
      incr cur_line 1
      set data($cur_line) "hardwareCpuArchitecture=$osArch"
      incr cur_line 1
   }

   set data($cur_line) "resourceHostname=$host_resource"
   set data(0) $cur_line

   write_remote_file $host_resource $exec_user $file_name data

   # print out created file
   set file_content [start_remote_prog $exec_host $exec_user cat $file_name]
   if {$service != "" } {
      set add_args "-s $service"
      ts_log_fine "adding host resource \"$host_resource\" to service $service of hedeby system ..."
   } else {
      set add_args ""
      ts_log_fine "adding host resource \"$host_resource\" to hedeby system ..."
   }
   ts_log_fine "properties file:"
   ts_log_fine $file_content


   # now use sdmadm command ...
   sdmadm_command $exec_host $exec_user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] ar -f $file_name $add_args" prg_exit_state "" $raise_error
   return $prg_exit_state
}

global ge_arch_mapping_table
if {[info exists ge_arch_mapping_table]} {
   unset ge_arch_mapping_table
}
#****** util/get_hedeby_ge_complex_mapping() ***********************************
#  NAME
#     get_hedeby_ge_complex_mapping() -- parse ge complex mapping values
#
#  SYNOPSIS
#     get_hedeby_ge_complex_mapping { arch {rp res_prop} } 
#
#  FUNCTION
#     This procedure is used to map the ge arch strings to hedeby resource
#     properties. The output of sdmadm sgcm is used to create a mapping
#     cache which is only updated, when an architecture was not found
#     or the testsuite is re-sourcing the tcl script files.
#
#  INPUTS
#     arch          - ts or ge arch string
#     {rp res_prop} - array name to store resource properties
#
#  RESULT
#     return value: 0 on success, 1 on error
#     The returned res_prop array contains following settings
#     
#          res_prop(PROPERTY) VALUE
#
#  EXAMPLE
#     get_hedeby_ge_complex_mapping [resolve_arch $hedeby_config(hedeby_master_host)] 
#     foreach name [array names res_prop] {
#        ts_log_fine "$name=$res_prop($name)"
#     }
#
#*******************************************************************************
proc get_hedeby_ge_complex_mapping { arch {rp res_prop} } {
   global hedeby_config
   global ge_arch_mapping_table

   upvar $rp resource_properties
   if {[info exists resource_properties]} {
      unset resource_properties
   }
   
   if {![info exists ge_arch_mapping_table($arch,properties)]} {
      ts_log_fine "re-reading ge_arch_mapping_table ..."
      set command "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sgcm -match default"
      sdmadm_command $hedeby_config(hedeby_master_host) [get_hedeby_admin_user] $command prg_exit_state "" 1 table
      for {set line 0} {$line < $table(table_lines)} {incr line 1} {
         foreach col $table(table_columns) {
   #         puts "line $line => $col: \"$table($col,$line)\""
            if { $col == "complex" && $table($col,$line) == "arch"} {
               set res_property $table(resource property,$line)
               set complex_arch $table(complex value,$line)
               set res_value $table(resource value,$line)
               if {![info exists ge_arch_mapping_table($complex_arch,properties)]} {
                  set ge_arch_mapping_table($complex_arch,properties) {}
               }
               lappend ge_arch_mapping_table($complex_arch,properties) $res_property
               ts_log_finest "ge_arch_mapping_table($complex_arch,properties)=$ge_arch_mapping_table($complex_arch,properties)"
               set ge_arch_mapping_table($complex_arch,$res_property) $res_value
            }
         }
      }
   } else {
      ts_log_fine "using chached ge_arch_mapping_table ..."
   }
   
   if {[info exists ge_arch_mapping_table($arch,properties)]} {
      foreach prop $ge_arch_mapping_table($arch,properties) {
         set resource_properties($prop) $ge_arch_mapping_table($arch,$prop)
      }
      return 0
   }
   ts_log_info "cannot find architecture mapping for ge arch \"$arch\""
   return 1
}

#****** util/get_hedeby_system_name() ******************************************
#  NAME
#     get_hedeby_system_name() -- get the testsuite hedeby system name
#
#  SYNOPSIS
#     get_hedeby_system_name { } 
#
#  FUNCTION
#     Returns the hedeby system name used by the testsuite. The name is a
#     combination of ts_+preferences_type+CS_port.
#
#  INPUTS
#
#  RESULT
#     system name used by testsuite
#
#  SEE ALSO
#     util/get_hedeby_system_name()
#     util/get_hedeby_pref_type()
#     util/get_hedeby_admin_user()
#     util/get_hedeby_startup_user()
#     util/get_hedeby_cs_url()
#     util/get_hedeby_local_spool_dir()
#     util/cleanup_hedeby_local_spool_dir()
#     util/get_all_hedeby_managed_hosts()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc get_hedeby_system_name { } {
   global hedeby_config
   set pref_type [get_hedeby_pref_type]
   set sys_name "ts"
   append sys_name $hedeby_config(hedeby_cs_port)
   append sys_name $pref_type
   return $sys_name
}

#****** util/get_hedeby_pref_type() ********************************************
#  NAME
#     get_hedeby_pref_type() -- get the preferences type of the hedeby system
#
#  SYNOPSIS
#     get_hedeby_pref_type { } 
#
#  FUNCTION
#     Returns the hedeby preferences type used by testsuite. The type may be
#     "user" or "system". If the testsuite was started as admin user system
#     (which happens when the root password wasn't provided) the testsuite
#     will install hedeby in user preferences. If the testsuite has the root
#     password the hedeby bootstrap information will be installed in the
#     "system" preferences.
#
#  INPUTS
#
#  NOTES
#     Currently the testsuite only supports the "user" preferences mode
#
#  RESULT
#     "user" or "system"
#    
#  SEE ALSO
#     util/get_hedeby_system_name()
#     util/get_hedeby_pref_type()
#     util/get_hedeby_admin_user()
#     util/get_hedeby_startup_user()
#     util/get_hedeby_cs_url()
#     util/get_hedeby_local_spool_dir()
#     util/cleanup_hedeby_local_spool_dir()
#     util/get_all_hedeby_managed_hosts()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc get_hedeby_pref_type { } {
   global CHECK_ADMIN_USER_SYSTEM
   global hedeby_config
   if {$CHECK_ADMIN_USER_SYSTEM == 0} {
      return $hedeby_config(preferences_mode)
   } else {
      if { $hedeby_config(preferences_mode) == "system" } {
         set error_text "WARNING: It is not possible to save \"system\" preferences without having root permissions!\n"
         append error_text "Please provide root password OR modify hedeby configuration to use preferences_mode \"user\"!\n"
         append error_text "INFO: Testsuite will store bootstrap information in \"user\" preferences!!!"
         ts_log_fine $error_text
      }
      return "user"
   }
}

#****** util/get_hedeby_admin_user() *******************************************
#  NAME
#     get_hedeby_admin_user() -- get the name of the hedeby admin user
#
#  SYNOPSIS
#     get_hedeby_admin_user { } 
#
#  FUNCTION
#     This procedure returns the username of the hedeby admin user. This is
#     currently the CHECK_USER variable. The CHECK_USER is the user which
#     started the testsuite.
#
#  INPUTS
#
#  RESULT
#     name of the hedeby admin user
#
#  SEE ALSO
#     util/get_hedeby_system_name()
#     util/get_hedeby_pref_type()
#     util/get_hedeby_admin_user()
#     util/get_hedeby_startup_user()
#     util/get_hedeby_cs_url()
#     util/get_hedeby_local_spool_dir()
#     util/cleanup_hedeby_local_spool_dir()
#     util/get_all_hedeby_managed_hosts()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc get_hedeby_admin_user { } {
   global CHECK_USER
   return $CHECK_USER
}


#****** util/read_bundle_properties_cache() ************************************
#  NAME
#     read_bundle_properties_cache() -- used to read bundle_cache from disk
#
#  SYNOPSIS
#     read_bundle_properties_cache { } 
#
#  FUNCTION
#     The procedure is used to read the internal message bundle cache produced
#     by parse_bundle_properties_files() in the results directory after
#     compiling the sources.
#     The bundle cache is used for parsing expected output of hedeby cli
#     commands and/or log files.
#     The bundle cache is an array containing the bundle id 
#     (e.g."bootstrap.error.message1") and the corr. error text.
#     If the cache file is not extisting parse_bundle_properties_files() 
#     is called to re-create the file.
#
#  INPUTS
#
#  RESULT
#     The internal cache contains the bundle messages after successfully
#     reading the cache file.
#
#  SEE ALSO
#     util/read_bundle_properties_cache()
#     util/parse_bundle_properties_files()
#     util/get_properties_messages_file_name()
#     util/get_bundle_string()
#     util/create_bundle_string()
#     util/parse_bundle_string_params()
#*******************************************************************************
proc read_bundle_properties_cache { } {
   global bundle_cache
   global hedeby_config
   global CHECK_USER
   if { [info exists bundle_cache] } {
      unset bundle_cache
   }
   set filename [get_properties_messages_file_name]
   
   if {[is_remote_file $hedeby_config(hedeby_master_host) $CHECK_USER $filename]} {
      read_array_from_file $filename "bundle_cache" bundle_cache 1
   } else {
      parse_bundle_properties_files $hedeby_config(hedeby_source_dir)
   }
}

#****** util/parse_bundle_properties_files() ***********************************
#  NAME
#     parse_bundle_properties_files() -- create cache for bundle file entries
#
#  SYNOPSIS
#     parse_bundle_properties_files { source_dir } 
#
#  FUNCTION
#     The procedure is used to parse the specified source directory path for
#     files ending with "*.properties" in order to find all used bundle ids
#     of the source code. All found property entries are stored in a global
#     cache which is also stored to disk in the results directory for the
#     next testsuite startup.
#
#  INPUTS
#     source_dir - full path to the hedeby source directory
#
#  SEE ALSO
#     util/read_bundle_properties_cache()
#     util/parse_bundle_properties_files()
#     util/get_properties_messages_file_name()
#     util/get_bundle_string()
#     util/create_bundle_string()
#     util/parse_bundle_string_params()
#*******************************************************************************
proc parse_bundle_properties_files { source_dir } {
   global bundle_cache
   global CHECK_USER
   global hedeby_config
   global ts_config

   # TODO: reparse messages if one file timestamp is newer than the file stamp
   #       of the cached files (same as for Grid Engine message files)        
   if {[info exists bundle_cache]} {
      unset bundle_cache
   }
   set filename [get_properties_messages_file_name]
   if {[is_remote_file $hedeby_config(hedeby_master_host) $CHECK_USER $filename]} {
      delete_remote_file $hedeby_config(hedeby_master_host) $CHECK_USER $filename

      # fix for hedeby testsuite issue #81
      wait_for_remote_file $ts_config(master_host) $CHECK_USER $filename 70 1 1
   }

   ts_log_fine "looking for properties files in dir \"$source_dir\" ..."
   
   # get all files ending with .properties in all subdirectories
   set prop_files {}
   set dirs [get_all_subdirectories $source_dir]
   foreach dir $dirs {
      set files [get_file_names $source_dir/$dir "*.properties"]
      foreach file $files {
         lappend prop_files $source_dir/$dir/$file
      }
   }

   set error_text ""
   foreach propFile $prop_files {
      set file_p [ open $propFile r ]
      set property ""
      while { [gets $file_p line] >= 0 } {
         set strLength [string length $line]
         set help $strLength
         incr help -1
         if { [string last "\\" $line] == $help } {
            incr help -1
            set help [string range $line 0 $help]
            append property $help
            continue
         }
         append property $line
         set property [string trim $property]
         if { [string first "#" $property] == 0 } {
            set property ""
            continue
         }
 
         if { [string length $property] == 0} {
            set property ""
            continue
         }

         set equalpos [string first "=" $property] 
         if { $equalpos > 0 } {
            set befpos $equalpos
            incr befpos -1
            set aftpos $equalpos 
            incr aftpos 1
            set propId  [string trim [string range $property 0 $befpos]]
            set propTxt [string trim [string range $property $aftpos end]]

            if {[info exists bundle_cache($propId)]} {
               append error_text "property \"$propId\" defined twice!\n"
            }
            set bundle_cache($propId) $propTxt
         }
         set property ""
      }
      close $file_p
   }
   if { $error_text != "" } {
      add_proc_error "parse_bundle_properties_files" -3 $error_text
   }

   # store parsed bundle ids
   spool_array_to_file $filename "bundle_cache" bundle_cache

   # wait remote for file ... 
   wait_for_remote_file $hedeby_config(hedeby_master_host) $CHECK_USER $filename
}

#****** util/get_properties_messages_file_name() *******************************
#  NAME
#     get_properties_messages_file_name() -- get file name of bundle cache file
#
#  SYNOPSIS
#     get_properties_messages_file_name { } 
#
#  FUNCTION
#     This procedure creates the file path to the file containting the bundle
#     cache messages from the hedeby properties files.
#
#  INPUTS
#
#  RESULT
#     Full path to cache file
#
#  SEE ALSO
#     util/read_bundle_properties_cache()
#     util/parse_bundle_properties_files()
#     util/get_properties_messages_file_name()
#     util/get_bundle_string()
#     util/create_bundle_string()
#     util/parse_bundle_string_params()
#*******************************************************************************
proc get_properties_messages_file_name { } {
   global CHECK_PROTOCOL_DIR 
   global hedeby_config
  
   ts_log_fine "checking properties file ..."
   if { [ file isdirectory $CHECK_PROTOCOL_DIR] != 1 } {
      file mkdir $CHECK_PROTOCOL_DIR
      ts_log_fine "creating directory: $CHECK_PROTOCOL_DIR"
   }
   set release $hedeby_config(hedeby_source_cvs_release)
   set filename $CHECK_PROTOCOL_DIR/source_code_properties_${release}.dump
   return $filename
}

#****** util/get_bundle_string() ***********************************************
#  NAME
#     get_bundle_string() -- get belonging to specified bundle id
#
#  SYNOPSIS
#     get_bundle_string { id } 
#
#  FUNCTION
#     The procedure tries to find the specified string in the bundle_cache
#     array and returns the bundle text.
#
#  INPUTS
#     id - bundle id, e.g.: "bootstrap.exception.constructor_of_not_allowed"
#  RESULT
#     corr. text, defined by the bundle id. E.g.:
#     "Not allowed to create instance if {0} for component {1}."
#
#  NOTES
#     This procedure is used more internally by create_bundle_string() and
#     parse_bundle_string_params()
#
#  SEE ALSO
#     util/read_bundle_properties_cache()
#     util/parse_bundle_properties_files()
#     util/get_properties_messages_file_name()
#     util/get_bundle_string()
#     util/create_bundle_string()
#     util/parse_bundle_string_params()
#*******************************************************************************
proc get_bundle_string { id } {
   global bundle_cache

   set ret_val ""
   if { [info exists bundle_cache($id)] } {
      set ret_val $bundle_cache($id)
   }
   if { $ret_val == "" } {
      add_proc_error "get_bundle_string" -1 "cannot find bundle string \"$id\""
      set ret_val "This is a return value for a unknown bundle string"
   }
   return $ret_val
}


#****** util/create_bundle_string() ********************************************
#  NAME
#     create_bundle_string() -- create message from bundle id by setting parameters
#
#  SYNOPSIS
#     create_bundle_string { id {params_array "params"} {default_param ""} } 
#
#  FUNCTION
#     This procedure is used to generate a message build out of the bundle id
#     text and the specified parameters.
#     The resulting string can be used for string matching options when it is
#     necessary to test cli output of commands.
#
#  INPUTS
#     id                      - bundle id
#     {params_array "params"} - array containing the parameters
#     {default_param ""}      - if set the array is not used. All found
#                               parameters will be replaced by the specified
#                               string
#
#  RESULT
#     A string where all the parameters from the bundle text are replaced
#     by the specified params from the array or (if default_param != "")
#     replaced by the default_param string.
#
#  EXAMPLE
#     set match_string [create_bundle_string "bootstrap.log.info.jvm_started" xyz "*"]
#     puts $match_string
#
#     # bundle text of "bootstrap.log.info.jvm_started" is "Jvm {0} started"
#     # Since the default parameter is set to "*" the {0} parameter is replaced
#     # by "*"
#     output: "Jvm * started"
#
#     The following lines would exactly produce the same output:
#
#     set xyz(0) "*"
#     set match_string [create_bundle_string "bootstrap.log.info.jvm_started" xyz]
#
#     set params(0) "*"
#     set match_string [create_bundle_string "bootstrap.log.info.jvm_started"]
#
#
#  SEE ALSO
#     util/read_bundle_properties_cache()
#     util/parse_bundle_properties_files()
#     util/get_properties_messages_file_name()
#     util/get_bundle_string()
#     util/create_bundle_string()
#     util/parse_bundle_string_params()
#*******************************************************************************
proc create_bundle_string { id {params_array "params"} {default_param ""} } {
   upvar $params_array params
   # get bundle string
   set bundle_string [get_bundle_string $id]
   set result_string $bundle_string

   # ts_log_fine "bundle string: \"$result_string\""
   # get number of params in bundle string
   set i 0
   while { [string match "*{$i}*" $bundle_string] } {
      incr i 1
   }
   # ts_log_fine "bundle string has $i parameter"
   for { set x 0 } { $x < $i } { incr x 1 } {
      set par_start [string first "{$x}" $result_string]
      set par_end $par_start
      incr par_end 2

      if { $default_param != "" } {
         set param_string $default_param
      } elseif { [info exists params($x)] } {
         set param_string $params($x)
      } else {
         add_proc_error "create_bundle_string" -1 "parameter $x is missing in params array"
         set param_string "{$x}"
      }
      set result_string [string replace $result_string $par_start $par_end $param_string]
      #ts_log_fine "result $x: \"$result_string\""
   }
   # ts_log_fine "output string: \"$result_string\""
   return $result_string
}

#****** util/parse_bundle_string_params() **************************************
#  NAME
#     parse_bundle_string_params() -- parse output with matching bundle text
#
#  SYNOPSIS
#     parse_bundle_string_params { output id {params_array params} } 
#
#  FUNCTION
#     This procedure is used to parse the output of a cli command and get the
#     parameters used when creating the output. Se the EXAMPLE section for a
#     better description.
#
#  INPUTS
#     output                - output which should be parsed (compared) to bundle
#                             string
#     id                    - bundle id
#     {params_array params} - array to store results
#
#  RESULT
#     result is stored in the named array. 
#     array_name(count) contains the number of params found
#     array_name(x) contains the parsed parameters
#
#  EXAMPLE
#     The output of a cli command is looking as follows:
#     "tuor: executor_vm -- status: started"
#
#     When using the message id "client.status.service" the procedure will use
#     the bundle text ("{0}: {1} -- status: {2}") to parse the output and try
#     to return the parameters used when the output was generated.
#
#     The parsed parameters are stored in the specified params array. After
#     the call the array contains the parameter count stored in params(count)
#     and the values in params(0), params(1), params(2), ...
#
#     Code example:
#     =============
#     ...
#     parse_bundle_string_params $line "client.status.service" params
#     set host   $params(0)
#     set comp   $params(1)
#     set status $params(2)
#
#
#  SEE ALSO
#     util/read_bundle_properties_cache()
#     util/parse_bundle_properties_files()
#     util/get_properties_messages_file_name()
#     util/get_bundle_string()
#     util/create_bundle_string()
#     util/parse_bundle_string_params()
#*******************************************************************************
proc parse_bundle_string_params { output id {params_array params}  } {
   upvar $params_array par

   if { [info exists par] } {
      unset par
   }

   set par(count) 0

   set bundle_string [get_bundle_string $id]
   #ts_log_fine "output: $output"
   #ts_log_fine "bundle: $bundle_string"
   set i 0
   while { [string match "*{$i}*" $bundle_string] } {
      incr i 1
   }
   set par(count) $i

   set max_pos 0

   for { set x 0 } { $x < $i } { incr x 1 } {
      set par($x,index) [string first "{$x}" $bundle_string]
      if { $max_pos > $par($x,index) } {
         add_proc_error "parse_bundle_string_params" -1 "This parser currently expects the bundle string parameters in the correct order!"
      }
      set max_pos $par($x,index)
      set irange_end $par($x,index)
      incr irange_end -1
      if { $irange_end < 0 } {
         set irange_end 0
      }
      if {$x > 0 } {
         set prev_par $x
         incr prev_par -1
         set irange_start $par($prev_par,index)
         incr irange_start 3
      } else {
         set irange_start 0
      }
      # here we have the string before the current parameter
      if { $irange_start != $irange_end } {
         set par($x,before) [string range $bundle_string $irange_start $irange_end]
      } else {
         set par($x,before) ""
      }
      #ts_log_fine "before $x ($irange_start - $irange_end): \"$par($x,before)\""
   }

   set last_static_string ""
   incr x -1
   set endOfLastParam $par($x,index)
   incr endOfLastParam 3
   set bundleStrLength [string length $bundle_string]
   set restString ""
   if { $endOfLastParam != $bundleStrLength} {
      # handle situations where the last param is not the last string content
      set restString [string range $bundle_string $endOfLastParam end ]
   }
   #ts_log_fine "rest string: \"$restString\""

   

   set parse_string $output
   for { set x 0 } { $x < $i } { incr x 1 } {
      set before $par($x,before)
      set before_length [string length $before]
      if { $before_length > 0 } {
         if { [string first $before $parse_string] != 0 } {
            set error_text "error parsing string can't find before sequence of param $x!\n"
            append error_text "   bundle string: \"$bundle_string\"\n"
            append error_text "   parse string:  \"$output\""
            add_proc_error "parse_bundle_string_params" -1 $error_text
         } else {
            set parse_string [string range $parse_string $before_length end]
            #ts_log_fine "remaining parse string: \"$parse_string\"" 
         }
      }
      set next_param $x
      incr next_param 1
       
      if { $next_param < $i } {
         # now we copy from begining to the start of the next param
         set next_str $par($next_param,before)
         if { $next_str == "" } {
            add_proc_error "parse_bundle_string_params" -1 "error parsing string some of the parameters have no separator string"
         }
      } else {
         # we use the rest for the last param
         set next_str $restString
      }

      if { $next_str == "" } {
         # this is the last param, use the rest of the parse string for last param
         set par($x) $parse_string
         set parse_string ""
      } else {
         set index [string first $next_str $parse_string]
         incr index -1
         set par($x) [string range $parse_string 0 $index]
         incr index 1
         set parse_string [string range $parse_string $index end]
      }
      #ts_log_fine "par($x) = \"$par($x)\""
      #ts_log_fine "remaining parse string: \"$parse_string\"" 
   }
}

#****** util/get_hedeby_startup_user() *****************************************
#  NAME
#     get_hedeby_startup_user() -- get name of user for starting hedeby
#
#  SYNOPSIS
#     get_hedeby_startup_user { } 
#
#  FUNCTION
#     This procedure returns the name of the hedeby startup user. The startup
#     user is used for starting the system. The user depends on the system
#     preferences type. For "user" systems the $CHECK_USER is returned (=user
#     which started testsuite). For "system" installations the user "root" is
#     returned.
#
#  INPUTS
#
#  RESULT
#     Name of hedeby startup user
#
#  SEE ALSO
#     util/get_hedeby_system_name()
#     util/get_hedeby_pref_type()
#     util/get_hedeby_admin_user()
#     util/get_hedeby_startup_user()
#     util/get_hedeby_cs_url()
#     util/get_hedeby_local_spool_dir()
#     util/cleanup_hedeby_local_spool_dir()
#     util/get_all_hedeby_managed_hosts()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc get_hedeby_startup_user { } {
   global CHECK_USER
   set pref_type [get_hedeby_pref_type]
   if { $pref_type == "system" } {
      set user "root"
   } else {
      set user $CHECK_USER
   }
   return $user
}

#****** util/get_hedeby_cs_url() ***********************************************
#  NAME
#     get_hedeby_cs_url() -- return url of configuration service
#
#  SYNOPSIS
#     get_hedeby_cs_url { } 
#
#  FUNCTION
#     The url is build of hedeby master host and the hedeby cs port specified
#     in the testsuite configuration (e.g. "hostfoo:43434").
#
#  INPUTS
#
#  RESULT
#     url string
#
#  SEE ALSO
#     util/get_hedeby_system_name()
#     util/get_hedeby_pref_type()
#     util/get_hedeby_admin_user()
#     util/get_hedeby_startup_user()
#     util/get_hedeby_cs_url()
#     util/get_hedeby_local_spool_dir()
#     util/cleanup_hedeby_local_spool_dir()
#     util/get_all_hedeby_managed_hosts()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc get_hedeby_cs_url { } {
   global hedeby_config
   return "$hedeby_config(hedeby_master_host):$hedeby_config(hedeby_cs_port)"
}


#****** util/get_hedeby_local_spool_dir() **************************************
#  NAME
#     get_hedeby_local_spool_dir() -- get the hedeby local spool directory path
#
#  SYNOPSIS
#     get_hedeby_local_spool_dir { host } 
#
#  FUNCTION
#     This procedure returns the path to the local spool directory for the
#     specified host. This path depends on the testsuite host configuration and
#     adds the subdirectory "hedeby_spool" to the path.
#
#  INPUTS
#     host - name of the host for which the local spooldir should be returned
#
#  RESULT
#     spool directory path
#
#  SEE ALSO
#     util/get_hedeby_system_name()
#     util/get_hedeby_pref_type()
#     util/get_hedeby_admin_user()
#     util/get_hedeby_startup_user()
#     util/get_hedeby_cs_url()
#     util/get_hedeby_local_spool_dir()
#     util/cleanup_hedeby_local_spool_dir()
#     util/get_all_hedeby_managed_hosts()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc get_hedeby_local_spool_dir { host } {
   set spool_dir [get_local_spool_dir $host "hedeby_spool" 0 ]
   # hedeby needs a local spool dir
   if {$spool_dir == ""} {
      ts_log_severe "Host \"$host\" has no local testsuite spool directory defined.\nHedeby needs a local spool directory for this host!"
   }
   return $spool_dir
}

#****** util/cleanup_hedeby_local_spool_dir() **********************************
#  NAME
#     cleanup_hedeby_local_spool_dir() -- delete the hedeby local spool dir
#
#  SYNOPSIS
#     cleanup_hedeby_local_spool_dir { host } 
#
#  FUNCTION
#     This procedure is used to delete the local spool directory of the
#     specified host. The procedure is using get_hedeby_local_spool_dir()
#     to get the path to be deleted. After that all files are recursivle
#     chown'ed to the $CHECK_USER by using the root account.
#   
#     After that the directory is completely deleted.
#
#  INPUTS
#     host - name of the host for which the local spooldir should be deleted
#
#  RESULT
#     path to the deleted spool directory
#
#  SEE ALSO
#     util/get_hedeby_system_name()
#     util/get_hedeby_pref_type()
#     util/get_hedeby_admin_user()
#     util/get_hedeby_startup_user()
#     util/get_hedeby_cs_url()
#     util/get_hedeby_local_spool_dir()
#     util/cleanup_hedeby_local_spool_dir()
#     util/get_all_hedeby_managed_hosts()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc cleanup_hedeby_local_spool_dir { host } {
   global CHECK_USER
   # to be able to cleanup (delete) the spooldir the file
   # permissions have to be set to the testsuite user
   set local_spool_dir [get_hedeby_local_spool_dir $host]
   if { $local_spool_dir != "" } {
      if {[is_remote_path $host $CHECK_USER $local_spool_dir]} {
         set comargs "-R $CHECK_USER $local_spool_dir"
         if {[have_root_passwd] == 0} {
            set chown_user "root"
         } else {
            set chown_user $CHECK_USER
         }
         ts_log_fine "${host}($chown_user): doing chown $comargs ..."
         set output [start_remote_prog $host $chown_user "chown" $comargs]
         ts_log_fine $output
         if { $prg_exit_state != 0 } {
            add_proc_error "cleanup_hedeby_local_spool_dir" -1 "doing chown $comargs returned exit code: $prg_exit_state\n$output"
         }
      }
   }
   set spool_dir [get_local_spool_dir $host "hedeby_spool" 1 ]
   remote_delete_directory $host $spool_dir
   return $spool_dir
}


# this procedure returns all possible managed hosts!!!
#****** util/get_all_hedeby_managed_hosts() ************************************
#  NAME
#     get_all_hedeby_managed_hosts() -- get all possible managed host names
#
#  SYNOPSIS
#     get_all_hedeby_managed_hosts { } 
#
#  FUNCTION
#     The procedure returns a list of all possible managed host candidates of
#     the specified Grid Engine clusters including all hedeby (host) resources.
#
#  INPUTS
#
#  RESULT
#     list with host names
#
#  SEE ALSO
#     util/get_hedeby_system_name()
#     util/get_hedeby_pref_type()
#     util/get_hedeby_admin_user()
#     util/get_hedeby_startup_user()
#     util/get_hedeby_cs_url()
#     util/get_hedeby_local_spool_dir()
#     util/cleanup_hedeby_local_spool_dir()
#     util/get_all_hedeby_managed_hosts()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc get_all_hedeby_managed_hosts {} {
   global hedeby_config
   set host_list $hedeby_config(hedeby_host_resources) 
   
   foreach host [get_all_execd_hosts] {
      if {[lsearch $host_list $host] < 0 && $host != $hedeby_config(hedeby_master_host) } {
         lappend host_list $host
      }
   }
   return $host_list
}

#****** util/get_hedeby_default_services() *************************************
#  NAME
#     get_hedeby_default_services() -- get information about ge services
#
#  SYNOPSIS
#     get_hedeby_default_services { service_names } 
#
#  FUNCTION
#     This procedure is used to get information about grid engine services
#     from testsuite configurations.
#
#  INPUTS
#     service_names - name of a array where to store service information
#
#  RESULT
#     1) returns list of qmaster hosts where ge services are running
#     2) informations in service_names:
#
#         array name                             | value
#         ================================================================
#         service_names(service,$host)           | list of all services on $host
#         service_names(execd_hosts,$service)    | list of all execds of $service
#         service_names(master_host,$service)    | name of master of $service
#         service_names(services)                | list of all services
#         service_names(moveable_execds,$service)| list of all not static resources of $service
#         service_names(ts_cluster_nr,$host)     | testsuite cluster nr of service
#         service_names(default_service,$host)   | default service of $host
#
#*******************************************************************************
proc get_hedeby_default_services { service_names } {
   upvar $service_names ret
   set current_cluster_config [get_current_cluster_config_nr]
   set cluster 0
   set ge_master_hosts {}
   set ret(services) {}
   while { [set_current_cluster_config_nr $cluster] == 0 } {
      get_current_cluster_config_array ts_config
      lappend ge_master_hosts $ts_config(master_host)
      if { [info exists ret(service,$ts_config(master_host))] } {
         set old_val $ret(service,$ts_config(master_host))
         set ret(service,$ts_config(master_host)) "$old_val $ts_config(cluster_name)"
      } else {
         set ret(service,$ts_config(master_host)) "$ts_config(cluster_name)"
      }
      set ret(execd_hosts,$ts_config(cluster_name)) $ts_config(execd_nodes)
      set ret(master_host,$ts_config(cluster_name)) $ts_config(master_host)
      set ret(ts_cluster_nr,$ts_config(master_host)) $cluster
      lappend ret(services) $ts_config(cluster_name)

      set ret(moveable_execds,$ts_config(cluster_name)) {}
      foreach exh $ts_config(execd_nodes) {
         set ret(default_service,$exh) $ts_config(cluster_name)
         if {$exh != $ts_config(master_host)} {
            lappend ret(moveable_execds,$ts_config(cluster_name)) $exh
            set ret(ts_cluster_nr,$exh) $cluster
         }
      }

      ts_log_fine "execds for service \"$ts_config(cluster_name)\": $ret(execd_hosts,$ts_config(cluster_name))"
      ts_log_fine "service names for hedeby on host \"$ts_config(master_host)\": $ret(service,$ts_config(master_host))"
      incr cluster 1
   }
   set_current_cluster_config_nr $current_cluster_config
   ts_log_fine "current ge master hosts: $ge_master_hosts"
   return $ge_master_hosts
}


#****** util/is_hedeby_process_running() ***************************************
#  NAME
#     is_hedeby_process_running() -- check a process is running
#
#  SYNOPSIS
#     is_hedeby_process_running { host pid } 
#
#  FUNCTION
#     This procedure is using the get_ps_info() call for the specified pid to
#     find out if the specified process is running.
#
#  INPUTS
#     host - host where the process is checked 
#     pid  - pid of process which should be checked
#
#  RESULT
#     1 - process is running
#     0 - process is NOT running
#
#  SEE ALSO
#     util/get_hedeby_system_name()
#     util/get_hedeby_pref_type()
#     util/get_hedeby_admin_user()
#     util/get_hedeby_startup_user()
#     util/get_hedeby_cs_url()
#     util/get_hedeby_local_spool_dir()
#     util/cleanup_hedeby_local_spool_dir()
#     util/get_all_hedeby_managed_hosts()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc is_hedeby_process_running { host pid } {

   ts_log_fine "checking pid $pid on host $host ..."
   get_ps_info $pid $host ps_info

   set result 0
   if {$ps_info($pid,error) == 0} {
        if { [string match "*java*" $ps_info($pid,string)] >= 0 } {
           ts_log_fine "process string of pid $pid is $ps_info($pid,string)"
           set result 1
        } else {
           ts_log_fine "hedeby process should have java string in command line"
           set result 0
        }
   } else {
        ts_log_fine "pid $pid not found!"
        set result 0
   }
   return $result
}

#****** util/kill_hedeby_process() *********************************************
#  NAME
#     kill_hedeby_process() -- kill a hedeby components java process
#
#  SYNOPSIS
#     kill_hedeby_process { host user component pid {atimeout 60} } 
#
#  FUNCTION
#     This procedure is used to send the SIGTERM signal to the specified
#     pid of a component. If the process doesn't stop within the default
#     wait time of 60 seconds the process is killed with SIGKILL signal.
#
#  INPUTS
#     host          - host of the component
#     user          - user which should send the signals
#     component     - name of the component pid file
#                     (e.g. "executor_vm@hostFoo")
#     pid           - process id of java process 
#     {atimeout 60} - optional timeout waiting for process end after 
#                     sending SIGTERM signal
#
#  RESULT
#     none
#
#  SEE ALSO
#     util/is_hedeby_process_running()
#     util/kill_hedeby_process()
#     util/shutdown_hedeby_hosts()
#     util/startup_hedeby_hosts()
#     util/shutdown_hedeby()
#     util/startup_hedeby()
#*******************************************************************************
proc kill_hedeby_process { host user component pid {atimeout 60}} {

   set del_pid_file [get_hedeby_local_spool_dir $host]
   append del_pid_file "/run/$component"
   if { [is_remote_file $host $user $del_pid_file] == 0 } {
      ts_log_fine "cannot find pid file of component $component in the hedeby run directory"
   }

   set delete_pid_file 0
   ts_log_fine "***********************************************************************"
   ts_log_fine "killing component \"$component\" with pid \"$pid\" using SIGTERM ..."
   start_remote_prog $host $user "kill" "$pid"
   set wait_time [timestamp]
   incr wait_time $atimeout
   set terminated 0
   while { [timestamp] < $wait_time } {
      after 2000
      set is_pid_running [is_hedeby_process_running $host $pid]
      if { $is_pid_running == 0 } {
         set terminated 1
         break
      }
   }
   if { $terminated == 0 } {
      ts_log_fine "***********************************************************************"
      ts_log_fine "killing component \"$component\" with pid \"$pid\" using SIGKILL ..."
      start_remote_prog $host $user "kill" "-9 $pid"
      set is_pid_running [is_hedeby_process_running $host $pid]
      if { $is_pid_running } {
         add_proc_error "kill_hedeby_process" -1 "cannot shutdown component \"$component\" on host \"$host\" as user \"$user\""
      } else {
         # we killed with SIGKILL, we have to delete the pid file
         set delete_pid_file 1
      }
   }
   # components should have delete the pidfiles by itself here (SIGTERM is normal shutdown)
   if { $delete_pid_file } {
      ts_log_fine "delete pid file \"$del_pid_file\"\nfor component \"$component\" on host \"$host\" as user \"$user\" ..."
      delete_remote_file $host $user $del_pid_file
   }
}

#****** util/shutdown_hedeby_hosts() ********************************************
#  NAME
#     shutdown_hedeby_hosts() -- shutdown complete hedeby host
#
#  SYNOPSIS
#     shutdown_hedeby_hosts { type host user } 
#
#  FUNCTION
#     This procedure is used to shutdown all hedeby components on the specified
#     host. First try will shutdown components using sdmadm command. If this
#     doesn't help SIGTERM and if also this does not help SIGKILL is send to
#     the java processes on the specified host.
#
#  INPUTS
#     type - type of hedeby host: "master" or "managed"
#     host_list - name of the hosts where the components should be stopped
#     user - user which should stop the components
#
#  RESULT
#     0 - on success
#     1 - on error
#
#  SEE ALSO
#     util/is_hedeby_process_running()
#     util/kill_hedeby_process()
#     util/shutdown_hedeby_hosts()
#     util/startup_hedeby_hosts()
#     util/shutdown_hedeby()
#     util/startup_hedeby()
#*******************************************************************************
proc shutdown_hedeby_hosts { type host_list user { only_raise_cannot_kill_error 0 } } {
   global hedeby_config

   set error_text ""
   if {$only_raise_cannot_kill_error} {
      set raise_error 0
   } else {
      set raise_error 1
   }

   if { $type != "managed" && $type != "master" } {
      add_proc_error "shutdown_hedeby_hosts" -1 "unexpected host type: \"$type\" supported are \"managed\" or \"master\"" $raise_error
      return 1
   }

   ts_log_fine "shutting down hedeby host(s): $host_list"

   foreach host $host_list {
      # get local run directory path
      set run_dir [get_hedeby_local_spool_dir $host]
      append run_dir "/run"
      set hostInfoArray($host,run_dir) $run_dir

      # now get running component information
      set pid_list {}
      set run_list {}
      set hostInfoArray($host,ret_val) [get_jvm_pidlist $host $user $hostInfoArray($host,run_dir) pid_list run_list]
      set hostInfoArray($host,pid_list) $pid_list
      set hostInfoArray($host,run_list) $run_list
   }
   
   switch -exact -- $type {
      "managed" {
         set shutdown_host_list {}
         foreach host $host_list {
            if { $host == $hedeby_config(hedeby_master_host) } {
               append error_text "host \"$host\" is the master host, but type is managed!\n\n"
               incr hostInfoArray($host,ret_val) 1
               continue
            }
            if { [llength $hostInfoArray($host,pid_list)] == 0 } {
               ts_log_fine "no jvms found on host $host"
            } else {
               lappend shutdown_host_list $host
            }
         }

         if { [llength $shutdown_host_list] > 0 } {
            set pref_type [get_hedeby_pref_type]
            set sys_name [get_hedeby_system_name]
            foreach host $shutdown_host_list {
               set task_info($host,expected_output) ""
               set task_info($host,sdmadm_command) "-p $pref_type -s $sys_name sdj -h $host -all"      
            }
            ts_log_fine "parallel shutting down \"$type\" hosts \"$shutdown_host_list\" ..."
            append error_text [start_parallel_sdmadm_command shutdown_host_list $user task_info $raise_error]

            foreach host $shutdown_host_list {
               if {$task_info($host,exit_status) != 0} {
                  incr hostInfoArray($host,ret_val) 1
               }
               debug_puts "----------------------------------"
               debug_puts "host: $host"
               debug_puts "exit status: $task_info($host,exit_status)"
               debug_puts "output:\n$task_info($host,output)"
               debug_puts "----------------------------------"
            }
         }
      }
      "master" {
         if {[llength $host_list] != 1} {
            append error_text "hostlist contains more than 1 entry - hedeby has only one master host\n\n"
            incr hostInfoArray($host,ret_val) 1
         } else {
            set host [lindex $host_list 0]
            if { $host != $hedeby_config(hedeby_master_host) } {
               append error_text "host \"$host\" is NOT the master host, but type is master!\n\n"
               incr hostInfoArray($host,ret_val) 1
            } else {
               if { [llength $hostInfoArray($host,pid_list)] == 0 } {
                  ts_log_fine "no components found on host $host"
               } else {
                  set output [sdmadm_command $host $user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sdj -h $host -all" prg_exit_state "" $raise_error]
                  if { $prg_exit_state != 0 } {
                     incr hostInfoArray($host,ret_val) 1
                  }
               }
            }
         }
      }
   }
   
   set ret_val 0
   foreach host $host_list {
      if { $hostInfoArray($host,ret_val) != 0 } {
         set ret_val 1
         # do cleanup
         cleanup_hedeby_processes $host $user $hostInfoArray($host,run_dir) $hostInfoArray($host,pid_list) $hostInfoArray($host,run_list) $raise_error
      } else {
         # check pid files and processes
         set back [check_hedeby_process_shutdown $host $user $hostInfoArray($host,run_dir) $hostInfoArray($host,pid_list) $hostInfoArray($host,run_list) $raise_error]
         incr hostInfoArray($host,ret_val) $back
      }
   }

   if {$ret_val == 0 && $error_text != "" } {
      append error_text "we have an error text, but return value is 0 - returning 1\n\n"
      set ret_val 1
   }

   if { $ret_val != 0 } {
      add_proc_error "shutdown_hedeby_hosts" -1 $error_text $raise_error
   }
   return $ret_val
}


#****** util/start_parallel_sdmadm_command() ***********************************
#  NAME
#     start_parallel_sdmadm_command() -- start sdmadm_command parallel
#
#  SYNOPSIS
#     start_parallel_sdmadm_command { host_list exec_user info {raise_error 1} 
#     {parallel 1} } 
#
#  FUNCTION
#     This procedure is used to start parallel sdmadm tasks
#
#  INPUTS
#     host_list       - hosts where to start sdmadm command
#     exec_user       - user which will execute the commands
#     info            - name of array to store task information
#     {raise_error 1} - optional: if 1 report errros
#     {parallel 1}    - optional: if 0 run commands in a sequence
#                                 (for debuging only)
#
#  RESULT
#     string "" on success, string with error text on error
#
#  EXAMPLE
#     Initialize the task info array:
#     ===============================
#        foreach host $host_list {
#           set task_info($host,expected_output) ""
#           set task_info($host,sdmadm_command) "-p $pref_type -s $sys_name rs"      
#        }
#     Execute the sdmadm command parallel:
#     ====================================
#        set error_text [start_parallel_sdmadm_command host_list $remove_user task_info $raise_error]
#     Examine the results:
#     ====================
#        foreach host $host_list {
#           set exit_state $task_info($host,exit_status)
#           set output $task_info($host,output)
#           debug_puts "host: $host"
#           debug_puts "exit status: $exit_state"
#           debug_puts "output:\n$output"
#        }
#        if { $error_text != "" } {
#           add_proc_error "remove_hedeby_preferences" -1 $error_text $raise_error
#        }
#
#*******************************************************************************
proc start_parallel_sdmadm_command {host_list exec_user info {raise_error 1} {parallel 1}} {
   set spawn_list {}
   set error_text ""

   upvar $info task_info
   upvar $host_list hostlist

   if {[llength $hostlist] <= 0} {
      append error_text "got empty hostlist\n"
   } else {
      foreach host $hostlist {
         set task_info($host,start_found) 0
         set task_info($host,end_found) 0
         set task_info($host,exit_status) -1
         set task_info($host,output) ""

         if { $parallel == 1 } {
            set tasks(RETURN_ISPID) 0
            set ispid [sdmadm_command $host $exec_user $task_info($host,sdmadm_command) prg_exit_state tasks $raise_error]
            set ispid_list($host) $ispid
            ts_log_fine "got ispid: $ispid"
            set spawn_id [lindex $ispid 1]
            set ispid_list($host,sp_id) $spawn_id
            set ispid_list($spawn_id) $host
            ts_log_fine "sp_id on host $host is $ispid_list($host,sp_id)"
            lappend spawn_list $ispid_list($host,sp_id)
         } else {
            set task_info($host,output) [sdmadm_command $host $exec_user $task_info($host,sdmadm_command) prg_exit_state tasks $raise_error]
            set task_info($host,exit_status) $prg_exit_state
         }
      }

      set last_running ""
      if { $parallel == 1 }  {
         set timeout 60
         set expect_runs 0
         expect {
            -i $spawn_list full_buffer {
               append error_text "expect full_buffer error\n"
            }
            -i $spawn_list timeout {
               append error_text "expect timeout error\n"
            }
            -i $spawn_list eof {
               set spawn_id $expect_out(spawn_id)
               set host_name $ispid_list($spawn_id)
               append error_text "expect eof error for host $host_name\nbuffer:\n$expect_out(0,string)\n"
            }
            -i $spawn_list -- "*\n" {
               set spawn_id $expect_out(spawn_id)
               set host_name $ispid_list($spawn_id)
               set buffer $expect_out(0,string)
               set buffer [string trim $buffer]
               set tokensline [split $buffer "\n"]
               foreach tokenl $tokensline {
                  set token "$tokenl\n"
                  if { [string match "*_exit_status_:(*" $token ] } {
                     set help $token
                     set st [string first "(" $help]
                     set ed [string first ")" $help]
                     incr st 1
                     incr ed -1
                     set task_info($host_name,exit_status) [string range $help $st $ed]
                     set task_info($host_name,end_found) 1
                  }
                  if { $task_info($host_name,start_found) == 1 && $task_info($host_name,end_found) == 0 } {
                     append task_info($host_name,output) $token
                  }
                  if {[string first "_start_mark_:" $token] >= 0} {
                     set task_info($host_name,start_found) 1
                  }
               }

               set all_exited 1
               set finished_hosts ""
               set running_hosts ""
               foreach host $hostlist {
                  if { $task_info($host,exit_status) == "-1" } {
                     set all_exited 0
                     append running_hosts "$host "
                  } else {
                     append finished_hosts "$host "
                  }
               }
               incr expect_runs 1
               
               if { $last_running != $running_hosts } {
                  ts_log_fine "finished: $finished_hosts | running:  $running_hosts"
                  set last_running $running_hosts
               }

               if { $all_exited == 0 } {
                  exp_continue
               } else {
                  ts_log_fine "all commands terminated!"
               }
            }
         }

         foreach host $hostlist {
            close_spawn_process $ispid_list($host)
         }
      } 

      foreach host $hostlist {
         set reported_error 0
         if { $task_info($host,expected_output) != "" } {
            if {[string match "*$task_info($host,expected_output)*" $task_info($host,output)]} {
               ts_log_fine "matchstring found"
            } else {
               append error_text "\n"
               append error_text "Command \"sdmadm $task_info($host,sdmadm_command)\"\n"
               append error_text "started as user \"$exec_user\" on host \"$host\" returned:\n"
               append error_text "Exit status: $task_info($host,exit_status)\n"
               append error_text "Cannot find matchstring on host \"$host\":\n"
               append error_text "Matchstring: $task_info($host,expected_output)\n"
               append error_text "Output:\n$task_info($host,output)\n"
               incr reported_error
            }
         }
     
         if { $task_info($host,exit_status) != 0 && $reported_error == 0 } {
            append error_text "\n"
            append error_text "Command \"sdmadm $task_info($host,sdmadm_command)\"\n"
            append error_text "started as user \"$exec_user\" on host \"$host\" returned:\n"
            append error_text "Exit status: $task_info($host,exit_status)\n"
            append error_text "Output:\n$task_info($host,output)\n"
         }
      }
   }
   if { $raise_error != 0 && $error_text != ""} {
      ts_log_severe "error starting parallel sdmadm command:\n$error_text"
   }
   return $error_text
}


#****** util/startup_hedeby_hosts() *********************************************
#  NAME
#     startup_hedeby_hosts() -- startup all components on the hedeby host
#
#  SYNOPSIS
#     startup_hedeby_hosts { type host user } 
#
#  FUNCTION
#     This procedure is used to start all configured hedeby components on the
#     specified host. The processes are started under the specified user account.
#
#  INPUTS
#     type - type of hedeby host: "master" or "managed"
#     host - name of the host where the components should be started
#     user - user which should start the components
#
#  RESULT
#     0 - on success
#     1 - on error
#
#  NOTES
#     Currently this proceder doesn't check if the processes are runing after
#     startup and if the pid files were written! (see TODOs)
#
#  SEE ALSO
#     util/is_hedeby_process_running()
#     util/kill_hedeby_process()
#     util/shutdown_hedeby_hosts()
#     util/startup_hedeby_hosts()
#     util/shutdown_hedeby()
#     util/startup_hedeby()
#*******************************************************************************
proc startup_hedeby_hosts { type host_list user } {
   global hedeby_config
   set expected_jvms($hedeby_config(hedeby_master_host)) "cs_vm executor_vm rp_vm"
   # setup managed host expectations ...
   foreach host_temp [get_all_hedeby_managed_hosts] {
      set expected_jvms($host_temp) "executor_vm"
   }

   set success [create_bundle_string "StartJVMCommand.success"]
   set error_text ""
   if { $type != "managed" && $type != "master" } {
      add_proc_error "startup_hedeby_hosts" -1 "unexpected host type: \"$type\" supported are \"managed\" or \"master\""
      return 1
   }

   ts_log_fine "starting up hedeby host(s): $host_list"

   # TODO: add more checking for "managed" and "master"
   # TODO: test with get_ps_info if the processes have started
   # TODO: check that all pid are written and no one is missing

   # turn off security if enabled
   if { $hedeby_config(security_disable) == "true" } {
      set pref_type [get_hedeby_pref_type]
      if { $pref_type == "system" } {
         foreach host $host_list {
            ts_log_fine "WARNING! Setting security disable property on host $host!"
            set propArray($host,expected_output) ""
            set propArray($host,sdmadm_command) "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sebcp -p ssl_disable -v true"
         }
         append error_text [start_parallel_sdmadm_command host_list $user propArray]
         foreach host $host_list {
            set exit_state $propArray($host,exit_status)
            set output $propArray($host,output)
            debug_puts "----------------------------------"
            debug_puts "host: $host"
            debug_puts "exit status: $exit_state"
            debug_puts "output:\n$output"
            debug_puts "----------------------------------"
         }
      } else {
         # the user installation is shared in home directory it is only necessary
         # to set system properties on master host
         ts_log_fine "WARNING! Setting security disable property!"
         set host $hedeby_config(hedeby_master_host)
         set output [sdmadm_command $host $user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sebcp -p ssl_disable -v true"]
         if { $prg_exit_state != 0 } {
            append error_text "cannot set security disable property on host $host:\n$output\n"
         }
      }
   }

   switch -exact -- $type {
      "managed" {
         set pref_type [get_hedeby_pref_type]
         set system_name [get_hedeby_system_name]
         foreach host $host_list {
            set taskArray($host,expected_output) ""
            set taskArray($host,sdmadm_command) "-p $pref_type -s $system_name suj"
         }
         append error_text [start_parallel_sdmadm_command host_list $user taskArray]
         foreach host_tmp $host_list {
            set exit_state $taskArray($host_tmp,exit_status)
            set output $taskArray($host_tmp,output)
            #make the check for the output
            if { $exit_state != 0 } {
               append error_text "cannot startup managed host $host_tmp:\n$output\n"
            }
            set jvm_count [parse_jvm_start_stop_output output]
            set match_count 0
            for {set i 0} {$i < $jvm_count} {incr i} {
                set host $ss_out($i,host)
                set jvm  $ss_out($i,jvm)
                set res $ss_out($i,result)
                set mes $ss_out($i,message)
                debug_puts "Found jvm $jvm on host $host, with result $res"
                
                foreach match_jvm $expected_jvms($host_tmp) {
                    if { $match_jvm == $jvm } {
                        incr match_count
                        if { $res == $success } {
                            ts_log_fine "output match for jvm: $jvm, host: $host, result: $res"
                        } else {
                           append error_text "startup hedeby host ${host} failed:\n"
                           append error_text "\"$output\"\n"
                           append error_text "Jvm: $jvm on host: $host exited with result: $res with message: $mes\n"
                        }
                    }
                }               
            }
            set expected_count 0
            foreach expect_c $expected_jvms($host_tmp) {
                incr expected_count
            }
            if { $match_count == $expected_count } {
               ts_log_fine "output matched expected number of jvms: $match_count"
            } else {
               append error_text "startup hedeby host ${host} failed:\n"
               append error_text "\"$output\"\n"
               append error_text "The expected output doesn't match expected number of jvms: $match_count .\n"               
            } 

            debug_puts "----------------------------------"
            debug_puts "host: $host"
            debug_puts "exit status: $exit_state"
            debug_puts "output:\n$output"
            debug_puts "----------------------------------"
         }
      }
      "master" {
         if { [llength $host_list] != 1 } {
            append error_text "hostlist contains more than 1 entry - hedeby has only one master host\n\n"
         } else {
            set host_tmp [lindex $host_list 0]
            set output [sdmadm_command $host_tmp $user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] suj"]
            if { $prg_exit_state != 0 } {
               append error_text "cannot startup master host $host_tmp:\n$output\n"
            }
            set jvm_count [parse_jvm_start_stop_output output]
            set match_count 0
            for {set i 0} {$i < $jvm_count} {incr i} {
                set host $ss_out($i,host)
                set jvm  $ss_out($i,jvm)
                set res $ss_out($i,result)
                set mes $ss_out($i,message)
                debug_puts "Found jvm $jvm on host $host, with result $res"
                
                foreach match_jvm $expected_jvms($host_tmp) {
                    if { $match_jvm == $jvm } {
                        incr match_count
                        if { $res == $success } {
                            ts_log_fine "output match for jvm: $jvm, host: $host, result: $res"

                        } else {
                           append error_text "startup hedeby host ${host} failed:\n"
                           append error_text "\"$output\"\n"
                           append error_text "Jvm: $jvm on host: $host exited with result: $res with message: $mes\n"
                        }
                    }
                }               
            }
            set expected_count 0
            foreach expect_c $expected_jvms($host_tmp) {
                incr expected_count
            }
            if { $match_count == $expected_count } {
               ts_log_fine "output matched expected number of jvms: $match_count"
            } else {
               append error_text "startup hedeby host ${host} failed:\n"
               append error_text "\"$output\"\n"
               append error_text "The expected output doesn't match expected number of jvms: $match_count .\n"
               
            }        
         }
      }
   }

   if { $error_text != "" } {
      add_proc_error "startup_hedeby_hosts" -1 $error_text
      return 1
   }

   return 0
}


#****** util/remove_prefs_on_hedeby_host() *************************************
#  NAME
#     remove_prefs_on_hedeby_host() -- remove preference settings on hedeby host
#
#  SYNOPSIS
#     remove_prefs_on_hedeby_host { host {raise_error 1} } 
#
#  FUNCTION
#     This procedure is used to remove the testsuite preference settings on the
#     specified host.
#
#  INPUTS
#     host            - host where the testsuite preferences should be removed
#     {raise_error 1} - optional parameter to disable error reporting
#
#  RESULT
#     none
#
#  SEE ALSO
#     util/remove_hedeby_preferences()
#     util/remove_prefs_on_hedeby_host()
#*******************************************************************************
proc remove_prefs_on_hedeby_host { host {raise_error 1}} {

   set pref_type [get_hedeby_pref_type]
   set sys_name [get_hedeby_system_name]
   set remove_user [get_hedeby_startup_user]

   ts_log_fine "removing \"$pref_type\" preferences for hedeby system \"$sys_name\" on host \"$host\" ..."

   sdmadm_command $host $remove_user "-p $pref_type -s $sys_name rbc" prg_exit_state "" $raise_error
}


#****** util/reset_hedeby() ****************************************************
#  NAME
#     reset_hedeby() -- reset hedeby system configuration
#
#  SYNOPSIS
#     reset_hedeby { } 
#
#  FUNCTION
#     Used to reset the hedeby configuration without shutting down hededby
#     components.
#
#  INPUTS
#
#  RESULT
#     0 - on success
#     1 - on error
#
#  NOTES
#     This procedure is currently not implemented
#
#  SEE ALSO
#     util/startup_hedeby()
#     util/shutdown_hedeby()
#     util/reset_hedeby()
#*******************************************************************************
global is_reset_hedeby_logged
set is_reset_hedeby_logged 0
proc reset_hedeby {} {
   global is_reset_hedeby_logged
   if {$is_reset_hedeby_logged == 0} {
      ts_log_config "reset_hedeby must be implemented in that way to recreate the default testsuite installation scenario"
      set is_reset_hedeby_logged 1
   }
   # TODO: reset all resources to install state = OK
   # TODO: all resources which are added by install test should be in the spare
   #       pool after reset_hedeby()
   return 0
}

#****** util/parse_table_output() **********************************************
#  NAME
#     parse_table_output() -- parse any sdmadm table output
#
#  SYNOPSIS
#     parse_table_output { output array_name delemitter } 
#
#  FUNCTION
#     This procedure can be used to parse any sdmadm table output which was
#     generated with column delemitter AND dupval option.
#     If table has AutoWordWrap enabled the first column of the table MUST
#     always have a value.
#     
#
#  INPUTS
#     output     - output from sdmadm which contains table 
#     array_name - name of array to save parsing results
#     delemitter - table delemitter character (one character)
#
#  RESULT
#     no return value
#     array has following data structure:
#                  
#          array(table_lines)      - nr of lines in table
#          array(table_columns)    - list with names of columns
#          array(COLUMN_NAME,LINE) - value of table position
#          array(additional,LINE)  - list with additional lines for  this
#                                    table row (e.g. resource properties)
#
#          where COLUMN_NAME is column id
#                LINE        is row id
#
#  EXAMPLE
#     set execute_host $hedeby_config(hedeby_master_host)
#        set execute_user [get_hedeby_admin_user]
#        set output [sdmadm_command $execute_host $execute_user \
#                    "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sr -all" \
#                     prg_exit_state ""  1 table]
#        for {set line 0} {$line < $table(table_lines)} {incr line 1} {
#           puts "-------"
#           foreach col $table(table_columns) {
#              puts "line $line => $col: \"$table($col,$line)\""
#           }
#           if { [llength $table(additional,$line)] > 0 } { 
#              puts "   additional info:"
#              foreach elem $table(additional,$line) {
#                 puts "   $elem"
#              }
#           }
#        }
#
#  SEE ALSO
#     util/sdmadm_command()
#     util/parse_table_output()
#     util/get_resource_info()
#*******************************************************************************
proc parse_table_output { output array_name delemitter } {
   upvar $array_name data

   ts_log_fine "parsing table output ..."
   set columns {}
   set lines [split $output "\n\r"]
   set header_line ""
   set act_table_line -1
   for {set i 0} {$i<[llength $lines]} {incr i 1} {
      set line [lindex $lines $i]
      ts_log_finest "$line"
      
      if { $header_line == "" } {
         # still searching for header containing delemiter
         if { [string first $delemitter $line] >= 0 } {
            set header_line $line
            # now find out column index
            set column_nr 0
            set column_start($column_nr) 0
            set column_end($column_nr) 0
            ts_log_finer "header line: \"$header_line\""
            set last_pos 0
            while {1} {
               set pos [string first $delemitter $header_line $last_pos]
               if { $pos < 0 } {
                  break
               }
               set column_end($column_nr) [ expr ( $pos - 1 ) ]
               incr column_nr 1
               set last_pos [ expr ( $pos + 1) ]
               set column_start($column_nr) $last_pos
            }
            set column_end($column_nr) "end"

            ts_log_finest "found [expr ($column_nr + 1)] columns:"
            set table_col_list {}
            for {set b 0} {$b<=$column_nr} {incr b 1} {
               ts_log_finest "c$b s$column_start($b) e$column_end($b)"
               set value [string trim [string range $line $column_start($b) $column_end($b)]]
               set column_names($b) $value
               lappend table_col_list $value
               ts_log_finest "found column \"$column_names($b)\""
            }
            set data(table_columns) $table_col_list

         }
      } else {
         # here we have found an header
         
         # find out delemitter count of current line
         set is_table_line 0
         set nr_delemitters 0
         for {set b 0} {$b<[string length $line]} {incr b 1} {
            if {[string index $line $b] == $delemitter} {
               incr nr_delemitters 1
            }
         }
         if {$nr_delemitters == $column_nr} {
            set is_table_line 1
         }
 
         if { $is_table_line } {
            ts_log_finest "parsing table line \"[expr ($act_table_line + 1)]\""
            set is_word_wrap 0
            for {set b 0} {$b<=$column_nr} {incr b 1} {
               set value [string trim [string range $line $column_start($b) $column_end($b)]]

               if { $value == "" && $b == 0} {
                  # we say word wrap is active if first column has empty value (dupval is enabled)
                  set is_word_wrap 1
                  break
               }
               if { $b == 0 } {
                  incr act_table_line 1
               }

               # we want to have tcl lists here, so we init data with empty list value
               set data($column_names($b),$act_table_line) {}
               lappend data($column_names($b),$act_table_line) $value
            }
            if { $is_word_wrap == 0 } { 
               set data(additional,$act_table_line) {}
            } else {
               # append word wrap content to table values
               for {set b 0} {$b<=$column_nr} {incr b 1} {
                  set value [string trim [string range $line $column_start($b) $column_end($b)]]
                  if { $value != ""} {
                     lappend data($column_names($b),$act_table_line) $value
#                     set old_value $data($column_names($b),$act_table_line)
#                     set new_value "$old_value $value"
#                     set data($column_names($b),$act_table_line) $new_value
                  }
               }
            }
         } else {
            if {$act_table_line >= 0} {
               set help [string trim $line]
               if {$help != ""} {
                  ts_log_finer "parsing additional info for line $act_table_line: \"$help\""
                  lappend data(additional,$act_table_line) $help
               }
            }
         }
      }
   }
   if { $act_table_line > 0 } {
      set data(table_lines) [ expr ( $act_table_line + 1 ) ]
   } else {
      set data(table_lines) 0
   }
}


#****** util/get_resource_info() ***********************************************
#  NAME
#     get_resource_info() -- get resource information (via sdmadm sr)
#
#  SYNOPSIS
#     get_resource_info { {host ""} {user ""} {ri res_info} {rp res_prop} 
#     {rl res_list} {da res_list_not_uniq} } 
#
#  FUNCTION
#     This procedure starts an sdmadm sr command and parses the output.
#
#  INPUTS
#     {host ""}              - host where to start command
#                                 (default: hedeby master host)
#     {user ""}              - user who starts command
#                                 (default: hedeby admin user)
#     {ri res_info}          - name of array for resource informations
#                                 (default: res_info)
#     {rp res_prop}          - name of array for resource properties
#                                 (default: res_prop) 
#     {rl res_list}          - name of array list with TS resource names 
#                                 (default: res_list)
#     {da res_list_not_uniq} - name of array list with not unique resoures
#                                 (default: res_list_not_uniq)
#
#  RESULT
#     Return value: "0" on success, "1" on error 
#
#     Arrays:
#             res_list          - tcl list with testsuite resource names
#             res_list_not_uniq - tcl list with testsuite resource names
#                                 which are ambiguous (double or more
#                                 times assignment to a service)
#
#             res_info(TS_NAME,INFO_TYPE) - resource info value
#
#             res_prop(TS_NAME,PROPERTY)  - resource property value  
#
#                where TS_NAME is testsuite resource name
#                where INFO_TYPE is "id", "service", "state", "type",
#                                   "annotation", "flags" or "usage"
#                where PROPERTY is hedeby resource property
#                                   e.g. "resourceHostname"
#
#  EXAMPLE
#     if {[get_resource_info] == 0} {
#        ts_log_fine "ambiguous resources: $res_list_not_uniq"
#        ts_log_fine "resources: $res_list"
#        foreach res $res_list {
#           ts_log_fine "resource \"$res\" (id=\"$res_info($res,id)\") is assinged to \"$res_info($res,service)\""
#           ts_log_fine "  resourceHostname=$res_prop($res,resourceHostname)"
#        }
#     }
#
#  SEE ALSO
#     util/sdmadm_command()
#     util/parse_table_output()
#     util/get_resource_info()
#     util/wait_for_resource_info()
#     util/get_service_info()
#*******************************************************************************
proc get_resource_info { {host ""} {user ""} {ri res_info} {rp res_prop} {rl res_list} {da res_list_not_uniq}} {
   global hedeby_config

   # setup arguments
   upvar $ri resource_info
   upvar $rp resource_properties
   upvar $da resource_ambiguous
   upvar $rl resource_list
   if {$host == ""} {
      set execute_host $hedeby_config(hedeby_master_host)
   } else {
      set execute_host $host
   }
   if {$user == ""} {
      set execute_user [get_hedeby_admin_user]
   } else {
      set execute_user $user
   }

   # first we delete possible existing info arrays
   if { [info exists resource_info] } {
      unset resource_info
   }
   if { [info exists resource_properties] } {
      unset resource_properties
   }
   if { [info exists resource_ambiguous] } {
      unset resource_ambiguous
   }

   # now we start sdmadm sr command ...
   set sdmadm_command "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sr -all"
   set output [sdmadm_command $execute_host $execute_user $sdmadm_command prg_exit_state "" 1 table]
   if { $prg_exit_state != 0 } {
      ts_log_severe "exit state of sdmadm $sdmadm_command was $prg_exit_state - aborting"
      return 1
   }

   # we expect the following table commands for ShowResourceStateCliCommand ...
   set exp_columns {}
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.id"]
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.service"]
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.state"]
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.type"]
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.anno"]
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.flags"]
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.usage"]
   set used_col_names "id service state type annotation flags usage"

   set res_ignore_list {}
   lappend res_ignore_list [create_bundle_string "ShowResourceStateCliCommand.error"]
   foreach col $exp_columns {
      set pos [lsearch -exact $table(table_columns) $col]
      if {$pos < 0} {
         ts_log_severe "cannot find expected column name \"$col\""
         return 1
      }
      ts_log_finer "found expected col \"$col\" on position $pos"
      if {[lsearch -exact $used_col_names $col] < 0} {
         ts_log_severe "used column name \"$col\" not expected - please check table column names!"
         return 1
      }
   }
   
   set res_id_col [lindex $exp_columns 0]
   set res_service_col [lindex $exp_columns 1]

   # now we fill up the arrays ... 
   set resource_list {}
   set double_assigned_resource_list {}
   for {set line 0} {$line < $table(table_lines)} {incr line 1} {
      set resource_id $table($res_id_col,$line)
      set do_ignore 0
      foreach ignore_resource $res_ignore_list {
         if { [string match $ignore_resource $resource_id] } {
            set do_ignore 1
            break
         }
      }
      if {!$do_ignore} {
         # if resources are e.g. in state UNASSIGNING at resource
         # provider the resources have the @SERVICE appended
         # => Testsuite is ignoring appendix of hostname
         set help [split $resource_id "@"]
         set ts_resource_name [resolve_host [lindex $help 0]]
         if {$ts_resource_name != $resource_id} {
            ts_log_finer "using resource name \"$ts_resource_name\" for resource id \"$resource_id\""
         }
         if { [lsearch -exact $resource_list $ts_resource_name] < 0 } { 
            lappend resource_list "$ts_resource_name"
         } else {
            lappend double_assigned_resource_list $ts_resource_name
         }
         foreach col $table(table_columns) {
            if {![info exists resource_info($ts_resource_name,$col)]} {
               set resource_info($ts_resource_name,$col) {}
            }
            lappend resource_info($ts_resource_name,$col) [lindex $table($col,$line) 0]
            ts_log_finer "resource_info($ts_resource_name,$col) = $resource_info($ts_resource_name,$col)"
         }
         if {[llength $table(additional,$line)] > 0} {
            foreach elem $table(additional,$line) {
               set pos [string first "=" $elem]
               if {$pos > 0} {
                  set property [string range $elem 0 [expr ( $pos - 1 )]]
                  set value [string range $elem [expr ( $pos + 1)] end]
                  set property [string trim $property]
                  set value [string trim $value]
                  
                  if {![info exists resource_properties($ts_resource_name,prop_list)]} {
                     set resource_properties($ts_resource_name,prop_list) {}
                  }
                  lappend resource_properties($ts_resource_name,prop_list) $property

                  if {![info exists resource_properties($ts_resource_name,$property)]} {
                     set resource_properties($ts_resource_name,$property) {}
                  }
                  lappend resource_properties($ts_resource_name,$property) $value
                  ts_log_finer "resource_properties($ts_resource_name,$property) = $resource_properties($ts_resource_name,$property)"
               }
            }
         } else {
            ts_log_warning "resource \"$ts_resource_name\" seems not to have any resource properties"
         }
      } else {
         ts_log_fine "SKIPPING RESOURCE \"$resource_id\"!"
      }
   }

   if {[llength $double_assigned_resource_list] > 0} {
      set error_text ""
      foreach resource $double_assigned_resource_list {
         append error_text "\nINFO: Resource \"$resource\" is assigned to [llength $resource_info($resource,$res_service_col)] services\n"
         append error_text "   resource_info:\n"
         append error_text "   ==============\n"
         foreach col $exp_columns {
            append error_text "      $col: $resource_info($resource,$col)\n"
         }
         append error_text "      properties\n"
         append error_text "      ==========\n"
         foreach property $resource_properties($resource,prop_list) {
            append error_text "         $property=$resource_properties($resource,$property)\n"
         }
      }
      ts_log_fine $error_text
   }

   ts_log_fine "double assigned resources: $double_assigned_resource_list"
   ts_log_fine "resource list: $resource_list"
   set resource_ambiguous $double_assigned_resource_list
   return 0
}

#****** util/wait_for_resource_info() ******************************************
#  NAME
#     wait_for_resource_info() -- wait for expected resource information
#
#  SYNOPSIS
#     wait_for_resource_info { exp_resinfo {atimeout 60} {report_error 1} 
#     {ev error_var } {host ""} {user ""} {ri res_info} {rp res_prop} 
#     {rl res_list} {da res_list_not_uniq} } 
#
#  FUNCTION
#     This procedure calls get_resource_info() until the specified
#     resource properties occur, a timeout or error occurs.
#
#  INPUTS
#     exp_resinfo            - expected resource info (same structure like
#                              get_resource_info() is returning).
#     {atimeout 60}          - optional timeout specification in seconds 
#     {report_error 1}       - report testsuite errors if != 0
#     {ev error_var }        - report error text into this tcl var
#     {host ""}              - see get_resource_info() 
#     {user ""}              - see get_resource_info() 
#     {ri res_info}          - see get_resource_info() 
#     {rp res_prop}          - see get_resource_info() 
#     {rl res_list}          - see get_resource_info() 
#     {da res_list_not_uniq} - see get_resource_info() 
#
#  RESULT
#     0 on success, 1 on error
#     setting of tcl arrays like known from get_resource_info()
#
#  EXAMPLE
#        foreach res $static_list {
#           set exp_resource_info($res,service) "$service_names(default_service,$res)" 
#           set exp_resource_info($res,flags) "S"
#           set exp_resource_info($res,state) "ASSIGNED"
#        }
#        # step 2: wait for expected resource informations
#        set retval [wait_for_resource_info exp_resource_info 60 0 mvr_error]
#     
#        # step 3: error handling
#        if { $retval != 0} {
#           # if there were no error till now, print output of previous actions
#           if {$error_text == ""} {
#              append error_text "Following action(s) was/were started:\n"
#              foreach res $mvr_list {
#                 append error_text $task_info($res,output)
#              }
#           }
#           # append missing resources info to error output
#           append error_text $mvr_error
#        }
#
#  SEE ALSO
#     util/get_resource_info()
#     util/wait_for_resource_info()
#*******************************************************************************
proc wait_for_resource_info { exp_resinfo  {atimeout 60} {report_error 1} {ev error_var } \
     {host ""} {user ""} {ri res_info} {rp res_prop} {rl res_list} {da res_list_not_uniq} } {
   global hedeby_config
   # setup arguments
   upvar $exp_resinfo exp_res_info
   upvar $ev error_text
   upvar $ri resource_info
   upvar $rp resource_properties
   upvar $da resource_ambiguous
   upvar $rl resource_list
   if {$host == ""} {
      set execute_host $hedeby_config(hedeby_master_host)
   } else {
      set execute_host $host
   }
   if {$user == ""} {
      set execute_user [get_hedeby_admin_user]
   } else {
      set execute_user $user
   }

   # init error and timeout
   set error_text ""
   set my_timeout [timestamp]
   incr my_timeout $atimeout

   # set expected results info
   set expected_resource_info ""
   set exp_values [array names exp_res_info]
   foreach val $exp_values {
      append expected_resource_info "$val=\"$exp_res_info($val)\"\n"
   }
   ts_log_fine "expected resource infos:\n$expected_resource_info"

   while {1} {
      set retval [get_resource_info $host $user resource_info resource_properties resource_list resource_ambiguous]
      if {$retval != 0} {
         append error_text "break because of get_resource_info() returned \"$retval\"!\n"
         append error_text "expected resource info was:\n$expected_resource_info"
         break
      }

      set not_matching ""
      foreach val $exp_values {
         if {[info exists resource_info($val)]} {
            if {$resource_info($val) == $exp_res_info($val)} {
               ts_log_finer "resource info \"$val\" matches expected info \"$exp_res_info($val)\""
            } else {
               append not_matching "resource info \"$val\" is set to \"$resource_info($val)\", should be \"$exp_res_info($val)\"\n"
            }
         } else {
            append not_matching "resource info \"$val\" not available\n"
         }
      }

      if {$not_matching == ""} {
         ts_log_fine "all specified resouce info are matching"
         break
      } else {
         ts_log_fine "not matching resource info:\n$not_matching"
      }

      if {[timestamp] >= $my_timeout} {
         append error_text "==> TIMEOUT(=$atimeout sec) while waiting for expected resource states!\n"
         append error_text "==> NOT matching values:\n$not_matching"
         break
      }
      after 1000
   }

   if {$error_text != "" } {
      if {$report_error != 0} {
         ts_log_severe $error_text
      }
      return 1
   }
   return 0
}


#****** util/get_service_info() ************************************************
#  NAME
#     get_service_info() -- get service information (via sdmadm ss)
#
#  SYNOPSIS
#     get_service_info { {host ""} {user ""} {si service_info} } 
#
#  FUNCTION
#     This procedure starts an sdmadm ss command and parses the output.
#
#  INPUTS
#     {host ""}              - host where to start command
#                                 (default: hedeby master host)
#     {user ""}              - user who starts command
#                                 (default: hedeby admin user)
#     {si service_info}      - name of array for service informations
#                                 (default: service_info) 
#
#  RESULT
#     Return value: "0" on success, "1" on error 
#
#     Arrays:
#             service_info(SERVICE_NAME,host)   - service host
#             service_info(SERVICE_NAME,cstate) - service component state
#             service_info(SERVICE_NAME,sstate) - service state
#             service_info(SERVICE_NAME,service_list) - list of all services
#
#  EXAMPLE
#     get_resource_info sinfo
#     foreach service $sinfo(service_list) {
#        ts_log_fine "service \"$service\": host=\"$sinfo($service,host)\""
#     }
#
#  SEE ALSO
#     util/sdmadm_command()
#     util/parse_table_output()
#     util/get_resource_info()
#     util/get_service_info()
#*******************************************************************************
proc get_service_info { {host ""} {user ""} {si service_info} } {
   global hedeby_config

   # setup arguments
   upvar $si sinfo

   if {$host == ""} {
      set execute_host $hedeby_config(hedeby_master_host)
   } else {
      set execute_host $host
   }
   if {$user == ""} {
      set execute_user [get_hedeby_admin_user]
   } else {
      set execute_user $user
   }

   # first we delete possible existing info arrays
   if { [info exists sinfo] } {
      unset sinfo
   }

   # now we start sdmadm sr command ...
   set sdmadm_command "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] ss"
   set output [sdmadm_command $execute_host $execute_user $sdmadm_command prg_exit_state "" 1 table]
   if { $prg_exit_state != 0 } {
      ts_log_severe "exit state of sdmadm $sdmadm_command was $prg_exit_state - aborting"
      return 1
   }

   # we expect the following table commands for ShowResourceStateCliCommand ...
   set exp_columns {}
   lappend exp_columns [create_bundle_string "ShowServicesCliCommand.col.host"]
   lappend exp_columns [create_bundle_string "ShowServicesCliCommand.col.name"]
   lappend exp_columns [create_bundle_string "ShowServicesCliCommand.col.cstate"]
   lappend exp_columns [create_bundle_string "ShowServicesCliCommand.col.sstate"]
   set used_col_names "host service cstate sstate"

   lappend res_ignore_list [create_bundle_string "ShowResourceStateCliCommand.error"]
   foreach col $exp_columns {
      set pos [lsearch -exact $table(table_columns) $col]
      if {$pos < 0} {
         ts_log_severe "cannot find expected column name \"$col\""
         return 1
      }
      ts_log_fine "found expected col \"$col\" on position $pos"
      if {[lsearch -exact $used_col_names $col] < 0} {
         ts_log_severe "used column name \"$col\" not expected - please check table column names!"
         return 1
      }
   }
   
   set service_col [lindex $exp_columns 1]
   set cstate_col  [lindex $exp_columns 2]
   set sstate_col  [lindex $exp_columns 3]
   set host_col    [lindex $exp_columns 0]

   # now we fill up the arrays ... 
   set sinfo(service_list) {}
   for {set line 0} {$line < $table(table_lines)} {incr line 1} {
      set service_id $table($service_col,$line)
      set sinfo($service_id,host)   $table($host_col,$line)
      set sinfo($service_id,cstate) $table($cstate_col,$line)
      set sinfo($service_id,sstate) $table($sstate_col,$line)
      lappend sinfo(service_list) $service_id
   }

   ts_log_fine "service list: $sinfo(service_list)"
   foreach service $sinfo(service_list) {
      ts_log_fine "service \"$service\": host=\"$sinfo($service,host)\" cstate=\"$sinfo($service,cstate)\" sstate=\"$sinfo($service,sstate)\""
   }
   return 0
}

#****** util/sdmadm_command() **************************************************
#  NAME
#     sdmadm_command() -- start sdmadm command
#
#  SYNOPSIS
#     sdmadm_command { host user arg_line {exit_var prg_exit_state} } 
#
#  FUNCTION
#     This procedure is used to start a "raw" sdmadm command on the specified
#     host under the specified user account. The complete argument line has
#     to be specified. The sdmadm command is started with JAVA_HOME settings
#     from testsuite host configuration.
#
#  INPUTS
#     host                      - host where sdmadm should be started
#     user                      - user account used for starting sdmadm
#     arg_line                  - complete argument list
#     {exit_var prg_exit_state} - default parameter specifying the variable where
#                                 to save the exit state
#     { interactive_tasks "" }  - optional interactive tasks for parsing
#                                 output and send via stdin
#                                 if this array contains entries the sdmadm
#                                 command is started interactive.
#     {raise_error 1}           - optional if set to 1 errors are reported
#     {table_output ""}         - table output parsed with parse_table_output()
#
#  RESULT
#     The output of the sdmadm command
#
#  SEE ALSO
#     util/sdmadm_command()
#*******************************************************************************
proc sdmadm_command { host user arg_line {exit_var prg_exit_state} { interactive_tasks "" } {raise_error 1} {table_output ""} } {
   upvar $exit_var back_exit_state
   global hedeby_config

   if { $interactive_tasks != "" } {
      upvar $interactive_tasks tasks
   }
   if { $table_output != "" } {
      upvar $table_output table
      append arg_line " -coldel \"|\" -dupval"
   }

   # this is only for getting debug output
#   set arg_line "-d $arg_line"

   set sdmadm_path [get_hedeby_binary_path "sdmadm" $user]
   set my_env(JAVA_HOME) [get_java_home_for_host $host $hedeby_config(hedeby_java_version)]
   set my_env(EDITOR) [get_binary_path $host "vim"]

   if { $interactive_tasks == "" } {
      ts_log_fine "${host}($user): starting binary not interactive \"sdmadm $arg_line\" ..."
      set output [start_remote_prog $host $user $sdmadm_path $arg_line back_exit_state 60 0 "" my_env 1 0 0 $raise_error]
      if { $back_exit_state != 0 } {
         ts_log_severe "${host}(${user}): sdmadm $arg_line failed:\n$output" $raise_error
      }
      ts_log_finest $output
      parse_table_output $output table "|"
      return $output
   } else {
      set back_exit_state -1
      ts_log_fine "${host}($user): starting binary INTERACTIVE \"sdmadm $arg_line\" ..."
      set pr_id [open_remote_spawn_process $host $user $sdmadm_path $arg_line 0 "" my_env 0]
      if { [info exists tasks(RETURN_ISPID)] } {
         ts_log_fine "returning internal spawn id \"$pr_id\" to caller!"
         return $pr_id
      }

      set sp_id [lindex $pr_id 1]
      set timeout 60
      set error_text ""
      set output ""
      set found_start 0
      set found_end 0
      set do_stop 0
      expect {
        -i $sp_id timeout {
            append error_text "got timeout error\n"
        }
        -i $sp_id full_buffer {
            append error_text "got full_buffer error\n"
        }
   
        -i $sp_id -- "*\[ \n\]" {
           set token $expect_out(0,string)
           if { [string match "*_exit_status_:(*" $token ] } {
              debug_puts "script terminated!" 
              set help $token
              set st [string first "(" $help]
              set ed [string first ")" $help]
              incr st 1
              incr ed -1
              set back_exit_state [string range $help $st $ed]
              ts_log_fine "found exit status of client: ($back_exit_state)"
              set do_stop 1
              set found_end 1
           }
           if {  $found_start == 1 && $found_end == 0 } {
              append output "${token}"
              set was_expected 0
              foreach name [array names tasks] {
                if { [string match "*${name}*" $token] } {
                    set was_expected 1
                    if { $tasks($name) != "ROOTPW" } {
                       ts_log_fine ".....found \"$name\", sending \"$tasks($name)\" ..."
                       ts_send $sp_id "$tasks($name)\n"
                    } else {
                       log_user 0  ;# in any case before sending password
                       ts_send $sp_id "[get_root_passwd]\n" "" 1
                       log_user 1
                       ts_log_fine ".....found \"$name\", sent \"$tasks($name)\" without prompt ..."
                    }
                 }
              }
           }
           if {[string first "_start_mark_:" $token] >= 0} {
              set found_start 1
           }
           if { $do_stop == 0 } {
              exp_continue
           }
        }
      }
      close_spawn_process $pr_id
      if { $error_text != "" } {
         ts_log_severe "interacitve errors:\n$error_text\noutput:\n$output\nexit state: $back_exit_state" $raise_error
      }
      if { $back_exit_state != 0 } {
         ts_log_severe "${host}(${user}): sdmadm $arg_line failed:\n$output" $raise_error
      }
      parse_table_output $output table "|"
      return $output
   }
}

#****** util/get_jvm_from_run_list() *************************************
#  NAME
#     get_jvm_from_run_list() -- help proc for shutdown_hedeby_hosts()
#
#  SYNOPSIS
#     get_jvm_from_run_list { pid run_list } 
#
#  FUNCTION
#     Used by check_hedeby_process_shutdown() and cleanup_hedeby_processes()
#     to find out component information for hedeby pid process.
#
#  INPUTS
#     pid      - pid reference in run_list
#     run_list - internal data structure containing additional information
#
#  RESULT
#     jvm name of the pid
#
#  SEE ALSO
#     util/shutdown_hedeby_hosts()
#*******************************************************************************
proc get_jvm_from_run_list { pid run_list } {
   set component ""


   foreach el $run_list {
      set elem [split $el ":"]
      set epid  [lindex $elem 0]
      set ejvm  [lindex $elem 1]
      set eport [lindex $elem 2]
      if { $pid == $epid } {
         return $ejvm
      }
   }
   ts_log_fine "cannot find pid $pid in runlist: $run_list"
   return $component
}

#****** util/get_jvm_pidlist() *******************************************
#  NAME
#     get_jvm_pidlist() -- help proc for shutdown_hedeby_hosts()
#
#  SYNOPSIS
#     get_jvm_pidlist { host user run_dir pidlist pidlistinfo 
#     {raise_error 1} } 
#
#  FUNCTION
#     This procedure fills the specified lists with hedeby component data.
#     The procedure will connect the specified host and fill pidlist and
#     pidlistinfo with hedeby process information data.
#
#  INPUTS
#     host            - hedeby host to analyze
#     user            - user which will analyze
#     run_dir         - run directory on host
#     pidlist         - list where the pids are stored
#     pidlistinfo     - list where additional info for pids is stored
#     {raise_error 1} - optional: if 1 report testsuite errors
#
#  RESULT
#     0 on success, not 0 on error
#
#  SEE ALSO
#     util/shutdown_hedeby_hosts()
#*******************************************************************************
proc get_jvm_pidlist { host user run_dir pidlist pidlistinfo {raise_error 1}} {
   upvar $pidlist pid_list
   upvar $pidlistinfo run_list
   set pid_list {}
   set ret_val 0

   ts_log_fine "check if host \"$host\" has running hedeby jvms ..."
   if { [remote_file_isdirectory $host $run_dir] } {
      set running_jvm_names [start_remote_prog $host $user "ls" "$run_dir"]
      if { [llength $running_jvm_names] == 0 } {
         ts_log_fine "no hedeby jvm running on host $host!"
         return $ret_val
      }
      foreach jvm_name $running_jvm_names {
         if {[read_hedeby_jvm_pid_file pid_info $host $user $run_dir/$jvm_name] != 0} {
            ts_log_fine "cannot get pid info for host $host!"
            set ret_val 1
            return $ret_val
         }
         set pid $pid_info(pid)
         set port $pid_info(port)
         
         lappend pid_list $pid
         lappend run_list "$pid:$jvm_name:$port"
         ts_log_fine "run_list = $run_list"
         ts_log_fine "jvm $jvm_name has pid \"$pid\""
         ts_log_fine "jvm $jvm_name has port \"$port\""
      }
   } else {
      ts_log_fine "no hedeby run directory found on host $host!"
      ts_log_fine "run directory was \"$run_dir\""
   }
   return $ret_val
}


#****** util/cleanup_hedeby_processes() ****************************************
#  NAME
#     cleanup_hedeby_processes() -- help proc for shutdown_hedeby_hosts()
#
#  SYNOPSIS
#     cleanup_hedeby_processes { host user run_dir pid_list run_list 
#     {raise_error 1} } 
#
#  FUNCTION
#     Kill not shutdown hedeby processes and cleanup run files. This procedure
#     is a helper function for shutdown_hedeby_hosts().
#
#  INPUTS
#     host            - host where hedeby processes are running
#     user            - user which is doing remote commands
#     run_dir         - run directory on remote host
#     pid_list        - pid list on remote host
#     run_list        - additional info for running commands
#     {raise_error 1} - optinal: if set report errors
#
#  RESULT
#     0 on success, not 0 on error
#
#  SEE ALSO
#     util/shutdown_hedeby_hosts()
#*******************************************************************************
proc cleanup_hedeby_processes { host user run_dir pid_list run_list {raise_error 1} } {
   set ret_val 0

   ts_log_fine "cleaning up incorrect hedeby shutdown on host $host ..."
   foreach pid $pid_list {
      set jvm_name [get_jvm_from_run_list $pid $run_list]
      ts_log_fine "jvm=$jvm_name"
      set is_pid_running [is_hedeby_process_running $host $pid]
      if { $is_pid_running } {
         ts_log_fine "killing hedeby process ..."
         kill_hedeby_process $host $user $jvm_name $pid
      } else {
         # there was an old pid file without running jvm -> delete the pid file
         ts_log_fine "delete pid file ..."
         if {$jvm_name != ""} {
            set del_pid_file "$run_dir/$jvm_name"
            ts_log_fine "delete pid file \"$del_pid_file\"\nfor jvm \"$jvm_name\" on host \"$host\" as user \"$user\" ..."
            delete_remote_file $host $user $del_pid_file
         }
      }
   }
   return $ret_val
}

#****** util/check_hedeby_process_shutdown() ***********************************
#  NAME
#     check_hedeby_process_shutdown() -- help proc for shutdown_hedeby_hosts
#
#  SYNOPSIS
#     check_hedeby_process_shutdown { host user run_dir pid_list run_list 
#     {raise_error 1} {atimeout 60} } 
#
#  FUNCTION
#     Check for correct shutdown of hedeby processes. This procedure
#     is a helper function for shutdown_hedeby_hosts().
#
#  INPUTS
#     host            - host where hedeby processes are running
#     user            - user which is doing remote commands
#     run_dir         - run directory on remote host
#     pid_list        - pid list on remote host
#     run_list        - additional info for running commands
#     {raise_error 1} - optinal: if set report errors
#     {atimeout 60}   - timeout when waiting for process shutdown
#
#  RESULT
#     0 on success, not 0 on error
#
#  SEE ALSO
#     util/shutdown_hedeby_hosts()
#*******************************************************************************
proc check_hedeby_process_shutdown { host user run_dir pid_list run_list {raise_error 1} {atimeout 60} } {
   set ret_val 0
   set error_text ""

   ts_log_fine "checking correct hedeby shutdown on host $host ..."
   set my_timeout [timestamp]
   incr my_timeout $atimeout

   # first setup a second pid list with pids to check
   set pids_to_check $pid_list

   # now check the pids
   while { [timestamp] < $my_timeout } {
      set not_removed_pids {}

      foreach pid $pids_to_check {
         set is_pid_running [is_hedeby_process_running $host $pid]
         if { $is_pid_running } {
            lappend not_removed_pids $pid
         }
      }

      # store not removed pids
      set pids_to_check $not_removed_pids

      # all pids gone - break
      if { [llength $pids_to_check] == 0 } {
         break
      }
      ts_log_fine "waiting for disappearance of pid(s): $pids_to_check"
      after 1000
   }

   foreach pid $pids_to_check {
      set ret_val 1
      set jvm_name [get_jvm_from_run_list $pid $run_list]
      append error_text "error shutting down jvm \"$jvm_name\" on host \"$host\" as user \"$user\".\n"
      append error_text "(process with pid \"$pid\" is still running - killing it ...)\n\n"
      kill_hedeby_process $host $user $jvm_name $pid
   }

   foreach pid $pid_list {
      set jvm_name [get_jvm_from_run_list $pid $run_list]
      set pid_file "$run_dir/$jvm_name"
      if { [is_remote_file $host $user $pid_file] } {
         set ret_val 1
         append error_text "error shutdown jvm \"$jvm_name\" on host \"$host\" as user \"$user\".\n"
         append error_text "(pid file \"$pid_file\" wasn't removed)\n\n"
      }
   }

   if { $error_text != "" } {
      add_proc_error "check_process_termination" -1 $error_text
   }
   return $ret_val
}





#****** util/remove_user_from_admin_list() *************************************
#  NAME
#     remove_user_from_admin_list() -- remove user from hedeby admin list
#
#  SYNOPSIS
#     remove_user_from_admin_list { execute_host execute_user user_name 
#     {raise_error 1} } 
#
#  FUNCTION
#     remove a user from the hedeby adminstirator user list
#
#  INPUTS
#     execute_host    - host where sdmadm is started
#     execute_user    - user who starts sdmadm
#     user_name       - user to remove
#     {raise_error 1} - optional: report errors if != 0
#
#  RESULT
#     0 on success, 1 on error
#*******************************************************************************
proc remove_user_from_admin_list { execute_host execute_user user_name {raise_error 1} } {
   set retval 0
   
   set output [sdmadm_command $execute_host $execute_user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] rau $user_name" prg_exit_state "" $raise_error]
   set exit_state $prg_exit_state

   set params(0) $user_name
   set user_removed_string [create_bundle_string "adminUser.removed" params]
   set output [string trim $output]
   if { [string match $user_removed_string $output] == 0 } {
      add_proc_error "remove_user_from_admin_list" -1 "user \"$user_name\" has not been removed from admin user list:\n$output" $raise_error
      set retval 1
   }
   if { $exit_state != $retval } {
      add_proc_error "remove_user_from_admin_list" -1 "shell exit value doesn't match to output of sdmadm_command" $raise_error
      set retval 1
   }
   return $retval;
}


#****** util/add_user_to_admin_list() ******************************************
#  NAME
#     add_user_to_admin_list() -- add user to administrator list
#
#  SYNOPSIS
#     add_user_to_admin_list { execute_host execute_user user_name 
#     {raise_error 1} } 
#
#  FUNCTION
#     adds a user to hedeby admin list
#
#  INPUTS
#     execute_host    - host where sdmadm is started
#     execute_user    - user who starts sdmadm
#     user_name       - user to add
#     {raise_error 1} - optional: report errors if != 0
#
#  RESULT
#     0 on success, 1 on error
#*******************************************************************************
proc add_user_to_admin_list { execute_host execute_user user_name {raise_error 1} } {
   set retval 0
   
   set output [sdmadm_command $execute_host $execute_user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] aau $user_name" prg_exit_state "" $raise_error ]
   set exit_state $prg_exit_state

   set params(0) $user_name
   set user_added_string [create_bundle_string "adminUser.added" params]
   set output [string trim $output]
   if { [string match $user_added_string $output] == 0 } {
      add_proc_error "add_user_to_admin_list" -1 "user \"$user_name\" has not been added to admin user list:\n$output" $raise_error
      set retval 1
   }
   if { $exit_state != $retval } {
      add_proc_error "add_user_to_admin_list" -1 "shell exit value doesn't match to output of sdmadm_command" $raise_error
      set retval 1
   }
   return $retval;
}


#****** util/get_admin_user_list() *********************************************
#  NAME
#     get_admin_user_list() -- get administrator user list
#
#  SYNOPSIS
#     get_admin_user_list { execute_host execute_user result_list 
#     {raise_error 1} } 
#
#  FUNCTION
#     return a list with user names which are in the administrator list
#
#  INPUTS
#     execute_host    - host where sdmadm is started
#     execute_user    - user who starts sdmadm
#     result_list     - list for storing user names
#     {raise_error 1} - optional: report errors if != 0
#
#  RESULT
#     0 on success, 1 on error
#*******************************************************************************
proc get_admin_user_list { execute_host execute_user result_list {raise_error 1} } {
   upvar $result_list user_list
   set retval 0
   
   set output [sdmadm_command $execute_host $execute_user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sau" prg_exit_state "" $raise_error ]
   set retval $prg_exit_state
   # parse output
   set user_list {}
   set lines [split $output "\n"]
   foreach ls $lines {
      set line [string trim $ls]
      lappend user_list $line
   }
   return $retval;
}


#****** util/parse_jvm_start_stop_output() *********************************
#  NAME
#     parse_jvm_start_stop_output() -- parse sdmadm show_status output
#
#  SYNOPSIS
#     parse_jvm_start_stop_output { output_var {status_array "ss_out" } } 
#
#  FUNCTION
#     This procedure is used to parse the output of the sdmadm suj/sdj
#     command and return the parsed values in the specified result array.
#
#  INPUTS
#     output_var               - output of the sdmadm suj/sdj cli command
#     {status_array "ss_out" } - name of the array were the parsed information
#                                should be stored. 
#                                The array (default="ss_out") has the following
#                                settings:
#                                ss_out(JVMNAME,HOSTNAME,result,message)
#
#  RESULT
#     number of parsed rows or -1 if the output could not be parsed
#
#  EXAMPLE
#     
#   set jvm_count [parse_jvm_start_stop_output output]
#   
#   for {set i 0} {$i < $component_count} {incr i} {
#      set host   $ss_out($i,host)
#      set jvm    $ss_out($i,jvm)
#      set res   $ss_out($i,result)
#      set mes  $ss_out($i,message)
#   }
#
#  SEE ALSO
#     util/sdmadm_command()
#*******************************************************************************
proc parse_jvm_start_stop_output { output_var {status_array "ss_out" } } {
   global CHECK_OUTPUT
   upvar $output_var out
   upvar $status_array ss

   set help [split $out "\n"]
   set line_count -1
   set col_count 0
   array set last_values {}
   
   set known_colums(host)  [create_bundle_string "StartJVMCliCommand.col.host"]
   set known_colums(jvm)  [create_bundle_string "StartJVMCliCommand.col.jvm"]
   set known_colums(result)  [create_bundle_string "StartJVMCliCommand.col.result"]
   set known_colums(message)  [create_bundle_string "StartJVMCliCommand.col.message"]

   
   foreach line $help {
      debug_puts "Process line $line_count: \"$line\""
      if { [string first "Error:" $line] >= 0 } {
         return -1
      } elseif {$line_count < 0} {
         
         set line [string trim $line]
         foreach col_name [split $line " "] {
            if {[string length $col_name] > 0} {
               set real_col_name ""
               foreach known_col [array names known_colums] {
                  if { $known_colums($known_col) == $col_name } {
                     set real_col_name $known_col
                     break;
                  }
               }
               if {$real_col_name == ""} {
                  add_proc_error "parse_jvm_start_stop_output" -1 "Found unknown column $col_name in output of \"sdmadm suj or sdj\""
                  return -1
               }
               set col($col_count,name)  $real_col_name
               set col($col_count,start_index) [string first "$col_name" "$line"]
               incr col_count
            }
         }
         set last_col_index [expr $col_count - 1]
         for {set i 0} {$i < $last_col_index} {incr i} {
            set col($i,end_index) $col([expr $i + 1],start_index)
            incr col($i,end_index) -1
            debug_puts "col$i: $col($i,name) = $col($i,start_index) -> $col($i,end_index)"
         }
         # We do not known the index of the last col
         # -1 means that the last col cosumes the rest of the line
         set col($last_col_index,end_index) -1
         debug_puts "col$i: $col($last_col_index,name) = $col($last_col_index,start_index) -> $col($last_col_index,end_index)"
         set line_count 0
      } elseif { [string length $line] == 0 } {
         continue
      } elseif { [string first "-------" $line] >= 0 } {
         continue
      } else {
         for {set i 0} {$i < $col_count} {incr i} {
            set col_name $col($i,name)
            if { $col($i,end_index) < 0 } {
               set end_index [string length $line]
            } else {
               set end_index $col($i,end_index)
            }
            set tvalue [string range $line $col($i,start_index) $end_index]
            set tvalue [string trim $tvalue]
            
            set ss($line_count,$col_name) $tvalue
         }
         incr line_count
      }
   }
   return $line_count
}

#****** util/read_hedeby_jvm_pid_info() **************************************************
#  NAME
#    read_hedeby_jvm_pid_info() -- Read the pid file of a hedeby jvm
#
#  SYNOPSIS
#    read_hedeby_jvm_pid_info { a_pid_info host user jvm_name }
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#    a_pid_info -- The info from the pid file is stored in this array 
#    host       --  the host where the jvm is running
#    user       --  user who has access to the pid file
#    jvm_name   -- Name of the jvm
#
#  RESULT
#     0  if the pid info has been read
#
#  EXAMPLE
#     
#   set host $hedeby_config(hedeby_master_host)
#   set jvm_name "executor_vm"
#
#   if {[read_hedeby_jvm_pid_info pid_info $host $jvm_name] != 0} {
#      ts_log_fine "pid file for jvm $jvm_name at $host not found"
#   } else {
#      ts_log_fine "pid is $pid_info(pid)"
#      ts_log_fine "url is $pid_info(url)"
#   }
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     util/read_hedeby_jvm_pid_file
#*******************************************************************************
proc read_hedeby_jvm_pid_info { a_pid_info host user jvm_name } {
   global hedeby_config
   
   upvar pid_info $a_pid_info

   set pid_file [get_pid_file_for_jvm $host $jvm_name]
   
   return [read_hedeby_jvm_pid_file pid_info $host $user $pid_file]
}

#****** util/get_pid_file_for_jvm() **************************************************
#  NAME
#    get_pid_file_for_jvm() -- get the path to the pid file of a jvm
#
#  SYNOPSIS
#    get_pid_file_for_jvm { } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#    host     -- the host where the jvm is running
#    jvm_name -- the name of the jvm
#
#  RESULT
#    
#    path to the pid file
#
#  EXAMPLE

#     set pid_file [get_pid_file_for_jvm "foo.bar" "executor_vm"]
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc get_pid_file_for_jvm { host jvm_name } {
   set spool_dir [get_hedeby_local_spool_dir $host]
   return "${spool_dir}/run/${jvm_name}@${host}"
}

#****** util/read_hedeby_jvm_pid_file() **************************************************
#  NAME
#    read_hedeby_jvm_pid_file() -- Read the pid file of a hedeby jvm
#
#  SYNOPSIS
#    read_hedeby_jvm_pid_file { a_pid_info host user pid_file } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#    a_pid_info --  The info from the pid file is stored in this array
#    host       --  the host where the jvm is running
#    user       --  user who has access to the pid file
#    pid_file   --  path to the pid file
#
#  RESULT
#     0   if pid file has been read
#     else error
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
#*******************************************************************************
proc read_hedeby_jvm_pid_file { a_pid_info host user pid_file } {
   
   upvar pid_info $a_pid_info
   if { [info exists pid_info] } {
      unset pid_info
   }
   get_file_content $host $user $pid_file
   if { $file_array(0) == 2} {
       set pid_info(pid) [string trim $file_array(1)]
       set pid_info(port) [string trim $file_array(2)]
       return 0
   } else {
       add_proc_error "read_hedeby_jvm_pid_file" -1 "runfile $pid_file on host $host contains not the expected 2 lines"
       return 1
   }
}


#****** util/create_fixed_usage_slo() ******************************************
#  NAME
#     create_fixed_usage_slo() -- create fixed usage slo xml string
#
#  SYNOPSIS
#     create_fixed_usage_slo { {urgency 50 } { name "fixed_usage" } } 
#
#  FUNCTION
#     creates xml string with specified values
#
#  INPUTS
#     {urgency 50 }          - urgency value
#     { name "fixed_usage" } - name value
#
#  RESULT
#     xml string
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/set_hedeby_slos()
#*******************************************************************************
proc create_fixed_usage_slo {{urgency 50 } { name "fixed_usage" }} {
   set slo {}
   lappend slo "<common:slo xsi:type=\"common:FixedUsageSLOConfig\" urgency=\"$urgency\" name=\"$name\"/>"
   return $slo
}

#****** util/create_min_resource_slo() *****************************************
#  NAME
#     create_min_resource_slo() -- create min resource slo xml string
#
#
#  SYNOPSIS
#     create_min_resource_slo { {urgency 50 } { name "min_res" } { min 2 } } 
#
#  FUNCTION
#     creates xml string with specified values
#
#  INPUTS
#     {urgency 50 }      - urcency value 
#     { name "min_res" } - name value
#     { min 2 }          - min value
#
#  RESULT
#     xml string
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/set_hedeby_slos()
#*******************************************************************************
proc create_min_resource_slo {{urgency 50 } { name "min_res" } { min 2 }} {
   set slo {}
   lappend slo "<common:slo xsi:type=\"common:MinResourceSLOConfig\" min=\"$min\" urgency=\"$urgency\" name=\"$name\"/>"
   return $slo
}


#****** util/hedeby_mod_setup() ************************************************
#  NAME
#     hedeby_mod_setup() -- startup hedeby (vi) modification sdmadm command
#
#  SYNOPSIS
#     hedeby_mod_setup { host execute_user sdmadm_arguments error_log } 
#
#  FUNCTION
#     This procedure will startup sdmadm mod command and will wait for started
#     up vi. After that the remote spawn id object is returned.
#
#  INPUTS
#     host             - host where to start the command
#     execute_user     - user who should start the command
#     sdmadm_arguments - sdmadm command arguments
#     error_log        - name of variable to store error messages
#
#  RESULT
#     internal spawn id array (returned from open_remote_spawn_process())
#
#  SEE ALSO
#     util/hedeby_mod_setup()
#     util/hedeby_mod_sequence()
#     util/hedeby_mod_cleanup()
#*******************************************************************************
global current_hedeby_mod_arguments
set current_hedeby_mod_arguments ""
proc hedeby_mod_setup { host execute_user sdmadm_arguments error_log } {
   global current_hedeby_mod_arguments 
   upvar $error_log errors
   set errors ""

   set current_hedeby_mod_arguments "${host}(${execute_user}) sdmadm $sdmadm_arguments"
   set tasks(RETURN_ISPID) ""
   set ispid [sdmadm_command $host $execute_user $sdmadm_arguments prg_exit_state tasks 1]
   set sp_id [ lindex $ispid 1 ]
   set timeout 30
   log_user 0  ;# we don't want to see vi output
   set clear_sequence [ format "%c%c%c%c%c%c%c" 0x1b 0x5b 0x48 0x1b 0x5b 0x32 0x4a 0x00 ]
   expect {
      -i $sp_id  "_start_mark_*\n" {
      }
   }
   ts_log_fine "got start mark"

   set timeout 10
   expect {
      -i $sp_id -- "$clear_sequence" {
         send -i $sp_id -- "G"
         ts_log_fine "got screen clear sequence"

      }
      -i $sp_id -- {[A-Za-z]+} {
         ts_log_fine "got screen output"
         send -i $sp_id -- "G"
      }
   }


   # now wait for 100% output
   set timeout 1
   set break_timer 10
   expect {
      -i $sp_id  "100%" {
         send -i $sp_id -- "1G"
      }
      -i $sp_id timeout {
         incr break_timer -1
         send -i $sp_id -- "G"
         if { $break_timer > 0 } {
            exp_continue
         } else {
            append errors "Error starting \"sdmadm $sdmadm_arguments\": vi does not start\n" 
            
         }
      }
   }
   ts_log_fine "vi started"
   return $ispid
}

#****** util/hedeby_mod_sequence() *********************************************
#  NAME
#     hedeby_mod_sequence() -- send vi mod sequences to open vi
#
#  SYNOPSIS
#     hedeby_mod_sequence { ispid sequence error_log } 
#
#  FUNCTION
#     This procedure is used to send the specified vi secquences to the open
#     remote spawn id.
#
#  INPUTS
#     ispid     - spawn id array returned by hedeby_mod_setup()
#     sequence  - list of vi command sequences
#     error_log - name of variable to store error messages
#
#  SEE ALSO
#     util/hedeby_mod_setup()
#     util/hedeby_mod_sequence()
#     util/hedeby_mod_cleanup()
#*******************************************************************************
proc hedeby_mod_sequence { ispid sequence error_log } {
   upvar $error_log errors
   if { $ispid == "" } {
      ts_log_fine "no ispid value - returning"
      return
   }

   if { $errors != "" } {
      ts_log_fine "skip sending sequence, there were errors!"
      return
   }

   set sp_id [ lindex $ispid 1 ]

   set timeout 0
   set nr 0
   
   foreach seq $sequence {
      ts_log_finer "sequence: $seq"
      send -i $sp_id -- $seq
   }
}

#****** util/hedeby_mod_cleanup() **********************************************
#  NAME
#     hedeby_mod_cleanup() -- finish mod (vi) session and return output
#
#  SYNOPSIS
#     hedeby_mod_cleanup { ispid error_log {exit_var prg_exit_state} 
#     {raise_error 1} } 
#
#  FUNCTION
#     This procedure is used to cleanup an open hedeby mod (vi) session
#     started with hedeby_mod_setup(). It returns the programm exit state
#     and the output.
#
#  INPUTS
#     ispid                     - spawn id array returned by hedeby_mod_setup()
#     error_log                 - name of variable to store error messages
#     {exit_var prg_exit_state} - optional: 
#                                    name of variable to store sdmadm exit state
#     {raise_error 1}           - optional:
#                                    raise error if there where errors
#
#  RESULT
#     the output of the command (also containing vi control characters which
#     are replaced with "?" characters)
#
#
#  SEE ALSO
#     util/hedeby_mod_setup()
#     util/hedeby_mod_sequence()
#     util/hedeby_mod_cleanup()
#*******************************************************************************
proc hedeby_mod_cleanup {ispid error_log {exit_var prg_exit_state} {raise_error 1}} {
   global current_hedeby_mod_arguments 
   upvar $exit_var exit_value
   upvar $error_log errors

   if { $ispid == "" } {
      ts_log_fine "no ispid value - returning"
      return
   }

   if { $errors != "" } {
      ts_log_fine "skip sending vi sequence, there were errors!"
   } else { 
      after 1000 ;# TODO: be sure to wait one second so that file timestamp has changed
                  # This might be done by have start timestamp and endtimestamp and only
                  # wait if timetamp has not changed (to fast edit)
      set sequence {}
      lappend sequence "[format "%c" 27]" ;# ESC
      lappend sequence ":wq\n"        ;# save and quit
      hedeby_mod_sequence $ispid $sequence errors
   }

   set sp_id [ lindex $ispid 1 ]
   set timeout 15
   set do_stop 0
   set output ""
   expect {
      -i $sp_id timeout {
      }
      -i $sp_id -- "*\n" {
        foreach line [split $expect_out(0,string) "\n\r"] {
           set line [string trim $line]
           if {$line != ""} {
              if { [string first "_exit_status_" $line] >= 0 } {
                 set exit_value [get_string_value_between "_exit_status_:(" ")" $line]
              } 
              if { [string first "_END_OF_FILE_" $line] >= 0 } {
                 set do_stop 1
              }
            
              set output_string ""
              for {set i 0} {$i<[string length $line]} {incr i 1} {
                 set char [string index $line $i]
                 if { ![string is control $char] } {
                    append output_string $char
                 } else {
                    append output_string "?"
                 }
              }  
              append output "$output_string\n"
           }
        }
        if { $do_stop == 0 } {
           exp_continue
        }
      }
   }
   log_user 1
   close_spawn_process $ispid
   if { $errors != "" } {
      append errors "output of command:\n"
      append errors $output
   }
   if { $raise_error } {
      if { $exit_value != 0 || $errors != "" } {
         if { $errors == "" } {
            append errors "output of command:\n"
            append errors $output
         }

         ts_log_severe "error calling \"sdmadm $current_hedeby_mod_arguments\":\n$errors\nexit_value: $exit_value" 
      }
   }
   return $output
}


#****** util/set_hedeby_slos() *************************************************
#  NAME
#     set_hedeby_slos() -- used to set slo configuration for a hedeby service
#
#  SYNOPSIS
#     set_hedeby_slos { host exec_user service slos } 
#
#  FUNCTION
#     This procedure is used to set the slo configuration for a hedeby ge service.
#
#  INPUTS
#     host      - host where to start command
#     exec_user - user who start command
#     service   - service which should be modified
#     slos      - list with slos to set (created with create_???_slo() and put
#                 into list)
#
#  RESULT
#     ??? 
#
#  NOTES
#     TODO: This procedure is not finished
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/set_hedeby_slos()
#*******************************************************************************
proc set_hedeby_slos { host exec_user service slos } {
   global CHECK_DEBUG_LEVEL
   ts_log_fine "setting slos for service \"$service\" ..."
   foreach new_slo $slos {
      ts_log_fine "new slo: $new_slo"
   }
   set arguments "-s [get_hedeby_system_name] mc -c $service"

   set ispid [hedeby_mod_setup $host $exec_user $arguments error_text]

   set sp_id [ lindex $ispid 1 ]
   
   set timeout 30
    
   # remove slo section
   set sequence {}
   lappend sequence "/<common:slos>\n"
   lappend sequence "ma/<\\/common:slos>\n"
   lappend sequence ":'a,.d\n"

   # add new slo section
   lappend sequence "i"
   lappend sequence "<common:slos>\n"
   foreach new_slo $slos {
      lappend sequence $new_slo
      lappend sequence "\n"
   }
   lappend sequence "</common:slos>\n"
   lappend sequence "[format "%c" 27]" ;# ESC

   hedeby_mod_sequence $ispid $sequence error_text
   set output [hedeby_mod_cleanup $ispid error_text]

   ts_log_fine "exit_status: $prg_exit_state"
   if { $prg_exit_state == 0 } {
      ts_log_fine "output: \n$output"
   }

   # TODO: check correct slo settings with sdmadm
   # TODO: should service be restarted or only updated
}
