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
      set host_list [get_all_movable_resources]
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
   set managed_hosts [get_all_movable_resources]
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
   set val [startup_hedeby_hosts "managed" [get_all_movable_resources] $startup_user]
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

#****** util/add_host_resources() ***********************************************
#  NAME
#     add_host_resources() -- add a host resource to hedeby
#
#  SYNOPSIS
#     add_host_resources { host_resources { service "" } { on_host "" } { as_user ""} 
#     {raise_error 1} } 
#
#  FUNCTION
#     This procedure is used to add host resources to the hedeby system. 
#
#     The function waits until the resources are ASSIGNED to the correct service.
#
#  INPUTS
#     host_resources  - list of hostnames to add
#     { service "spare_pool"}   - optional: name of the service which will be
#                       the owner of the resource
#     { on_host "" }  - optional: host where sdmadm should be started 
#                       if not set the hedeby master host is used
#     { as_user ""}   - optional: user name which starts sdmadm command 
#                       if not set the hedeby admin user is used
#     {raise_error 1} - if set to 1 testsuite reports errors on failure 
#
#  RESULT
#     the prg_exit_state of the sdmadm command
#
#  NOTES
#     TODO: use the new hedeby_add_resources_to_service after setting up
#     default properties (no temp file necessary)
#
#*******************************************************************************
proc add_host_resources { host_resources { service "spare_pool" } { on_host "" } { as_user ""} {raise_error 1} } {
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
   set cur_line 0
   foreach host_resource $host_resources {
      if { $cur_line > 0 } {
         # write a delimiter
         incr cur_line
         set data($cur_line) "==="
      }
      
      incr cur_line
      set data($cur_line) "resourceHostname=$host_resource"
      incr cur_line
      set data($cur_line) "unbound_name=$host_resource"
  
      
      set osArch [resolve_arch $host_resource]
      get_hedeby_ge_complex_mapping $osArch
      set found_mapping 0
      foreach prop [array names res_prop] {
         incr cur_line 1
         set data($cur_line) $prop=$res_prop($prop)
         set found_mapping 1
      }
   
      # in case we have no mapping ...
      if {$found_mapping == 0 } {
         # ... we simply use uname info
         set osName [string trim [start_remote_prog $host_resource $exec_user uname -s]]
         if {$osName == "SunOS"} {
            set osName "Solaris"
         }
         incr cur_line 1
         set data($cur_line) "operatingSystemName=$osName"
         set osRel  [string trim [start_remote_prog $host_resource $exec_user uname -r]]
         incr cur_line 1
         set data($cur_line) "operatingSystemRelease=$osRel"
         incr cur_line 1
         set data($cur_line) "hardwareCpuArchitecture=$osArch"
      }
   }
   set data(0) $cur_line

   write_remote_file $host_resource $exec_user $file_name data

   # print out created file
   set file_content [start_remote_prog $exec_host $exec_user cat $file_name]
   ts_log_fine "properties file:"
   ts_log_fine $file_content

   ts_log_fine "adding host resources \"$host_resources\" to service $service of hedeby system ..."

   # now use sdmadm command ...
   set opt(exit_var) ar_exit_state
   set opt(raise_error) $raise_error
   set opt(user) $exec_user
   set opt(host) $exec_host
   sdmadm_command_opt "ar -f $file_name -s $service" opt

   if {$ar_exit_state == 0} {
      foreach res $host_resources {
         set exp_res_info($res,state) "ASSIGNED"
         set exp_res_info($res,service) "$service"
      }
      set ar_exit_state [wait_for_resource_info exp_res_info 60 $raise_error]
      unset exp_res_info
   }

   return $ar_exit_state
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
global ge_arch_mapping_table
if {[info exists ge_arch_mapping_table]} {
   unset ge_arch_mapping_table
}
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
            if { $col == "complex" && $table($col,$line) == "arch"} {
               set res_property $table(resource_property,$line)
               set complex_arch $table(complex_value,$line)
               set res_value $table(resource_value,$line)
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
      ts_log_finer "using chached ge_arch_mapping_table ..."
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
#     util/get_all_movable_resources()
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
#     util/get_all_movable_resources()
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
#     util/get_all_movable_resources()
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

            # The java class MessageFormat requires the quoting of ' 
            # Our create_bundle_string method does not consider this quoting
            # We simply replace here all double '' with '            
            set propTxt [string map { '' ' } $propTxt] ;#'

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

#****** util/get_bundle_string() ***********************************************
#  NAME
#     exists_bundle_string() -- get belonging to specified bundle id
#
#  SYNOPSIS
#     exists_bundle_string { id } 
#
#  FUNCTION
#     The procedure tries to find the specified string in the bundle_cache
#     array and returns 1 if found or zero
#
#  INPUTS
#     id - bundle id, e.g.: "bootstrap.exception.constructor_of_not_allowed"
#  RESULT
#     1 if found or zero
#
#*******************************************************************************
proc exists_bundle_string { id } {
   global bundle_cache

   return [info exists bundle_cache($id)]
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

   # A parameter in a bundle string looks like this: {\d+(,\w+)*}
   # where \d+ matches the parameter index (starting at 0)
   set param_regex {\{([0-9]+)(,[^\}]+)?\}}

   # get bundle string
   set bundle_string [get_bundle_string $id]
   ts_log_finer "bundle string for id $id='$bundle_string'"

   # handle case of $default_param set
   if { $default_param != "" } {
      set result_string [regsub -all $param_regex $bundle_string $default_param]
      ts_log_finer "result string for id $id='$result_string'"
      return $result_string
   }

   set result_string $bundle_string
   while { [regexp $param_regex $result_string dummy i] == 1 } {
      # now i contains the number of the {i} pattern
      #   => determine replacement string
      if { [info exists params($i)] } {
         set replace_str $params($i)
      } else {
         ts_log_severe "No entry for parameter $i in params_array: bundle string=$bundle_string"
         set replace_str "{$i}"
      }

      # get the position of the match and replace it
      set result_string [regsub $param_regex $result_string $replace_str]
      ts_log_finer "new result string iteration=$result_string"
   }
   ts_log_finer "result string for id $id='$result_string'"
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
#     util/get_all_movable_resources()
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
#     util/get_all_movable_resources()
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
#     adds the subdirectory "hedeby_$host" to the path.
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
#     util/get_all_movable_resources()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc get_hedeby_local_spool_dir { host } {
   set spool_dir [get_local_spool_dir $host "hedeby_$host" 0 ]
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
#     util/get_all_movable_resources()
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
         set chmodnargs "-R 700 $local_spool_dir"
         set output [start_remote_prog $host  $CHECK_USER "chmod" $chmodnargs]
         ts_log_fine $output
         if { $prg_exit_state != 0 } {
            add_proc_error "cleanup_hedeby_local_spool_dir" -1 "doing chmod $chmodnargs returned exit code: $prg_exit_state\n$output"
         }
      }
   }
   # now we can cleanup the spool dir (set last option to 1)
   set spool_dir [get_local_spool_dir $host "hedeby_$host" 1 ]
   remote_delete_directory $host $spool_dir
   return $spool_dir
}


#****** util/get_current_non_static_resources() ************************************
#  NAME
#     get_current_non_static_resources()  -- get all current movable managed host resources
#
#  SYNOPSIS
#     get_all_non_static_resource 
#
#  FUNCTION
#     It determines the set of managed resources that are allowed to be moved 
#     around in the system. The only resources that are not allowed to move are
#     the static resources. The qmasters of the managed clusters are usually 
#     defined static. 
#
#  INPUTS
#
#  RESULT
#     list with host names that are non static resources
#
#  SEE ALSO
#     
#*******************************************************************************

proc get_current_non_static_resources {} {
   global hedeby_config
   #these resources are non static by default
   set host_list [get_all_spare_pool_resources]
   
   get_hedeby_default_services service_names
   foreach service $service_names(services) {
      # Store all moveable resources in mvr_list
      # We will check later that all moveable resource are assigned to
      # spare_pool
      foreach res $service_names(moveable_execds,$service) {
         if {[lsearch -exact $host_list $res] < 0} {
            lappend host_list $res
         }
      } 
   }
   return $host_list
}



#****** util/get_all_movable_resources() ************************************
#  NAME
#     get_all_movable_resources() -- get all possible managed host names
#
#  SYNOPSIS
#     get_all_movable_resources { } 
#
#  FUNCTION
#     The procedure returns a list of all possible managed host candidates of
#     the specified Grid Engine clusters including all hedeby (host) resources.
#     ATTENTION: This list does not contain static resources.
#     This are movable execd resources.
#  WARNING THIS FUNCTION DOES !NOT! RETURN THE MOVABLE LIST BUT ALL HOSTS EXCEPT THE
#  HEDEBY MASTER HOST!
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
#     util/get_all_movable_resources()
#     util/get_all_spare_pool_resources()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc get_all_movable_resources {} {
   global hedeby_config
   set host_list [get_all_spare_pool_resources]
   
   foreach host [get_all_execd_nodes] {
      if {[lsearch $host_list $host] < 0 && $host != $hedeby_config(hedeby_master_host) } {
         lappend host_list $host
      }
   }
   return $host_list
}

#****** util/get_all_spare_pool_resources() ***********************************
#  NAME
#     get_all_spare_pool_resources() -- get configured hedeby resources
#
#  SYNOPSIS
#     get_all_spare_pool_resources { } 
#
#  FUNCTION
#     This procedure returns the list of all hosts (or nodes) which are 
#     configured to be in the hedeby spare_pool. (Free resources)
#
#  INPUTS
#
#  RESULT
#     list of resources
#
#  SEE ALSO
#     util/get_all_movable_resources()
#     util/get_all_default_hedeby_resources()
#*******************************************************************************
proc get_all_spare_pool_resources {} {
   global hedeby_config
   return [host_conf_get_nodes $hedeby_config(hedeby_host_resources)]
}

#****** util/get_all_default_hedeby_resources() ****************************************
#  NAME
#     get_all_default_hedeby_resources() -- return list with all configured resources
#
#  SYNOPSIS
#     get_all_default_hedeby_resources { } 
#
#  FUNCTION
#     This procedure returns a list of all expected resources which should
#     be reported by hedeby. This are all execd hosts and all hedeby resources.
#     This list includes static and not static resources.
#
#  INPUTS
#
#  RESULT
#     List with testsuite resource names
#
#  SEE ALSO
#     util/get_hedeby_default_services()
#     util/get_all_movable_resources()
#*******************************************************************************
proc get_all_default_hedeby_resources {} {

   # get all resources from the default services
   get_hedeby_default_services service_names
   set expected_resource_list {}
   foreach service $service_names(services) {
      foreach execd $service_names(execd_hosts,$service) {
         lappend expected_resource_list $execd
      }
   }
   # get all resources which are defined for the hedeby spare_pool
   foreach hres [get_all_spare_pool_resources] {
      lappend expected_resource_list $hres
   }
   return $expected_resource_list
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
#         service_names(services)                | list of all services
#         service_names(execd_hosts,$service)    | list of all execds of $service
#         service_names(master_host,$service)    | name of master of $service
#         service_names(moveable_execds,$service)| list of all not static resources of $service
#         service_names(ts_cluster_nr,$service)  | testsuite cluster nr of service
#         service_names(ts_cluster_nr,$host)     | testsuite cluster nr of host
#         service_names(default_service,$host)   | default service of $host
#         service_names(service,$host)           | ge-service of $host (not spare_pool)
#
#*******************************************************************************
proc get_hedeby_default_services { service_names } {
   global hedeby_config
   upvar $service_names ret
   set current_cluster_config [get_current_cluster_config_nr]
   set cluster 0
   set ge_master_hosts {}
   set ret(services) {}
   while { [set_current_cluster_config_nr $cluster] == 0 } {
      get_current_cluster_config_array ts_config
      lappend ge_master_hosts $ts_config(master_host)
      set ret(execd_hosts,$ts_config(cluster_name)) $ts_config(execd_nodes)
      set ret(master_host,$ts_config(cluster_name)) $ts_config(master_host)
      set ret(ts_cluster_nr,$ts_config(master_host)) $cluster
      set ret(ts_cluster_nr,$ts_config(cluster_name)) $cluster
      lappend ret(services) $ts_config(cluster_name)

      set ret(moveable_execds,$ts_config(cluster_name)) {}
      foreach exh $ts_config(execd_nodes) {
         set ret(default_service,$exh) $ts_config(cluster_name)
         set ret(service,$exh)         $ts_config(cluster_name)
         if {$exh != $ts_config(master_host)} {
            lappend ret(moveable_execds,$ts_config(cluster_name)) $exh
            set ret(ts_cluster_nr,$exh) $cluster
         }
      }

      ts_log_finer "execds for service \"$ts_config(cluster_name)\": $ret(execd_hosts,$ts_config(cluster_name))"
      ts_log_finer "service names for hedeby on host \"$ts_config(master_host)\": $ret(service,$ts_config(master_host))"
      incr cluster 1
   }
   set_current_cluster_config_nr $current_cluster_config

   foreach hres [get_all_spare_pool_resources] {
      set ret(default_service,$hres) "spare_pool"
   }

   ts_log_finer "current ge master hosts: $ge_master_hosts"
   return $ge_master_hosts
}

#****** util/get_hedeby_current_services() *************************************
#  NAME
#     get_hedeby_current_services() -- get current information about ge services
#
#  SYNOPSIS
#     get_hedeby_current_services { service_names } 
#
#  FUNCTION
#     This procedure is used to get information about grid engine services
#     but unlike get_hedeby_default_services() this information is current,
#     i.e. the current distribution of resources is taken into account
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
#         service_names(services)                | list of all services
#         service_names(execd_hosts,$service)    | list of all execds of $service
#         service_names(master_host,$service)    | name of master of $service
#         service_names(moveable_execds,$service)| list of all not static resources of $service
#         service_names(ts_cluster_nr,$service)  | testsuite cluster nr of service
#         service_names(ts_cluster_nr,$host)     | testsuite cluster nr of host
#         service_names(default_service,$host)   | see get_hedeby_default_services
#         service_names(service,$host)           | service to which a host belongs, only
#                                                | works for hosts belonging to ge-adapters
#
#  NOTES
#     This method works under a couple of assumptions:
#     1) all grid engine services have the service names of the default
#        configuration, none of the names were changed
#     2) all static resources represent a master_host
#     3) the state (ASSIGNED, ERROR, etc.) of the resources is irrelevant
#     4) A service NEVER has the same name as a resource
#     5) Ambiguous resoures are ignored
#     6) Services that do not have any resource, not even a static one, will not show up.
#
#  SEE ALSO
#     util/get_hedeby_default_services()
#*******************************************************************************
proc get_hedeby_current_services { service_names } {
   global hedeby_config
   upvar $service_names ret
   set ge_master_hosts {}

   # get the default configuration
   set def_ge_master_hosts [get_hedeby_default_services def_service_names]

   # just copy the default_service entries from def_service_names
   foreach n [list_grep "^default_service," [array names def_service_names]] {
      set ret($n) $def_service_names($n)
   }

   # loop over all resources currently in the system and filter out the
   # uninteresting resources
   get_resource_info
   set filtered_res_list {}
   foreach res $res_list {
      set s $res_info($res,service)
      set type $res_info($res,type)
      # TODO: write a helper function is_flag_set for these cases and use it everywhere!
      if { [string first "A" $res_info($res,flags)] >= 0 } {
         # resource is ambiguous
         ts_log_fine "Skipping ambiguous resource $res with service $s (type=\"$type\")"
         continue
      }
      if { [lsearch -exact $def_service_names(services) $s] < 0 || $type != "host" } {
         # we are only interested in host resources belonging to grid engine
         # services, see also assumption 1)
         ts_log_fine "Skipping resource $res with service $s (type=\"$type\")"
         continue
      }
      ts_log_fine "Accepting resource $res with service $s"
      lappend filtered_res_list $res
   }

   # build up the ret structure
   foreach res $filtered_res_list {
      set s $res_info($res,service)
      set all_serv($s) 1

      set ret(service,$res) $s
      lappend ret(execd_hosts,$s) $res

      if { $res_info($res,flags) == "S" } {
         # this is a master host (assumption 2)
         set ret(master_host,$s) $res
         lappend ge_master_hosts $res
      } else {
         # it is an execd
         lappend ret(moveable_execds,$s) $res
      }
   }

   set ret(services) [array names all_serv]

   # copy ts_cluster_nr from def_service_names
   foreach res $filtered_res_list {
      # the cluster number for each resource is the cluster number of the
      # service this resource belongs to
      set s $res_info($res,service)
      set cluster_nr $def_service_names(ts_cluster_nr,$s)
      set ret(ts_cluster_nr,$s)   $cluster_nr 
      set ret(ts_cluster_nr,$res) $cluster_nr
   }

   ts_log_finer [format_array ret]
   ts_log_finer "current ge master hosts: $ge_master_hosts"

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
#     util/get_all_movable_resources()
#     util/is_hedeby_process_running()
#*******************************************************************************
proc is_hedeby_process_running { host pid } {

   ts_log_finer "checking pid $pid on host $host ..."
   get_ps_info $pid $host ps_info

   if {$ps_info($pid,error) == 0} {
        if { [string match "*java*" $ps_info($pid,string)] >= 0 } {
           ts_log_finer "process string of pid $pid is $ps_info($pid,string)"
           return 1
        } else {
           ts_log_fine "hedeby process should have java string in command line"
           return 0
        }
   } else {
        ts_log_finer "pid $pid not found!"
        return 0
   }
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
      after 500
      set is_pid_running [is_hedeby_process_running $host $pid]
      if { $is_pid_running == 0 } {
         set terminated 1
         break
      }
      after 1000
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
   global LP_master_host_pid

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
               #TODO: Temporal fix for infinite hedeby install issue LP had
               # To be removed and fixed properly
               if {[info exists LP_master_host_array(pid)]} {
                  if {[llength $LP_master_host_array(pid)] > 0} {
                     set hostInfoArray($host,pid_list) $LP_master_host_array(pid)
                     set hostInfoArray($host,run_list) $LP_master_host_array(run_list)
                     unset LP_master_host_array(pid)
                  }
               }
               if { [llength $hostInfoArray($host,pid_list)] == 0} {
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


#****** util/private_start_parallel_sdmadm_command() ***************************
#  NAME
#     private_start_parallel_sdmadm_command() -- private impl of parallel sdmadm
#
#  SYNOPSIS
#     private_start_parallel_sdmadm_command { host_list exec_user info 
#     {raise_error 1} {parallel 1} } 
#
#  FUNCTION
#     Used TS internal. Only use start_parallel_sdmadm_command() in tests.
#
#  INPUTS
#     host_list       - see start_parallel_sdmadm_command()
#     exec_user       - see start_parallel_sdmadm_command() 
#     info            - see start_parallel_sdmadm_command() 
#     {raise_error 1} - see start_parallel_sdmadm_command() 
#     {parallel 1}    - see start_parallel_sdmadm_command() 
#
#  RESULT
#     see start_parallel_sdmadm_command() 
#
#  SEE ALSO
#     util/start_parallel_sdmadm_command()
#*******************************************************************************
proc private_start_parallel_sdmadm_command {host_list exec_user info {raise_error 1} {parallel 1}} {
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
            ts_log_finer "got ispid: $ispid"
            set spawn_id [lindex $ispid 1]
            set ispid_list($host,sp_id) $spawn_id
            set ispid_list($spawn_id) $host
            ts_log_finer "sp_id on host $host is $ispid_list($host,sp_id)"
            lappend spawn_list $ispid_list($host,sp_id)
         } else {
            set task_info($host,output) [sdmadm_command $host $exec_user $task_info($host,sdmadm_command) prg_exit_state tasks $raise_error]
            set task_info($host,exit_status) $prg_exit_state
         }
      }

      set last_running ""
      if { $parallel == 1 }  {
         set timeout 120
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
   if { $error_text != ""} {
      ts_log_severe "error starting parallel sdmadm command:\n$error_text" $raise_error
   }
   return $error_text
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
#     This procedure is used to start parallel sdmadm tasks. But will only
#     start max. 15 commands parallel and only 1 command per node on a
#     node of a physical hosts at once. All additional necessary runs
#     are done in further steps.
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
#  SEE ALSO
#     util/private_start_parallel_sdmadm_command()
#
#*******************************************************************************
proc start_parallel_sdmadm_command {host_list exec_user info {raise_error 1} {parallel 1}} {
   upvar $info task_info
   upvar $host_list hostlist

   if { $parallel != 1 } {
      # for NOT parallel execution it does not matter how much processes are done parallel
      ts_log_fine "running private_start_parallel_sdmadm_command() for hosts \"$hostlist\" ..."
      return [private_start_parallel_sdmadm_command hostlist $exec_user task_info $raise_error $parallel]
   } 

   # We have to start parallel tasks, we minimize the nr. of parallel tasks to max. 15
   set max_hosts 15

   set hosts_todo {}
   foreach host $hostlist {
      lappend hosts_todo $host
      set physical_host($host) [node_get_host $host]

   }
   set error_text ""

   while {[llength $hosts_todo] > 0} {
      ts_log_fine "outstanding hosts to start parallel commands: $hosts_todo"

      # build a host start list
      set start_list {}

      # set list of used physical hosts
      set used_physical {}
      foreach host $hosts_todo {
         # only run 1 sdmadm command per physical host (on one node of a physical host)
         if {[lsearch -exact $used_physical $physical_host($host)] < 0} {
            lappend used_physical $physical_host($host)
         } else {
            ts_log_fine "skipping node $host for this run (already added a node of its the physical host \"$physical_host($host)\"!"
            continue
         }
         lappend start_list $host
         # stop if we have enough hosts for this run
         if {[llength $start_list] >= $max_hosts} {
            ts_log_fine "found enough host for this run ([llength $start_list])!"
            break
         }
      }

      # execute parallel on start_list hosts     
      ts_log_fine "running private_start_parallel_sdmadm_command() for hosts \"$start_list\" ..."
      append error_text [private_start_parallel_sdmadm_command start_list $exec_user task_info $raise_error $parallel]

      # remove started hosts fro hosts_todo list
      foreach host $start_list {
         set pos [lsearch -exact $hosts_todo $host]
         if {$pos >= 0} {
            set hosts_todo [lreplace $hosts_todo $pos $pos]
         }
      }
   }
   return $error_text
}

#****** util/start_parallel_sdmadm_command_opt() ***********************************
#  NAME
#     start_parallel_sdmadm_command_opt() -- start sdmadm_command parallel
#
#  SYNOPSIS
#     start_parallel_sdmadm_command_opt {host_list task_info {opt ""}}
#
#  FUNCTION
#     This procedure is the optional argument passing version of
#     start_parallel_sdmadm_command(). For a description of the command, see
#     there.
#
#  INPUTS
#     host_list        - hosts where to start sdmadm command
#     task_info        - name of array to store task information
#
#     opt              - optional named arguments, see get_hedeby_proc_default_opt_args()
#     opt(parallel)    - if 0 run commands in a sequence (for debuging only)
#                        default: 1
#     opt(host)        - not used
#     opt(system_name) - if "" then no -s parameter is added to the sdmadm commands
#     opt(pref_type)   - if "" then no -p parameter is added to the sdmadm commands
#
#  RESULT
#     string "" on success, string with error text on error
#
#  EXAMPLE
#     # Initialize the task info array:
#     foreach host $host_list {
#        set task_info($host,expected_output) ""
#        set task_info($host,sdmadm_command) "rs"      
#     }
#
#     # Execute the sdmadm command parallel
#     set opt(parallel) 0
#     set error_text [start_parallel_sdmadm_command_opt host_list task_info opt]
#
#     # Examine the results
#     foreach host $host_list {
#        set exit_state $task_info($host,exit_status)
#        set output $task_info($host,output)
#        debug_puts "host: $host"
#        debug_puts "exit status: $exit_state"
#        debug_puts "output:\n$output"
#     }
#     if { $error_text != "" } {
#        ts_log_severe "Error in remove_hedeby_preferences: $error_text"
#     }
#
#  SEE ALSO
#     util/start_parallel_sdmadm_command()
#     util/get_hedeby_proc_opt_arg()
#*******************************************************************************
proc start_parallel_sdmadm_command_opt {host_list task_info {opt ""}} {
   set opts(parallel) 1
   get_hedeby_proc_opt_arg $opt opts

   upvar $host_list u_host_list
   upvar $task_info u_task_info

   # now alter u_task_info(*,sdmadm_command) to include pref_type and system_name
   foreach key [list_grep ",sdmadm_command$" [array names u_task_info]] {
      set args $u_task_info($key)

      # add preference type and system name to command line when != ""
      if { $opts(pref_type) != "" } {
         set args "-p $opts(pref_type) $args"
      }
      if { $opts(system_name) != "" } {
         set args "-s $opts(system_name) $args"
      }

      set u_task_info($key) $args
   }

   return [start_parallel_sdmadm_command u_host_list $opts(user) u_task_info $opts(raise_error) $opts(parallel)]
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
#     Currently this procedure doesn't check if the processes are runing after
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
   set expected_jvms($hedeby_config(hedeby_master_host)) [get_expected_jvms $hedeby_config(hedeby_master_host)]
   # setup managed host expectations ...
   foreach host_temp [get_all_movable_resources] {
      set expected_jvms($host_temp) [get_expected_jvms $host_temp]
   }

   set success [create_bundle_string "StartJVMCommand.success"]
   set error_text ""
   if { $type != "managed" && $type != "master" } {
      add_proc_error "startup_hedeby_hosts" -1 "unexpected host type: \"$type\" supported are \"managed\" or \"master\""
      return 1
   }

   ts_log_fine "starting up hedeby host(s): $host_list"

   # turn off security if enabled
   if { $hedeby_config(security_disable) == "true" } {
      set pref_type [get_hedeby_pref_type]
      if { $pref_type == "system" } {
         foreach host $host_list {
            ts_log_fine "WARNING! Setting security disable property on host $host!"
            set propArray($host,expected_output) ""
            set propArray($host,sdmadm_command) "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sebcp -p no_ssl -v true"
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
         set output [sdmadm_command $host $user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sebcp -p no_ssl -v true"]
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
            set match_count 0
            if { $exit_state != 0 } {
               append error_text "cannot startup managed host $host_tmp:\n$output\n"
            } else {
               set jvm_count [parse_jvm_start_stop_output output]
               for {set i 0} {$i < $jvm_count} {incr i} {
                   set host $ss_out($i,host)
                   set jvm  $ss_out($i,jvm)
                   set res $ss_out($i,result)
                   set mes $ss_out($i,message)
                   ts_log_finer "Found jvm $jvm on host $host, with result $res"
                   
                   foreach match_jvm $expected_jvms($host_tmp) {
                       if { $match_jvm == $jvm } {
                           incr match_count
                           if { $res == $success } {
                               ts_log_finer "output match for jvm: $jvm, host: $host, result: $res"
                           } else {
                              append error_text "startup hedeby host ${host} failed:\n"
                              append error_text "\"$output\"\n"
                              append error_text "Jvm: $jvm on host: $host exited with result: $res with message: $mes\n"
                           }
                       }
                   }               
               }
               # get run directory
               set run_dir [get_hedeby_local_spool_dir $host_tmp]
               append run_dir "/run"
               set pid_list {}
               
               get_jvm_pidlist $host_tmp $user $run_dir pid_list run_list

               # check if processes exists for the given pid numbers.
               foreach pid $pid_list {
                    set is_pid_running [is_hedeby_process_running $host_tmp $pid]
                    if {$is_pid_running != 1} {
                        append error_text "The process is not running for $pid pid number\n"
                    } else {
                        ts_log_finer "Process for pid $pid is running"
                    }
               }
            }

            set expected_count 0
            foreach expect_c $expected_jvms($host_tmp) {
                incr expected_count
            }
            if { $match_count == $expected_count } {
               ts_log_finer "output matched expected number of jvms: $match_count"
            } else {
               append error_text "startup hedeby host ${host_tmp} failed:\n"
               append error_text "\"$output\"\n"
               append error_text "The expected output doesn't match expected number of jvms: $match_count .\n"               
            } 

            ts_log_finer "----------------------------------"
            ts_log_finer "host: $host"
            ts_log_finer "exit status: $exit_state"
            ts_log_finer "output:\n$output"
            ts_log_finer "----------------------------------"
         }
      }
      "master" {
         if { [llength $host_list] != 1 } {
            append error_text "hostlist contains more than 1 entry - hedeby has only one master host\n\n"
         } else {
            set host_tmp [lindex $host_list 0]
            set output [sdmadm_command $host_tmp $user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] suj"]
            set match_count 0
            if { $prg_exit_state != 0 } {
               append error_text "cannot startup master host $host_tmp:\n$output\n"
            } else {
               set jvm_count [parse_jvm_start_stop_output output]
               for {set i 0} {$i < $jvm_count} {incr i} {
                   set host $ss_out($i,host)
                   set jvm  $ss_out($i,jvm)
                   set res $ss_out($i,result)
                   set mes $ss_out($i,message)
                   ts_log_finer "Found jvm $jvm on host $host, with result $res"
                   
                   foreach match_jvm $expected_jvms($host_tmp) {
                       if { $match_jvm == $jvm } {
                           incr match_count
                           if { $res == $success } {
                               ts_log_finer "output match for jvm: $jvm, host: $host, result: $res"

                           } else {
                              append error_text "startup hedeby host ${host} failed:\n"
                              append error_text "\"$output\"\n"
                              append error_text "Jvm: $jvm on host: $host exited with result: $res with message: $mes\n"
                           }
                       }
                   }               
                }
                set run_dir [get_hedeby_local_spool_dir $host_tmp]
                append run_dir "/run"
                set pid_list {}
                
                get_jvm_pidlist $host_tmp $user $run_dir pid_list run_list

                # check if processes exists for the given pid numbers.
                foreach pid $pid_list {
                    set is_pid_running [is_hedeby_process_running $host_tmp $pid]
                    if {$is_pid_running != 1} {
                        append error_text "The process is not running for $pid pid number\n"
                    } else {
                        ts_log_finer "Process for pid $pid is running"
                    }
                }
            }

            set expected_count 0
            foreach expect_c $expected_jvms($host_tmp) {
                incr expected_count
            }
            if { $match_count == $expected_count } {
               ts_log_finer "output matched expected number of jvms: $match_count"
            } else {
               append error_text "startup hedeby host ${host_tmp} failed:\n"
               append error_text "\"$output\"\n"
               append error_text "The expected output doesn't match expected number of jvms: $match_count .\n"
               
            }
         }
      }
   }
   
   if { $error_text != "" } {
      ts_log_severe $error_text
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
#     reset_hedeby { {force 0} } 
#
#  FUNCTION
#     Used to reset the hedeby configuration to the state after first
#     installation. 
#
#  INPUTS
#     force - if != 0 reset the system, even if freshly installed
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
proc reset_hedeby {{force 0}} {
   global check_use_installed_system
   global hedeby_config
   if {!$check_use_installed_system && $force == 0} {
      ts_log_fine "This is a fresh installation, skip reset_hedeby!"
      return 0
   } else {
      ts_log_fine "reset hedeby installation ..."
   }
   set ret_val 0
   set pref_type [get_hedeby_pref_type]
   set sys_name [get_hedeby_system_name]
   set admin_user [get_hedeby_admin_user]
   set exec_host $hedeby_config(hedeby_master_host)
   set error_text ""

   # first find out resource states
   set ret_val [wait_for_resource_state "ASSIGNED ERROR" 0 15 res_state_info]

   # if we have missing resources we want to restart hedeby first
   # and hope that only a component is not up
   if { [llength $res_state_info(missing)] > 0 } {
      ts_log_fine "we have missing resources, restart hedeby installation ..."
      
      # shutdown_hedeby
      set ret_val [hedeby_shutdown]
      if { $ret_val != 0} {
         return 1
      }

      # startup hedeby
      set ret_val [hedeby_startup] 
      if { $ret_val != 0} {
         return 1
      }

      set ret_val [wait_for_resource_state "ASSIGNED ERROR" 0 15 res_state_info]
      # if the missing resources are hedeby resources we can add them
      if { [llength $res_state_info(missing)] > 0 } {
         set hedeby_nodes [get_all_spare_pool_resources]
         set resources_to_add {}
         foreach res $res_state_info(missing) {
            if {[lsearch -exact $hedeby_nodes $res] >= 0} {
               ts_log_fine "adding missing hedeby resource \"$res\" ..."
	            lappend resources_to_add $res
            }
         }
         if {[llength $resources_to_add] > 0} {
            add_host_resources $resources_to_add "spare_pool"
         }
      }

      set ret_val [wait_for_resource_state "ASSIGNED ERROR" 0 30 res_state_info]

      # if we still have missing resources we can stop here
      if { [llength $res_state_info(missing)] > 0 } {
         ts_log_severe "still missing resources: \"$res_state_info(missing)\", reset_failed!"
         return 1   
      }
   }

   # now if there are resources in "ERROR" or "unexpected" state and 
   # reset them
   set reset_resource_list {}
   if {[llength $res_state_info(ERROR)] > 0} {
      ts_log_fine "we have resources in ERROR state, reset them ..."
      foreach res $res_state_info(ERROR) {
         lappend reset_resource_list $res
      }
   }
   if {[llength $res_state_info(unexpected)] > 0} {
      ts_log_fine "we have resources in unexpected state, reset them ..."
      foreach res $res_state_info(unexpected) {
         lappend reset_resource_list $res
      }
   }

   foreach res $reset_resource_list {
      ts_log_fine "reset resource \"$res\" ..."
      set sdmadm_command_line "-p $pref_type -s $sys_name rsr -r $res"
      set output [sdmadm_command $exec_host $admin_user $sdmadm_command_line]
      append error_text "${exec_host}($admin_user)> sdmadm $sdmadm_command_line\n$output\n"
   }

   # for resources which are in a not uniq we check if they are
   # in "ERROR" state and reset them on the affected service
   foreach res $res_state_info(ambiguous) {
      ts_log_fine "resource \"$res\" is ambiguous and has following states:"
      for {set index 0} {$index < [llength $res_info($res,state)]} {incr index 1} {
         set state   [lindex $res_info($res,state) $index]
         set service [lindex $res_info($res,service) $index]
         ts_log_fine "state \"$state\" at service \"$service\""
         # reset resource at service when state = "ERROR"
         if {$state == "ERROR"} {
            # 1) Remove resource from all other services
            foreach serv $res_info($res,service) {
               if {$serv == $service} {
                  ts_log_fine "skip service \"$serv\""
                  continue
               }
               ts_log_fine "remove resource \"$res\" from service \"$serv\""
               set sdmadm_command_line "-p $pref_type -s $sys_name rr -r $res -s $serv" 
               set output [sdmadm_command $exec_host $admin_user $sdmadm_command_line]
               append error_text "${exec_host}($admin_user)> sdmadm $sdmadm_command_line\n$output\n"
            }
            # 2) Reset resource
            ts_log_fine "reset resource \"$res\" at service \"$service\""
            set sdmadm_command_line "-p $pref_type -s $sys_name rsr -r $res"
            set output [sdmadm_command $exec_host $admin_user $sdmadm_command_line]
            append error_text "${exec_host}($admin_user)> sdmadm $sdmadm_command_line\n$output\n"
            break
         }
      } 
   }

   # remove still unknown resources
   foreach res $res_state_info(unknown) {
      append error_text "removing unexpected resource \"$res\" ...\n"
      ts_log_fine "remove resource \"$res\""
      set sdmadm_command_line "-p $pref_type -s $sys_name rr -r $res"
      set output [sdmadm_command $exec_host $admin_user $sdmadm_command_line]
      append error_text "${exec_host}($admin_user)> sdmadm $sdmadm_command_line\n$output\n"
   }
   
   if {$error_text != ""} {
      ts_log_info $error_text
   }
   
   remove_blacklisted

   # wait for resources to get "assigned" state
   set ret_val [wait_for_resource_state "ASSIGNED"]
   if { $ret_val != 0} {
      return 1
   }

   # reset slos
   set ret_val [reset_default_slos "mod_config"]
   if { $ret_val != 0} {
      return 1
   }

   # move resources to correct services
   set ret_val [move_resources_to_default_services]
   if { $ret_val != 0} {
      return 1
   }

   # check correct startup of resources
   set ret_val [hedeby_check_default_resources]
   if { $ret_val != 0} {
      return 1
   }

   # check correct startup of services
   set ret_val [hedeby_check_default_services]
   if { $ret_val != 0} {
      return 1
   }
   return 0
}


#****** util/remove_blacklisted() ****************************************************
#  NAME
#     remove_blacklisted() -- search for and remove blacklisted resources
#
#  SYNOPSIS
#     remove_blacklisted { } 
#
#  FUNCTION
#     Search for and remove blacklisted resources.
#
#     Sends an info mail for every found blacklisted resource. Normal case: no
#     resources are blacklisted.
#
#  SEE ALSO
#     util/reset_hedeby()
#*******************************************************************************
proc remove_blacklisted {} {
   ts_log_fine "Searching for blacklisted resources ..."
   
   # Check if we have blacklisted resources
   set opts(table_output) table
   sdmadm_command_opt "show_blacklist" opts
   if { $prg_exit_state != 0 } {
      return
   }
   # Remove all blacklisted resources from all services
   for {set line 0} {$line < $table(table_lines)} {incr line 1} {
      #cols are "service resource"
      set service $table(service,$line)
      set resource $table(resource,$line)
      ts_log_info "Error: Found unexpected resource '$resource' on blacklist of service '$service'"
      sdmadm_command_opt "rrfb -r $resource -s $service" ; # remove_resource_from_blacklist
      if { $prg_exit_state == 0 } {
         ts_log_fine "Removed resource '$resource' from blacklist of service '$service'"
      }
   }
}


#****** util/hedeby_check_default_services() ***********************************
#  NAME
#     hedeby_check_default_services() -- check default hedeby services
#
#  SYNOPSIS
#     hedeby_check_default_services { } 
#
#  FUNCTION
#     Check whether all default services are up and running
#
#  INPUTS
#
#  RESULT
#     0 on success
#     1 on error
#
#  SEE ALSO
#     util/hedeby_check_default_services()
#     util/hedeby_check_default_resources()
#*******************************************************************************
proc hedeby_check_default_services {} {
   global hedeby_config
   set ret_val 0

   # set timeout for this check
   set mytimeout [timestamp]
   incr mytimeout 60  ;# 60 seconds

   set ge_hosts [get_hedeby_default_services service_names]
   set s_names {}
   foreach geh $ge_hosts {
      lappend s_names $service_names(service,$geh)
   }
   set error_text ""
   # now set expected service states
   set expected_service_states "RUNNING"
   set expected_component_states "STARTED"
   lappend s_names "spare_pool"
   set service_names(master_host,spare_pool) $hedeby_config(hedeby_master_host)

   while { [timestamp] < $mytimeout } {
      ts_log_finer "obtaining service information ..."
      set ret [get_service_info]
      if {$ret != 0} {
         append error_text "get_service_info() returned $ret\n"
         break
      }

      # now check the service states
      set error_text ""
      foreach service $s_names {

         # check service availability
         ts_log_fine "checking service \"$service\" ..."
         if {[lsearch $service_info(service_list) $service] < 0} {
            append error_text "Service \"$service\" not found!\n"
            ts_log_fine "   service not found!"
         } else {
            ts_log_finer "   service found!"
         }
         # ceck component state
         if {[info exists service_info($service,cstate)]} {
            if {$service_info($service,cstate) != $expected_component_states} {
               append error_text "Service \"$service\" component state is \"$service_info($service,cstate)\""
               append error_text ", should be \"$expected_component_states\"\n"
               ts_log_fine "   component state \"$service_info($service,cstate)\" - error"
            } else {
               ts_log_finer "   component state \"$service_info($service,cstate)\" - ok"
            }
         } else {
            append error_text "cannot get component state for service \"$service\"\n"
            ts_log_fine "cannot get component state for service \"$service\""
         }

         # check service host
         if {[info exists service_info($service,host)]} {
            set service_info_host [resolve_host $service_info($service,host)]
            set expected_host [get_service_host $service_names(master_host,$service)]
            if {$service_info_host != $expected_host} {
               append error_text "Service \"$service\" is running on host \"$service_info_host\""
               append error_text ", should be \"$expected_host\"\n"
               ts_log_fine "   is running on host \"$service_info_host\" - error"
            } else {
               ts_log_finer "   is running on host \"$service_info_host\" - ok"
            }
         } else {
            append error_text "cannot get host for service \"$service\"\n"
            ts_log_fine "cannot get host for service \"$service\""
         }

         # check service state
         if {[info exists service_info($service,sstate)]} {
            if {$service_info($service,sstate) != $expected_service_states} {
               append error_text "Service \"$service\" service state is \"$service_info($service,sstate)\""
               append error_text ", should be \"$expected_service_states\"\n"
               ts_log_fine "   service state \"$service_info($service,sstate)\" - error"
            } else {
               ts_log_finer "   service state \"$service_info($service,sstate)\" - ok"
            }
         } else {
            append error_text "cannot get service state for service \"$service\"\n"
            ts_log_fine "cannot get service state for service \"$service\""
         }


      }
      if {$error_text == ""} {
         break  ;# fine no errors skip timeout loop
      }
      after 1000
      ts_log_fine "retry"
   }
   if {$error_text != ""} {
      append error_text "timeout waiting for correct service information!\n"
      ts_log_severe $error_text
      set ret_val 1
   }
   return $ret_val
}


#****** util/move_resources_to_default_services() ******************************
#  NAME
#     move_resources_to_default_services() -- move resources back to orig. services
#
#  SYNOPSIS
#     move_resources_to_default_services { } 
#
#  FUNCTION
#     move resources back to orig. services from testsuite installation
#
#  INPUTS
#
#  SEE ALSO
#     util/reset_hedeby()
#*******************************************************************************
proc move_resources_to_default_services {} {
   global hedeby_config
   ts_log_fine "Moving resources to default services ..."
   set ge_hosts [get_hedeby_default_services service_names]
   set expected_resource_list [get_all_default_hedeby_resources]
   set pref_type [get_hedeby_pref_type]
   set sys_name [get_hedeby_system_name]
   set admin_user [get_hedeby_admin_user]
   set exec_host $hedeby_config(hedeby_master_host)

   # first reset all blacklists
   set sdmadm_command "-p $pref_type -s $sys_name sb"
   sdmadm_command $exec_host $admin_user $sdmadm_command prg_exit_state "" 1 table
   for {set line 0} {$line < $table(table_lines)} {incr line 1} {
      set service $table(service,$line)
      set resource $table(resource_id,$line)
      set sdmadm_command "-p $pref_type -s $sys_name rrfb -r $resource -s $service"
      sdmadm_command $exec_host $admin_user $sdmadm_command
      if {$prg_exit_state != 0} {
         return 1
      }
   }

   set ret [get_resource_info "" "" resource_info resource_properties resource_list resource_ambiguous]
   if { $ret != 0 } {
      return 1
   }

   set error_text ""
   set mvr_list {}
   foreach res $expected_resource_list {
      set move_the_resource 1
      if {[info exists resource_info($res,service)]} {
         if { $resource_info($res,service) == $service_names(default_service,$res)} {
            set move_the_resource 0
            ts_log_fine "resource \"$res\" is already assigned to service \"$service_names(default_service,$res)\""
         }
      }
      if {$move_the_resource == 1} {
         set task_info($res,expected_output) ""
         set task_info($res,sdmadm_command) "-p $pref_type -s $sys_name mvr -force -r $res -s $service_names(default_service,$res)"
         lappend mvr_list $res
      }
   }
   if { [llength $mvr_list] > 0 } {
      set par_error [start_parallel_sdmadm_command mvr_list [get_hedeby_admin_user] task_info 0]
      if {$par_error != ""} {
         append error_text $par_error
      }
   }

   foreach res $expected_resource_list {
      set service_name $service_names(default_service,$res)
      set exp_resource_info($res,service) $service_name
      if {$service_name == "spare_pool"} {
         set exp_resource_info($res,flags) "{}"
      } else {
         if {$service_names(master_host,$service_name) == $res } {
            set exp_resource_info($res,flags) "S"
         } else {
            set exp_resource_info($res,flags) "{}"
         }
      }
      set exp_resource_info($res,state) "ASSIGNED"
   }
   set retval [wait_for_resource_info exp_resource_info 60 0 mvr_error]
   if { $retval != 0} {
      append error_text $mvr_error
   }
   if {$error_text != ""} {
      ts_log_severe $error_text
      return 1
   }
   return 0
}

#****** util/hedeby_check_default_resources() **********************************
#  NAME
#     hedeby_check_default_resources() -- check default resources
#
#  SYNOPSIS
#     hedeby_check_default_resources { } 
#
#  FUNCTION
#     1) check that all configured default resources are reported by hedeby 
#     2) check reported resource properties settings of the resources
#
#  INPUTS
#
#  RESULT
#     0 on success
#     1 on error
#
#  SEE ALSO
#     util/hedeby_check_default_services()
#     util/hedeby_check_default_resources()
#*******************************************************************************
proc hedeby_check_default_resources {} {
 

   # if the executor of a tests has been shutdown 
   # it can happen that some resources are for a short
   # time static. We use wait_for_resource_info_opt to
   # await that the resources have the correct state

   get_hedeby_default_services service_names

   foreach service $service_names(services) {
      # All moveable resource must be assigned to the service
      # they must be non static
      foreach res $service_names(moveable_execds,$service) {
         set ri($res,service) "$service" 
         set ri($res,flags) "{}"
         set ri($res,state) "ASSIGNED"
      }
      # The resource on master host must be static
      set res $service_names(master_host,$service)
      set ri($res,service) "$service" 
      set ri($res,flags) "S"
      set ri($res,state) "ASSIGNED"
   }

   # All spare_pool resource must be assigned to spare_pool
   foreach res [get_all_spare_pool_resources] {
      set ri($res,service) "spare_pool" 
      set ri($res,flags) "{}"
      set ri($res,state) "ASSIGNED"
   } 

   ts_log_fine "Waiting that all resources reach their default states .."

   set opt(timeout)    60
   set opt(res_prop)   reported_props
   set opt(res_list)   res_list
   set opt(res_list_not_uniq) res_list_not_uniq
   wait_for_resource_info_opt ri opt

   if {[info exists res_list_not_uniq] && [llength $res_list_not_uniq] > 0} {
      ts_log_severe "got ambiguous resources: $res_list_not_uniq"
      return 1
   }

   ts_log_fine "Checking for unexpected resources ..."
   set expected_resource_list [get_all_default_hedeby_resources]
   set unexpected_resources {}
   foreach res $res_list {
      if {[lsearch -exact $expected_resource_list $res] < 0} {
         lappend unexpected_resources $res
      }
   }

   if {[llength $unexpected_resources] != 0} {
      ts_log_severe "The following resource(s) are not expected in the default setup\n$unexpected_resources"
      return 1
   }

   # now check resource properties
   set error_text ""
   foreach res $expected_resource_list {
      ts_log_finer "checking resource properties of resource $res:"
      set osArch [resolve_arch $res]
      get_hedeby_ge_complex_mapping $osArch res_prop
      ts_log_finer "GE arch \"$osArch\" is mapped to props:"
      foreach name [array names res_prop] {
         ts_log_finer "   $name=$res_prop($name)"
         if {[info exists reported_props($res,$name)]} {
            if { $reported_props($res,$name) != $res_prop($name) } {
               append error_text "resource '$res' reported property '$name' with\n"
               append error_text "value '$reported_props($res,$name)', should be '$res_prop($name)'\n"
            } else {
               ts_log_finer "resource '$res' has property '$name' set to '$res_prop($name)' - fine!"
            }
         } else {
            append error_text "resource '$res' property '$name' is missing!\n"
         }
      }
   }

   if { $error_text != "" } {
      ts_log_severe $error_text
      return 1
   }
   return 0
}

#****** util/parse_table_output() **********************************************
#  NAME
#     parse_table_output() -- parse any sdmadm table output
#
#  SYNOPSIS
#     parse_table_output { output array_name delimiter } 
#
#  FUNCTION
#     This procedure can be used to parse any sdmadm table output which was
#     generated with column delimiter AND dupval option.
#     If table has AutoWordWrap enabled the first column of the table MUST
#     always have a value.
#     
#
#  INPUTS
#     output     - output from sdmadm which contains table 
#     array_name - name of array to save parsing results
#     delimiter  - table delimiter character (one character)
#
#  RESULT
#     no return value
#     array has following data structure:
#                  
#          array(table_lines)      - number of lines in table
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
proc parse_table_output { output array_name delimiter } {
   upvar $array_name data

   ts_log_finer "parsing table output ..."
   set columns {}
   set lines [split $output "\n\r"]
   set header_line ""
   set act_table_line -1
   for {set i 0} {$i<[llength $lines]} {incr i 1} {
      set line [lindex $lines $i]
      ts_log_finest "$line"

      if {[regexp "^(ERROR|WARNING|DEBUG):" $line]} {
         ts_log_fine "Skipping log message: $line"
         continue
      }
      
      if { $header_line == "" } {
         # still searching for header containing delimiter
         if { [string first $delimiter $line] >= 0 } {
            set header_line $line
            # now find out column index
            set column_nr 0
            set column_start($column_nr) 0
            set column_end($column_nr) 0
            ts_log_finer "header line: \"$header_line\""
            set last_pos 0
            while {1} {
               set pos [string first $delimiter $header_line $last_pos]
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
               #TCL array cannot contain a value with a space array(resource id,0) => TCL error
               set value [regsub -all " " $value "_"]
               set column_names($b) $value
               lappend table_col_list $value
               ts_log_finest "found column \"$column_names($b)\""
            }
            set data(table_columns) $table_col_list

         }
      } else {
         # here we have found an header
         
         # find out delimiter count of current line
         set is_table_line 0
         set nr_delimiters 0
         for {set b 0} {$b<[string length $line]} {incr b 1} {
            if {[string index $line $b] == $delimiter} {
               incr nr_delimiters 1
            }
         }
         if {$nr_delimiters == $column_nr} {
            set is_table_line 1
         }
 
         if { $is_table_line } {
            ts_log_finest "parsing table line \"[expr ($act_table_line + 1)]\""
            set is_word_wrap 0
            set column_nr 0
            set column_start($column_nr) 0
            set column_end($column_nr) 0
            set last_pos 0
            while {1} {
               set pos [string first $delimiter $line $last_pos]
               if { $pos < 0 } {
                  break
               }
               set column_end($column_nr) [ expr ( $pos - 1 ) ]
               incr column_nr 1
               set last_pos [ expr ( $pos + 1) ]
               set column_start($column_nr) $last_pos
            }
            set column_end($column_nr) "end"
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
                     set old_value [lindex $data($column_names($b),$act_table_line) 0]
                     set new_value "$old_value $value"
                     set data($column_names($b),$act_table_line) {}
                     lappend data($column_names($b),$act_table_line) $new_value
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
   if { $act_table_line >= 0 } {
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
#     {rl res_list} {da res_list_not_uniq} {raise_error 1}
#     {sdmout sdmadm_output} {system_name ""} {pref_type ""} } 
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
#     {raise_error 1}        - report errors
#                                 (default: 1)
#     {sdmout sdmadm_output} - variable to store sdmadm output 
#                                 (default: sdmadm_output)
#     {system_name ""}       - name of the hedeby system
#                                 (default: [get_hedeby_system_name])
#     {preference_type ""}   - preference type of the hedeby system
#                                 (default: [get_hedeby_pref_type])
#     { cached 0 }           - if the cached parameter is not 0 call sdmdm sr -cached
#     {ril res_id_list}      - name of tcl list where the resource ids are stored 
#     {service ""}           - name of the service
#     {res_filter "" }       - resource filter for sdmadm sr
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
#             res_info(<res_name>,INFO_TYPE) - resource info value
#             res_prop(<res_name>,PROPERTY)  - resource property value  
#             res_prop(<res_name>,prop_list) - resource property list
#             res_info(<res_id>,INFO_TYPE)   - resource info value
#             res_prop(<res_id>,PROPERTY)    - resource property value  
#             res_prop(<res_id>,prop_list)   - resource property list
#
#                where <res_name> is testsuite resource name
#                where <res_id>   is the id of the resource
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
proc get_resource_info { {host ""} {user ""} {ri res_info} {rp res_prop} {rl res_list} {da res_list_not_uniq} {raise_error 1} {sdmout sdmadm_output} {system_name ""} {preference_type ""} { cached 0 } {ril res_id_list} {service ""} {res_filter ""} } {
   global hedeby_config

   # setup arguments
   upvar $ri resource_info
   upvar $rp resource_properties
   upvar $da resource_ambiguous
   upvar $rl resource_list
   upvar $ril resource_id_list
   upvar $sdmout output
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
   if {$system_name == ""} {
      set sys_name [get_hedeby_system_name]
   } else {
      set sys_name $system_name
   }
   if {$preference_type == ""} {
      set pref_type [get_hedeby_pref_type]
   } else {
      set pref_type $preference_type
   }

   # first we delete possible existing info arrays
   if { [info exists resource_info] } {
      unset resource_info
   }
   if { [info exists resource_properties] } {
      unset resource_properties
   }

   # cleanup the lists
   set resource_ambiguous {}
   set resource_list {}
   set resource_id_list {}
   set double_assigned_resource_list {}

   # now we start sdmadm sr command ...
   set sdmadm_command "-d -p $pref_type -s $sys_name sr -all"

   if { $cached != 0 } {
      append sdmadm_command " -cached"
   }
   if {$service != "" } {
      append sdmadm_command " -s $service"
   }
   if {$res_filter != ""} {
      append sdmadm_command " -rf '$res_filter'"
   }
   set output [sdmadm_command $execute_host $execute_user $sdmadm_command prg_exit_state "" $raise_error table]
   if { $prg_exit_state != 0} {
      ts_log_severe "exit state of sdmadm $sdmadm_command was $prg_exit_state - aborting\noutput:\n$output" $raise_error
      return 1
   }
   if {![info exists table(table_columns)]} {
      # exit code 0 and no table output => no resources found
      ts_log_fine $output
      return 0
   }

   # we expect the following table commands for ShowResourceStateCliCommand ...
   set exp_columns {}

   set res_id_col [create_bundle_string "ShowResourceStateCliCommand.col.id"]
   lappend exp_columns $res_id_col

   if {[exists_bundle_string ShowResourceStateCliCommand.col.name]} {
      set res_name_col [create_bundle_string "ShowResourceStateCliCommand.col.name"]
      # Since version > 1.0u3 we have the additional column resource name
      lappend exp_columns $res_name_col
   } else {
      # We have a sdm <= 1.0u3 (without bound resource)
      # Take the resource name from the id column
      set res_name_col [create_bundle_string "ShowResourceStateCliCommand.col.id"]
   }
   
   set res_service_col [create_bundle_string "ShowResourceStateCliCommand.col.service"]
   lappend exp_columns $res_service_col
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.state"]
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.type"]
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.anno"]
   set flags_col [create_bundle_string "ShowResourceStateCliCommand.col.flags"]
   lappend exp_columns $flags_col
   lappend exp_columns [create_bundle_string "ShowResourceStateCliCommand.col.usage"]

   set res_ignore_list {}
   lappend res_ignore_list [create_bundle_string "ShowResourceStateCliCommand.error"]
   foreach col $exp_columns {
      set pos [lsearch -exact $table(table_columns) $col]
      if {$pos < 0} {
         ts_log_severe "cannot find expected column name \"$col\"" $raise_error
         return 1
      }
      ts_log_finer "found expected col \"$col\" on position $pos"
   }
   
   # now we fill up the arrays ... 

   for {set line 0} {$line < $table(table_lines)} {incr line 1} {
       #ts_log_fine "Processing line $line ------------------------------------"
       #foreach col $table(table_columns) {
       #   ts_log_fine ="table\[$line,$col\]=$table($col,$line)"
       #}
      set resource_name $table($res_name_col,$line)
      set resource_id   $table($res_id_col,$line)

      set do_ignore 0
      foreach ignore_resource $res_ignore_list {
         if { [string match $ignore_resource $resource_name] } {
            set do_ignore 1
            break
         }
      }
      if {!$do_ignore} {
         # if resources are e.g. in state UNASSIGNING at resource
         # provider the resources have the @SERVICE appended
         # => Testsuite is ignoring appendix of hostname
         set help [split $resource_name "@"]
         set ts_resource_name [lindex $help 0]
       
         # Resolve the hostname only of the resource is bound 
         if { [string first $table($flags_col,$line) "U"] < 0 } {
            set ts_resource_name [resolve_host $ts_resource_name]
            if {$ts_resource_name != $resource_name} {
               ts_log_finer "using resource name \"$ts_resource_name\" for resource id \"$resource_name\""
            }
         }

         lappend resource_id_list $resource_id
         if { [lsearch -exact $resource_list $ts_resource_name] < 0 } { 
            lappend resource_list "$ts_resource_name"
            set res_line($ts_resource_name) $line
         } else {
            ts_log_fine "Found double assigned resource '$ts_resource_name' in line $line"
            ts_log_fine "Duplicate defined in line $res_line($ts_resource_name)"
            lappend double_assigned_resource_list $ts_resource_name
         }
         foreach col $table(table_columns) {
            if {![info exists resource_info($ts_resource_name,$col)]} {
               set resource_info($ts_resource_name,$col) {}
               set resource_info($resource_id,$col) {}
            }
            lappend resource_info($ts_resource_name,$col) [lindex $table($col,$line) 0]
            lappend resource_info($resource_id,$col) [lindex $table($col,$line) 0]
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
         ts_log_finer "SKIPPING RESOURCE \"$resource_name\"!"
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
      ts_log_finer $error_text
   }

   if { [llength $double_assigned_resource_list] > 0 } {
      ts_log_fine "double assigned resources: $double_assigned_resource_list"
   }
   ts_log_finer "resource list: $resource_list"
   set resource_ambiguous $double_assigned_resource_list

   return 0
}

#****** util/get_resource_info_opt() **************************************************
#  NAME
#     get_resource_info_opt() -- get resource information (via sdmadm sr)
#
#  SYNOPSIS
#     get_resource_info_opt { arg_line {opt ""} } {
#
#  FUNCTION
#     This procedure is the optional argument passing version of
#     get_resource_info(). For a description of the command, see there.
#
#  INPUTS
#     {ri res_info}          - name of array for resource informations
#                                 (default: res_info)
#
#     opt                    - optional named arguments, see get_hedeby_proc_default_opt_args()
#     opt(res_prop)          - variable name, see get_resource_info() (default: res_prop)
#     opt(res_list)          - variable name, see get_resource_info() (default: res_list)
#     opt(res_list_not_uniq) - variable name, see get_resource_info() (default: res_list_not_uniq)
#     opt(sdmadm_output)     - variable name, see get_resource_info() (default: sdmadm_output)
#     opt(res_id_list)       - variable name, see get_resource_info() (default: res_id_list)
#     opt(service)           - name of the service (default: "")
#     opt(cached)            - use the -cached option? (default: 0 => don't use)
#     opt(res_filter)        - resource filter for the sdmadm sr command (default: "")
#
#  RESULT
#     Return value: "0" on success, "1" on error 
#
#  SEE ALSO
#     util/get_resource_info()
#     util/get_hedeby_proc_opt_arg()
#*******************************************************************************
proc get_resource_info_opt { {ri res_info} {opt ""} } {
   upvar $ri u_ri

   # set function default optional arguments
   set opts(res_prop)          "res_prop"
   set opts(res_list)          "res_list"
   set opts(res_list_not_uniq) "res_list_not_uniq"
   set opts(sdmadm_output)     "sdmadm_output"
   set opts(res_id_list)       "res_id_list"
   set opts(res_filter)        ""
   set opts(cached)            0
   set opts(service)           ""

   get_hedeby_proc_opt_arg $opt opts

   upvar $opts(res_prop)          u_res_prop
   upvar $opts(res_list)          u_res_list
   upvar $opts(res_list_not_uniq) u_res_list_not_uniq
   upvar $opts(sdmadm_output)     u_sdmadm_output
   upvar $opts(res_id_list)       u_res_id_list

   return [get_resource_info $opts(host) $opts(user) \
               u_ri u_res_prop u_res_list u_res_list_not_uniq \
               $opts(raise_error) u_sdmadm_output \
               $opts(system_name) $opts(pref_type) $opts(cached) \
               u_res_id_list $opts(service) $opts(res_filter) ]
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
#                              It is possible to specifiy more than only
#                              one expected resource info. The resource
#                              will match when one of the specified entries
#                              matches.
#                              If there are resource infos expected which
#                              are not reported the resource info is set
#                              to the value "missing"
#     {atimeout 60}          - optional timeout specification in seconds 
#     {raise_error 1}        - report testsuite errors if != 0
#     {ev error_var }        - report error text into this tcl var
#     {host ""}              - see get_resource_info() 
#     {user ""}              - see get_resource_info() 
#     {ri res_info}          - see get_resource_info() (except the added
#                              resource info for "missing" values)
#     {rp res_prop}          - see get_resource_info() 
#     {rl res_list}          - see get_resource_info() 
#     {da res_list_not_uniq} - see get_resource_info() 
#     {expect_no_ambiguous_resources 0} - if set to 1: don't expect ambiguous resources
#     { cached }             - see get_resource_info()
#     {ril res_id_list}      - name of tcl list where the resource ids are stored 
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
#     util/wait_for_service_info()
#*******************************************************************************
proc wait_for_resource_info { exp_resinfo  {atimeout 60} {raise_error 1} {ev error_var } {host ""} {user ""} {ri res_info} {rp res_prop} {rl res_list} {da res_list_not_uniq} {expect_no_ambiguous_resources 0} { cached 0 } {ril res_id_list} } {
   global hedeby_config
   # setup arguments
   upvar $exp_resinfo exp_res_info
   upvar $ev error_text_up
   upvar $ri resource_info
   upvar $rp resource_properties
   upvar $da resource_ambiguous
   upvar $rl resource_list
   upvar $ril resource_id_list


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
   if {![info exists error_text_up]} {
      # some calling code relies on the initialization of the error_text variable
      set error_text_up ""
   }
   set error_text ""
   set my_timeout [timestamp]
   incr my_timeout $atimeout

   # set expected results info
   set expected_resource_info ""
   set exp_values [array names exp_res_info]
   foreach val $exp_values {
      append expected_resource_info "$val=\"$exp_res_info($val)\"\n"
   }
   ts_log_finer "expected resource infos:\n$expected_resource_info"

   set system_name ""
   set prefs_type ""

   while {1} {
      set retval [get_resource_info $host $user resource_info resource_properties resource_list \
                                    resource_ambiguous $raise_error sdmadm_output \
                                    $system_name $prefs_type $cached resource_id_list]
      if {$retval != 0} {
         append error_text "break because of get_resource_info() returned \"$retval\"!\n$sdmadm_output\n"
         append error_text "expected resource info was:\n$expected_resource_info"
         ts_log_fine "ignore this run because get_resource_info() returned: $retval"
         foreach val $exp_values {
            if {![info exists resource_info($val)]} {
               set resource_info($val) "missing"
            }
         }
         break
      }
      set not_matching ""
      unset -nocomplain not_matching_res

      foreach val $exp_values {
         if {![info exists resource_info($val)]} {
            set resource_info($val) "missing"
         }
            set all_matching 0
            if {[llength $resource_info($val)] == [llength $exp_res_info($val)]} {
               ts_log_finer "compare \"$resource_info($val)\" with \"$exp_res_info($val)\""
               # here we can directly compare the expected resource info
               if { $resource_info($val) == $exp_res_info($val) } {
                  set all_matching 1
               }
            } else {
               # duplicate assigned resources may produce more than one entry
               # in resource_info() array. We expect that all states have to be
               # equal
               set all_matching 1
               foreach res_info_tmp $resource_info($val) {
                  set one_is_matching 0
                  foreach exp_res_info_entry $exp_res_info($val) {
                     ts_log_finer "lcompare \"$res_info_tmp\" with \"$exp_res_info_entry\""
                     if {$res_info_tmp == $exp_res_info_entry} {
                        ts_log_finer "lcompare matching"
                        set one_is_matching 1
                        break
                     }
                  }
                  if {$one_is_matching == 0} {
                     ts_log_finer "lcompare not matching"
                     set all_matching 0
                     break
                  }
               }
            }
         if {$all_matching} {
            ts_log_finer "resource info(s) \"$val\" matches expected info \"$exp_res_info($val)\""
         } else {
            append not_matching "resource info \"$val\" is set to \"$resource_info($val)\", should be \"$exp_res_info($val)\"\n"
            set index [string first "," $val]
            if {$index > 0 } {
               set res_name [string range $val 0 $index]
               set not_matching_res($res_name) 1
            } else {
               ts_log_fine "Not matching resource value '$val' does not contain a comma, don't know the resource"
            }
         }
      }

      if {[info exists not_matching_res]} {
         set not_matching_res_count [array size not_matching_res]
      } else {
         set not_matching_res_count 0
      }

      set cur_time [timestamp]
      set cur_time_left [expr ($my_timeout - $cur_time)]

      set sleep_time [expr $cur_time_left / 60]
      if {$sleep_time < 1} {
         set sleep_time 1
      } elseif {$sleep_time > 10 } {
         set sleep_time 10
         ts_log_fine "Next try in $sleep_time seconds"
      }

      if {$not_matching == ""} {
         ts_log_fine "all specified resource info are matching"
         if {[llength $resource_ambiguous] > 0 && $expect_no_ambiguous_resources != 0} {
            ts_log_fine "but waiting for ambiguous resources to disappear ..."
            append not_matching "resource ambiguous list is not empty: \"$resource_ambiguous\"\n"
         } else {
            break
         }
      } else {
         ts_log_fine "$not_matching_res_count resources are still not matching ... (timeout in ${cur_time_left}s, next try in ${sleep_time}s))"
         if {$not_matching_res_count < 10} {
            ts_log_fine "still not matching resource info:\n$not_matching"
         }
      }
      if {[timestamp] >= $my_timeout} {
         append error_text "==> TIMEOUT(=$atimeout sec) while waiting for expected resource states!\n"
         append error_text "==> NOT matching values:\n$not_matching"
         break
      }

      after [expr $sleep_time * 1000]
   }  ;# end of while{1}

   if {$error_text != "" } {
      append error_text_up $error_text
      ts_log_severe $error_text $raise_error
      return 1
   }
   return 0
}

#****** util/wait_for_resource_info_opt() **************************************
#  NAME
#     wait_for_resource_info_opt() -- wait for resource info 
#
#  SYNOPSIS
#     wait_for_resource_info_opt { exp_res_info { opt "" } } 
#
#  FUNCTION
#
#     This procedure calls get_resource_info() until the specified component
#     information or a timeout occurs.
#
#     This method is the optional argument passing version of wait_for_resource_info.
#
#  INPUTS
#     exp_res_info - see wait_for_resource_info
#     { opt "" }    - options for this command. Besides the standard options
#                     this command supports the following options:
#
#       opt(timeout)                         - timeout in seconds (default is 60)
#       opt(res_info)                        - name of the tcl array (upvar) where the found
#                                              resource info is stored 
#       opt(error_var)                       - name of the upvar variable where error messages will 
#                                              be stored
#       opt(res_prop)                        - name of the tcl array where the resource properties for each
#                                              found resource is stored  
#       opt(res_list)                        - name of the variable (upvar) where the list of found resources
#                                              is stored
#       opt(res_id_list)                     - name of the variable (upvar) where the list of found resource ids is stored
#       opt(res_list_not_uniq)               - name of the variable (upvar) where the list of non unique resources
#                                              is stored
#       opt(expect_not_ambiguous_resources)  - If set to 1 the command checks that no ambiguous resources are avaiable
#                                              (default: 0)
#       opt(cached)                          - If not 0 sdmadm sr -cached will be called to check the resources
# 
#  INPUTS
#     exp_res_info - expected resource info (see wait_for_resource_info) 
#     { opt "" }   - option array 
#
#  RESULT
#     0 on success , 1 on error
#
#  EXAMPLE
#
#     set opt(timeout) 30
#     set opt(res_info) res_info
#     set opt(res_prop) res_prop
#     set opt(res_list) res_list
#     set opt(res_list_not_uniq) res_list_not_uniq
#
#     if {[wait_for_resource_info_opt exp_res_info opt] != 0 } {
#        return
#     }
#     puts "     Found resources: $res_list"
#     puts " Resource properties: [format_array res_prop]"
#     puts "Not unique Resources: $res_list_not_uniq"
#
#  SEE ALSO
#     util/wait_for_resource_info
#     util/get_resource_info
#     util/get_hedeby_proc_opt_arg 
#*******************************************************************************
proc wait_for_resource_info_opt { exp_res_info { opt "" } } {

   upvar $exp_res_info exp_info

   set opts(timeout)    60
   set opts(error_var)  ""
   set opts(res_info)   ""
   set opts(res_prop)    ""
   set opts(res_list)    ""
   set opts(res_id_list)   ""
   set opts(res_list_not_uniq) ""
   set opts(expect_no_ambiguous_resources) 0
   set opts(cached) 0

   get_hedeby_proc_opt_arg $opt opts

   if { $opts(error_var) != "" } {
      upvar $opts(error_var) error_var
   }

   if { $opts(res_info) != "" } {
      upvar $opts(res_info) res_info
   }

   if { $opts(res_prop) != "" } {
      upvar $opts(res_prop) res_prop
   }

   if { $opts(res_list) != "" } {
      upvar $opts(res_list) res_list
   }

   if { $opts(res_id_list) != "" } {
      upvar $opts(res_id_list) res_id_list
   }

   if { $opts(res_list_not_uniq) != "" } {
      upvar $opts(res_list_not_uniq) res_list_not_uniq
   }

   return [wait_for_resource_info exp_info  $opts(timeout) $opts(raise_error) error_var\
                                  $opts(host) $opts(user) res_info res_prop res_list \
                                  res_list_not_uniq $opts(expect_no_ambiguous_resources) $opts(cached) res_id_list]
}

#****** util/wait_for_service_info() *******************************************
#  NAME
#     wait_for_service_info() -- wait for expected service state information
#
#  SYNOPSIS
#     wait_for_service_info { exp_serv_info {atimeout 60} {raise_error 1} 
#     {ev error_var } {host ""} {user ""} {si service_info} } 
#
#  FUNCTION
#     This procedure calls get_service_info() until the specified service
#     information or a timeout occurs.
#
#  INPUTS
#     exp_serv_info     - expected service info (same structure like
#                         get_service_info() is returning).
#     {atimeout 60}     - optional timeout specification in seconds
#     {raise_error 1}   - report testsuite errors if != 0
#     {ev error_var }   - report error text into this tcl var 
#     {host ""}         - see get_service_info()
#     {user ""}         - see get_service_info() 
#     {si service_info} - see get_service_info() 
#
#  RESULT
#     0 on success, 1 on error
#     setting of tcl arrays like known from get_service_info()
#
#  EXAMPLE
#     set exp_service_info(spare_pool,cstate) "STARTED"
#     set exp_service_info($aservice,sstate) "STOPPED"
#     wait_for_service_info exp_service_info
#
#
#  SEE ALSO
#     util/get_service_info()
#     util/wait_for_resource_info()
#*******************************************************************************
proc wait_for_service_info { exp_serv_info  {atimeout 60} {raise_error 1} {ev error_var } {host ""} {user ""} {si service_info} } {
   global hedeby_config
   # setup arguments
   upvar $exp_serv_info exp_srv_info
   upvar $ev error_text_up
   upvar $si service_info
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
   if {![info exists error_text_up]} {
      # some calling code relies on the initialization of the error_text variable
      set error_text_up ""
   }
   set error_text ""
   set my_timeout [timestamp]
   incr my_timeout $atimeout

   # set expected results info
   set expected_service_info ""
   set exp_values [array names exp_srv_info]
   foreach val $exp_values {
      append expected_service_info "$val=\"$exp_srv_info($val)\"\n"
   }
   ts_log_fine "expected service infos:\n$expected_service_info"

   while {1} {
      set retval [get_service_info $host $user service_info $raise_error]
      if {$retval != 0} {
         append error_text "break because of get_service_info() returned \"$retval\"!\n"
         append error_text "expected service info was:\n$expected_service_info"
         break
      }

      set not_matching ""
      foreach val $exp_values {
         if {[info exists service_info($val)]} {
            if { $service_info($val) == $exp_srv_info($val)} {
               ts_log_fine "service info \"$val\" matches expected info \"$exp_srv_info($val)\""
            } else {
               append not_matching "service info \"$val\" is set to \"$service_info($val)\", should be \"$exp_srv_info($val)\"\n"
            }
         } else {
            append not_matching "service info \"$val\" not available\n"
         }
      }

      if {$not_matching == ""} {
         ts_log_fine "all specified service info is matching"
         break
      } else {
         ts_log_fine "still waiting for specified service settings ..."
         ts_log_fine "still not matching service info:\n$not_matching"
      }

      if {[timestamp] >= $my_timeout} {
         append error_text "==> TIMEOUT(=$atimeout sec) while waiting for expected service states!\n"
         append error_text "==> NOT matching values:\n$not_matching"
         break
      }
      after 1000
   }

   if {$error_text != "" } {
      append error_text_up $error_text
      if {$raise_error != 0} {
         ts_log_severe $error_text
      }
      return 1
   }
   return 0
}


#****** util/get_history() **************************************************
#  NAME
#    get_history() -- Get the output of the sdmadm show_history command
#
#  SYNOPSIS
#    get_history { } 
#
#  FUNCTION
#     Parses the output of the sdmadm show_history command and stores
#     the information in an tcl array.
#
#  INPUTS
#    filter_args --  filter arguments like -sd or -ed
#    hist_info   --  array where the found history is stored 
#    opt         --  Default options
#
#  RESULT
#    0  -- Success, the history is store in the hi array in the following form:
#           hist_info(lines)   - contains the number of lines
#           hist_info(<line index>,time)        -  timestamp of the row as string
#           hist_info(<line index>,millis)      -  timestamp of the rows in millis
#                                                  if the content of the time column can
#                                                  not be parsed the value is set to -1
#           hist_info(<line index>,type)        -  type if the notification
#           hist_info(<line index>,service)     -  name of the service
#           hist_info(<line index>,resource)    -  the resource name
#           hist_info(<line index>,resource_id) -  the id of the resource
#           hist_info(<line index>,desc)        -  description (annotation)
#    else -- error
#  EXAMPLE
#
#  get_history "-sd 09:00 -ed 09:12" hi
#  for {set i 0}{$i < $hi(lines)}{incr i} {
#       puts "Got $hi($i,type) notification from $hi($i,service)"
#  }
#
#*******************************************************************************
proc get_history { filter_args hist_info_array {opt ""} } {

   get_hedeby_proc_opt_arg $opt opts

   upvar $hist_info_array hist_info
 
   set opts(table_output) table 
   sdmadm_command_opt "shist $filter_args" opts
   if { $prg_exit_state != 0 } {
      ts_log_severe "exit state of sdmadm $cmd_args was $prg_exit_state - aborting" $raise_error
      return 1
   }
   
   
   # we expect the following table commands for ShowResourceStateCliCommand ...
   set exp_columns {}
   
   lappend exp_columns [create_bundle_string "GetReporterDataCliCommand.col.time"]
   lappend exp_columns [create_bundle_string "GetReporterDataCliCommand.col.type"]
   lappend exp_columns [create_bundle_string "GetReporterDataCliCommand.col.service"]
   lappend exp_columns [create_bundle_string "GetReporterDataCliCommand.col.resid"]
   lappend exp_columns [create_bundle_string "GetReporterDataCliCommand.col.desc"]

   lappend res_ignore_list [create_bundle_string "ShowResourceStateCliCommand.error"]
   foreach col $exp_columns {
      set pos [lsearch -exact $table(table_columns) $col]
      if {$pos < 0} {
         ts_log_severe "sdmadm shist: cannot find expected column name \"$col\"" $raise_error
         return 1
      }
      ts_log_finer "found expected col \"$col\" on position $pos"
   }
   
   set time_col    [lindex $exp_columns 0]
   set type_col    [lindex $exp_columns 1]
   set service_col [lindex $exp_columns 2]
   set res_col     [lindex $exp_columns 3]
   set desc_col    [lindex $exp_columns 4]

   # now we fill up the arrays ... 
   set hist_info(lines) $table(table_lines)
   
   for {set line 0} {$line < $table(table_lines)} {incr line 1} {
      
      # parse the time string into millis
      #           0    5    10   15   20
      #           +----+----+----+----+--
      # format is mm/dd/yyyy HH:MM:SS.mmm
      
      # The table output of the sdmadm command contains only lists, we need the first element
      set time_str [lindex $table($time_col,$line) 0]
      set time_str_len [string length $time_str]
      if {$time_str_len < 21 || $time_str_len > 23} {
         ts_log_severe "Could not parse time_str \"$time_str\" from history (invalid string length $time_str_len)" $opts(raise_error)
         return 1
      } else {
         set clock_str [string range $time_str 0 18]
         set ms_str   [string range $time_str 20 $time_str_len]
         set seconds 0
         set catch_ret [catch {clock scan $clock_str} seconds]
         if {$catch_ret != 0} {
            ts_log_severe "Could not parse time_str \"$time_str\" from history (clock_str=\"$clock_str\")" $opts(raise_error)
            return 1
         } elseif {[string is digit $ms_str]} {
            # explicitly cast the $seconds to wide (=at least 64bit) so that
            # millis is also at least a 64bit integer => otherwise there would
            # be a int overflow with 32 bit TCL binaries
            set millis [expr wide($seconds) * 1000 + $ms_str]
         } else {
            ts_log_severe "Could not parse time_str \"$time_str\" from history (invalid ms_str \"$ms_str\")" $opts(raise_error)
            return 1
         }
      }
      set hist_info($line,time)     [lindex $table($time_col,$line) 0]
      set hist_info($line,millis)   $millis
      set hist_info($line,type)     [lindex $table($type_col,$line) 0]
      set hist_info($line,service)  [lindex $table($service_col,$line) 0]

      # Since version 1.0u5 the resource name is printed in the format
      # <res_name>(<res_id>). If the following regexp does not match
      # we have an older SDM system
      if {[regexp "(\[^\\(\]+)\\((res#\[^\\)]*)\\)" $table($res_col,$line) match_str res_name res_id]} {
         set hist_info($line,resource) $res_name
         set hist_info($line,resource_id) $res_id
      } else {
         # old system => resource id = resource name
         set hist_info($line,resource) $table($res_col,$line)
         set hist_info($line,resource_id) $table($res_col,$line)
      }
      set hist_info($line,desc)     [lindex $table($desc_col,$line) 0]
   }
   return 0
}

#****** util/wait_for_notification() *******************************************
#  NAME
#     wait_for_notification() -- wait for a sequence of events in the sdm history 
#
#  SYNOPSIS
#     wait_for_notification { start_time exp_history error_history 
#     {atimeout 60} {raise_error 1} {host ""} {user ""} } 
#
#  FUNCTION
#     This method poll every 3 seconds the history of the sdm system (sdmadm shist)
#     and search in the result for a sequence of events.
#     It will stop if 
#       - events do not occur in the correct order
#       - the timeout is reached
#       - an event of the error history has been found 
#
#  INPUTS
#     start_time      - starttime for the search in the history
#     exp_history     - array with the expected event sequence in the form
#                        exp_history(count)            -- number of expected events
#                        exp_history(<index>,type)     -- type of event
#                        exp_history(<index>,resource) -- resource of the event
#                        exp_history(<index>,service)  -- service of the event
#
#     error_history   - array with the unexpected events (has the same form as the 
#                       exp_history 
#     opt             - opt array. The following options are supported:
#
#          opt(timeout)  - max waiting time for the expected events (in seconds, default 60s)
#          opt(hist_ret) - upvar where the found history events will be stored in the form
#                 hist_ret(count)               -- number of found lines
#                 hist_ret(<index>,time)        -- timestamp of the history line
#                 hist_ret(<index>,type)        -- the type of the notification
#                 hist_ret(<index>,resource)    -- the resource
#                 hist_ret(<index>,resource_id) -- the resource id
#                 hist_ret(<index>,service)     -- the service
#                 hist_ret(<index>,desc)        -- the description of the notification
#          opt(ensure_correct_event_order)   -- If set to 1 ensure that the events are received in
#                                               exactly the same order as specified in exp_history
#                                               If set to 0 the events can be received in a arbitrary 
#                                               order (default is 1)
#          opt(ignore_unexpected_events)     -- If set to 1 unexpected events (not defined in exp_history
#                                               and error_history) are siliently ignored
#                                               If set to 0 an error will be reported once a unpexpected
#                                               has been found between the events defined in exp_history
#                                               (default is 1)
#                                               
#  RESULT
#     0    --   all expected events received
#     else --   error 
#
#  EXAMPLE
#     set hist(0,resource) $ge_unassign_resources_ctx(host_name)
#     set hist(0,type)     "RESOURCE_REMOVE"
#     set hist(0,service)  $ge_unassign_resources_ctx(service_name)
#     
#     set hist(1,resource) $ge_unassign_resources_ctx(host_name)
#     set hist(1,type)     "RESOURCE_REMOVED"
#     set hist(1,service)  $ge_unassign_resources_ctx(service_name)
#     
#     set hist(count) 2
#
#     set start_time [expr [clock seconds] - 60]
#     wait_for_notification $start_time  hist err_hist 60
# 
#  NOTES
#
#*******************************************************************************
proc wait_for_notification {start_time exp_history error_history  {opt ""} } {
   
   set opts(timeout)                     60
   set opts(hist_ret)                    ""
   set opts(ensure_correct_event_order)  1
   set opts(ignore_unexpected_events)    1

   get_hedeby_proc_opt_arg $opt opts

   if {$opts(hist_ret) != ""} {
      upvar $opts(hist_ret) hist_ret
   } 

   upvar $exp_history     exp_hist
   upvar $error_history   error_hist

   private_wait_for_notification_setup exp_hist error_hist this

   set cmd_args [private_wait_for_notification_build_args $start_time exp_hist error_hist this]
   ts_log_fine "Searching in history ($cmd_args)"
   
   set my_timeout [timestamp]
   incr my_timeout $opts(timeout)


   set error_event_index_list {}
   for {set i 0} {$i < $error_hist(count)} {incr i} {
      lappend error_event_index_list $i
   }



   set this(report_cols) { "time" }

   foreach val $this(existing_vals) {
       lappend this(report_cols) $val
   }

   # Setup the options for the get_history call
   copy_hedeby_proc_opt_arg opts history_opts "defaults" 

   while {1} {

      unset -nocomplain hist_info
    
      if {[get_history $cmd_args hist_info history_opts] != 0} {
         return -1
      }

      # The missing_event_list contains the index of any event that have not been found
      # in the history. If an event is found the index is removed from the list
      # If the list is empty all expected events has been found
      set missing_event_index_list {}
      for {set i 0} {$i < $exp_hist(count)} {incr i} {
         lappend missing_event_index_list $i
      }

      set this(report_rows) {}
      unset -nocomplain report_data
      set this(report_data) report_data
      set found_error 0
      unset -nocomplain hist_ret
      set hist_ret(count) 0
      
   
      for {set line 0} {$line < $hist_info(lines) && $found_error == 0 && [llength $missing_event_index_list] > 0} {incr line} {
         # search the event at line line of hist_info in exp_hist. Only the events that
         # are also defined in the missing_event_index_list are considered
         set index [private_wait_for_notification_search_event hist_info $line exp_hist this $missing_event_index_list]

         if {$index < 0} {
            # We did not find the event from hist_info($line) in the exp_hist
            # (considering the missing_event_index_list)
            if {[llength $missing_event_index_list] == $exp_hist(count)} {
               # We still have not found any event from the expected event block
               # Check only that the event does not match an event from error_hist
               set mode "look_for_error_event"
            } else {
               # The expected event block began. We found already an event
               # If ignore_unexpected_events is not set produce an error
               if {$opts(ignore_unexpected_events) == 0} {
                  set mode "unexpected_event"
               } else { ;# Ignore unexpected event, may be it is in the error history
                  set mode "look_for_error_event"
               }
            }
         } else {
             # Found the event hist_info($line) in exp_hist (considering the missing_event_index_list)
             if {$opts(ensure_correct_event_order)} {
               if {[lindex $missing_event_index_list 0] == $index} {
                  set mode "found_event"
               } elseif { [llength $missing_event_index_list] == $exp_hist(count)} {
                  # We still have not found any event from the expected event block
                  # Check only that the event does not match an event from error_hist
                  set mode "look_for_error_event"
               } else {
                  # The ensure_correct_event_order is set, but the event is not the first in
                  # the missing_event_index_list
                  # => report missing events
                  set mode "missing_events"
               }
             } else {
               # The ensure_correct_event_order is not set, we accept the event no matter in
               # what order it arrived
               set mode "found_event"
               set missing_event_index_list [remove_from_list $missing_event_index_list $index]
               set found_exp_event 1
             }
         }
         # Depending on the value of mode we perform different
         # actions
         switch -- $mode {
            "unexpected_event" {
               private_wait_for_notification_report "Unexpected event" this hist_info $line 
               set found_error 1 
            }
            "look_for_error_event" {
                set err_index [private_wait_for_notification_search_event hist_info $line \
                               error_hist this $error_event_index_list]
                if {$err_index >= 0} {
                  private_wait_for_notification_report "Event from error_history" this hist_info $line 
                  set found_error 1
                }
            }
            "found_event" {
               set i $hist_ret(count) 
 
               set hist_ret($i,time)        $hist_info($line,time)
               set hist_ret($i,millis)      $hist_info($line,millis)
               set hist_ret($i,type)        $hist_info($line,type)
               set hist_ret($i,resource)    $hist_info($line,resource)
               set hist_ret($i,resource_id) $hist_info($line,resource_id)
               set hist_ret($i,desc)        $hist_info($line,desc)
               incr hist_ret(count)
               set missing_event_index_list [remove_from_list $missing_event_index_list $index]
               private_wait_for_notification_report [format "Found %d/%d" [expr $i + 1] $exp_hist(count)] \
                                                    this hist_info $line 
               set found_error 0
            }
            "missing_events" {
               set line_msg ""
               foreach i $missing_event_index_list {
                  if {$i >= $index} {
                     break
                  }
                  set found_error 1
                  private_wait_for_notification_report [format "Missing %d/%d" [expr $i + 1] $exp_hist(count)] \
                                                       this exp_hist $i 
               }
               set i $hist_ret(count) 
               private_wait_for_notification_report [format "Found %d/%d" [expr $i + 1] $exp_hist(count)] \
                                                    this hist_info $line 
            }
            "duplicate_event" {
               private_wait_for_notification_report "Duplicate Event" this hist_info $line 
               set found_error 1
            }
            default {
               private_wait_for_notification_report "Internal Error: Invalid mode '$mode'" this hist_info $line 
               set found_error 1
            }
         }
      } ; # end of for
      set msg [print_xy_array $this(report_cols) $this(report_rows) report_data]
      if {$found_error} {
         ts_log_severe $msg $opts(raise_error)
         return -1
      } 
      ts_log_fine $msg
      if {[llength $missing_event_index_list] == 0} {
         ts_log_fine "Found all expected events in the history"
         return 0
      }
      if {[timestamp] >= $my_timeout} {
         ts_log_severe "==> TIMEOUT(=$opts(timeout) sec) while waiting for expected history info" $opts(raise_error)
         return -1
      }
      after 3000
   }
   return 0
}

#****** util/private_wait_for_notification_report() ****************************
#  NAME
#     private_wait_for_notification_report() -- Add a report line to the report
#
#  SYNOPSIS
#     private_wait_for_notification_report { message ctx hi line } 
#
#  FUNCTION
#
#      This method add a report line to the context of a wait_for_notification
#      call
#
#  INPUTS
#     row_id - row identifier 
#     ctx    - The context of the wait_for_notification call
#              
#     hi     - the array containing the history 
#     line   - the line index in hi
#
#  RESULT
#     Nothing
#
#  NOTES
#
#     This method is an internal method. It should only be used by wait_for_notification
#
#  SEE ALSO
#     util/wait_for_notification
#*******************************************************************************
proc private_wait_for_notification_report { row_id ctx hi line } {

   upvar $ctx                this
   upvar $this(report_data)  data
   upvar $hi                 hist_info

   lappend this(report_rows) $row_id

   foreach val $this(report_cols) {
       set str ""
       if {[info exists hist_info($line,$val)]} {
          set str $hist_info($line,$val)
       }
       set data($val,$row_id) $str
   }
}

#****** util/private_wait_for_notification_setup() ******************************
#  NAME
#     private_wait_for_notification_setup() -- set up the context for a 
#                                           wait_for_notification method
#
#  SYNOPSIS
#     private_wait_for_notification_setup { a_exp_hist a_error_hist a_ctx }
#
#  FUNCTION
#
#     This method sets up the context for a wait_for_notification method. In addition
#     it prints out tables containing the expected and error history
#
#  INPUTS
#     a_exp_hist   - the expected history array
#     a_error_hist - the error history array
#     ctx          - the context for the wait_for_notification call
#                    This method adds the following values to the context
#
#          ctx(allowed_vals)   - list of allowed values for exp_hist and error_hist
#          ctx(existing_vals) - list of defined values from exp_hist and error_hist
#
#  RESULT
#
#     No result
#
#  NOTES
#
#     This method is an internal method. It should only be used by wait_for_notification
#
#  SEE ALSO
#     util/wait_for_notification()
#*******************************************************************************
proc private_wait_for_notification_setup { a_exp_hist a_error_hist a_ctx } {

   upvar $a_exp_hist exp_hist
   upvar $a_error_hist error_hist
   upvar $a_ctx this

   set this(allowed_vals) { "type" "resource"  "resource_id" "service" } 
   set level [info level]

   # search for existing values in exp_hist and error_hist
   foreach a_hist { exp_hist error_hist } {
      upvar 0 $a_hist hist
      for {set i 0} {$i < $hist(count)} {incr i} {
         foreach val $this(allowed_vals) {
            if {[info exists hist($i,$val)]} {
               set existing_vals($val) 1
            }
         }
      }
   }
   set this(existing_vals) [array names existing_vals]
 
   ts_log_fine "Waiting for the following events in history"
   set this(report_rows) {}
   set this(report_cols) $this(existing_vals)
   set this(report_data) report_data

   for {set i 0} {$i < $exp_hist(count)} {incr i} {
      private_wait_for_notification_report [expr $i + 1] this exp_hist $i 
   }
   ts_log_fine [print_xy_array $this(report_cols) $this(report_rows) report_data]

   if {$error_hist(count) > 0} {
      unset -nocomplain report_data
      set this(report_rows) {}
      ts_log_fine "Will terminate on the following events:"

      for {set i 0} {$i < $error_hist(count)} {incr i} {
         private_wait_for_notification_report  [expr $i + 1] this error_hist $i 
      }
      ts_log_fine [print_xy_array $this(report_cols) $this(report_rows) report_data]
   }
}

#****** util/private_wait_for_notification_build_args() ************************
#  NAME
#     private_wait_for_notification_build_args() -- build the filter arguments 
#                                 for the sdmadm shist call of wait_for_notification
 
#
#  SYNOPSIS
#     private_wait_for_notification_build_args { start_time a_exp_hist 
#     a_error_hist a_ctx } 
#
#  FUNCTION
#
#     This method builds out of the exp_hist and error_hist array the arguments
#     for the sdmadm shist command
#
#  INPUTS
#     start_time   - start time for filtering (in seconds since 01.01.1970)
#     a_exp_hist   - the array containing the expected history (see wait_for_notification)
#     a_error_hist - the array defining the error history (see wait_for_notification)
#     a_ctx        - the context of the wait_for_notification call 
#
#  RESULT
#
#     the argument for the sdmadm shist command
#
#  SEE ALSO
#     util/wait_for_notification
#*******************************************************************************
proc private_wait_for_notification_build_args { start_time a_exp_hist a_error_hist a_ctx } {

   upvar $a_exp_hist exp_hist
   upvar $a_error_hist error_hist
   upvar $a_ctx this

   foreach val $this(allowed_vals) {
      set filter_values($val) {}
   }

   foreach a_hist {exp_hist error_hist} {
      upvar 0 $a_hist hist
      for {set i 0} {$i < $hist(count)} {incr i} {
         foreach val $this(existing_vals) { 
             if {[info exists hist($i,$val)]} {
                if {[lsearch $filter_values($val) $hist($i,$val)] < 0} {
                   lappend filter_values($val) $hist($i,$val)
                }
             }
         }
      }
   }
   set filter_args ""
   
   if {[llength $filter_values(resource)] > 0} {
      append filter_args "("
      set first 1
      foreach resource $filter_values(resource) {
         if {$first} {
            set first 0
         } else {
            append filter_args "|"
         }
         ts_log_finer "Adding resource '$resource' to filter"
         
         # TODO the following code can be removed once the hostname
         # resolving problem in the filter is solved (issue ???)
         # quote all '.' in the hostname
         set reg_exp [string map { . \\. } $resource]
         append reg_exp ".*"
         append filter_args "(resource_name matches \"$reg_exp\" | resource matches \"$reg_exp\")"
      }
      append filter_args ")"
   }
   
   if {[llength $filter_values(resource_id)] > 0} {
      if {[string length $filter_args] > 0} {
         append filter_args " & "
      }
      append filter_args "("
      set first 1
      foreach resource_id $filter_values(resource_id) {
         if {$first} {
            set first 0
         } else {
            append filter_args "|"
         }
         ts_log_finer "Adding resource id '$resource_id' to filter"
         append filter_args " resource_id = \"$resource_id\""
      }
      append filter_args ")"
   }

   if {[llength $filter_values(service)] > 0} {
      if {[string length $filter_args] > 0} {
         append filter_args " & "
      }
      append filter_args "("
      set first 1
      foreach service $filter_values(service) {
         if {$first} {
            set first 0
         } else {
            append filter_args "|"
         }
         ts_log_finer "Adding service '$service' to filter"
         append filter_args " service = \"$service\""
      }
      append filter_args ")"
   }
   
   if {[llength $filter_values(type)] > 0} {
      if {[string length $filter_args] > 0} {
         append filter_args " & "
      }
      append filter_args "("
      set first 1
      foreach type $filter_values(type) {
         if {$first} {
            set first 0
         } else {
            append filter_args "|"
         }
         
         ts_log_finer "Adding notification type '$type' to filter"
         # With SDM1.0u5 the name of the event type has been changed from
         # SERVICE_UKNOWN to SERVICE_UNKNOWN
         # We accept in the filter both versions
         if { $type == "SERVICE_UKNOWN" || $type == "SERVICE_UNKNOWN" } {
            append filter_args "(type = \"SERVICE_UNKNOWN\" | type = \"SERVICE_UKNOWN\")"
         } else {
            append filter_args "type = \"$type\""
         }
      }
      append filter_args ")"
   }

   if {[string length $filter_args] > 0} {
      set filter_args "-f '$filter_args'"
   } else {
      ts_log_finer "Have no additional filter arguments"
   }

   # format of -sd is : yyyy/MM/dd HH:mm:ss"
   set ts_str [clock format $start_time -format "%Y/%m/%d %H:%M:%S"] 
   set cmd_args "-sd '$ts_str' $filter_args"

   return $cmd_args
}

#****** util/private_wait_for_notification_search_event() **********************
#  NAME
#     private_wait_for_notification_search_event() -- Search a history event 
#
#  SYNOPSIS
#     private_wait_for_notification_search_event { a_hist_info line a_exp_hist 
#     a_ctx accepted_event_index_list } 
#
#  FUNCTION
#
#     This method search the history event a_hist_info($line,...) in a_exp_hist
#
#  INPUTS
#     a_hist_info               - array contains the result of get_history
#     line                      - index of the line in a_hist_info
#     a_exp_hist                - array with the expected history entries
#     a_ctx                     - the context of the wait_for_notification call
#     accepted_event_index_list - the event index list is used to search over
#                                 a_exp_hist
#
#  RESULT
#
#     >= 0    index of the event in a_exp_host
#     else    event not found
#
#  NOTES
#
#     This method is a private method. It should only be called from wait_for_notification.
#
#  SEE ALSO
#     util/wait_for_notification
#*******************************************************************************
proc private_wait_for_notification_search_event { a_hist_info line a_exp_hist a_ctx accepted_event_index_list} {

   upvar $a_hist_info hist_info
   upvar $a_exp_hist  exp_hist
   upvar $a_ctx       this

   set msg "Searching for events in $a_hist_info\[[join $accepted_event_index_list ","]\] ------ \n"
   set ret -1
   foreach i $accepted_event_index_list {
      set event_matches 1
      foreach val $this(existing_vals) {
         if {[info exists exp_hist($i,$val)]} {
            set exp_value $exp_hist($i,$val)
            if {[info exists hist_info($line,$val)]} {
               set hist_value $hist_info($line,$val)
            } else {
               set hist_value ""
            }
            append msg "$i:$val: exp('$exp_value') == hist('$hist_value')? "
            if {$exp_value != $hist_value
               && !(($exp_value == "SERVICE_UKNOWN" && $hist_value == "SERVICE_UNKNOWN")
               || ($exp_value == "SERVICE_UNKNOWN" && $hist_value == "SERVICE_UKNOWN")) } {
               append msg " false\n"
               set event_matches 0
               break
            }
            append msg "true\n"
         }
      }
      if {$event_matches == 1} {
         set ret $i
         break
      }
   }
   ts_log_finest $msg
   ts_log_finest "ret=$ret"
   return $ret
}



#****** util/wait_for_component_info() *******************************************
#  NAME
#     wait_for_component_info() -- wait for expected component state information
#
#  SYNOPSIS
#     wait_for_component_info { exp_comp_info {atimeout 60} {raise_error 1} 
#     {ev error_var } {host ""} {user ""} {ci component_info} } 
#
#  FUNCTION
#     This procedure calls get_component_info() until the specified component
#     information or a timeout occurs.
#
#  INPUTS
#     exp_comp_info     - expected component info (same structure like
#                         get_component_info() is returning).
#     {atimeout 60}     - optional timeout specification in seconds
#     {raise_error 1}   - report testsuite errors if != 0
#     {ev error_var }   - report error text into this tcl var 
#     {host ""}         - see get_component_info()
#     {user ""}         - see get_component_info() 
#     {ci component_info} - see get_component_info() 
#
#  RESULT
#     0 on success, 1 on error
#     setting of tcl arrays like known from get_component_info()
#
#  EXAMPLE
#     set exp_component_info("spare_pool","tuor",state) "STARTED"
#     set exp_component_info($acomponent,"tuor",type) "Executor"
#     wait_for_component_info exp_component_info
#
#
#  SEE ALSO
#     util/get_component_info()
#*******************************************************************************
proc wait_for_component_info { exp_comp_info  {atimeout 60} {raise_error 1} {ev error_var } {host ""} {user ""} {ci component_info} } {
   global hedeby_config
   # setup arguments
   upvar $exp_comp_info exp_cmp_info
   upvar $ev error_text_up
   upvar $ci component_info
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
   if {![info exists error_text_up]} {
      # some calling code relies on the initialization of the error_text variable
      set error_text_up ""
   }
   set error_text ""
   set my_timeout [timestamp]
   incr my_timeout $atimeout

   # set expected results info
   set expected_component_info ""
   set exp_values [array names exp_cmp_info]
   foreach val $exp_values {
      append expected_component_info "$val=\"$exp_cmp_info($val)\"\n"
   }
   ts_log_finer "expected component infos:\n$expected_component_info"

   while {1} {
      set retval [get_component_info $host $user component_info $raise_error]
      if {$retval != 0} {
         append error_text "break because of get_component_info() returned \"$retval\"!\n"
         append error_text "expected component info was:\n$expected_component_info"
         break
      }

      set not_matching ""
      foreach val $exp_values {
         if {[info exists component_info($val)]} {
            if { $component_info($val) == $exp_cmp_info($val)} {
               ts_log_fine "component info \"$val\" matches expected info \"$exp_cmp_info($val)\""
            } else {
               append not_matching "component info \"$val\" is set to \"$component_info($val)\", should be \"$exp_cmp_info($val)\"\n"
            }
         } else {
            append not_matching "component info \"$val\" not available\n"
         }
      }

      if {$not_matching == ""} {
         ts_log_fine "all specified component info is matching"
         break
      } else {
         ts_log_fine "still waiting for specified component settings ..."
         ts_log_fine "still not matching component info:\n$not_matching"
      }

      if {[timestamp] >= $my_timeout} {
         append error_text "==> TIMEOUT(=$atimeout sec) while waiting for expected component states!\n"
         append error_text "==> NOT matching values:\n$not_matching"
         break
      }
      after 1000
   }

   if {$error_text != "" } {
      append error_text_up $error_text
      ts_log_severe $error_text $raise_error
      return 1
   }
   return 0
}


#****** util/wait_for_component_info_opt() *************************************
#  NAME
#     wait_for_component_info_opt() -- wait for a expected component info is reached 
#
#  SYNOPSIS
#     wait_for_component_info_opt { exp_comp_info { opt "" } } 
#
#  FUNCTION
#
#     This procedure calls get_component_info() until the specified component
#     information or a timeout occurs.
#
#     This method is the optional argument passing version of wait_for_component_info.
#
#  INPUTS
#     exp_comp_info - see wait_for_component_info
#     { opt "" }    - options for this command. Besides the standard options
#                     this command supports the following options:
#
#       opt(timeout)        - timeout in seconds (default is 60)
#       opt(component_info) - name of the tcl array (upvar) where the found
#                             component info is stored
#       opt(error_var)      - name of the upvar variable where error messages will 
#                             be appended
#
#  RESULT
#
#     the result of wait_for_component_info
#
#  EXAMPLE
#
#    # The following example waits until component 'reporter' on host 'foo.bar' reaches
#    # the state 'STOPPED'
#
#    set opts(timeout) 30
#    set opts(component_info) ci
#
#    set exp_component_info(reporter,foo.bar,state) "STOPPED"
#    wait_for_component_info exp_component_info opts
#
#  SEE ALSO
#     util/wait_for_component_info
#     util/get_hedeby_proc_opt_arg
#*******************************************************************************
proc wait_for_component_info_opt { exp_comp_info { opt "" } } {

   upvar $exp_comp_info exp_info
   set opts(timeout) 60
   set opts(component_info) ""
   set opts(error_var)  ""
   get_hedeby_proc_opt_arg $opt opts

   if { $opts(error_var) != "" } {
      upvar $opts(error_var) error_var
   }

   if { $opts(component_info) != "" } {
      upvar $opts(component_info) component_info
   }

   return [wait_for_component_info exp_info $opts(timeout) $opts(raise_error) \
                  error_var $opts(host) $opts(user) component_info]
}

#****** util/get_jvm_info() ****************************************************
#  NAME
#     get_jvm_info() -- get the information about running jvms 
#
#  SYNOPSIS
#     get_jvm_info { ji {opt ""} } 
#
#  FUNCTION
#     This command invokes a 'sdmadm sj' command, parses the output of the command
#     and returns the result in a tcl array.
#
#  INPUTS
#     ji       - name of the tcl array where the result of the 'sdmadm sj' command
#                is stored. This tcl array will contain the following entries:
#
#       ji(jvm_list)                   - list of all reported jvms
#       ji(<jvm_name>,hosts)           - list of hosts where the jvm <jvm_name> is running
#       jj(<jvm_name>,<host>,state)    - state of the jvm <jvm_name> running on host <host>
#       ji(<jvm_name>,<host>,used_mem) - current heap size of the jvm <jvm_name> on host <host>
#       ji(<jvm_name>,<host>,max_mem)  - max. heap size of the jvm <jvm_name> on host <host>
#       ji(<jvm_name>,<host>,message)  - the message for jvm <jvm_name> on host <host>
#        
#     {opt ""} - Beside the standard command options (see get_hedeby_proc_opt_arg)
#                this command supports the following options:
#
#        opt(jvm_name) - name of the jvm (-j parameter for the 'sdmadm sj' command)
#        opt(jvm_host) - hostname of the jvm (-h parameter for the 'sdmadm sj' command)
#
#
#  RESULT
#     -1  if the parsing of the table output failed
#     >0  the exit status of 'sdmadm sj' if the command failed
#     0   success
#
#  EXAMPLE
#
#   set opts(jvm_name) "rp_vm"
#   get_jvm_info ji opts
#
#   foreach jvm $ji(jvm_list) {
#       foreach host $ji($jvm,hosts) {
#          puts "jvm $jvm host $host is in state $ji($jvm,$host,state)"
#       }
#   }
#
#  SEE ALSO
#     util/get_hedeby_proc_opt_arg
#*******************************************************************************
proc get_jvm_info { ji {opt ""} } {

   # set the default values for opt
   set opts(jvm_name) ""
   set opts(jvm_host) ""
   get_hedeby_proc_opt_arg $opt opts

   # setup arguments
   upvar $ji jinfo

   # first we delete possible existing info arrays
   unset -nocomplain jinfo

   # now we start sdmadm sc command ...
   set sj_cmd "sj"
   if { $opts(jvm_name) != "" } {
      append sj_cmd " -j \"$opts(jvm_name)\""
   }
   if { $opts(jvm_host) != "" } {
      append sj_cmd " -h \"$opts(jvm_host)\""
   }

   copy_hedeby_proc_opt_arg opts sj_opts "default"
   set sj_opts(table_output) table
   set output [sdmadm_command_opt $sj_cmd sj_opts]
   if { $prg_exit_state != 0 } {
      return $prg_exit_state
   }

   # we expect the following table columns for ShowJvmCliCommand ...
   set exp_columns(jvm)      [create_bundle_string "ShowJvmCliCommand.col.name"]
   set exp_columns(host)     [create_bundle_string "ShowJvmCliCommand.col.host"]
   set exp_columns(state)    [create_bundle_string "ShowJvmCliCommand.col.state"]
   set exp_columns(used_mem) [create_bundle_string "ShowJvmCliCommand.col.usedMem"]
   set exp_columns(max_mem)  [create_bundle_string "ShowJvmCliCommand.col.maxMem"]
   set exp_columns(message)  [create_bundle_string "ShowJvmCliCommand.col.message"]

   foreach col [array names exp_columns] {
      set col_name $exp_columns($col)
      set pos [lsearch -exact $table(table_columns) $col_name]
      if {$pos < 0} {
         ts_log_severe "cannot find expected column name \"$col_name\"" $opts(raise_error)
         return -1
      }
      ts_log_finer "found expected col \"$col_name\" on position $pos"
   }
   
   # now we fill up the arrays ... 
   for {set line 0} {$line < $table(table_lines)} {incr line 1} {
      set jvm  $table($exp_columns(jvm),$line)
      set host [resolve_host $table($exp_columns(host),$line)]
      
      set jvm_exists($jvm) 1
      lappend jinfo($jvm,hosts) $host

      foreach param { state used_mem max_mem message } {
         set jinfo($jvm,$host,$param)    $table($exp_columns($param),$line)
      }
   }
   set jinfo(jvm_list) [array names jvm_exists]
 
   ts_log_fine "jvm list: $jinfo(jvm_list)"
   ts_log_finer [format_array jinfo]

   return 0
}


#****** util/wait_for_jvm_info() *******************************************
#  NAME
#     wait_for_jvm_info() -- wait for expected jvm state information
#
#  SYNOPSIS
#     wait_for_jvm_info { exp_jvm_info {opt ""}  } {
#
#  FUNCTION
#     This procedure calls get_jvm_info() until the specified jvm
#     information is found. A timeout or an encountered error condition
#     stops the waiting as well.
#
#  INPUTS
#     exp_jvm_info      - expected component info (same structure like
#                         get_jvm_info() is returning).
#
#     {opt ""} - Beside the standard command options (see get_hedeby_proc_opt_arg)
#                this command supports the following options:
#
#        opt(timeout)        - maximal waiting time for expected information in seconds (default: 60s)
#        opt(poll_interval)  - wait XXX milliseconds between calls to 'sdmadm sj'       (default: 1000ms)
#        opt(jvm_name)       - name of the jvm (-j parameter for the 'sdmadm sj' command)
#        opt(jvm_host)       - hostname of the jvm (-h parameter for the 'sdmadm sj' command)
#        opt(error_jvm_info) - name of tcl array to specify 'error conditions' for the waiting
#                              This array has the same structure as the exp_jvm_info array, but when one of
#                              the states in error_jvm_info is reached, the waiting also stops and an error
#                              is returned.
#                              A JVM in STOPPED state in error_jvm_info criterium is met, when the JVM does
#                              not appear in the output of 'sdmadm sj'.
#
#  RESULT
#     0 on success, 1 on error
#     setting of tcl array like in get_jvm_info()
#
#  EXAMPLE
#     # after executing a 'sdmadm suj' command, the jvm is in state "STARTING"
#     # => wait for complete startup
#     set exp_ji(rp_vm,$this(master_host),state) "STARTED" 
#     set err_ji(rp_vm,$this(master_host),state) "STOPPED"
#     set err_ji(rp_vm,$this(master_host),state) "STOPPING"
#     set ji_opts(error_jvm_info) err_ji
#     set ji_opts(timeout) 30
#     set ji_opts(poll_interval) 5000
#     set ji_opts(jvm_name) "rp_vm"
#     set ji_opts(jvm_host) $this(master_host)
#
#     wait_for_jvm_info exp_ji ji_opts
#
#  SEE ALSO
#     util/get_jvm_info()
#*******************************************************************************
proc wait_for_jvm_info { exp_jvm_info {opt ""}  } {

   # set the default values for opt
   set opts(timeout) 60
   set opts(poll_interval) 1000
   set opts(jvm_name) ""
   set opts(jvm_host) ""
   set opts(error_jvm_info) ""
   get_hedeby_proc_opt_arg $opt opts

   # setup arguments
   upvar $exp_jvm_info exp_info

   ts_log_fine "expected jvm infos:\n[format_array exp_info]"

   if { $opts(error_jvm_info) != "" } {
      upvar $opts(error_jvm_info) err_info
      ts_log_fine "stop processing if the following jvm infos are found:\n [format_array err_info]"
   }

   set my_timeout [timestamp]
   incr my_timeout $opts(timeout)


   copy_hedeby_proc_opt_arg_exclude opts jvm_info_opts "timeout poll_interval error_jvm_info"

   while {1} {
      set retval [get_jvm_info jinfo jvm_info_opts]
      if {$retval != 0} {
         ts_log_severe "Give up waiting for the expected jvm info, because 'sdmadm sj' exited with status '$retval'" $opts(raise_error)
         return 1               
      }

      set not_matching ""
      foreach val [array names exp_info] {
         if {[info exists jinfo($val)]} {
            if { $jinfo($val) == $exp_info($val)} {
               ts_log_fine "jvm info '$val' matches expected info '$exp_info($val)'"
            } else {
               append not_matching "jvm info '$val' is set to '$jinfo($val)' should be '$exp_info($val)'\n"
            }
         } else {
            # If the exp_info contains a condition for jvms in STOPPED state the exp_info
            # also matches if the jvms has not been found in the output of 'sdmadm sj'.
            # We assume in this case that the jvm is STOPPED
            if {[regexp ",state$" $val] && $exp_info($val) == "STOPPED"} {
               ts_log_fine "jvm info '$val' matches to not existing jvm in output"
            } else {
               append not_matching "jvm info '$val' not available\n"
            }
         }
      }

      if {$not_matching == ""} {
         ts_log_fine "all specified jvm info is matching"
         return 0
      }

      # ------------------------------------------------------------------------------
      # Did any jvm reached an exit state
      # ------------------------------------------------------------------------------
      if {[info exists err_info]} {
         foreach val [array names err_info] {
            if {[info exists jinfo($val)]} {
               if { $jinfo($val) == $err_info($val)} {
                  ts_log_severe "Found exit criteria '$jinfo($val)'" $opts(raise_error)
                  return 1
               }
            } elseif {[regexp ",state$" $val] && $err_info($val) == "STOPPED"} {
               # The err_info contains a condition for jvms in STOPPED state
               # and the jvm has not been found in the output (jinfo($val) does not exist)
               # => stop the processing, we assume in this case that the jvm is STOPPED
               set values [split $val ","]
               ts_log_severe "JVM '[lindex $values 1]' on host '[lindex $values 1]' not found in output of 'sdmadm sj'" $opts(raise_error)
               return 1
            }
         }
      }

      if {[timestamp] >= $my_timeout} {
         set msg "TIMEOUT(=$opts(timeout) sec) while waiting for expected component states!\n"
         append msg "NOT matching values:\n$not_matching"
         ts_log_severe $msg $opts(raise_error)
         return 1               
      }

      ts_log_fine "still waiting for specified jvm settings ..."
      ts_log_fine "still not matching jvm info:\n$not_matching"

      after $opts(poll_interval)
   }
   return 0
}


#****** util/get_free_service() ************************************************
#  NAME
#     get_free_service() -- get a service name which is free to use
#
#  SYNOPSIS
#     get_free_service { exclude_service_list {raise_error 1} } 
#
#  FUNCTION
#     This procedure returns the next free service name which is not in the
#     specified exclude service name list
#
#  INPUTS
#     exclude_service_list - list of service names which should be returned
#     {raise_error 1}      - if set to 1 raise error if no service is found
#
#  RESULT
#     name of a free (not excluded) service
#
#  SEE ALSO
#     util/get_hedeby_default_services()
#*******************************************************************************
proc get_free_service { exclude_service_list {raise_error 1} } {
   set free_service_name ""
   set ge_hosts [get_hedeby_default_services service_names]
   foreach pos_service $service_names(services) {
      if {[lsearch -exact $exclude_service_list $pos_service] >= 0} {
         continue
      }
      set free_service_name $pos_service
      break
   }
   if { $free_service_name == "" } {
      ts_log_severe "no matching service found!\nAvailable services: \"$service_names(services)\",\nExcluded services:  \"$exclude_service_list\"" $raise_error
   }
   return $free_service_name
}



#****** util/reset_produced_ambiguous_resource() *******************************
#  NAME
#     reset_produced_ambiguous_resource() -- reset previous produced ambiguous resource
#
#  SYNOPSIS
#     reset_produced_ambiguous_resource { } 
#
#  FUNCTION
#     This procedure is used to reset the resource which was set into ambiguous
#     state with produce_ambiguous_resource(). On errors the procedure is
#     calling hedeby_reset().
#
#  INPUTS
#     none
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     util/produce_ambiguous_resource()
#*******************************************************************************
global last_produce_ambiguous_resource_state
set last_produce_ambiguous_resource_state "undefined"
proc reset_produced_ambiguous_resource { } {
   global last_produce_ambiguous_resource_state

   if {$last_produce_ambiguous_resource_state == "undefined"} {
      ts_log_severe "There was no previous call of produce_ambiguous_resource()!"
      return 1
   }
   if {$last_produce_ambiguous_resource_state == "error"} {
      set last_produce_ambiguous_resource_state "undefined"
      ts_log_info "Last call to produce_ambiguous_resource() produced error - reset hedeby now ..."
      return [reset_hedeby 1]
   }
  
   if { [llength $last_produce_ambiguous_resource_state] != 2 } {
      ts_log_info "There should be 2 entries in global variable last_produce_ambiguous_resource_state - reset hedeby now ..."
      return [reset_hedeby 1]
   }

   # last call was ok, reset resource ...
   set resource [lindex $last_produce_ambiguous_resource_state 0]
   set service  [lindex $last_produce_ambiguous_resource_state 1]
   set error_text ""
   ts_log_fine "Removing resource \"$resource\" from service \"spare_pool\" ..."
   set output [sdmadm_command_opt "rr -r $resource -s spare_pool"]
   if { $prg_exit_state != 0} {
      append error_text "Error removing resource \"$resource\" from service \"spare_pool\":\n$output\n"
   }
   
   # wait for ambiguous flag to disappear ...
   set exp_res_info($resource,flags) "{}"
   set exp_res_info($resource,state) "ASSIGNED"
   set exp_res_info($resource,service) "$service"
   wait_for_resource_info exp_res_info 60 0 error_text

   ts_log_fine "Moving resource \"$resource\" from service \"$service\" back to service \"spare_pool\" ..."
   set output [sdmadm_command_opt "mvr -r $resource -s spare_pool"]
   if { $prg_exit_state != 0} {
      append error_text "Error moving resource \"$resource\" from service \"$service\" back to service \"spare_pool\":\n$output\n"
   }

   # wait for resource to appear at spare_pool ...
   unset exp_res_info
   set exp_res_info($resource,state) "ASSIGNED"
   set exp_res_info($resource,service) "spare_pool"
   wait_for_resource_info exp_res_info 60 0 error_text

   if { $error_text != "" } {
      append error_text "\nreset hedeby now ..."
      ts_log_info $error_text
      return [reset_hedeby 1]
   }

   ts_log_fine "reset resource \"$resource\" from ambiguous state was successfull!"
   set last_produce_ambiguous_resource_state "undefined"

   return 0
}

#****** util/produce_ambiguous_resource() **************************************
#  NAME
#     produce_ambiguous_resource() -- ??? 
#
#  SYNOPSIS
#     produce_ambiguous_resource { ares asrv } 
#
#  FUNCTION
#     This procedure takes the first resource of the TS hedeby resource list and 
#     moves it to the first service in the TS default service list. This means
#     that a resource from the spare pool is assigned to a service. After that
#     the service is shutdown and the resource is added again to spare pool.
#
#     This is possible, because shutdown service will not report any resources
#     and resource provider does not see the former assigned resource anymore.
#
#     After that the shutdown service is started up again and will report its
#     resources again. Since the resource is now also available at the spare
#     pool the resource is marked "ambiguous" and gets the state "A".
#
#     The procedure reset_produced_ambiguous_resource() is used to reset the
#     resource again and should be used in the cleanup() procedures of tests
#     which needs an ambiguous resource. The reset procedure will also work
#     when produce_ambiguous_resource() failed (By doing forced hedeby_reset()). 
#
#  INPUTS
#     ares - variable name to store the used resource name
#     asrv - variable name to store the used service name
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     util/reset_produced_ambiguous_resource()
#*******************************************************************************
proc produce_ambiguous_resource { ares asrv } {
   global last_produce_ambiguous_resource_state
   upvar $ares aresource
   upvar $asrv aservice
   set aresource ""
   set ge_hosts [get_hedeby_default_services service_names]

   if {$last_produce_ambiguous_resource_state != "undefined"} {
      ts_log_severe "There was already a call of produce_ambiguous_resource() - calling reset_produced_ambiguous_resource() first ..."
      reset_produced_ambiguous_resource
   }

   # use first resource from hedeby_resource_list
   set aresource [lindex [get_all_spare_pool_resources] 0]
   

   # we need a service to assign the resource ...
   set aservice [lindex $service_names(services) 0]

   ts_log_fine "try to make resource \"$aresource\" ambiguous ..."

   set command "mvr -r $aresource -s $aservice"
   sdmadm_command_opt $command
   if { $prg_exit_state != 0 } {
      set aresource ""
      set aservice ""
      set last_produce_ambiguous_resource_state "error"
      ts_log_severe "command $command failed with exit state = $prg_exit_state"
      return 1
   }

   # wait for resource movement
   set exp_res_info($aresource,service) $aservice
   set exp_res_info($aresource,state) "ASSIGNED"
   set retval [wait_for_resource_info exp_res_info 120]
   if {$retval != 0} {
      set aresource ""
      set aservice ""
      set last_produce_ambiguous_resource_state "error"
      return 1
   }

   # shutdown service
   set command "sds -s $aservice"
   sdmadm_command_opt $command
   if { $prg_exit_state != 0 } {
      set aresource ""
      set aservice ""
      set last_produce_ambiguous_resource_state "error"
      ts_log_severe "command $command failed with exit state = $prg_exit_state"
      return 1
   }

   # wait for shutdown of service (resource must be missing)
   set exp_service_info($aservice,cstate) "STARTED"
   set exp_service_info($aservice,sstate) "UNKNOWN"
   if { [wait_for_service_info exp_service_info 120] != 0 } {
      set aresource ""
      set aservice ""
      set last_produce_ambiguous_resource_state "error"
      return 1
   }

   # wait that resource disappears at resource provider
   unset exp_res_info
   set exp_res_info($aresource,state) "missing"
   if { [wait_for_resource_info exp_res_info 120] != 0 } {
      set aresource ""
      set aservice ""
      set last_produce_ambiguous_resource_state "error"
      return 1
   }

   # add resource again to spare pool
   if {[add_host_resources $aresource "spare_pool"] != 0} {
      set aresource ""
      set aservice ""
      set last_produce_ambiguous_resource_state "error"
      ts_log_severe "add_host_resources $aresource \"spare_pool\" failed"
      return 1
   }

   # startup service
   set command "sus -s $aservice"
   sdmadm_command_opt $command
   if { $prg_exit_state != 0 } {
      set aresource ""
      set aservice ""
      set last_produce_ambiguous_resource_state "error"
      ts_log_severe "command $command failed with exit state = $prg_exit_state"
      return 1
   }

   # wait for service up and running 
   set exp_service_info($aservice,cstate) "STARTED"
   set exp_service_info($aservice,sstate) "RUNNING"
   if { [wait_for_service_info exp_service_info 120] != 0 } {
      set aresource ""
      set aservice ""
      set last_produce_ambiguous_resource_state "error"
      return 1
   }

   # wait for resource reported by service, now the resource is 
   # at spare_pool AND service
   set ret_val [wait_for_resource_state "ASSIGNED" 0 90 res_state_info]
   if {[lsearch -exact $res_state_info(ambiguous) $aresource] < 0} {
      set aresource ""
      set aservice ""
      set last_produce_ambiguous_resource_state "error"
      return 1
   }
   set services $res_info($aresource,service)
   if {[llength $services] != 2} {
      ts_log_severe "Resource \"$aresource\" is not assigned to 2 services"
   }
   if {[lsearch -exact $services $aservice] < 0} {
      ts_log_severe "Resource \"$aresource\" is not assigned to service \"$aservice\""
   }
   if {[lsearch -exact $services "spare_pool"] < 0} {
      ts_log_severe "Resource \"$aresource\" is not assigned to service \"spare_pool\""
   }

   # check ambiguous flags of resource !!!
   unset exp_res_info
   set exp_res_info($aresource,flags) "A"
   if { [wait_for_resource_info exp_res_info 120] != 0 } {
      set aresource ""
      set aservice ""
      set last_produce_ambiguous_resource_state "error"
      return 1
   }

   ts_log_fine "resource \"$aresource\" is ambiguous now for service \"$aservice\" and \"spare_pool\""
   set last_produce_ambiguous_resource_state "$aresource $aservice"
   return 0
}


#****** util/produce_inprocess_resource() *************************************
#  NAME
#     produce_inprocess_resource() -- produce resource which is in progress
#
#  SYNOPSIS
#     produce_inprocess_resource { ares asrv } 
#
#  FUNCTION
#     This procedure submits a long runnig job to a resource and moves it
#     away to another service. As long the job is running the resource is in
#     progress state. The procedure reset_produced_inprocess_resource()
#     is used to cleanup this state again.
#
#  INPUTS
#     ares - name of variable to store the selected resource name
#     asrv - name of variable to store the selected service name
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     util/reset_produced_inprocess_resource()
#*******************************************************************************
proc produce_inprocess_resource { ares asrv } {
   global last_produce_inprocess_resource_state
   upvar $ares aresource
   upvar $asrv aservice
   set aresource ""
   set ge_hosts [get_hedeby_current_services service_names]

   if {$last_produce_inprocess_resource_state != "undefined"} {
      ts_log_severe "There was already a call of produce_inprocess_resource() - calling reset_produced_inprocess_resource() first ..."
      reset_produced_inprocess_resource
   }

   # we need a service to assign the resource ...
   set aservice [lindex $service_names(services) 0]

   # use first moveable resource from the service ...
   set aresource [lindex $service_names(moveable_execds,$aservice) 0]

   # get cluster of resource
   set sCluster $service_names(ts_cluster_nr,$aresource)

   ts_log_fine "try to make resource \"$aresource\" inprocess ..."

   # switch cluster and get config ...
   set curCluster [get_current_cluster_config_nr]
   set_current_cluster_config_nr $sCluster
   get_current_cluster_config_array ts_tmp_config

   # now submit a long running job to the service
   set master_host $service_names(master_host,$aservice)
   ts_log_fine "submitting long running job to host \"$aresource\", command executed on host \"$master_host\""
   set job_arguments "-o /dev/null -e /dev/null -l h=$aresource $ts_tmp_config(product_root)/examples/jobs/sleeper.sh 6000"
   set job_id [submit_job $job_arguments 1 60 $master_host]
   if { $job_id <= 0 } {
      set_current_cluster_config_nr $curCluster
      set last_produce_inprocess_resource_state "error"
      set aservice ""
      set aresource ""
      return 1
   }

   # wait for last submitted job to start ...
   if {[wait_for_jobstart $job_id "leeper" 60 1 1] != 0} {
      # error starting job delete job, return error
      delete_job $job_id
      set_current_cluster_config_nr $curCluster
      set last_produce_inprocess_resource_state "error"
      set aservice ""
      set aresource ""
      return 1
   }

   # now move the resource to another service ...
   set mvr_service_name [get_free_service $aservice]
   sdmadm_command_opt "mvr -r $aresource -s $mvr_service_name"
   if { $prg_exit_state != 0 } {
      delete_job $job_id
      set_current_cluster_config_nr $curCluster
      set last_produce_inprocess_resource_state "error"
      set aservice ""
      set aresource ""
      return 1
   }

   # wait that resource goes into UNASSINGING state ...
   ts_log_fine "resource \"$aresource\" should go into \"UNASSINGING\" state now ..."
   set exp_res_info($aresource,state) "UNASSIGNING"
   if {[wait_for_resource_info exp_res_info 60] != 0} {
      delete_job $job_id
      set_current_cluster_config_nr $curCluster
      set last_produce_inprocess_resource_state "error"
      set aservice ""
      set aresource ""
      return 1
   }

   # switch back to orig. cluster
   set_current_cluster_config_nr $curCluster

   ts_log_fine "resource \"$aresource\" is inprocess now for service \"$aservice\" and \"resource_provider\""
   set last_produce_inprocess_resource_state "$aresource $aservice $job_id"
   return 0
}


#****** util/reset_produced_inprocess_resource() ******************************
#  NAME
#     reset_produced_inprocess_resource() -- cleanup in progress resource
#
#  SYNOPSIS
#     reset_produced_inprocess_resource { } 
#
#  FUNCTION
#     This procedure is used to clean up the resource "in progress" state after
#     calling the produce_inprocess_resource() procedure.
#
#  INPUTS
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     util/produce_inprocess_resource()
#*******************************************************************************
global last_produce_inprocess_resource_state
set last_produce_inprocess_resource_state "undefined"
proc reset_produced_inprocess_resource { } {
   global last_produce_inprocess_resource_state

   if {$last_produce_inprocess_resource_state == "undefined"} {
      ts_log_severe "There was no previous call of produce_inprocess_resource()!"
      return 1
   }
   if {$last_produce_inprocess_resource_state == "error"} {
      ts_log_info "Last call to produce_inprocess_resource() produced error - reset hedeby now ..."
      set last_produce_inprocess_resource_state "undefined"
      return [reset_hedeby 1]
   }
  
   # get resource infos
   set resource [lindex $last_produce_inprocess_resource_state 0]
   set service  [lindex $last_produce_inprocess_resource_state 1]
   set job_id   [lindex $last_produce_inprocess_resource_state 2]

   # last call was ok, reset resource ...
   set ge_hosts [get_hedeby_current_services service_names]

   # get cluster of resource and switch
   set sCluster $service_names(ts_cluster_nr,$resource)
   set oldCluster [get_current_cluster_config_nr]
   set_current_cluster_config_nr $sCluster

   # delete the job
   delete_job $job_id

   # switch back to orig. cluster
   set_current_cluster_config_nr $oldCluster


   # Move resource back to orig. service

   # wait for UNASSIGNING state to disappear ...
   set exp_res_info($resource,state) "ASSIGNED"

   # It can take up to 60 seconds util GE service detects that the job is deleted
   # The execd uninstallation needs max. 30s
   # The execd installation needs max. 30s
   wait_for_resource_info exp_res_info 150 0 error_text

   # Move resource back to orig. service
   ts_log_finer "Moving resource \"$resource\" back to service \"$service\" ..."
   set output [sdmadm_command_opt "mvr -r $resource -s $service"]
   if { $prg_exit_state != 0} {
      append error_text "Error moving resource \"$resource\" back to service \"$service\":$output\n"
   }

   # wait for resource to appear at service 
   unset exp_res_info
   set exp_res_info($resource,state) "ASSIGNED"
   set exp_res_info($resource,service) "$service"
   wait_for_resource_info exp_res_info 60 0 error_text

   set last_produce_inprocess_resource_state "undefined"
   if { $error_text != "" } {
      append error_text "\nreset hedeby now ..."
      ts_log_info $error_text
      return [reset_hedeby 1]
   }

   ts_log_fine "reset resource \"$resource\" from inprocess state was successfull!"
   return 0
}



#****** util/wait_for_resource_state() **********************************
#  NAME
#     wait_for_resource_state() -- await resource state(s)
#
#  SYNOPSIS
#     wait_for_resource_state { state {raise_error 1} {atimeout 60} 
#     {ares res_state_info} {ri res_info} } 
#
#  FUNCTION
#     This procedure can be used to wait for a specified resource state(s) on
#     all configured hedeby resources. 
#
#  INPUTS
#     state                 - List of expected resource states
#                             Supported states are: ASSIGNED, ERROR, ASSIGNING,
#                             UNASSIGNED, UNASSIGNING and INPROCESS
#     {raise_error 1}      - report errors (default 1=true)
#     {atimeout 60}         - timeoute (default 60 seconds)
#     {ares res_state_info} - name of array to store resource state info
#                              (default: res_state_info) see RESULT
#     {ri res_info}         - array to store resource info from 
#                             wait_for_resource_info() call
#
#  RESULT
#     1 on error, 0 on success
#     The returned array res_state_info contains following information:
#        res_state_info(missing)    => list of missing resource names
#        res_state_info(unexpected) => list of unexpected resource names
#        res_state_info(ambiguous)  => list of double assigned resource names
#        res_state_info(unkown)     0> list of not configured resources
#        res_state_info(ASTATE)     => list of resource names in the state ASTATE
#
#        (ASTATE is a place holder for each state specified with the
#        state parameter)
#
#  EXAMPLE
#     wait_for_resource_state "ASSIGNED ERROR"
#     set index [array names res_state_info]
#     foreach ind $index {
#        ts_log_fine "res_state_info($ind) = $res_state_info($ind)"
#     }
#
#  SEE ALSO
#     util/wait_for_resource_info()
#*******************************************************************************
proc wait_for_resource_state { state {raise_error 1} {atimeout 60} {ares res_state_info} {ri res_info}} {
   upvar $ares result
   upvar $ri res_info
   if {[info exists result]} {
      unset result
   }
   ts_log_fine "entering wait_for_resource_state() ..."
   set supported_states "ASSIGNED ERROR ASSIGNING UNASSIGNED UNASSIGNING INPROCESS"
   set supported 1
   
   
   foreach st $state {
      if {[lsearch -exact $supported_states $st] < 0} {
         set supported 0
         break
      }
   }
   if { $supported == 0 } {
      ts_log_severe "resource state \"$st\" is not supported"
      return 1
   }

   set resource_list [get_all_default_hedeby_resources]
   foreach res $resource_list {
      set exp_resource_info($res,state) "$state"
   }
   set ret_val [wait_for_resource_info exp_resource_info $atimeout $raise_error]

   # now group and report lists for the resources states
   set result(missing) {}
   set result(unexpected) {}
   set result(ambiguous) {}
   set result(unknown) {}
   foreach res $res_list_not_uniq {
      lappend result(ambiguous) $res
   }
   foreach st $state {
      set result($st) {} 
   }
   foreach res $resource_list {
      if {[lsearch -exact $result(ambiguous) $res] >= 0} {
         ts_log_fine "skipp ambiguous resource \"$res\""
         continue
      }
      if {$res_info($res,state) == "missing" } {
         lappend result(missing) $res
      } else {
         set resource_state $res_info($res,state)
         if {[lsearch -exact $state $resource_state] >= 0} {
            lappend result($resource_state) $res
         } else {
            ts_log_fine "resource \"$res\" is in not specified state \"$resource_state\""
            lappend result(unexpected) $res
         }
      }
   }

   # set "unknown" resource list information
   foreach res $res_list {
      if {[lsearch -exact $resource_list $res] < 0} {
         lappend result(unknown) $res
      }
   }

   set index [array names result]
   foreach ind $index {
      ts_log_fine "${ares}($ind) = $result($ind)"
   }
   return $ret_val
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
#     {raise_error 1}        - if 1 report errors
#
#  RESULT
#     Return value: "0" on success, "1" on error 
#
#     Arrays:
#             service_info(SERVICE_NAME,host)   - service host
#             service_info(SERVICE_NAME,cstate) - service component state
#             service_info(SERVICE_NAME,sstate) - service state
#             service_info(service_list)        - list of all services
#
#  EXAMPLE
#     get_service_info sinfo
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
proc get_service_info { {host ""} {user ""} {si service_info} {raise_error 1} } {
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
   set output [sdmadm_command $execute_host $execute_user $sdmadm_command prg_exit_state "" $raise_error table]
   if { $prg_exit_state != 0 } {
      ts_log_severe "exit state of sdmadm $sdmadm_command was $prg_exit_state - aborting" $raise_error
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
         ts_log_severe "cannot find expected column name \"$col\"" $raise_error
         return 1
      }
      ts_log_finer "found expected col \"$col\" on position $pos"
      if {[lsearch -exact $used_col_names $col] < 0} {
         ts_log_severe "used column name \"$col\" not expected - please check table column names!" $raise_error
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
      set sinfo($service_id,host)   [resolve_host $table($host_col,$line)]
      set sinfo($service_id,cstate) $table($cstate_col,$line)
      set sinfo($service_id,sstate) $table($sstate_col,$line)
      lappend sinfo(service_list) $service_id
   }

   ts_log_finer "service list: $sinfo(service_list)"
   foreach service $sinfo(service_list) {
      ts_log_finer "service \"$service\": host=\"$sinfo($service,host)\" cstate=\"$sinfo($service,cstate)\" sstate=\"$sinfo($service,sstate)\""
   }
   return 0
}

#****** util/get_component_info() ************************************************
#  NAME
#     get_component_info() -- get component information (via sdmadm sc)
#
#  SYNOPSIS
#     get_component_info { {host ""} {user ""} {ci component_info} } 
#
#  FUNCTION
#     This procedure starts an sdmadm sc command and parses the output.
#
#  INPUTS
#     {host ""}              - host where to start command
#                                 (default: hedeby master host)
#     {user ""}              - user who starts command
#                                 (default: hedeby admin user)
#     {ci component_info}    - name of array for component informations
#                                 (default: component_info) 
#     {raise_error 1}        - if 1 report errors
#
#  RESULT
#     Return value: "0" on success, "1" on error 
#
#     Arrays:
#             component_info(component_NAME,host)       - list of hosts on which component runs
#             component_info(component_NAME,host,jvm)  - component jvm
#             component_info(component_NAME,host,type) - component type
#             component_info(component_NAME,host,state)- component component state
#             component_info(component_list)            - list of all components
#
#  EXAMPLE
#     get_component_info cinfo
#     foreach component $cinfo(component_list) {
#       foreach host $cinfo($component,host) {
#           set jvm $cinfo($component,$host,jvm)
#           set type $cinfo($component,$host,type)
#           set state $cinfo($component,$host,state)
#           ts_log_fine "component \"$component\": host=\"$host\": jvm=\"$jvm\": type=\"$type\": state=\"$state\""
#       }
#     }
#
#  SEE ALSO
#     util/sdmadm_command()
#     util/parse_table_output()
#     util/get_resource_info()
#     util/get_service_info()
#*******************************************************************************
proc get_component_info { {host ""} {user ""} {ci component_info} {raise_error 1} } {
   global hedeby_config

   # setup arguments
   upvar $ci cinfo

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
   if { [info exists cinfo] } {
      unset cinfo
   }

   # now we start sdmadm sc command ...
   set sdmadm_command "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sc"
   set output [sdmadm_command $execute_host $execute_user $sdmadm_command prg_exit_state "" $raise_error table]
   if { $prg_exit_state != 0 } {
      ts_log_severe "exit state of sdmadm $sdmadm_command was $prg_exit_state - aborting" $raise_error
      return 1
   }

   # we expect the following table columns for ShowComponentStatusCliCommand ...
   set exp_columns {}
   lappend exp_columns [create_bundle_string "ShowComponentStatusCliCommand.HostCol"]
   lappend exp_columns [create_bundle_string "ShowComponentStatusCliCommand.JvmCol"]
   lappend exp_columns [create_bundle_string "ShowComponentStatusCliCommand.NameCol"]
   lappend exp_columns [create_bundle_string "ShowComponentStatusCliCommand.TypeCol"]
   lappend exp_columns [create_bundle_string "ShowComponentStatusCliCommand.StateCol"]
   set used_col_names "host jvm component type state"

   set xyz(0) "*"
   lappend res_ignore_list [create_bundle_string "ShowComponentStatusCliCommand.err" xyz]
   foreach col $exp_columns {
      set pos [lsearch -exact $table(table_columns) $col]
      if {$pos < 0} {
         ts_log_severe "cannot find expected column name \"$col\"" $raise_error
         return 1
      }
      ts_log_finer "found expected col \"$col\" on position $pos"
      if {[lsearch -exact $used_col_names $col] < 0} {
         ts_log_severe "used column name \"$col\" not expected - please check table column names!" $raise_error
         return 1
      }
   }
   
   set component_col    [lindex $exp_columns 2]
   set state_col        [lindex $exp_columns 4]
   set jvm_col          [lindex $exp_columns 1]
   set type_col         [lindex $exp_columns 3]
   set host_col         [lindex $exp_columns 0]
   
   # now we fill up the arrays ... 
   set cinfo(component_list) {}
   # set cinfo($component_id,host) {}

   for {set line 0} {$line < $table(table_lines)} {incr line 1} {
      set component_id $table($component_col,$line)
      set host [resolve_host $table($host_col,$line)]
      
      set ci_on_list [lsearch -exact $cinfo(component_list) $component_id]
      if { $ci_on_list < 0} {
        lappend cinfo(component_list) $component_id
      } else {
        ts_log_finer "Component $component_id is already on the list"
      }

      lappend cinfo($component_id,host) $host
      # ts_log_fine "cinfo $component_id, host: $cinfo($component_id,host)"
      set cinfo($component_id,$host,state)    $table($state_col,$line)
      set cinfo($component_id,$host,jvm)      $table($jvm_col,$line)
      set cinfo($component_id,$host,type)     $table($type_col,$line)
   }

   ts_log_fine "component list: $cinfo(component_list)"
   foreach component $cinfo(component_list) {
      foreach host $cinfo($component,host) {
         ts_log_finer "component \"$component\": host=\"$host\" state=\"$cinfo($component,$host,state)\" jvm=\"$cinfo($component,$host,jvm)\" type=\"$cinfo($component,$host,type)\""
      }
   }
   return 0
}


#****** util/get_component_info_opt() ******************************************
#  NAME
#     get_component_info_opt() -- Opt version of get_component_info 
#
#  SYNOPSIS
#     get_component_info_opt { ci opt} 
#
#  FUNCTION
#
#     This procedure starts an 'sdmadm sc' command and parses the output.
#
#  INPUTS
#     ci     - tcl array where the component info is stored (see get_component_info) 
#     opt    - name of the tcl array (upvar) containing the options for the
#              command. The following options are supported:
#
#        opt(host)  - host where the sdmadm command is started (default: hedeby master host)
#        opt(user)  - name of the user executing the sdmadm command (default: hedeby admin user)
#        opt(raise_error) - If set to 1 errors will be reported with ts_log_severe (default: 1)
#
#  RESULT
#     0  -- Success
#     else "sdmadm sc" reported error
#
#*******************************************************************************
proc get_component_info_opt { ci { opt "" } } {
   upvar $ci u_ci

   # set function default optional arguments
   get_hedeby_proc_opt_arg $opt opts

   return [get_component_info $opts(host) $opts(user) u_ci $opts(raise_error)]
}

#****** util/sdmadm_command() **************************************************
#  NAME
#     sdmadm_command() -- start sdmadm command
#
#  SYNOPSIS
#     sdmadm_command { host user arg_line {exit_var prg_exit_state} 
#         { interactive_tasks "" } {raise_error 1} {table_output ""}
#         {own_env_array "my_env"}}
#
#  FUNCTION
#     This procedure is used to start a "raw" sdmadm command on the specified
#     host under the specified user account. The complete argument line has
#     to be specified. The sdmadm command is started with JAVA_HOME settings
#     from testsuite host configuration.
#
#     If the interactive_tasks array is given, then the sdmadm command is
#     executed interactively. When the entry RETURN_ISPID is set, then the
#     internal spawn id is returned and all expect processing has to be done by
#     the user of this function. Otherwise, the keys of the entries in
#     interactive_tasks are searched for in the output of the sdmadm. When a
#     key is found the corresponding value is sent to the sdmadm task.
#
#     There are some special cases with this handling of interactive_tasks:
#     - value ROOTPW: sends instead of "ROOTPW" the return value of
#       [get_root_passwd].
#     - key STANDARD_IN: sends $interactive_tasks(STANDARD_IN) to the sdmadm
#       command as stdin right away at the start and the "pipe" is closed
#       afterwards.
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
#     {own_env_array ""}        - an upvar array that contains a set of environment 
#                                 variable definitions to be used for the call. If
#                                 the variable is not defined in the upvar context
#                                 the default Hedeby environment is used. 
#                                 
#                                 Be aware that the specified environment is "added"
#                                 ontop of the default environment of the user. 
#                                 Variables of the users env can be redefined but not 
#                                 directly unset! (the ""-string is a value!)
#                                 
#                                 The users env variables can be unset meta entry 
#                                 UNSET_VARS in the my_env array. Lappend any env variable name
#                                 that should be unset before execution of the command.
#                                 
#                                 Example:
#                                 lappend myarray(UNSET_VARS) SDM_SYSTEM                                 
#
#  RESULT
#     The output of the sdmadm command
#
#  SEE ALSO
#     util/sdmadm_command()
#*******************************************************************************
proc sdmadm_command { host user arg_line {exit_var prg_exit_state} { interactive_tasks "" } {raise_error 1} {table_output ""} {own_env_array ""}} {
   upvar $exit_var back_exit_state
   
   # if no own_env_array is provided, the default hedeby environment will be loaded
   if { $own_env_array == "" } {
      hedeby_get_default_env $host my_env
   } else {
      upvar $own_env_array my_env
   }
   
   if { $interactive_tasks != "" } {
      upvar $interactive_tasks tasks
   }
   if { $table_output != "" } {
      upvar $table_output table
      append arg_line " -coldel \"|\" -dupval"
   }

   # this is only for getting debug output
   # set arg_line "-d $arg_line"
   
   set sdmadm_path [get_hedeby_binary_path "sdmadm" $user]
   ts_log_finer "${host}($user): using JAVA_HOME=$my_env(JAVA_HOME)"
   if { $interactive_tasks == "" } {
      ts_log_fine "starting binary not interactive \"sdmadm $arg_line\" (${host}($user)) ..."
      set output [start_remote_prog $host $user $sdmadm_path $arg_line back_exit_state 90 0 "" my_env 1 0 0 $raise_error]
      if { $back_exit_state != 0 } {
         ts_log_severe "${host}(${user}): sdmadm $arg_line failed:\n$output" $raise_error
      }
      ts_log_finest $output
      parse_table_output $output table "|"
      return $output
   } else {
      set back_exit_state -1
      ts_log_fine "starting binary INTERACTIVE \"sdmadm $arg_line\" (${host}($user)) ..."
      set pr_id [open_remote_spawn_process $host $user $sdmadm_path $arg_line 0 "" my_env 0]
      if { [info exists tasks(RETURN_ISPID)] } {
         ts_log_finer "returning internal spawn id \"$pr_id\" to caller!"
         return $pr_id
      }

      set sp_id [lindex $pr_id 1]
      set timeout 90
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
           if { [regexp "(.*)_exit_status_:\\((\[^\n\]*)\\)" $token whole_match rest_of_output back_exit_state] } {
              ts_log_fine "found exit status of client: ($back_exit_state)"
              set do_stop 1
              set found_end 1
              # maybe token contains still some output before exit_status
              append output $rest_of_output
           }
           if {  $found_start == 1 && $found_end == 0 } {
              append output "${token}"
              foreach name [array names tasks] {
                 if { $name == "STANDARD_IN" } {
                    # STANDARD_IN is special and used only for direct piping into
                    # sdmadm at the start of the command, see below
                    continue
                 }
                 if { [string match "*${name}*" $token] } {
                    if { $tasks($name) != "ROOTPW" } {
                       ts_log_fine ".....found \"$name\", sending \"$tasks($name)\" ..."
                       ts_send $sp_id "$tasks($name)\n"
                    } else {
                       ts_log_fine "waiting for a few seconds before sending root password ..."
                       after 5000
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
              if { [info exists tasks(STANDARD_IN)] } {
                 ts_log_fine "... at _start_mark_: piping STANDARD_IN into sdmadm"
                 ts_send $sp_id $tasks(STANDARD_IN)
                 ts_send $sp_id ""  ;# close pipe
              }
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
         ts_log_severe "${host}(${user}): sdmadm $arg_line failed with exit state '$back_exit_state':\n$output" $raise_error
      }
      parse_table_output $output table "|"
      return $output
   }
}

#****** util/sdmadm_command_opt() **************************************************
#  NAME
#     sdmadm_command_opt() -- start sdmadm command
#
#  SYNOPSIS
#     sdmadm_command_opt { arg_line {opt ""} } {
#
#  FUNCTION
#     This procedure is the optional argument passing version of
#     sdmadm_command(). For a description of the command, see there.
#
#     The global sdmadm parameter -s and -p are taken from opt(system_name) and
#     opt(pref_type) and are automatically added to the arg_line.
#
#  INPUTS
#     arg_line               - argument line for sdmadm command
#
#     opt                    - optional named arguments, see get_hedeby_proc_default_opt_args()
#     opt(system_name)       - if "" then no -s parameter is added to the sdmadm arg_line
#     opt(pref_type)         - if "" then no -p parameter is added to the sdmadm arg_line
#     opt(exit_var)          = prg_exit_state
#                              variable name where to save the exit state 
#     opt(interactive_tasks) - variable name, see sdmadm_command()
#     opt(table_output)      - variable name, see sdmadm_command()
#     opt(own_env_array)     - variable name, see sdmadm_command()
#
#  RESULT
#     The output of the sdmadm command
#
#  EXAMPLE
#     # log output of show_resource command
#     set opt(exit_var) exit_code
#     set opt(raise_error) 0
#     ts_log_fine [sdmadm_command_opt "show_resource -r $resource" opt]
#     if { $exit_code != 0 } {
#        ts_log_severe "Error in sdmadm command, exit_code = $exit_code"
#     }
#
#  SEE ALSO
#     util/sdmadm_command()
#     util/get_hedeby_proc_opt_arg()
#*******************************************************************************
proc sdmadm_command_opt { arg_line {opt ""} } {
   set opts(exit_var) "prg_exit_state"
   set opts(interactive_tasks) ""
   set opts(table_output) ""
   set opts(own_env_array) ""
   get_hedeby_proc_opt_arg $opt opts

   # prepare all arrays for upvar behavior
   upvar $opts(exit_var) u_exit_var
   if { $opts(own_env_array) != "" } {
      upvar $opts(own_env_array) u_own_env_array
      set own_env_name "u_own_env_array"
   } else {
      set own_env_name ""
   }
   if { $opts(interactive_tasks) != "" } {
      upvar $opts(interactive_tasks) u_interactive_tasks
      set interactive_tasks_name "u_interactive_tasks"
   } else {
      set interactive_tasks_name ""
   }
   if { $opts(table_output) != "" } {
      upvar $opts(table_output) u_table_output
      set table_output_name "u_table_output"
   } else {
      set table_output_name ""
   }

   # add preference type and system name to command line when != ""
   if { $opts(pref_type) != "" } {
      set arg_line "-p $opts(pref_type) $arg_line"
   }
   if { $opts(system_name) != "" } {
      set arg_line "-s $opts(system_name) $arg_line"
   }

   return [sdmadm_command $opts(host) $opts(user) $arg_line u_exit_var $interactive_tasks_name $opts(raise_error) $table_output_name $own_env_name]
}

#****** util/hedeby_get_default_env() **************************************************
#  NAME
#     hedeby_get_default_env() -- creates default values for environment variables
#
#  SYNOPSIS
#     hedeby_get_default_env { host own_env_array }  
#
#  FUNCTION
#     The function expects a host for which the enviroment variables are generated
#     Additionally it expects an upvar array where the variable names and values are
#     stored in. It generated three variables and their values:
#         JAVA_HOME     the java home directory of the host
#         EDITOR        The default editor of the host
#         SDM_SYSTEM    "" #empty string to filter side effects if the system name 
#                       is allready defined in the machines enviroment
#
#  INPUTS
#     host                      - host where sdmadm should be started
#     {own_env_array "my_env"}  - upvar name to match an array where the values 
#                                 should be stored
#
#  RESULT
#     no return value
#
#  SEE ALSO
#     util/sdmadm_command()
#*******************************************************************************
proc hedeby_get_default_env { host own_env_array } {
   global hedeby_config
   upvar $own_env_array my_env

   set my_env(JAVA_HOME) [get_java_home_for_host $host $hedeby_config(hedeby_java_version)]
   set my_env(EDITOR) [get_binary_path $host "vim"]
	# reset environment variable SDM_SYSTEM to illegal value to avoid user environment side effects
   set my_env(SDM_SYSTEM) "" 
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

   ts_log_finer "check if host \"$host\" has running hedeby jvms ..."
   if { [remote_file_isdirectory $host $run_dir] } {
      set msg "Hedeby jvms on host '$host': "
      set running_jvm_names [start_remote_prog $host $user "ls" "$run_dir"]
      if { [llength $running_jvm_names] == 0 } {
         ts_log_fine "no hedeby jvm running on host $host!"
         return 0
      }
      foreach jvm_name $running_jvm_names {
         if {[read_hedeby_jvm_pid_file pid_info $host $user $run_dir/$jvm_name] != 0} {
            ts_log_fine "cannot get pid info for host $host!"
            return 1
         }
         set pid $pid_info(pid)
         set port $pid_info(port)
         
         lappend pid_list $pid
         lappend run_list "$pid:$jvm_name:$port"
         # delete host part of $jvm_name (jvm@host)
         set only_jvm_name [regsub {@.*} $jvm_name ""]
         append msg "${only_jvm_name}(pid=$pid, port=$port) "
         ts_log_finer "jvm $jvm_name has pid \"$pid\""
         ts_log_finer "jvm $jvm_name has port \"$port\""
      }
      ts_log_fine $msg
   } else {
      ts_log_fine "no hedeby run directory found on host '$host'!"
      ts_log_fine "run directory was \"$run_dir\""
   }
   return 0
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
   
   set output [sdmadm_command $execute_host $execute_user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] rau -au $user_name" prg_exit_state "" $raise_error]
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
   
   set output [sdmadm_command $execute_host $execute_user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] aau -au $user_name" prg_exit_state "" $raise_error ]
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

#****** util/produce_unknown_resource() ****************************************
#  NAME
#     produce_unknown_resource() -- produce name for unknwon resource
#
#  SYNOPSIS
#     produce_unknown_resource { type } 
#
#  FUNCTION
#     This procedure will produce a name for a resource that is not managed by
#     hedeby (is unknown).
#
#  INPUTS
#     type - type of resource "host" or "any"
#
#  RESULT
#     resource name
#
#*******************************************************************************
proc produce_unknown_resource { type } {
    global hedeby_config
    global ts_host_config
    set exec_host $hedeby_config(hedeby_master_host)

    if { $type == "any" } {
       # '@' sign is valid in resource name, so use it for constructing the name
       set unknown_name "unknown@"
       # initialize output to empty string
       set output ""

       # build expected output message from bundle properties file ... 
       set expected_output [string trim [create_bundle_string "ShowResourceStateCliCommand.res.notfound"]]
       ts_log_fine "expected output: $expected_output"
       
       while { 1 } {
           # prepare sdmadm command ...
           set sdmadm_command_line "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] sr -r $unknown_name"
           set output [string trim [sdmadm_command $exec_host [get_hedeby_admin_user] $sdmadm_command_line prg_exit_state "" 0 table]]
           ts_log_finer "output is: $output"
           if {[string match "$expected_output" "$output"]} {
               break
           } else {        
               append unknown_name "@" 
           }
       }
    }
    
    if { $type == "host" } {
       # lookup for an not used testsuite host name
       set unknown_name ""
       set used_hosts [get_all_movable_resources]
       foreach host [host_conf_get_nodes $ts_host_config(hostlist)] {
          if {[lsearch -exact $used_hosts $host] < 0} {
             set unknown_name $host
             break
          }
       }
       if {$unknown_name == ""} {
          ts_log_info "cannot find unused testsuite hostname, returning hedeby master host \"$hedeby_config(hedeby_master_host)\""
          set unknown_name $hedeby_config(hedeby_master_host)
       }
    }
    ts_log_fine "produced unknown resource \"$unknown_name\" of type \"$type\" "       
    return $unknown_name
}

#****** util/produce_error_resource() ******************************************
#  NAME
#     produce_error_resource() -- produce resource ERROR state
#
#  SYNOPSIS
#     produce_error_resource { resource { method "soft" } } 
#
#  FUNCTION
#     This procedure will produce resource ERROR state by shutting down
#     the execd of the resource. The "soft" method will do this by
#     qconf -ke, the "hard" method does it by killing the execd on the resource.
#     After that the procedure also checks that the resource is in
#     ERROR state.
#   
#     The ERROR state reset is done by reset_produced_error_resource().
#
#  INPUTS
#     resource          - name of the resource to set into error state
#     { method "soft" } - method used for shutting down execd on resource
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     util/reset_produced_error_resource()
#*******************************************************************************
proc produce_error_resource { resource { method "soft" } } {
   set ge_hosts [get_hedeby_current_services service_names]

   if { $method != "soft" && $method != "hard" } {
      ts_log_severe "method \"$method\" not supported!"
      return 1
   }

   if { ![info exists service_names(ts_cluster_nr,$resource)] } {
      ts_log_severe "resource $resource not found!"
      return 1
   }

   # remember current cluster
   set oldCluster [get_current_cluster_config_nr]

   set_current_cluster_config_nr $service_names(ts_cluster_nr,$resource)
   set error_text ""
   if { $method == "soft" } {
      ts_log_fine "doing soft execd shutdown by \"qconf -ke $resource\" ..."
      set ret [soft_execd_shutdown $resource]
      if {$ret != 0} {
         append error_text "\"soft_execd_shutdown $resource\" returned: $ret\n"
      }
   } else {
      ts_log_fine "doing hard execd shutdown by killing execd pid on host \"$resource\" ..."
      set ret [shutdown_system_daemon $resource "execd"]
      if {$ret != 0} {
         append error_text "\"shutdown_system_daemon $resource \"execd\"\" returned: $ret\n"
      }
   }
   set_current_cluster_config_nr $oldCluster

   # wait for resource go to error state
   ts_log_fine "resource \"$resource\" should go into error state now ..."
   set exp_res_info($resource,state) "ERROR"
   wait_for_resource_info exp_res_info 300 0 error_text
   # Enhanced timeout to 120 seconds because on some architecures (LX24) with
   # old threading implementation it takes one minute till qmaster realize that
   # execd was killed:

   if { $error_text != "" } {
      ts_log_severe $error_text
      return 1
   }
   return 0
}

#****** util/reset_produced_error_resource() ***********************************
#  NAME
#     reset_produced_error_resource() -- reset produced ERROR state
#
#  SYNOPSIS
#     reset_produced_error_resource { resource {resource_was_removed 0} }
#
#  FUNCTION
#     This procedure is used to cleanup the ERROR state of a resource which
#     was produced by produce_error_resource(). It will restart the execd
#     on the specified resource and wait for the resource "ASSIGNED" state.
#
#  INPUTS
#     resource - resource to startup the execd
#     resource_was_removed - if the resource was removed from the system
#                            altogether, default = 0 (not removed)
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     util/produce_error_resource()
#*******************************************************************************
proc reset_produced_error_resource { resource {resource_was_removed 0}} {
   if {$resource_was_removed} {
      set ge_hosts [get_hedeby_default_services service_names]
   } else {
      set ge_hosts [get_hedeby_current_services service_names]
   }

   set error_text ""
   if { ![info exists service_names(ts_cluster_nr,$resource)] } {
      ts_log_severe "resource $resource not found!"
      return 1
   }

   set sCluster $service_names(ts_cluster_nr,$resource)
   ts_log_finer "Resource \"$resource\" has TS cluster nr $sCluster"

   # saving current cluster nr and switch to ts cluster
   set oldCluster [get_current_cluster_config_nr]
   set_current_cluster_config_nr $sCluster

   # startup the execd
   set ret [startup_execd $resource]
   if {$ret != 0} {
      append error_text "\"startup_execd $resource\" returned: $ret\n"
   }
   
   # switch back to stored cluster nr
   set_current_cluster_config_nr $oldCluster

   # wait for resource error state to disappear
   ts_log_fine "resource \"$resource\" should go into assigned state now ..."
   set exp_res_info($resource,state) "ASSIGNED"
   wait_for_resource_info exp_res_info 90 0 error_text

   if { $error_text != "" } {
      ts_log_severe $error_text
      return 1
   }
   return 0
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
#     Read and parse the pid file of a hedeby jvm 
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
#  SEE ALSO
#     util/read_hedeby_jvm_pid_file
#     util/get_pid_file_for_jvm()
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
#     Get path of jvm pid file 
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
#
#     set pid_file [get_pid_file_for_jvm "foo.bar" "executor_vm"]
#
#  SEE ALSO
#     util/read_hedeby_jvm_pid_info()
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
#     Read pid file of hedeby jvm
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
#  SEE ALSO
#     util/read_hedeby_jvm_pid_info()
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
#     { resource_filter "" } - resource filter for the slo
#     { usage ""}            - usage value (if empty no usage is set)
#
#  RESULT
#     xml string
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/set_hedeby_slos_config()
#*******************************************************************************
proc create_fixed_usage_slo {{urgency 50 } {name "fixed_usage"} {resource_filter ""} {usage ""}} {
  
   if {$usage == ""} {
      set usage $urgency
   }
   if {$usage != $urgency} {
      set slo "<common:slo xsi:type=\"common:FixedUsageSLOConfig\" urgency=\"$urgency\" name=\"$name\" usage=\"$usage\">"
   } else {
      set slo "<common:slo xsi:type=\"common:FixedUsageSLOConfig\" urgency=\"$urgency\" name=\"$name\">"
   }
   if {$resource_filter != ""} {
      append slo "<common:resourceFilter>$resource_filter</common:resourceFilter>"
   }   
   append slo "</common:slo>"
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
#     { resourceFilter ""} - optional: resource filter created with 
#                            procedure create_resource_filter()
#     { request  ""}       - optional: the request filter for the produced needs
#
#  RESULT
#     xml string
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/create_resource_filter()
#     util/set_hedeby_slos_config()
#*******************************************************************************
proc create_min_resource_slo {{urgency 50 } { name "min_res" } { min 2 } {resourceFilter ""} {request ""} {usage ""} } {
   if {$usage == ""} {
      set usage $urgency
   }
   if {$usage != $urgency} {
      set slo "<common:slo xsi:type=\"common:MinResourceSLOConfig\" urgency=\"$urgency\" name=\"$name\" min=\"$min\" usage=\"$usage\">"
   } else {
      set slo "<common:slo xsi:type=\"common:MinResourceSLOConfig\" urgency=\"$urgency\" name=\"$name\" min=\"$min\">"
   }
   if {$request != ""} {
      append slo $request
   }
   if {$resourceFilter != ""} {
      append slo $resourceFilter
   }
   append slo "</common:slo>"
   return $slo
}

#****** util/create_min_resource_slo_opt() *************************************
#  NAME
#     create_min_resource_slo_opt() -- Opt version of create_min_resource_slo
#
#  SYNOPSIS
#     create_min_resource_slo_opt { opt } 
#
#  FUNCTION
#     Creates the xml tag for a minResourceSLO
#
#  INPUTS
#     opt - option array. The following options are supported
#        opt(urgency)        -  Urgency of the slo
#        opt(usage)          -  Usage of the SLO (if "" the usage with be taken from opt(urgency))
#        opt(name)           -  Name of the SLO (default min_res)
#        opt(min)            -  Value for the min attribute of the minResourceSLO (default 2)
#        opt(requestFilter)  -  *Complete* xml tag for the request filter of the SLO
#                               (in the form <common:request>....</common:request>) 
#                               (default "")
#        opt(resourceFilter) -  *Complete* xml tag for the request filter of the SLO
#                               (in the form <common:resourceFilter>....</common:resourceFilter>) 
#                               (default "")
#
#  RESULT
#    the xml string
#
#  SEE ALSO
#     util/create_min_resource_slo
#*******************************************************************************
proc create_min_resource_slo_opt { opt } {

   set opts(urgency)        50
   set opts(usage)          ""
   set opts(name)           "min_res"
   set opts(min)            2
   set opts(resourceFilter) ""
   set opts(requestFilter)  ""

   get_hedeby_proc_opt_arg $opt opts

   return [create_min_resource_slo $opts(urgency) $opts(name) $opts(min)\
                                   $opts(resourceFilter) $opts(requestFilter) $opts(usage)]
}

#****** util/create_filter() **************************************
#  NAME
#     create_filter() -- create filter for slo definitions
#
#  SYNOPSIS
#     create_filter { filter_name resProp op } {
#
#  FUNCTION
#     This procedure is used to create an xml string for a filter
#     definition. It is a helper function to create concrete resource or
#     request filters.
#
#  INPUTS
#     filter_name - name of the start/end-tag for the xml structure, e.g.
#                   common:resourceFilter
#     resProp     - array which contains filter specification
#           
#                   The array must have following settings:
#                   resProp(PROP_NAME) {OPERATOR} {VALUE}
#                 
#                   PROP_NAME: name of property: e.g. operatingSystemName, state
#                   OPERATOR:  used property operator: e.g. "=", "!="
#                   VALUE:     match value: e.g. "Linux", "ASSIGNED", "ERROR"
#
#     op          - string with which to combine the separate filters, beware
#                   that that string is used directly in the xml, so take care
#                   to escape properly ("&amp;" for "&", etc.)
#
#  RESULT
#     filter string in xml format
#
#  SEE ALSO
#     util/create_resource_filter()
#     util/create_request_filter()
#*******************************************************************************
proc create_filter { filter_name resProp op } {
   upvar $resProp resProps
   set filter ""
   set pnames [array names resProps]
   if {[llength $pnames] > 0} {
      append filter "<$filter_name>"
      set is_first 1
      foreach pname $pnames {
         if {$is_first == 1} {
            set is_first 0
         } else {
            append filter " $op "
         }
         append filter "$pname"
         append filter "[lindex $resProps($pname) 0]"    
         append filter "\"[lindex $resProps($pname) 1]\""
      }
      append filter "</$filter_name>"
   }
   ts_log_finer "created filter $filter_name:\n$filter\n"
   return $filter
}


#****** util/create_resource_filter() **************************************
#  NAME
#     create_resource_filter() -- create resource filter for slo definitions
#
#  SYNOPSIS
#     create_resource_filter { resProp op } 
#
#  FUNCTION
#     This procedure is used to create xml string for a resource filter
#     definition. The specified resource properties are by default combined
#     with AND.
#
#     A resource filter filters the resources that are considered during SLO
#     calculation.  It is NOT a filter on the need that is created by the SLO
#     (for this, see create_request_filter).
#
#  INPUTS
#     resProp - array which contains filter specification
#           
#               The array must have following settings:
#               resProp(PROP_NAME) {OPERATOR} {VALUE}
#             
#               PROP_NAME: name of property: e.g. operatingSystemName, state
#               OPERATOR:  used property operator: e.g. "=", "!="
#               VALUE:     match value: e.g. "Linux", "ASSIGNED", "ERROR"
#
#     {op "&amp;"} - string with which to combine the separate filters,
#                    by default this is AND = & = &amp;
#
#  RESULT
#     string in xml format
#
#  EXAMPLE
#     set propA(operatingSystemName) "{=} {Linux}"
#     set propA(state)               "{!=} {ERROR}"
#     set filterA [create_resource_filter propA]
#
#  SEE ALSO
#     util/create_filter()
#*******************************************************************************
proc create_resource_filter { resProp {op "&amp;"} } {
   upvar $resProp resProps
   set filter [create_filter "common:resourceFilter" resProps $op]
   return $filter
}


#****** util/create_request_filter() **************************************
#  NAME
#     create_request_filter() -- create request filter for slo definitions
#
#  SYNOPSIS
#     create_request_filter { resProp op } 
#
#  FUNCTION
#     This procedure is used to create an xml string for a request filter
#     definition. The specified resource properties are by default combined
#     with AND.
#
#     A request filter is attached to the need that is created by an SLO. It
#     does NOT influence the resources that are considered during SLO
#     calculation (for this, see create_resource_filter).
#
#  INPUTS
#     resProp - array which contains filter specification
#           
#               The array must have following settings:
#               resProp(PROP_NAME) {OPERATOR} {VALUE}
#             
#               PROP_NAME: name of property: e.g. operatingSystemName, state
#               OPERATOR:  used property operator: e.g. "=", "!="
#               VALUE:     match value: e.g. "Linux", "ASSIGNED", "ERROR"
#
#     {op "&amp;"} - string with which to combine the separate filters,
#                    by default this is AND = & = &amp;
#
#  RESULT
#     string in xml format
#
#  EXAMPLE
#     set propA(operatingSystemName) "{=} {Linux}"
#     set propA(type)                "{=} {host}"
#     set filterA [create_request_filter propA]
#
#  SEE ALSO
#     util/create_filter()
#*******************************************************************************
proc create_request_filter { resProp {op "&amp;"} } {
   upvar $resProp resProps
   set filter [create_filter "common:request" resProps $op]
   return $filter
}


#****** util/create_job_filter() **************************************
#  NAME
#     create_job_filter() -- create job filter for slo definitions
#
#  SYNOPSIS
#     create_job_filter { resProp op } 
#
#  FUNCTION
#     This procedure is used to create an xml string for a job filter
#     definition. The specified resource properties are by default combined
#     with AND.
#
#  INPUTS
#     resProp - array which contains filter specification
#           
#               The array must have following settings:
#               resProp(PROP_NAME) {OPERATOR} {VALUE}
#             
#               PROP_NAME: name of property: e.g. arch, state
#               OPERATOR:  used property operator: e.g. "=", "!="
#               VALUE:     match value: e.g. "sol-sparc64"
#
#     {op "&amp;"} - string with which to combine the separate filters,
#                    by default this is AND = & = &amp;
#
#  RESULT
#     string in xml format
#
#  EXAMPLE
#     set propA(arch) "{=} {sol-sparc64}"
#     set filterA [create_job_filter propA]
#
#  SEE ALSO
#     util/create_filter()
#*******************************************************************************
proc create_job_filter { resProp {op "&amp;"} } {
   upvar $resProp resProps
   set filter [create_filter "ge_adapter:jobFilter" resProps $op]
   return $filter
}

#****** util/create_permanent_request_slo() ************************************
#  NAME
#     create_permanent_request_slo() -- create perm. request slo xml string
#
#  SYNOPSIS
#     create_permanent_request_slo { {urgency 1 } 
#     { name "PermanentRequestSLO" } {resourceFilter ""} {requestFilter ""}
#     {quantity 10} {usage 1} } 
#
#  FUNCTION
#     creates xml string with specified values
#
#  INPUTS
#     {urgency 1 }                   - urgency value of generated requests
#     {name "PermanentRequestSLO" }  - name value
#     {resourceFilter ""}            - optional: resource filter created with 
#                                      procedure create_resource_filter()
#     {requestFilter ""}             - optional: request filter created with 
#                                      procedure create_request_filter()
#                                      if "" -> default: type = "host"
#     {quantity 10}                  - quantity of resource that is requested
#     { usage ""}                    - usage value (if empty no usage is set)
#
#  RESULT
#     xml string
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/set_hedeby_slos_config()
#     util/create_resource_filter()
#*******************************************************************************
proc create_permanent_request_slo {{urgency 1 } { name "PermanentRequestSLO" } {resourceFilter ""} {requestFilter ""} {quantity 10} {usage ""}} {
   if {$usage == ""} {
      set usage $urgency
   }
   if {$usage != $urgency} {
      set slo_txt "<common:slo xsi:type=\"common:PermanentRequestSLOConfig\" urgency=\"$urgency\" name=\"$name\" quantity=\"$quantity\" usage=\"$usage\">"
   } else {
      set slo_txt "<common:slo xsi:type=\"common:PermanentRequestSLOConfig\" urgency=\"$urgency\" name=\"$name\" quantity=\"$quantity\">"
   }

   if { $requestFilter != "" } {
      append slo_txt $requestFilter
   } else {
      set prop(type) "{=} {host}"
      append slo_txt [create_request_filter prop]
   }

   if { $resourceFilter != "" } {
      append slo_txt $resourceFilter
   }

   append slo_txt "</common:slo>"
   return $slo_txt
}

#****** util/create_permanent_request_slo_opt() ********************************
#  NAME
#     create_permanent_request_slo_opt() -- opt version of create_permanent_request_slo
#
#  SYNOPSIS
#     create_permanent_request_slo_opt { opt } 
#
#  FUNCTION
#
#     Create the xml string for a permanent request SLO
#
#  INPUTS
#     opt - Option for the permanent request SLO. The following options are 
#           supported:
#        opt(urgency)        -   Urgency of the slo
#        opt(usage)          -   Usage of the SLO (if "" the usage with be taken from opt(urgency))
#        opt(name)           -   Name of the SLO (default min_res)
#        opt(quantity)       -   Quantity for the SLO (default 10)
#        opt(requestFilter)  -  *Complete* xml tag for the request filter of the SLO
#                               (in the form <common:request>....</common:request>) 
#                               (default "")
#        opt(resourceFilter) -  *Complete* xml tag for the request filter of the SLO
#                               (in the form <common:resourceFilter>....</common:resourceFilter>) 
#                               (default "")
#
#  RESULT
#     the xml string for the SLO
#
#  SEE ALSO
#     util/create_permanent_request_slo
#*******************************************************************************
proc create_permanent_request_slo_opt { opt } {

   set opts(urgency)        1
   set opts(name)           "PermanentRequestSLO"
   set opts(resourceFilter) ""
   set opts(requestFilter)  ""
   set opts(quantity)       10
   set opts(usage)          ""

   get_hedeby_proc_opt_arg $opt opts

   return [create_permanent_request_slo $opts(urgency) $opts(name) \
                      $opts(resourceFilter) $opts(requestFilter) $opts(quantity) $opts(usage)]

}

#****** util/create_max_pending_jobs_slo() ************************************
#  NAME
#     create_max_pending_jobs_slo() -- create max pending jobs slo xml string
#
#  SYNOPSIS
#     create_max_pending_jobs_slo { {urgency 1 } {name "MaxPendingJobsSLO" } {resourceFilter ""}
#                        {requestFilter ""} { jobFilter ""} { max 1 } {averageSlotsPerHost 10} {{maxWaitTimeForJobs_value 2} 
#                        {maxWaitTimeForJobs_unit "minutes"} {usage ""} }
#
#  FUNCTION
#     creates xml string with specified values
#
#  INPUTS
#     { urgency 1 }                       - urgency value
#     { name "MaxPendingJobsSLO" }        - name value
#     { max 1 }                           - maximun number of pending jobs for this host.
#     {resourceFilter ""}                 - optional: resource filter created with 
#                                           procedure create_resource_filter()
#     {requestFilter ""}                  - optional: request filter created with 
#                                           procedure create_request_filter()
#     {jobFilter ""}                      - optional: job filter created with 
#                                           procedure create_job_filter()
#     {averageSlotsPerHost 10}            - optional: average slots per host value.
#
#     {maxWaitTimeForJobs_value 2}        - optional: value for the wait time for job to start
#     {maxWaitTimeForJobs_unit "minutes"} - optional: unit for wait time for job to start
#     {usage ""}                          - optional: usage for the slo
#
#  RESULT
#     xml string
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/set_hedeby_slos_config()
#*******************************************************************************
proc create_max_pending_jobs_slo {{ urgency 1 } { name "MaxPendingJobsSLO" } { resourceFilter "" } 
                                 { requestFilter "" } { jobFilter "" } { max 1 } {averageSlotsPerHost 10} 
                                 {maxWaitTimeForJobs_value 2} {maxWaitTimeForJobs_unit "minutes"} {usage ""} } {
   if {$usage == ""} {
      set usage $urgency
   }
   set slo_txt "<common:slo xsi:type=\"ge_adapter:MaxPendingJobsSLOConfig\" urgency=\"$urgency\""
   if {$usage != $urgency} {
      append slo_txt " usage=\"$usage\""
   }
   append slo_txt " name=\"$name\" max=\"$max\" averageSlotsPerHost=\"$averageSlotsPerHost\">"
   
   if { $requestFilter != "" } {
      append slo_txt $requestFilter
   }
   
   
   if { $resourceFilter != "" } {
      append slo_txt $resourceFilter
   }

   append slo_txt "<ge_adapter:maxWaitTimeForJobs unit=\"$maxWaitTimeForJobs_unit\" value=\"$maxWaitTimeForJobs_value\"/>"

   if { $jobFilter != "" } {
      append slo_txt $jobFilter
   }
   
   append slo_txt "</common:slo>"
   return $slo_txt
}

#****** util/create_max_pending_jobs_slo_opt() *********************************
#  NAME
#     create_max_pending_jobs_slo_opt() -- Opt version of create_max_pending_jobs_slo
#
#  SYNOPSIS
#     create_max_pending_jobs_slo_opt { opt } 
#
#  FUNCTION
#
#     Create the xml string for a MaxPendingJobsSLO
#
#  INPUTS
#     opt - Option for the max pending jobs SLO. The following options are 
#           supported:
#        opt(urgency)                       -   Urgency of the slo
#        opt(usage)                         -   Usage of the SLO (if "" the usage with be taken from opt(urgency))
#        opt(name)                          -   Name of the SLO (default min_res)
#        opt(requestFilter)                 -  *Complete* xml tag for the request filter of the SLO
#                                              (in the form <common:request>....</common:request>) 
#                                              (default "")
#        opt(resourceFilter)                -  *Complete* xml tag for the request filter of the SLO
#                                              (in the form <common:resourceFilter>....</common:resourceFilter>) 
#                                              (default "")
#        opt(jobFilter)                     -  *Complete* xml tag for the job filter of the SLO
#                                              (in the form <ge_adapter:jobFilter>....</ge_adapter:jobFilter>) 
#                                              (default "")
#        set opt(max)                       -  value for the max attribute (default 1)
#        set opt(averageSlotsPerHost)       -  value for the averageSlotsPerHost attribute (default 10)
#        set opt(maxWaitTimeForJobsValue)  -  value for the maxWaitTimeForJobs element (default 2)
#        set opt(maxWaitTimeForJobsUnit)   -  unit for the maxWaitTimeForJobs element (default minutes)
#
#  RESULT
#     the xml string of the SLO
#
#  SEE ALSO
#     util/create_max_pending_jobs_slo()
#*******************************************************************************
proc create_max_pending_jobs_slo_opt { opt } {

   set opts(urgency)                  1
   set opts(usage)                    ""
   set opts(name)                     "MaxPendingJobsSLO"
   set opts(resourceFilter)           ""
   set opts(requestFilter)            ""
   set opts(jobFilter)                ""
   set opts(max)                      1
   set opts(averageSlotsPerHost)      10
   set opts(maxWaitTimeForJobsValue)  2
   set opts(maxWaitTimeForJobsUnit)   "minutes"

   get_hedeby_proc_opt_arg $opt opts 

   return [create_max_pending_jobs_slo $opts(urgency) $opts(name) $opts(resourceFilter) $opts(requestFilter) \
                                       $opts(jobFilter) $opts(max) $opts(averageSlotsPerHost) \
                                       $opts(maxWaitTimeForJobsValue) $opts(maxWaitTimeForJobsUnit) $opts(usage)]

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
   set timeout 60
   log_user 0  ;# we don't want to see vi output
   set clear_sequence [ format "%c%c%c%c%c%c%c" 0x1b 0x5b 0x48 0x1b 0x5b 0x32 0x4a 0x00 ]
   expect {
      -i $sp_id timeout {
         ts_log_fine "got timeout while waiting for vi start command"
         append errors "got timeout while waiting for vi start command!\n"
      }
      -i $sp_id  "_start_mark_*\n" {
      }
   }
   ts_log_finer "got start mark"

   set timeout 60
   expect {
      -i $sp_id timeout {
         ts_log_fine "got timeout while waiting for vi screen output!"
         append errors "got timeout while waiting for vi screen output!\n"
      }
      -i $sp_id -- "$clear_sequence" {
         send -i $sp_id -- "G"
         ts_log_finer "got screen clear sequence"

      }
      -i $sp_id -- {[A-Za-z]+} {
         ts_log_fine "got screen output"
         send -i $sp_id -- "G"
      }
   }


   # now wait for 100% output
   set timeout 1
   set break_timer 30
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
   ts_log_finer "vi started"
   return $ispid
}

#****** util/hedeby_mod_setup_opt() **************************************************
#  NAME
#     hedeby_mod_setup_opt() -- startup hedeby (vi) modification sdmadm command
#
#  SYNOPSIS
#     hedeby_mod_setup_opt { sdmadm_arguments error_log {opt ""} } {
#
#  FUNCTION
#     This procedure is the optional argument passing version of
#     hedeby_mod_setup(). For a description of the command, see there.
#
#     The global sdmadm parameter -s and -p are taken from opt(system_name) and
#     opt(pref_type) and are automatically added to the sdmadm_arguments.
#
#  INPUTS
#     sdmadm_arguments   - argument line for sdmadm command
#     error_log          - name of variable to store error messages
#
#     opt                - optional named arguments, see get_hedeby_proc_default_opt_args()
#     opt(system_name)   - if "" then no -s parameter is added to the sdmadm_arguments
#     opt(pref_type)     - if "" then no -p parameter is added to the sdmadm_arguments
#
#  RESULT
#     internal spawn id array (returned from open_remote_spawn_process())
#
#  SEE ALSO
#     util/hedeby_mod_setup()
#     util/hedeby_mod_sequence()
#     util/hedeby_mod_cleanup()
#     util/get_hedeby_proc_opt_arg()
#*******************************************************************************
proc hedeby_mod_setup_opt { sdmadm_arguments error_log {opt ""} } {
   upvar $error_log error

   get_hedeby_proc_opt_arg $opt opts

   # add preference type and system name to command line when != ""
   if { $opts(pref_type) != "" } {
      set sdmadm_arguments "-p $opts(pref_type) $sdmadm_arguments"
   }
   if { $opts(system_name) != "" } {
      set sdmadm_arguments "-s $opts(system_name) $sdmadm_arguments"
   }

   return [hedeby_mod_setup $opts(host) $opts(user) $sdmadm_arguments error]
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


   set exit_value 111
   if { $ispid == "" } {
      ts_log_fine "no ispid value - returning"
      return
   }

   if { $errors != "" } {
      ts_log_fine "skip sending vi sequence, there were errors!"
      ts_log_fine "send \":q!\" command to vi ..."
      append errors "skip sending vi sequence, send ESC:q! sequence\n"
      set sequence {}
      lappend sequence "[format "%c" 27]" ;# ESC
      lappend sequence ":q!\n"        ;# don't save and quit
      hedeby_mod_sequence $ispid $sequence errors
      set timeout 2
   } else { 
      # we change the file size for sure below, so no need to wait. A file
      # is changed for hedeby if the file size or the modification time is
      # different.
      set sequence {}
      lappend sequence "[format "%c" 27]" ;# ESC
      # Put 1001 new lines at the end of the file.
      # This makes sure that the file is considered as changed (compares
      # modification time and file size). By adding this many chars it is
      # nearly impossible that the normal edit of the file beforehand deleted
      # exactly as many bytes as are added. Use new lines as they are ignored
      # both by the XML parser and the resource properties parser.
      lappend sequence "Go[format "%c" 27]" ;# append empty line at end of file
      lappend sequence "1000."              ;# repeat 1000 times
      lappend sequence ":wq\n"        ;# save and quit
      hedeby_mod_sequence $ispid $sequence errors
      set timeout 60
   }

   ts_log_finer "waiting for vi termination ..."
  
   set sp_id [ lindex $ispid 1 ]
   set do_stop 0
   set output ""
   set close_keep_open 1
   expect {
      -i $sp_id timeout {
         ts_log_fine "timeout waiting for vi termination"
         append errors "timeout waiting for vi termination\n"
         set close_keep_open 0
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
   close_spawn_process $ispid 0 $close_keep_open
   if { $errors != "" } {
      append errors "output of command:\n"
      append errors $output
   }
   if { $exit_value != 0 || $errors != "" } {
      if { $errors == "" } {
         append errors "exit value of command: $exit_value\n"
         append errors "output of command:\n$output\n"
      }
      ts_log_severe "error calling \"sdmadm $current_hedeby_mod_arguments\":\n$errors\nexit_value: $exit_value" $raise_error 
   }
   return $output
}

#****** util/set_hedeby_job_suspend_policy() ***********************************
#  NAME
#     set_hedeby_job_suspend_policy() -- set the job suspend policy for a grid engine service 
#
#  SYNOPSIS
#     set_hedeby_job_suspend_policy { service suspend_methods {opt ""} }
#
#  FUNCTION
#     Modifies the jobs suspend policy in the component configuration of a grid
#     engine service. The GE service is updated and the command waits until the
#     service is running again.
#
#     If called without optional named arguments set, it resets the job suspend
#     policy of the GE service to the default values.
#
#  INPUTS
#     service          - name of the grid engine service 
#     {opt ""}         - optional named arguments, see get_hedeby_proc_default_opt_args()
#       opt(suspend_methods)          - list of supported job suspend methods
#                                       (by default this is the GE service default setting)
#       opt(job_finish_timeout_value) - timeout value for waiting for job end (2)
#       opt(job_finish_timeout_unit)  - unit of the time out                  (minutes)
#
#  RESULT
#     0    --  job suspend policy of the gridengine service successfully modified 
#     else -- error
#*******************************************************************************
proc set_hedeby_job_suspend_policy { service {opt ""} } {
   set opts(job_finish_timeout_value) 2
   set opts(job_finish_timeout_unit)  "minutes" 
   set opts(suspend_methods) { "reschedule_jobs_in_rerun_queue" "reschedule_restartable_jobs" "suspend_jobs_with_checkpoint" }
   get_hedeby_proc_opt_arg $opt opts

   # check parameters
   foreach suspend_method $opts(suspend_methods) {
      switch -- $suspend_method {
         "reschedule_jobs_in_rerun_queue" -
         "reschedule_restartable_jobs"    -
         "suspend_jobs_with_checkpoint"   {
            ts_log_finest "suspend_method '$suspend_method' is valid" $opts(raise_error)
         }
         default {
            ts_log_severe "Unknown suspend_method '$suspend_method'" $opts(raise_error)
         }
      }
   }
   switch -- $opts(job_finish_timeout_unit) {
      "seconds" -
      "minutes" -
      "hours"   {
         ts_log_finest "job_finish_timeout_unit has valid value '$opts(job_finish_timeout_unit)'" 
      }
      default {
         ts_log_severe "Unknown job_finish_timeout_unit '$opts(job_finish_timeout_unit)'" $opts(raise_error)
         return -1
      }
   }
   
   if {![string is digit $opts(job_finish_timeout_value)] || $opts(job_finish_timeout_value) < 0} {
      ts_log_severe "job_finish_timeout_value ($opts(job_finish_timeout_value)) must be a positive number" $opts(raise_error)
      return -1
   }
   
   # remove jobSuspendPolicy section
   set sequence {}
   lappend sequence "/<ge_adapter:jobSuspendPolicy\n"
   lappend sequence "ma/<\\/ge_adapter:jobSuspendPolicy>\n"
   lappend sequence ":'a,.d\n"
   # insert the new jobSuspendPolicy
   lappend sequence "i"
   lappend sequence "<ge_adapter:jobSuspendPolicy suspendMethods=\""
   foreach suspend_method $opts(suspend_methods) {
      lappend sequence "$suspend_method "
   }
   lappend sequence "\">"
   lappend sequence "<ge_adapter:timeout unit=\""
   lappend sequence $opts(job_finish_timeout_unit)
   lappend sequence "\" value=\""
   lappend sequence $opts(job_finish_timeout_value)
   lappend sequence "\"/>"
   lappend sequence "</ge_adapter:jobSuspendPolicy>"
   
   lappend sequence "[format "%c" 27]" ;# ESC

   # only use the default set of optional arguments for the call to
   # hedeby_change_component
   copy_hedeby_proc_opt_arg opts call_opts "default"
   return [hedeby_change_component $service $sequence call_opts]
}

#****** util/set_hedeby_slos_config() ******************************************
#  NAME
#     set_hedeby_slos_config() -- used to set slo config for a hedeby service
#
#  SYNOPSIS
#     set_hedeby_slos_config { service slos {opt ""} }
#
#  FUNCTION
#     This procedure is used to set the slo configuration for a hedeby ge service.
#     It also supports setting of "spare_pool" service.
#
#     By default this procedure modifies the configuration with sdmadm mc -c
#     service, updates the component, waits until the component is STARTED
#     again, but will NOT check for correctness of modification action (test
#     with sdmadm sslo -u). To turn off the update functionality, set the
#     do_update parameter to false.
#
#  INPUTS
#     service    - service which should be modified
#     slos       - list with slos to set
#                  (created with create_???_slo() and put
#                   into list)
#     {opt ""}   - optional named arguments, see get_hedeby_proc_default_opt_args()
#       opt(do_update)             if set to 1 update the component and (potentially) wait
#                                  for given state, by default set to 1
#       opt(do_wait_for_state)     if set to 1 wait for given state, by default set to 1
#                                  Only relevant if do_update is 1
#       opt(update_interval_unit)  slo update interval unit of service, by default not set on SLO
#       opt(update_interval_value) slo update interval value of service, by default not set on SLO
#
#  RESULT
#     0 on success, 1 on error
#
#  NOTES
#
#  Only GE services support the SLO update interval in the service
#  configuration. If update_interval_unit or update_interval_value is used for
#  non GE services it will fail.
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/create_permanent_request_slo()
#     util/set_hedeby_slos_config()
#     util/hedeby_change_component()
#*******************************************************************************
proc set_hedeby_slos_config { service slos {opt ""} } {
   set opts(do_update)             1
   set opts(do_wait_for_state)     1
   set opts(update_interval_unit)  ""
   set opts(update_interval_value) ""
   get_hedeby_proc_opt_arg $opt opts

   ts_log_fine "setting slos for service \"$service\" ..."
   foreach new_slo $slos {
      ts_log_fine "new slo: $new_slo"
   }

   ##########################################################################
   # piece together the vi sequence
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

   if {$opts(update_interval_unit) != "" && $opts(update_interval_value) != "" } {
      ts_log_fine "Setting sloUpdateInterval to '$opts(update_interval_value)' '$opts(update_interval_unit)'"
      # search and replace sloUpdateInterval 
      lappend sequence "/sloUpdateInterval\n"
      # jump to beginning of next word, delete until '/' of tag closing '/>'
      lappend sequence "Wdt/"
      # insert at cursor position both parameters ...
      lappend sequence "iunit=\"$opts(update_interval_unit)\" value=\"$opts(update_interval_value)\""
      # ... and exit insert mode
      lappend sequence "[format "%c" 27]" ;# ESC
   }

   #Uncomment the following line for debugging vi sequence
   # lappend sequence ":w! /tmp/hedeby_mod_config.xml\n"

   ##########################################################################
   # ... and update the service

   # use the value of the do_update option!
   copy_hedeby_proc_opt_arg_exclude opts call_opts "update_interval_unit update_interval_value"
   return [hedeby_change_component $service $sequence call_opts]
}

#****** util/remove_resource_property() ******************************************
#  NAME
#     remove_resource_property() -- used to set slo config for a hedeby service
#
#  SYNOPSIS
#     remove_resource_property { resource prop_list {opt ""} } {
#
#  FUNCTION
#     This procedure is used to delete certain properties of a resource. The
#     names of the properties to delete are handed in as a tcl list in the
#     prop_list parameter.
#
#     The resource modification is done with 'sdmadm mr' and a vi sequence
#     handed to hedeby_mod_setup().
#
#  INPUTS
#     resource   - resource to change
#     prop_list  - names of properties to delete (tcl list)
#     opt        - optional named arguments, see get_hedeby_proc_default_opt_args()
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     util/get_hedeby_resource_properties()
#     util/mod_hedeby_resource()
#     util/hedeby_mod_setup_opt()
#     util/get_hedeby_proc_opt_arg()
#*******************************************************************************
proc remove_resource_property { resource prop_list {opt ""} } {
   get_hedeby_proc_opt_arg opt opts

   set ispid [hedeby_mod_setup_opt "mr -r $resource" error_text opts]

   set sequence {}
   foreach prop $prop_list {
       lappend sequence ":g/^${prop} =/delete\n"
   }
     
   hedeby_mod_sequence $ispid $sequence error_text
   set output [hedeby_mod_cleanup $ispid error_text prg_exit_state $opts(raise_error)]

   ts_log_fine "finished removing properties '$prop_list' from resource '$resource', exit_status: $prg_exit_state"
   if { $prg_exit_state == 0 } {
      ts_log_finer "output: \n$output"
   }

   if {$error_text != ""} {
      return 1
   }
   return 0
}

#****** check/hedeby_executor_set_keep_files() **************************************************
#  NAME
#    hedeby_executor_set_keep_files() -- set the keep files flag of an executor
#
#  SYNOPSIS
#    hedeby_executor_set_keep_files { executor_host keep_files { executor_name "executor" } } 
#
#  FUNCTION
#     This method sets the keepFiles flag in the configuration of an executor component
#     and notifies the executor on the executor host that it's configuration 
#     has been changed (sdmadm uc)
#
#  INPUTS
#    executor_host --  hostname were the executor runs
#    keep_files    --  the value of the keep_files flag
#    executor_name --  Optional, name of the executor (default is executor)
#
#  RESULT
#     0    if the keep files flag has been set 
#     else error, error message has been written with ts_log_severe
#  EXAMPLE
#
#   if { [hedeby_executor_set_keep_files "foo.bar" false] != 0 } {
#      # error message has already been reported
#      return 0
#   }
#
#*******************************************************************************
proc hedeby_executor_set_keep_files { executor_host keep_files { executor_name "executor" } } {

   set sequence {}
   # Delete the keepFiles attribute
   lappend sequence ":%s/keepFiles=\"\[^\"\]*\"//\n"
   # Append the new keepFiles attribute directly after the executor tag
   lappend sequence ":%s/executor:executor/executor:executor keepFiles=\"$keep_files\"/\n"
   # lappend sequence ":w! /tmp/set_keep_files.xml\n"
   
   set opt(do_wait_for_state) 0
   set opt(update_on_host) $executor_host
   return [hedeby_change_component $executor_name $sequence opt]
}


#****** util/compare_resource_infos() ******************************************
#  NAME
#     compare_resource_infos() -- compare two resource infos
#
#  SYNOPSIS
#     compare_resource_infos { res_info1 res_prop1 res_list1 res_list_not_uniq1 res_info2 res_prop2 res_list2 res_list_not_uniq2 { et error_text} } 
#
#  FUNCTION
#     This procedure will produce a name for a resource that is not managed by
#     hedeby (is unknown).
#
#  INPUTS
#    resource_info1     --  resource info as returned by get_resource_info
#    rp1                --  resource property array as returned by get_resource_info
#    res_list1          --  resource list as returned by get_resource_info
#    res_list_not_uniq1 --  ambiguous resource list as returned by get_resource_info
#    resource_info2     --  resource info as returned by get_resource_info
#    rp2                --  resource property array as returned by get_resource_info
#    res_list2          --  resource list as returned by get_resource_info
#    res_list_not_uniq2 --  ambiguous resource list as returned by get_resource_info
#    et                 --  optional: error text (if comparison returns -1)
#
#  OUTPUTS
#    et                  --  detailed message if result is -1
#   
#  RESULT
#     0                 --  if all "*1" and related "*2" attributes are equal
#    -1                 --  if not all "*1" and related "*2" attributes are equal
#
#  SEE ALSO
#     util/get_proc_info()
#     
#*******************************************************************************
proc compare_resource_infos { resource_info1 rp1 res_list1 res_list_not_uniq1 resource_info2 rp2 res_list2 res_list_not_uniq2 {et error_text} } {
    
    upvar $et result_et
    if {[info exists result_et]} {
      unset result_et
    }

    array set res_info1 $resource_info1
    array set res_prop1 $rp1    
    array set res_info2 $resource_info2
    array set res_prop2 $rp2
    
    set result_et ""

    set result 0
    # 1. check the number of resources
    if { [llength $res_list1] == [llength $res_list2] } {
        ts_log_finer "both resource lists contain the same number of resources"
        foreach elem $res_list1 { 
            set has [lsearch -exact $res_list2 $elem]
            if { $has < 0 } {
                append result_et "resource list 2 does not contain resources $elem"  
                return -1
            } else {
                ts_log_finer "both resource lists contain resource $elem"
            }
        }
    } else {
        append result_et "resource lists do not contain the same number of resources"
        return -1
    }
    # 2. check the number of ambiguous resources
    if { [llength $res_list_not_uniq1] == [llength $res_list_not_uniq2] } {
        ts_log_finer "both ambiguous resource lists contain the same number of resources"
        foreach elem $res_list_not_uniq1 { 
            set has [lsearch -exact $res_list_not_uniq2 $elem]
            if { $has < 0 } {
                append result_et "ambiguous resource list 2 does not contain resources $elem"                                
                return -1
            } else {
                ts_log_finer "both ambiguous resource lists contains resource $elem"
            }
        }
    } else {
        append result_et "ambiguous resource lists do not contain the same number of resources"
        return -1
    }
    # 3. check the resources
    foreach rst $res_list1 {
        if {[string match "$res_info1($rst,flags)" "$res_info2($rst,flags)"]} {
            ts_log_finer "resource $rst has the same flags in both resource infos"                            
        } else {
            append result_et "resource infos differ: $res_info1($rst,flags), $res_info2($rst,flags)\n"
            return -1
        }
        if {[string match "$res_info1($rst,state)" "$res_info2($rst,state)"]} {
            ts_log_finer "resource $rst has the same state in both resource infos"                            
        } else {
            append result_et "resource infos differ: $res_info1($rst,state), $res_info2($rst,state)\n"
            return -1
        }
        if {[string match "$res_info1($rst,type)" "$res_info2($rst,type)"]} {
            ts_log_finer "resource $rst has the same type in both resource infos"                            
        } else {
            append result_et "resource infos differ: $res_info1($rst,type), $res_info2($rst,type)\n"
            return -1
        }
        if {[string match "$res_info1($rst,service)" "$res_info2($rst,service)"]} {
            ts_log_finer "resource $rst has the same service in both resource infos"                            
        } else {
            append result_et "resource infos differ: $res_info1($rst,service), $res_info2($rst,service)\n"
            return -1
        }
        if {[string match "$res_info1($rst,annotation)" "$res_info2($rst,annotation)"]} {
            ts_log_finer "resource $rst has the same annotation in both resource infos"                            
        } else {
            append result_et "resource infos differ: $res_info1($rst,annotation), $res_info2($rst,annotation)\n"
            return -1
        }
        if {[string match "$res_info1($rst,usage)" "$res_info2($rst,usage)"]} {
            ts_log_finer "resource $rst has the same usage in both resource infos"                            
        } else {
            append result_et "Resource $rst has different usage: $res_info1($rst,usage), $res_info2($rst,usage)\n"
            return -1
        }      
        if {[llength $res_prop1($rst,prop_list)] == [llength $res_prop2($rst,prop_list)]} {
            ts_log_finer "both resource property lists of $rst contain the same number of properties"      
            foreach prop $res_prop1($rst,prop_list) { 
                set has [lsearch -exact $res_prop2($rst,prop_list) $prop]
                if { $has < 0 } {
                    append result_et "ambiguous resource property list 2 does not contain property $prop"                                
                    return -1
                } else {
                    ts_log_finer "both ambiguous resource property lists contain property $prop"
                    if {[string match "$res_prop1($rst,$prop)" "$res_prop2($rst,$prop)"]} {
                        ts_log_finer "resource $rst has the same value of property $prop"                            
                    } else {
                        append result_et "resource property $prop of resource $rst differs: $res_prop1($rst,$prop), $res_prop2($rst,$prop)\n"
                        return -1
                    }
                }
            }
        } else {
            append result_et "resource property lists of $rst do not contain the same number of resources"
            return -1
        }
    }
    return 0
}

#****** util/produce_unassigning_resource() ******************************************
#  NAME
#     produce_unassigning_resource() -- produce resource UNASSIGNING state
#
#  SYNOPSIS
#     produce_unassigning_resource { resource {sji sleeper_job_id} } 
#
#  FUNCTION
#     This procedure will produce resource UNASSIGNING state by submitting a long
#     running sleeper job to a resource assigned to GE and then by triggering a 
#     remove of the  the resource from system.    
#     After that the procedure also checks that the resource is in
#     UNASSIGNING state.
#   
#     The UNASSIGNING state reset is done by reset_produced_unassigning_resource().
#
#  INPUTS
#     resource          - name of the resource to set into unassigning state
#     sji               - optional: job id of a sleeper job, needed for reset
#     service           - optional: name of the ge service, needed for reset
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     util/reset_produced_unassigning_resource()
#*******************************************************************************
proc produce_unassigning_resource { resource { sji sleeper_job_id } { svc ge_service} } {
   get_current_cluster_config_array ts_config

   set ge_hosts [get_hedeby_current_services service_names]
   
   upvar $sji job_id
   if {[info exists job_id]} {
      unset job_id
   }

   upvar $svc service
   if {[info exists service]} {
      unset service
   }

   if { ![info exists service_names(ts_cluster_nr,$resource)] } {
      ts_log_severe "resource $resource not found!"
      return 1
   }

   set sCluster $service_names(ts_cluster_nr,$resource)
   set service $service_names(service,$resource)

   set oldCluster [get_current_cluster_config_nr]
   set_current_cluster_config_nr $sCluster

   # set sleep timeout to reasonable big value, e.g. one day (in sec) = 24*3600
   set sleeptimeout 86400
   set remote_host_arg "-l h=$resource"
   set output_argument "-o /dev/null -e /dev/null"
   set job_argument "$ts_config(product_root)/examples/jobs/sleeper.sh $sleeptimeout"
   set job_id [submit_job "$remote_host_arg $output_argument $job_argument" 1 60 "" [get_hedeby_admin_user]]
   # wait until job gets out of pending list and will be running
   wait_for_jobstart $job_id "leeper" 30 1 1           
   set_current_cluster_config_nr $oldCluster

   # trigger move of resource to spare_pool, that should bring resource to UNASSIGNING state
   set output [sdmadm_command_opt "mvr -r $resource -s spare_pool"]
   if { $prg_exit_state != 0 } {
       ts_log_severe "Resource move was not triggered: exit state \"$prg_exit_state\" doesn't match the expected exit state \"0\": $output"
       return 1
   } else {
       ts_log_finer "Move of resource $resource was triggered"        
   }    

   # wait for resource to go into unassigning state
   ts_log_fine "Resource \"$resource\" should go into unassigning state now ..."
   set exp_res_info($resource,state) "UNASSIGNING"
   wait_for_resource_info exp_res_info 60 0 error_text

   if { $error_text != "" } {
      ts_log_severe $error_text
      return 1
   }
   return 0
}

#****** util/reset_produced_unassigning_resource() ******************************************
#  NAME
#     reset_produced_unassigning_resource() -- reset resource in UNASSIGNING state
#
#  SYNOPSIS
#     reset_produced_unassigning_resource { resource sleeper_job_id service
#                                          {move_interrupted} } 
#
#  FUNCTION
#     This procedure will reset resource in UNASSIGNING state produced by 
#     produce_unassigning_resource() by deleting a sleeper job (that will
#     result into a moving of the resource to spare_pool). Following, the 
#     resource is moved back to its original service.
#     After that the procedure also checks that the resource is in
#     ASSIGNED state.
#
#     If an error occured during the procedure a reset_hedeby will be performed.
#   
#  INPUTS
#     resource           - name of the resource in unassigning state
#     sleeper_job_id     - job id of a sleeper job
#     service            - original service of the resource
#     {move_interrupted 0} - if set to 0 resource is expected in spare_pool
#                            if set to != 0 resource is at his original service
#
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     util/produce_unassigning_resource()
#*******************************************************************************
proc reset_produced_unassigning_resource { resource sleeper_job_id service {move_interrupted 0}} {
   set ge_hosts [get_hedeby_current_services service_names]
      
   if { ![info exists service_names(ts_cluster_nr,$resource)] } {
      ts_log_severe "resource $resource not found!"
      return 1
   }

   set sCluster $service_names(ts_cluster_nr,$resource)
 
   set oldCluster [get_current_cluster_config_nr]
   set_current_cluster_config_nr $sCluster
   set error_text ""

   # delete sleeper job and wait for job end!
   set result [delete_job $sleeper_job_id 1]

   set_current_cluster_config_nr $oldCluster

   if { $result != 0} {
      ts_log_fine "error has occured while deleting sleeper job, resource can not be reset."
      return 1
   }     

   # wait for resource state changes from "UNASSINING" to "ASSIGNED"
   set exp_resource_info($resource,state) "ASSIGNED"
   if {[wait_for_resource_info exp_resource_info 120 0 tmp_error "" "" resource_info res_prop res_list res_list_not_uniq 1] != 0} {
      append error_text "wait_for_resource_info failed:\n$tmp_error\n"
   }

   set current_service $resource_info($resource,service)
   if {$move_interrupted != 0} {
      if { $current_service != $service } {
         append error_text "resource $resource is at service \"$current_service\", should be \"$service\"\n"
      }
   } else {
      if { $current_service != "spare_pool" } {
         append error_text "resource $resource is at service \"$current_service\", should be \"spare_pool\"\n"
      }
   }

   # check if we have to move the resource back to original service
   set is_moved 0
   set is_ok 0
   if {$resource_info($resource,state) == "ASSIGNED"} {
      ts_log_finer "$resource is in \"ASSIGNED\" state - good" 
      if {$current_service == "spare_pool"} {
         ts_log_fine "$resource has been moved to spare_pool"
         set is_moved 1
         set is_ok 1
      }
      if {$current_service == $service} {
         ts_log_fine "$resource is at original service"
         set is_ok 1
      } 
      if { $is_ok == 0 } {
         append error_text "resource $resource is at service $current_service which is not expected\n"
      }
   } 
   
   if { $is_moved == 1 } {
      # yes, resource is now at spare_pool
      # trigger move of resource to original service
      set sdmadm_command_line 
      set output [sdmadm_command_opt "mvr -r $resource -s $service"]
      if { $prg_exit_state != 0 } {
         ts_log_severe "Resource move was not triggered: exit state \"$prg_exit_state\" doesn't match the expected exit state \"0\": $output"
         return [reset_hedeby 1]
      } else {
         ts_log_finer "Move of resource $resource was triggered"
      }
        
      ts_log_fine "resource \"$resource\" should appear in \"$service\" in assigned state ..."
      set exp_res_info($resource,state) "ASSIGNED"
      set exp_res_info($resource,service) "$service"
      set tmp_error ""
      if {[wait_for_resource_info exp_res_info 60 0 tmp_error "" "" resource_info res_prop res_list res_list_not_uniq 1] != 0} {
         append error_text "wait_for_resource_info failed:\n$tmp_error\n"
      }
   }

   # check for errors and do reset hedeby if there were ...
   if { $error_text != "" } {
      append error_text "\nreset hedeby now ..."
      ts_log_severe $error_text
      return [reset_hedeby 1]
   }
   ts_log_fine "Resource $resource is back in service $service"
   return 0
}

#****** util/reset_default_slos() **********************************************
#  NAME
#     reset_default_slos() -- reset default slo settings for default config
#
#  SYNOPSIS
#     reset_default_slos { method {services "all"} {raise_error 1} } 
#
#  FUNCTION
#     First the procedure checks that all involved components are started, after
#     that it resets the default slo configuration settings for the
#     specified service list. It supports the service "spare_pool" and ge
#     services. The method "mod_config" modifies the component configuration
#     and will reload (update) the compoent after modification. The method
#     "mod_slos" is using the cli interface for setting slos.
#
#     ATTENTION: After performing the command the defaults settings for ALL
#                services are checked with sdmadm sslo -u command.
#
#  INPUTS
#     method           - Method specification "mod_config" or "mod_slos"
#     {services "all"} - optional: If "all" (default) all default services
#                                  will get its default slo settings.
#                                  Or a list of service names.
#     {raise_error 1}  - optional: If "1" errors are reported.
#
#  RESULT
#     0 on success, 1 on error
#
#  NOTES
#     "mod_slos" method is not yet implemented and will use "mod_config" 
#     currently.
#     
#     ATTENTION: components must be started
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/create_permanent_request_slo()
#     util/set_hedeby_slos_config()
#*******************************************************************************
proc reset_default_slos { method {services "all"} {raise_error 1} } {
   ts_log_fine "Resetting default SLOs for services '$services' ..."

   if { $method != "mod_config" && $method != "mod_slos" } {
      ts_log_severe "Method \"$method\" not supported. Use \"mod_config\" or \"mod_slos\""
      return 1
   }

   set error_text ""
   get_hedeby_default_services service_names
   set call_opts(raise_error) $raise_error

   # Setup expected service infos (used twice in this procedure)
   if {$services == "all"} {
      set exp_serv_info(spare_pool,cstate) "STARTED"
      foreach service $service_names(services) {
         set exp_serv_info($service,cstate) "STARTED"
      }
   } else {
      foreach service $services {
         set exp_serv_info($service,cstate) "STARTED"
      }
   }

   # Wait for components to be STARTED
   if {[wait_for_service_info exp_serv_info 60 $raise_error] != 0} {
      ts_log_fine "wait_for_service_info failed - skip further actions!"
      return 1
   }

   # TODO: Implement "mod_slos" if cli available
   if {$method == "mod_slos"} {
      ts_log_info "Method \"mod_slos\" currently not supported, using method \"mod_config\""
      set method "mod_config"
   }

   # Change slos by modify the component configurations and update the components after that
   if {$method == "mod_config"} {
      # reset services
      set host_list {}
      set default_slo [create_fixed_usage_slo 50 "fixed_usage"]
      foreach service $service_names(services) {
         if {[lsearch -exact $services "all"] < 0 &&
             [lsearch -exact $services $service] < 0} {
            ts_log_fine "skip not requested service \"$service\""
            continue
         }
         set call_opts(do_update) 0
         if {[set_hedeby_slos_config $service $default_slo call_opts] != 0} {
            append error_text "setting slos for service \"$service\" failed!"
         }
         unset call_opts(do_update)
         # setup update component command
         set host $service_names(master_host,$service)
         lappend host_list $host
         set task_info($host,expected_output) ""
         set task_info($host,sdmadm_command) "uc -c $service"
      }

      # now update the components (services)
      if {[llength $host_list] > 0} {
         ts_log_fine "updating services ..."
         append error_text [start_parallel_sdmadm_command_opt host_list task_info call_opts]
      } else {
         ts_log_fine "no default services to update"
      }
      
      # reset spare_pool
      if {[lsearch -exact $services "all"] >= 0 ||
          [lsearch -exact $services "spare_pool"] >= 0} {
         ts_log_fine "resetting \"spare_pool\" ..."
         # set spare pool SLO and update component
         # don't wait for service state, this is done below
         set default_spare_pool_slo [create_permanent_request_slo 1 "PermanentRequestSLO"]
         set call_opts(do_wait_for_state) 0
         if {[set_hedeby_slos_config "spare_pool" $default_spare_pool_slo call_opts] != 0} {
            append error_text "setting slos for service \"spare_pool\" failed!"
         }
         unset call_opts(do_wait_for_state)
      } else {
         ts_log_fine "no reset of \"spare_pool\" requested!"
      }
   }

   # Wait for all components in STARTED state
   wait_for_service_info exp_serv_info 60 $raise_error


   set tservice   [create_bundle_string "ShowSLOCliCommand.col.service"]
   set tslo       [create_bundle_string "ShowSLOCliCommand.col.slo"]
   set tresource  [create_bundle_string "ShowSLOCliCommand.col.resource"]
   set tusage     [create_bundle_string "ShowSLOCliCommand.col.usage" ]
   set tnot_avail [create_bundle_string "ShowSLOCliCommand.na"]

   # Check that show slos report the correct values
   set call_opts(table_output) table
   set output [sdmadm_command_opt "sslo -u" call_opts]
   unset call_opts(table_output)
   if { $prg_exit_state == 0 } {
      ts_log_fine "checking slo settings ..."
      for {set line 0} {$line < $table(table_lines)} {incr line 1} {
         if {$table($tservice,$line) == "spare_pool"} {
            set expected_slo_name "PermanentRequestSLO"
            set expected_usage    1
         } else {
            set expected_slo_name "fixed_usage"
            set expected_usage    50
         }
         set out_ser $table($tservice,$line)
         set out_slo $table($tslo,$line)
         set out_res $table($tresource,$line)
         set out_usa $table($tusage,$line)
         if { $out_res == $tnot_avail } {
            ts_log_fine "skip resource name \"$tnot_avail\""
            continue
         }
         ts_log_fine "service \"$out_ser\" has slo \"$out_slo\" defined for resource \"$out_res\" with a usage of \"$out_usa\""
         if {$out_usa != $expected_usage} {
            append error_text "Defined usage of service \"$out_ser\" resource \"$out_res\" is set to \"$out_usa\", should be \"$expected_usage\"\n"
         }
         if {$out_slo != $expected_slo_name} {
            append error_text "Defined slo of service \"$out_ser\" resource \"$out_res\" is set to \"$out_slo\", should be \"$expected_slo_name\"\n"
         }
      }
   } else {
      append error_text "sdmadm $sdmadm_command_line exited with status=$prg_exit_state:\n$output\n"
   }
   if {$error_text != ""} {
      ts_log_severe "$error_text" $raise_error
      return 1
   }

   return 0
}

#****** util/set_service_slos() ************************************************
#  NAME
#     set_service_slos() -- used to set slos for a service
#
#  SYNOPSIS
#     set_service_slos { method service slos {raise_error 1} 
#     {update_interval_unit "minutes"} {update_interval_value "5"} } 
#
#  FUNCTION
#     If the method "mod_config" is used the procedure is using 
#     set_hedeby_slos_config() to modify the service component configurations 
#     and and will also update the component after modification. 
#
#     If the method "mod_slos" is used the procedure will also use method
#     "mod_config" until mod slos cli commands are available.
#
#  INPUTS
#     method                     - "mod_config" or "mod_slos"
#     service                    - name of service to modify
#     slos                       - list of slos
#                                  (created with create_???_slo() 
#                                   procedures and added to a list)
#     {raise_error 1}            - if 1 report errors
#     {update_interval_unit ""}  - slo update unit of service
#     {update_interval_value ""} - slo update value of service
#
#  RESULT
#     0 on success, 1 on error
#
#  NOTES
#     "mod_slos" method is not implemented
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/create_permanent_request_slo()
#     util/set_hedeby_slos_config()
#*******************************************************************************
proc set_service_slos { method service slos {raise_error 1} {update_interval_unit ""} {update_interval_value ""}} {
   global hedeby_config

   if { $method != "mod_config" && $method != "mod_slos" } {
      ts_log_severe "Method \"$method\" not supported. Use \"mod_config\" or \"mod_slos\""
      return 1
   }

   set error_text ""
   set call_opts(raise_error) $raise_error
   set call_opts(update_interval_unit)  $update_interval_unit
   set call_opts(update_interval_value) $update_interval_value

   # Wait for service component to be STARTED
   set exp_serv_info($service,cstate) "STARTED"
   if {[wait_for_service_info exp_serv_info 60 $raise_error] != 0} {
      ts_log_fine "wait_for_service_info failed - skip further actions!"
      return 1
   }

   # TODO: Implement "mod_slos" if cli available
   if {$method == "mod_slos"} {
      ts_log_info "Method \"mod_slos\" currently not supported, using method \"mod_config\""
      set method "mod_config"
   }

   # Change slos
   if {$method == "mod_config"} {
      # set slo config
      if {[set_hedeby_slos_config $service $slos call_opts] != 0} {
         append error_text "setting slos for service \"$service\" failed!"
      }
   }

   if {$error_text != ""} {
      ts_log_severe "$error_text" $raise_error
      return 1
   }

   return 0
}


#****** util/set_service_slos_opt() ********************************************
#  NAME
#     set_service_slos_opt() -- Opt version of set_service_slos 
#
#  SYNOPSIS
#     set_service_slos_opt { service slos {opt ""} } 
#
#  FUNCTION
#
#     Modifies the SLO setup of a service and reloads the service
#
#  INPUTS
#     service  - name of the service
#     slos     - list of slos (elements created with create_???_slo() 
#     {opt ""} - options for the method. The following options are supported
#
#        opt(method)                 -  SLO modification method (currently only mod_config is supported)
#        opt(update_interval_unit)   -  Unit for the update interval of the SLO 
#                                       (works only for GE services, default is "")
#        opt(update_interval_value)  -  Value for the update interval of the SLO 
#                                        (works only for GE services, default is "")
#        opt(requestFilter)  -  *Complete* xml tag for the request filter of the SLO
#                               (in the form <common:request>....</common:request>) 
#                               (default "")
#        opt(resourceFilter) -  *Complete* xml tag for the request filter of the SLO
#                               (in the form <common:resourceFilter>....</common:resourceFilter>) 
#                               (default "")
#        opt(raise_error)            -  if 0 no error will be raised (default is 1)
#
#  RESULT
#     0 on success, 1 on error
#
#  NOTES
#     "mod_slos" method is not implemented
#
#  SEE ALSO
#     util/create_min_resource_slo()
#     util/create_fixed_usage_slo()
#     util/create_max_pending_jobs_slo()
#     util/set_service_slos()
#*******************************************************************************
proc set_service_slos_opt { service slos {opt ""} } {

   set opts(method)                "mod_config"
   set opts(update_interval_unit)  ""
   set opts(update_interval_value) "" 
   set opts(requestFilter)         ""
   set opts(resourceFilter)        ""
   set opts(raise_error)           1

   get_hedeby_proc_opt_arg $opt opts


   return [set_service_slos $opts(method) $service $slos $opts(raise_error) \
                            $opts(update_interval_unit) $opts(update_interval_value)]
}


#****** util/set_execd_install_params() **************************************************
#  NAME
#    set_execd_install_params() -- set the parameters for the execd installation for a ge service
#
#  SYNOPSIS
#    set_execd_install_params { service my_execd_install_params } 
#
#  FUNCTION
#     This method modifies the execd install parameters for a GE service
#
#  INPUTS
#    service -- name of the GE service
#    my_execd_install_params -- array with the new execd install parameters. The can contain
#                               for each host the following parameters
#
#        spool_dir          defines the local spool dir for the execds on this host. If the spool dir
#                            is not defined for a host the default execd spool dir is used.
#
#        install_template   defines the path to the execd install template
#        uninstall_template defines the path to the execd uninstall template
#
#  RESULT
#     The exit state of the "sdmadm mc"
#
#  EXAMPLE
#     set execd_params(hostA,spool_dir) "/tmp/myspooldir/hostA"
#     set execd_params(hostB,spool_dir) "/tmp/myspooldir/hostB"
#     set_execd_install_params "ge-service1" execd_params
#
#  SEE ALSO
#     util/get_hedeby_execd_install_params_sequence()
#*******************************************************************************
proc set_execd_install_params { service my_execd_install_params } {
   upvar $my_execd_install_params execd_install_params
   
   ts_log_fine "set execd params for GE service '$service' ..."
   
   set sequence [get_hedeby_execd_install_params_sequence execd_install_params]
   
   set opt(do_update) 0
   return [hedeby_change_component $service $sequence opt]
}

#****** util/get_hedeby_execd_install_params_sequence() ************************
#  NAME
#     get_hedeby_execd_install_params_sequence() -- get the execd install params vi sequence 
#
#  SYNOPSIS
#     get_hedeby_execd_install_params_sequence { my_execd_install_params } 
#
#  FUNCTION
#      
#     build the vi sequence for modifying the execd install parameters of a GE service.
#
#  INPUTS
#    my_execd_install_params -- array with the new execd install parameters. The can contain
#                               for each host the following parameters
#
#        spool_dir          defines the local spool dir for the execds on this host. If the spool dir
#                            is not defined for a host the default execd spool dir is used.
#
#        install_template   defines the path to the execd install template
#        uninstall_template defines the path to the execd uninstall template
#
#  RESULT
#     a tcl list for the vi sequence for modifying the execd install params 
#
#  SEE ALSO
#     util/set_execd_install_params
#*******************************************************************************
proc get_hedeby_execd_install_params_sequence { my_execd_install_params } {
   global hedeby_config

   upvar $my_execd_install_params execd_install_params
   
   set managed_host_list [get_all_movable_resources]

   set param_names { spool_dir install_template uninstall_template }
   
   # store in execd_params the DIFFERENT configurations:
   # for each host: first gather parameters, then check if the exact same
   # parameter set already exists for a different host => simply append the
   # host, otherwise make a new parameter set
   set execd_params(count) 0
   foreach host $managed_host_list {
      foreach param_name $param_names {
         if {[info exists execd_install_params($host,$param_name)]} {
            set param_value($param_name) $execd_install_params($host,$param_name)
         } else {
            # no value for this parameter specified, use the default value
            switch -- $param_name {
               spool_dir {
                  set param_value($param_name) [get_local_spool_dir $host "execd" 0]
               }
               default {
                  set param_value($param_name) "default"
               }
            }
         }
      }
      
      # Search for a match execd_params set
      set execd_params_index -1

      for {set i 0} {$i < $execd_params(count)} {incr i} {
         set matches 1
         foreach param_name $param_names {
            if {$param_value($param_name) != $execd_params($i,$param_name)} {
               set matches 0
               break
            }
         }
         if {$matches == 1} {
            lappend execd_params($i,hosts) $host
            set execd_params_index $i
            break
         }
      }
      
      if { $execd_params_index == -1 } {
         # did not find a matching param set, create a new one
         set execd_params_index $execd_params(count)
         incr execd_params(count) 1
         foreach param_name $param_names {
            set execd_params($execd_params_index,$param_name) $param_value($param_name)
         }
         set execd_params($execd_params_index,hosts) $host
      }
      unset param_value
   }
   
   set log_message ""
   set sequence {}   
   lappend sequence "[format "%c" 27]" ;# ESC
      
   # Delete all available execd configurations
   
   ## goto the first line
   lappend sequence "1G"
   ## Search for the for execd install param
   lappend sequence "/<ge_adapter:execd\n"
   ## The xml schema guarantees that the execd install params
   ## are the last entries in the xml file
   ## => delete to EOF
   lappend sequence dG
   
   # insert at the end of the config the new execd parameters
   lappend sequence "GA"
   
   lappend sequence "<!-- =========================================================\n"
   lappend sequence "     Start of modifications with set_execd_install_params     \n"
   lappend sequence "     =========================================================-->\n"
   
   for {set i 0} {$i < $execd_params(count)} {incr i} {
      lappend sequence "<!-- =========================================================\n"
      lappend sequence "     execd install params set number $i\n"
      lappend sequence "     =========================================================-->\n"
      lappend sequence "<ge_adapter:execd adminUsername=\"root\" defaultDomain=\"\" ignoreFQDN=\"true\" rcScript=\"false\" adminHost=\"true\"\n"
      lappend sequence "submitHost=\"true\" cleanupDefault=\"false\">\n"
      lappend sequence "<ge_adapter:filter>\n"
      set isFirst 1
      foreach host $execd_params($i,hosts) {
         if { $isFirst == 0 } {
            lappend sequence " | "
         }
         lappend sequence "resourceHostname = \"$host\"\n"
         set isFirst 0
      }
      lappend sequence "</ge_adapter:filter>\n"
      lappend sequence "<ge_adapter:localSpoolDir>$execd_params($i,spool_dir)</ge_adapter:localSpoolDir>\n"
      
      if {$execd_params($i,install_template) != "default"} {
         lappend sequence "<ge_adapter:installTemplate>\n"
         lappend sequence "<ge_adapter:script>$execd_params($i,install_template)</ge_adapter:script>\n"
         lappend sequence "</ge_adapter:installTemplate\n>"
      }
      if { $execd_params($i,uninstall_template) != "default" } {
         lappend sequence "<ge_adapter:uninstallTemplate>\n"
         lappend sequence "<ge_adapter:script>$execd_params($i,uninstall_template)</ge_adapter:script>\n"
         lappend sequence "</ge_adapter:uninstallTemplate>\n"
      }
      lappend sequence "</ge_adapter:execd>\n"
      
      append log_message "-------------------------------------------------------------\n"
      append log_message "execd_params for hosts $execd_params($i,hosts)\n"
      foreach param_name $param_names {
         append log_message [format "%-20s:%s\n" $param_name $execd_params($i,$param_name)]
      }
   }
   
   ts_log_fine $log_message
   
   # add execd install settings for simulated hosts
   lappend sequence "<!-- =========================================================\n"
   lappend sequence "     execd install params for simulated hosts\n"
   lappend sequence "     =========================================================-->\n"
   
   lappend sequence "<ge_adapter:execd adminUsername=\"root\" defaultDomain=\"\" ignoreFQDN=\"true\" rcScript=\"false\" adminHost=\"false\"\n"
   lappend sequence "submitHost=\"false\" cleanupDefault=\"false\">\n"
   lappend sequence "<ge_adapter:filter>simhost=\"true\"\n"
   lappend sequence "</ge_adapter:filter>\n"
   lappend sequence "  <ge_adapter:installTemplate executeOn=\"qmaster_host\">"
   lappend sequence "     <ge_adapter:script>util/templates/ge-adapter/install_execd_sim.sh</ge_adapter:script>"
   lappend sequence "  </ge_adapter:installTemplate>"
   lappend sequence "  <ge_adapter:uninstallTemplate executeOn=\"qmaster_host\">"
   lappend sequence "     <ge_adapter:script>util/templates/ge-adapter/uninstall_execd_sim.sh</ge_adapter:script>"
   lappend sequence "  </ge_adapter:uninstallTemplate>"
   lappend sequence "</ge_adapter:execd>\n"
   
   lappend sequence "\n"

    # add execd install settings for cloud hosts
   lappend sequence "<!-- =========================================================\n"
   lappend sequence "     execd install params for cloud hosts\n"
   lappend sequence "     =========================================================-->\n"
   lappend sequence "   <ge_adapter:execd adminUsername='root'\n"
   lappend sequence "                      defaultDomain='' \n"
   lappend sequence "                      ignoreFQDN='true' \n"
   lappend sequence "                      rcScript='false' \n"
   lappend sequence "                      adminHost='true' \n"
   lappend sequence "                      submitHost='false' \n"
   lappend sequence "                      cleanupDefault='true'>\n"
   lappend sequence "        <ge_adapter:filter>cloudResource='true'</ge_adapter:filter>\n"
   lappend sequence "        <ge_adapter:installTemplate needsConfigFile='false' \n"
   lappend sequence "                                    executeOn='qmaster_host'>\n"
   lappend sequence "            <ge_adapter:script>util/templates/ge-adapter/copy_sge_root_to_cloud.sh</ge_adapter:script>\n"
   lappend sequence "        </ge_adapter:installTemplate>\n"
   lappend sequence "        <ge_adapter:installTemplate needsConfigFile='false'\n"
   lappend sequence "                                    executeOn='exec_host'>\n"
   lappend sequence "            <ge_adapter:script>util/templates/ge-adapter/patch_bootstrap_files_on_cloud.sh</ge_adapter:script>\n"
   lappend sequence "        </ge_adapter:installTemplate>\n"
   lappend sequence "        <ge_adapter:installTemplate needsConfigFile='true'\n"
   lappend sequence "                                    executeOn='exec_host'>\n"
   lappend sequence "            <ge_adapter:script>util/templates/ge-adapter/install_execd_cloud.sh</ge_adapter:script>\n"
   lappend sequence "            <ge_adapter:conf>util/templates/ge-adapter/install_execd_cloud.conf</ge_adapter:conf>\n"
   lappend sequence "        </ge_adapter:installTemplate>\n"
   lappend sequence "        <ge_adapter:uninstallTemplate needsConfigFile='true'\n"
   lappend sequence "                                      executeOn='exec_host'>\n"
   lappend sequence "            <ge_adapter:script>util/templates/ge-adapter/uninstall_execd_cloud.sh</ge_adapter:script>\n"
   lappend sequence "            <ge_adapter:conf>util/templates/ge-adapter/uninstall_execd_cloud.conf</ge_adapter:conf>\n"
   lappend sequence "        </ge_adapter:uninstallTemplate>\n"
   lappend sequence "    </ge_adapter:execd>\n"
   lappend sequence "\n"


   # We deleted from <ge_adapter:execd to EOF
   # => the closing common:componentConfig is missing
   lappend sequence "</common:componentConfig>\n"

   lappend sequence "[format "%c" 27]" ;# ESC
   lappend sequence ":w\n"

   return $sequence
}

#****** util/get_resource_slo_info() *******************************************
#  NAME
#     get_resource_slo_info() -- get slo information
#
#  SYNOPSIS
#     get_resource_slo_info { {host ""} {user ""} {rsi res_slo_info} 
#     {raise_error 1} } 
#
#  FUNCTION
#     This procedure is doing sdmadm sslo -u and parsing the output
#
#  INPUTS
#     {host ""}          - host where to start command
#     {user ""}          - user who starts command
#     {rsi res_slo_info} - name of array to store the information
#     {raise_error 1}    - if 1 report errors
#
#  RESULT
#     0 on success, 1 on error
#     The res_slo_info has following entries:
#        resource_slo_info(resource_list) - list of all resources (uniq)
#        resource_slo_info(slo_list)      - list of all slo names (uniq)
#        NOTE: All listed slos and resources are set in the array and have
#              the value "n.a." if not set!
# 
#        resource_slo_info(RESOURCE,SLO,service) - name of service
#        resource_slo_info(RESOURCE,SLO,usage)   - usage of slo for resource
#
#        where RESOURCE is a resource name
#        where SLO is a slo name
#
#  SEE ALSO
#     util/get_resource_info()
#*******************************************************************************
proc get_resource_slo_info {{host ""} {user ""} {rsi res_slo_info} {raise_error 1}} {
   global hedeby_config
   upvar $rsi resource_slo_info

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


   # delete existing info array
   if {[info exists resource_slo_info]} {
      unset resource_slo_info
   }

   # fill up array with default "not available" string
   set resource_slo_info(resource_list) {}
   set resource_slo_info(slo_list) {}

   # get some default settings
   set error_text ""
   set pref_type [get_hedeby_pref_type]
   set sys_name [get_hedeby_system_name]
   
   # get correct table names
   set tservice   [create_bundle_string "ShowSLOCliCommand.col.service"]
   set tslo       [create_bundle_string "ShowSLOCliCommand.col.slo"]
   set tresource  [create_bundle_string "ShowSLOCliCommand.col.resource"]
   set tusage     [create_bundle_string "ShowSLOCliCommand.col.usage" ]
   set tnot_avail [create_bundle_string "ShowSLOCliCommand.na"]


   # start sslo -u command
   set sdmadm_command_line "-p $pref_type -s $sys_name sslo -u"
   set output [sdmadm_command $execute_host $execute_user $sdmadm_command_line prg_exit_state "" $raise_error table]
   if { $prg_exit_state == 0 } {
      ts_log_fine "checking slo settings ..."
      for {set line 0} {$line < $table(table_lines)} {incr line 1} {
         set out_ser $table($tservice,$line)
         set out_slo $table($tslo,$line)
         set out_res $table($tresource,$line)
         set out_usa $table($tusage,$line)
         if { $out_res == $tnot_avail } {
            ts_log_fine "skip resource name \"$tnot_avail\""
            continue
         }
         set out_res [resolve_host $out_res]
         if {[lsearch -exact $resource_slo_info(resource_list) $out_res] < 0} {
            lappend resource_slo_info(resource_list) $out_res
         }
         if {[lsearch -exact $resource_slo_info(slo_list) $out_slo] < 0} {
            lappend resource_slo_info(slo_list) $out_slo
         }
         set resource_slo_info($out_res,$out_slo,service) $out_ser
         set resource_slo_info($out_res,$out_slo,usage) $out_usa
      }
   } else {
      append error_text "sdmadm $sdmadm_command_line exited with status=$prg_exit_state:\n$output\n"
   }

   # set not available values in the returned array
   foreach res $resource_slo_info(resource_list) {
      foreach slo $resource_slo_info(slo_list) {
         if {[info exists resource_slo_info($res,$slo,service)] == 0} {
            set resource_slo_info($res,$slo,service) "n.a."
         }
         if {[info exists resource_slo_info($res,$slo,usage)] == 0} {
            set resource_slo_info($res,$slo,usage) "n.a."
         } else {
            ts_log_finer "resource \"$res\" at service \"$resource_slo_info($res,$slo,service)\" has slo \"$slo\" with urgceny \"$resource_slo_info($res,$slo,usage)\""
         }
      }
   }

   if {$error_text != ""} {
      ts_log_severe "$error_text" $raise_error
      return 1
   }
   return 0
}

#****** util/get_service_slo_info() ********************************************
#  NAME
#     get_service_slo_info() -- get sdmadm sslo information
#
#  SYNOPSIS
#     get_service_slo_info { {host ""} {user ""} {ssi ser_slo_info} 
#     {raise_error 1} } 
#
#  FUNCTION
#     This procedure returns the output of sdmadm sslo in a tcl array
#
#  INPUTS
#     {host ""}          - host where sdmadm should be started
#     {user ""}          - user who should start sdmadm command
#     {ssi ser_slo_info} - array to store the output information
#     {raise_error 1}    - if 1 raise TS errors
#
#  RESULT
#     0 on success, 1 on error
#
#     The output array has the following format:
#
#          ser_slo_info(service_list) - list of all service names
#          ser_slo_info(slo_list)     - list of all slo names
#
#          ser_slo_info(SERVICE,SLO,quantity) - quantity value
#          ser_slo_info(SERVICE,SLO,urgency)  - urgency value
#          ser_slo_info(SERVICE,SLO,request)  - request value
# 
#          where SERVICE is a service name
#          where SLO is a slo name
#          
#
#  SEE ALSO
#     util/wait_for_service_slo_info()
#*******************************************************************************
proc get_service_slo_info {{host ""} {user ""} {ssi ser_slo_info} {raise_error 1}} {
   global hedeby_config
   upvar $ssi service_slo_info

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


   # delete existing info array
   if {[info exists service_slo_info]} {
      unset service_slo_info
   }

   # fill up array with default "not available" string
   set service_slo_info(service_list) {}
   set service_slo_info(slo_list) {}

   # get some default settings
   set error_text ""
   set pref_type [get_hedeby_pref_type]
   set sys_name [get_hedeby_system_name]
   
   # get correct table names
   set tservice   [create_bundle_string "ShowSLOCliCommand.col.service"]
   set tslo       [create_bundle_string "ShowSLOCliCommand.col.slo"]
   set tquantity  [create_bundle_string "ShowSLOCliCommand.col.quantity"]
   set turgency   [create_bundle_string "ShowSLOCliCommand.col.urgency" ]
   set trequest   [create_bundle_string "ShowSLOCliCommand.col.request"]

   # start sslo command
   set sdmadm_command_line "-p $pref_type -s $sys_name sslo"
   set output [sdmadm_command $execute_host $execute_user $sdmadm_command_line prg_exit_state "" $raise_error table]
   if { $prg_exit_state == 0 } {
      ts_log_fine "checking service slo settings ..."
      for {set line 0} {$line < $table(table_lines)} {incr line 1} {
         set out_ser $table($tservice,$line)
         set out_slo $table($tslo,$line)
         set out_qua $table($tquantity,$line)
         set out_urg $table($turgency,$line)
         set out_req $table($trequest,$line)
         if {[lsearch -exact $service_slo_info(service_list) $out_ser] < 0} {
            lappend service_slo_info(service_list) $out_ser
         }
         if {[lsearch -exact $service_slo_info(slo_list) $out_slo] < 0} {
            lappend service_slo_info(slo_list) $out_slo
         }
         set service_slo_info($out_ser,$out_slo,quantity) $out_qua
         set service_slo_info($out_ser,$out_slo,urgency) $out_urg
         set service_slo_info($out_ser,$out_slo,request) $out_req
      }
   } else {
      append error_text "sdmadm $sdmadm_command_line exited with status=$prg_exit_state:\n$output\n"
   }

   # set not available values in the returned array
   foreach ser $service_slo_info(service_list) {
      foreach slo $service_slo_info(slo_list) {
         foreach elem "quantity urgency request" {
            if {[info exists service_slo_info($ser,$slo,$elem)] == 0} {
               set service_slo_info($ser,$slo,$elem) "n.a."
            }
            ts_log_finer "service_slo_info($ser,$slo,$elem)=$service_slo_info($ser,$slo,$elem)"
         }
      }
   }

   if {$error_text != ""} {
      ts_log_severe "$error_text" $raise_error
      return 1
   }
   return 0
}

#****** util/wait_for_service_slo_info() ***************************************
#  NAME
#     wait_for_service_slo_info() -- wait for specified sdmadm sslo output
#
#  SYNOPSIS
#     wait_for_service_slo_info { exp_sloinfo {atimeout 60} {raise_error 1} 
#     {ev error_var } {host ""} {user ""} {ssi ser_slo_info} } 
#
#  FUNCTION
#     This procedure is calling get_service_slo_info() until output matches or
#     timeout occurs.
#
#  INPUTS
#     exp_sloinfo        - expected sslo info output
#     {atimeout 60}      - timeout in seconds
#     {raise_error 1}    - if 1 TS reports errors
#     {ev error_var }    - variable to store error text
#     {host ""}          - parameter for get_service_slo_info()
#     {user ""}          - parameter for get_service_slo_info()
#     {ssi ser_slo_info} - parameter for get_service_slo_info()
#
#  RESULT
#     0 on success, 1 on error
#     result array ser_slo_info is described in get_service_slo_info()
#
#  SEE ALSO
#     util/get_service_slo_info()
#*******************************************************************************
proc wait_for_service_slo_info { exp_sloinfo  {atimeout 60} {raise_error 1} {ev error_var } {host ""} {user ""} {ssi ser_slo_info} } {
   global hedeby_config
   # setup arguments
   upvar $exp_sloinfo exp_slo_info
   upvar $ev error_text_up
   upvar $ssi service_slo_info

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
   if {![info exists error_text_up]} {
      # some calling code relies on the initialization of the error_text variable
      set error_text_up ""
   }
   set error_text ""
   set my_timeout [timestamp]
   incr my_timeout $atimeout

   # set expected results info
   set expected_slo_info ""
   set exp_values [array names exp_slo_info]
   foreach val $exp_values {
      append expected_slo_info "$val=\"$exp_slo_info($val)\"\n"
   }
   ts_log_fine "expected slo infos:\n$expected_slo_info"
   while {1} {
      set retval [get_service_slo_info $host $user service_slo_info $raise_error]
      if {$retval != 0} {
         append error_text "break because of get_service_slo_info() returned \"$retval\"!\n"
         append error_text "expected slo info was:\n$expected_slo_info"
         ts_log_fine "ignore this run because get_service_slo_info() returned: $retval"
         foreach val $exp_values {
            if {![info exists service_slo_info($val)]} {
               set service_slo_info($val) "missing"
            }
         }
         break
      }
      set not_matching ""
      foreach val $exp_values {
         if {![info exists service_slo_info($val)]} {
            set service_slo_info($val) "missing"
         }
         if { $service_slo_info($val) == $exp_slo_info($val) } {
            ts_log_fine "slo info(s) \"$val\" matches expected info \"$exp_slo_info($val)\""
         } else {
            append not_matching "slo info \"$val\" is set to \"$service_slo_info($val)\", should be \"$exp_slo_info($val)\"\n"
         } 
      }
      if {$not_matching == ""} {
         ts_log_fine "all specified resource info are matching"
         break
      } else {
         set cur_time [timestamp]
         set cur_time_left [expr ($my_timeout - $cur_time)]
         ts_log_fine "still waiting for specified slo information ... (timeout in $cur_time_left seconds)"
         ts_log_finer "still not matching slo info:\n$not_matching"
      }
      if {[timestamp] >= $my_timeout} {
         append error_text "==> TIMEOUT(=$atimeout sec) while waiting for expected slo states!\n"
         append error_text "==> NOT matching values:\n$not_matching"
         break
      }
      after 1000
   }

   if {$error_text != "" } {
      append error_text_up $error_text
      ts_log_severe $error_text $raise_error
      return 1
   }
   return 0
}

#****** util/get_show_resource_request_info() **********************************
#  NAME
#     get_show_resource_request_info() -- get sdmadm srr -all output
#
#  SYNOPSIS
#     get_show_resource_request_info { {host ""} {user ""} {rri res_req_info} 
#     {raise_error 1} } 
#
#  FUNCTION
#     This procedure is starting sdmadm srr -all and returns the output info
#     in a tcl array.
#
#  INPUTS
#     {host ""}          - host where sdmadm should be started
#     {user ""}          - user who starts the command
#     {rri res_req_info} - name of array to parse the output info into
#     {raise_error 1}    - if 1 TS reports errors
#
#  RESULT
#     0 on success, 1 on error
#
#       res_req_info(service_list) - list of all service names
#       res_req_info(slo_list)     - list of all slo names
#
#       res_req_info(SERVICE,SLO,type)     - type value
#       res_req_info(SERVICE,SLO,urgency)  - urgency value
#       res_req_info(SERVICE,SLO,quantity) - quantity value
#       res_req_info(SERVICE,SLO,requests) - requests value
#
#  SEE ALSO
#     util/get_service_slo_info()
#*******************************************************************************
proc get_show_resource_request_info {{host ""} {user ""} {rri res_req_info} {raise_error 1}} {
   global hedeby_config
   upvar $rri resource_request_info

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

   # delete existing info array
   if {[info exists resource_request_info]} {
      unset resource_request_info
   }

   # fill up array with default "not available" string
   set resource_request_info(service_list) {}
   set resource_request_info(slo_list) {}

   # get some default settings
   set error_text ""
   set pref_type [get_hedeby_pref_type]
   set sys_name [get_hedeby_system_name]
   
   # get correct table names
   set ttype     [create_bundle_string "ShowRequestCliCommand.col.type"]
   set tservice  [create_bundle_string "ShowRequestCliCommand.col.service"]
   set tslo      [create_bundle_string "ShowRequestCliCommand.col.slo"]
   set turgency  [create_bundle_string "ShowRequestCliCommand.col.urgency"]
   set tquantity [create_bundle_string "ShowRequestCliCommand.col.quantity"]
   set trequests [create_bundle_string "ShowRequestCliCommand.col.request"]

   # start srr -all command
   set sdmadm_command_line "-p $pref_type -s $sys_name srr -all"
   set output [sdmadm_command $execute_host $execute_user $sdmadm_command_line prg_exit_state "" $raise_error table]
   if { $prg_exit_state == 0 } {
      ts_log_fine "checking resource provider slo requests ..."
      for {set line 0} {$line < $table(table_lines)} {incr line 1} {
         set out_typ $table($ttype,$line)
         set out_ser $table($tservice,$line)
         set out_slo $table($tslo,$line)
         set out_urg $table($turgency,$line)
         set out_qua $table($tquantity,$line)
         set out_req $table($trequests,$line)
         if {[lsearch -exact $resource_request_info(service_list) $out_ser] < 0} {
            lappend resource_request_info(service_list) $out_ser
         }
         if {[lsearch -exact $resource_request_info(slo_list) $out_slo] < 0} {
            lappend resource_request_info(slo_list) $out_slo
         }
         set resource_request_info($out_ser,$out_slo,type)     $out_typ
         set resource_request_info($out_ser,$out_slo,urgency)  $out_urg
         set resource_request_info($out_ser,$out_slo,quantity) $out_qua
         set resource_request_info($out_ser,$out_slo,requests) $out_req
      }
   } else {
      append error_text "sdmadm $sdmadm_command_line exited with status=$prg_exit_state:\n$output\n"
   }

   # set not available values in the returned array
   foreach ser $resource_request_info(service_list) {
      foreach slo $resource_request_info(slo_list) {
         foreach elem "type urgency quantity requests" {
            if {[info exists resource_request_info($ser,$slo,$elem)] == 0} {
               set resource_request_info($ser,$slo,$elem) "n.a."
            } 
            ts_log_finer "resource_request_info($ser,$slo,$elem)=$resource_request_info($ser,$slo,$elem)"
         }
      }
   }

   if {$error_text != ""} {
      ts_log_severe "$error_text" $raise_error
      return 1
   }
   return 0
}

#****** util/get_hedeby_resource_properties() *******
#  NAME
#     get_hedeby_resource_properties() -- get the properties of a resource
#
#  SYNOPSIS
#     get_hedeby_resource_properties { resource my_properties {opt ""} } {
#
#
#  FUNCTION
#     This procedure gets the properties of a resource. The properties are
#     obtained by calling 'sdmadm sr -all' and the properties are returned as
#     key => value pairs in the array properties.
#
#  INPUTS
#     resource           - id of the resource
#     properties         - name of the array in which the properties of
#                          resource are returned
#
#     opt                - optional named arguments, see get_hedeby_proc_default_opt_args()
#
#  RESULT
#     properties of the resource in array properties
#
#  SEE ALSO
#     util/mod_hedeby_resource()
#     util/get_hedeby_proc_opt_arg()
#*******************************************************************************
proc get_hedeby_resource_properties { resource properties {opt ""} } {
   upvar $properties props

   get_hedeby_proc_opt_arg $opt opts

   # get the properties for the specified resource
   # $table_output(additional,0) contains the resource properties
   set opts(table_output) table_output
   # try to work around issue 550 by not using -r $resource but -rf ...
   if {[regexp "res#\[0-9\]+" $resource] == 0} {
      sdmadm_command_opt "show_resource -rf 'resourceHostname=\"$resource\"' -all" opts 
   } else {
      sdmadm_command_opt "show_resource -r $resource -all" opts 
   }

   # ... and save them in props array
   foreach prop_line [split $table_output(additional,0) " "] {
      set split_list [split $prop_line "="]
      set prop_name  [lindex $split_list 0]
      set prop_value [lindex $split_list 1]
      set props($prop_name) $prop_value
   }

   ts_log_finest [format_array props]

   return
}
      

#****** util/mod_hedeby_resource() ******************************************
#  NAME
#     mod_hedeby_resource() -- modify a resource
#
#  SYNOPSIS
#     mod_hedeby_resource { resource my_properties {opt ""} }
#
#
#  FUNCTION
#     This procedure modifies the properties of a resource. The properties are
#     given in the TCL array my_properties.
#
#     Depending on the value of opt(delete_all) one of the following modifying
#     strategies is chosen:
#       opt(delete_all) == 0: [default] only add or update properties of the
#                             resource
#       opt(delete_all) == 1: delete all properties of the resource. Then set 
#                             the properties to the ones defined in my_properties.
#
#  INPUTS
#     resource           - id of the resource
#     my_properties      - array with the resource properties
#
#     opt                - optional named arguments, see get_hedeby_proc_default_opt_args()
#     opt(delete_all)    - see above in FUNCTION (default = 0)
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     util/get_hedeby_resource_properties()
#*******************************************************************************
proc mod_hedeby_resource { resource my_properties {opt ""} } {
   upvar $my_properties properties

   ts_log_fine "modify resource \"$resource\" ..."

   set opts(delete_all) 0
   get_hedeby_proc_opt_arg $opt opts

   # get_hedeby_resource_properties only needs the default set of arguments
   copy_hedeby_proc_opt_arg opts new_opts "default"
   
   # mix existing and (new) properties into new_props
   if { $opts(delete_all) == 0 } {
      get_hedeby_resource_properties $resource new_props new_opts
   }
   foreach prop_name [array names properties] {
      set new_props($prop_name) $properties($prop_name)
   }

   ts_log_finest [format_array new_props]

   # set new_props via stdin piping to 'sdmadm mr -f -'
   set tasks(STANDARD_IN) ""
   foreach prop_name [array names new_props] {
      append tasks(STANDARD_IN) "$prop_name=$new_props($prop_name)\n"
   }
   set new_opts(interactive_tasks) tasks
   set output [ sdmadm_command_opt "mr -r $resource -f -" new_opts ]

   if { $prg_exit_state != 0 } {
      ts_log_fine "mod_hedeby_resource: sdmadm_command exit_state=$prg_exit_state, output=$output"
      return 1
   }

   return 0
}

#****** util/get_log_files() ***************************************************
#  NAME
#     get_log_files() -- get all log files on the hedeby host
#
#  SYNOPSIS
#     get_log_files { host user } 
#
#  FUNCTION
#     Retruns a file list with full path names of hedeb log files on specified
#     host
#
#  INPUTS
#     host - hostname where the log files should be returned
#     user - user who should start the execution of find command
#
#  RESULT
#     File list
#
#  SEE ALSO
#     util/get_all_log_files()
#     util/get_log_files()
#*******************************************************************************
proc get_log_files { host user } {
   set spool_dir_path [get_hedeby_local_spool_dir $host]
   set output [start_remote_prog $host $user "find" "$spool_dir_path -type f -name \"*.log\""]
   set file_list {}
   foreach f [split $output "\n\r"] {
      if {$f != ""} {
         lappend file_list $f
      }
   }
   set output [start_remote_prog $host $user "find" "$spool_dir_path -type f -name \"*.std*\""]
   foreach f [split $output "\n\r"] {
      if {$f != ""} {
         lappend file_list $f
      }
   }

   return $file_list
}

#****** util/get_all_log_files() ***********************************************
#  NAME
#     get_all_log_files() -- create test specific merged logfile
#
#  SYNOPSIS
#     get_all_log_files { user tar_file_path } 
#
#  FUNCTION
#     Creates a hedeby_merged.$test_name.log.gz file and returns the path to the
#     file. The file contains merged log entries from the local log files of 
#     every hedeby installation of the TS system.
#
#  INPUTS
#     user          - user who start commands
#     tar_file_path - path to a directory where the gzip'ed logfile should be
#                     created
#     {test_name}      - optional: name of the test which created the logs.
#                        If set to "" the test_name is the actual test and
#                        its runlevel number.
#     {log_start_time} - optional: specify the time (unix timestamp) of messages
#                        in log file which should be merged into files.
#                        Messages older than log_start_time are not merged.
#                        Default value is 0.
#     {log_end_time}   - optional: specify the time (unix timestamp) of messages
#                        in log file which should be merged into files.
#                        Messages newer than the log_end_time are not merged.
#                        Default value is 9999999999.
#                                               
#
#  RESULT
#     Full path to hedeby_merged.${test_name}.log.gz file
#
#  SEE ALSO
#     util/get_all_log_files()
#     util/get_log_files()
#*******************************************************************************
proc get_all_log_files { user tar_file_path {test_name ""} {log_start_time 0} {log_end_time 9999999999}} {
   global hedeby_config CHECK_USER check_name CHECK_ACT_LEVEL
   if { $test_name == "" } {
      set test_name "$check_name.$CHECK_ACT_LEVEL"
   }

   file mkdir $tar_file_path

   if {[file isfile $tar_file_path/hedeby_merged.${test_name}.log.gz]} {
      ts_log_fine "deleting existing log file: $tar_file_path/hedeby_merged.${test_name}.log.gz"
      delete_file $tar_file_path/hedeby_merged.${test_name}.log.gz 
   }
   if {[file isfile $tar_file_path/hedeby_merged.${test_name}.log]} {
      ts_log_fine "deleting existing log file: $tar_file_path/hedeby_merged.${test_name}.log"
      delete_file $tar_file_path/hedeby_merged.${test_name}.log 
   }


   set host_list [get_all_default_hedeby_resources]
   lappend host_list $hedeby_config(hedeby_master_host)

   set local_host [gethostname]
   ts_log_fine "local host is $local_host"

   # First get all files path names for each host make a
   # temporary local copy ...
   foreach host $host_list {
      set file_list($host,files) {}
      ts_log_fine "getting file list for host $host ..."
      set local_spool_dir  [get_hedeby_local_spool_dir $host]
      set files [get_log_files $host "root"]
      foreach f $files {
         set dirname [file dirname $f]
         set filename [file tail $f]
         
         switch -glob $filename {
            "*log" {
               if {$dirname == "$local_spool_dir/log"} {
                  set current_file_type "jvm_log"
               } elseif {$dirname == "$local_spool_dir/spool/reporter"} {
                  set current_file_type "reporter_log"
               } else {
                  set current_file_type "misc"
               }
            }
            "*stderr" {
               if {$dirname == "$local_spool_dir/log"} {
                  set current_file_type "jvm_stderr"
               } else {
                  set current_file_type "misc"
               }
            }
            "*stdout" {
               if {$dirname == "$local_spool_dir/log"} {
                  set current_file_type "jvm_stdout"
               } else {
                  set current_file_type "misc"
               }
            }
            default {
               set current_file_type "misc"
            }
         }
         if {$current_file_type != "misc"} {
            lappend file_list($host,files) $f
            set file_types($host,$f) $current_file_type
         }
      }
   }

   # calculate the max host and max file name length to get the
   # max column with in the merged log file ...
   set max_host_length 0
   set max_file_length 0
   foreach host $host_list {
      if { $max_host_length < [string length $host] } {
         set max_host_length [string length $host]
      }
      foreach f $file_list($host,files) {
         if { $max_file_length < [string length [file tail $f]] } {
            set max_file_length [string length [file tail $f]]
         }
      }
   }

   # Parse each log file ...
   # Supported is 
   #    a) standard hedeby logging 
   #    b) reporter file format
   foreach host $host_list {
      foreach f $file_list($host,files) {
         set current_file_type $file_types($host,$f)
         
         ts_log_fine "host $host: processing $f (type=$current_file_type)"
         # TODO: Make only one cat for all files per host  
         set sid [open_remote_spawn_process $host "root" "cat" $f]
         set sp_id [lindex $sid 1]
         set current_time 0
         set last_time 0
         set timeout 15
         set start_found 0
         set do_stop 0
         expect {
            -i $sp_id timeout {
               ts_log_info "got timeout"
            }
            -i $sp_id full_buffer {
               ts_log_info "got full buffer"
            }
            -i $sp_id eof { 
               ts_log_info "got eof"
            }
            -i $sp_id -- "*\n" {
               foreach pos_line [split $expect_out(0,string) "\r\n"] {
                  set line [string trimright $pos_line]
                  if { $line == "" } {
                     continue
                  }
                  if { [string first "_exit_status_" $line] >= 0 } {
                     set do_stop 1
                     ts_log_finer "ignore(1): $line"
                     break
                  } 
                  
                  if { $start_found == 0 } {
                     if { [string first "_start_mark_" $line] >= 0 } {
                        set start_found 1
                     }
                     ts_log_finer "ignore(2): $line"
                     continue
                  }
                  #ts_log_fine "$host [file tail $f]: $line"
                  # First we have to find out the unix time stamp of the log message line
                  # If the first column is a timestamp we set current_time to new value
                  # If there is no timestamp found the last current_time is used
                  
                  switch $current_file_type {
                     "jvm_log" {
                        set date_time [lindex [split $line "|"] 0]
                        set catch_ret [catch {clock scan $date_time} output]
                        if {$catch_ret == 0} {
                           set current_time $output
                        } 
                     }
                     "reporter_log" {
                        set date_time [lindex [split $line ":"] 0]
                        if {[string is digit $date_time]} {
                           # first column is digit ...
                           if {$date_time > 0} {
                              # if time is > 0 it is millis format, recalculate seconds
                              set seconds [expr ( $date_time / 1000 )]
                              if {$seconds > 1213710000} {
                                 set current_time $seconds
                              }
                           }
                        }
                     }
                  }
                  
                  # store this line
                  set have_time $current_time
                  if {$current_time == 0} {
                     if {$current_file_type == "jvm_log" && $last_time != 0} {
                        # Stacktraces of exception do not contain any timestamp
                        # If we had an valid log entry we assume that it is a stacktrace
                        set current_time $last_time
                     } else {
                        # We did not find a time stamp till now. This might happen for stderr, stdin files
                        # In this case we use the actual time stamp of testsuite and store it also into log array 
                        ts_log_finer "no logging time information found (file: [file tail $f], host: $host): line= $line"
                        ts_log_finer "using current time!"
                        set current_time [timestamp]
                        if { $current_time > $log_end_time } {
                           set current_time $log_end_time
                        }
                        set line [format "%s|%s" "no time info in logfile - time is from TS!" $line]
                     }
                  } else {
                     # save the current_time in the last_time variable
                     # lines with stacktrace will inherit the timestamp
                     set last_time $current_time
                  }

                  # Store the line with timestamp information into merged_log array
                  # Additional messages (with same time) are logged with higher log "nr" (see max_nr)
                  if {![info exists merged_log($current_time,max_nr)]} {
                     set max_nr 0
                  } else {
                     set max_nr $merged_log($current_time,max_nr)
                     incr max_nr 1
                  }
                  set merged_log($current_time,max_nr) $max_nr
                  set merged_log($current_time,$max_nr) [format "%${max_host_length}s|%${max_file_length}s|%s" $host [file tail $f] $line]

                  # If we had to fake the timestamp we reset current_time to 0 in order to create 
                  # additional faked timestamp
                  if { $have_time == 0} {
                     set current_time 0
                  }
               }
               if { $do_stop == 0 } {
                  exp_continue
               }
            }
         }
         close_spawn_process $sid
      }
   }

   # Now all messages are merged into the merged_log array ...
   # Find out min and max time of entries ...
   set names [array names merged_log]
   set min_time 9999999999
   set max_time 0
   foreach name $names {
      set time [lindex [split $name ","] 0]
      if { $min_time > $time } {
         set min_time $time
      }
      if { $max_time < $time } {
         set max_time $time
      }
   }
   ts_log_fine "min time: $min_time"
   ts_log_fine "max time: $max_time"


   # Now we can write a new merged log file ...
   set fp [open "$tar_file_path/hedeby_merged.${test_name}.log" w]
   for { set time $min_time } { $time <= $max_time } { incr time 1 } {
      if { $time <= $log_end_time && $time >= $log_start_time } {
         if { [info exists merged_log($time,max_nr)] } {
            set max_entry $merged_log($time,max_nr)
            for { set line 0 } { $line <= $max_entry } { incr line 1 } {
               set time_string [clock format $time -format "%Y-%m-%d %H:%M:%S"]
               puts $fp "$time_string|$merged_log($time,$line)"
            }
         }
      }
   }
   close $fp

   # here we do a gzip to the log file, delete a old one ...
   set gzip_bin [get_binary_path $local_host "gzip"]

   ts_log_fine [start_remote_prog $local_host $CHECK_USER "$gzip_bin" "$tar_file_path/hedeby_merged.${test_name}.log"]

   # cleanup the temp directory
   return "$tar_file_path/hedeby_merged.${test_name}.log.gz"
}


#****** util/wait_for_resource_removal() ******************************************
#  NAME
#     wait_for_resource_removal() -- wait for removal of resource
#
#  SYNOPSIS
#     wait_for_resource_removal { res_remove_list {opt ""} }
#
#  FUNCTION
#     This procedure calls get_resource_info() until the specified
#     resource(s) is/are removed from the system, a timeout or error occurs.
#
#  INPUTS
#     res_remove_list    - list of resources to be removed
#
#     opt                - optional named arguments, see get_hedeby_proc_default_opt_args()
#     opt(timeout)       - timeout specification in seconds (default 60 seconds)
#     opt(error_text)    - report error text into this tcl var (default error_var)
#     opt(system_name)   - not used
#     opt(pref_type)     - not used
#
#  RESULT
#     0 on success, 1 on error
#
#  EXAMPLE
#     # step 1: set up resources to remove
#     set resources { res1 res2 }
#     sdmadm_command_opt "rr -r $resources"
#
#     # step 2: wait for expected resource informations
#     set opt(raise_error) 0
#     set opt(error_text) remove_error
#     set retval [wait_for_resource_removal $resources opt]
#     
#     # step 3: error handling
#     if { $retval != 0} {
#        # append removal error to error output
#        append error_text $remove_error
#     }
#
#  SEE ALSO
#     util/get_resource_info()
#     util/wait_for_resource_info()
#     util/get_hedeby_proc_opt_arg()
#*******************************************************************************
proc wait_for_resource_removal { res_remove_list {opt ""} } {
   # set function default values
   set opts(timeout) 60
   set opts(error_text) error_var
   get_hedeby_proc_opt_arg $opt opts

   # setup arguments
   upvar $opts(error_text) error_text_up
   if {![info exists error_text_up]} {
      # some calling code relies on the initialization of the error_text variable
      set error_text_up ""
   }
   set error_text ""
   set my_endtime [timestamp]
   incr my_endtime $opts(timeout)

   # set options for call to get_resource_info_opt
   copy_hedeby_proc_opt_arg opts call_opts "default"
   set call_opts(res_list) res_list
   set call_opts(res_id_list) res_id_list
   set call_opts(sdmadm_output) sdmadm_output

   while {1} {
      set retval [get_resource_info_opt resource_info call_opts]
      if {$retval != 0} {
         append error_text "break because get_resource_info_opt() returned \"$retval\"!\n$sdmadm_output"
         break
      }
      set not_removed ""
      foreach res $res_remove_list {
         # if $res looks like a resource id, search in $res_id_list
         # otherwise look into res_list
         if {[regexp "^res#\[0-9\]+$" $res]} {
            # we have a resource id
            ts_log_finer "resource '$res' looks like a resource id" $opts(raise_error)
            set search_list res_id_list
         } else {
            ts_log_finer "resource '$res' looks like a resource hostname" $opts(raise_error)
            set search_list res_list
         }
         if {[lsearch -exact $search_list $res] != -1} {
            append not_removed "\"$res\" "
         }
      }

      if {$not_removed == ""} {
         ts_log_fine "All specified resources are removed from the system."
         break
      } else {
         set cur_time [timestamp]
         set cur_time_left [expr ($my_endtime - $cur_time)]
         ts_log_fine "Still waiting for specified resources to be removed ... (timeout in $cur_time_left seconds)" $opts(raise_error)
         ts_log_fine "The following resources are not yet removed: $not_removed\n" $opts(raise_error)
      }
      if {[timestamp] >= $my_endtime} {
         append error_text "==> TIMEOUT(=$opts(timeout) sec) while waiting for resources to be removed!\n"
         append error_text "==> The following resources were NOT removed:\n$not_removed\n"
         break
      }
      after 1000
   }

   if {$error_text != "" } {
      append error_text_up $error_text
      ts_log_severe $error_text $opts(raise_error)
      return 1
   }
   return 0
}


#****** util/get_hedeby_proc_default_opt_args() ******************************************
#  NAME
#     get_hedeby_proc_default_opt_args() -- gets the default optional arguments for a procedure
#
#  SYNOPSIS
#     get_hedeby_proc_default_opt_args { opt }
#
#
#  FUNCTION
#     This procedure defines a standard set of optional arguments that should
#     be used for all relevant hedeby procedures. Passing named arguments in
#     the optional-arguments TCL array is preferable to having lots of
#     positional parameters.
#
#     Normally, this procedure should not have to be called directly. It is
#     used from get_hedeby_proc_opt_arg().
#
#     If any of the values are already set in the passed in opt array, then
#     they are NOT overwritten with the default value. This behavior is useful
#     because then the user of get_hedeby_proc_opt_arg() can preset some default
#     values of his/her own before calling get_hedeby_proc_opt_arg() without them
#     getting overwritten here.
#
#  INPUTS
#     opt - name of the output array to store the default values in
#
#  RESULT
#     opt array set with the following default values:
#        opt(user)         - the user as whom to execute the command  (hedeby admin user)
#        opt(host)         - the host on which to execute the command (hedeby master host)
#        opt(system_name)  - name of the SDM system                   (TS hedeby system name)
#        opt(pref_type)    - preference type of the SDM system        (TS hedeby preference type)
#        opt(raise_error)  - report errors? 1 - yes, 0 - n            (1)
#
#  SEE ALSO
#     util/get_hedeby_proc_opt_arg()
#*******************************************************************************
proc get_hedeby_proc_default_opt_args { opt } {
   global hedeby_config
   upvar $opt opts

   if { ![info exists opts(user)] } {
      set opts(user) [get_hedeby_admin_user]
   }
   if { ![info exists opts(host)] } {
      set opts(host) $hedeby_config(hedeby_master_host)
   }
   if { ![info exists opts(system_name)] } {
      set opts(system_name) [get_hedeby_system_name]
   }
   if { ![info exists opts(pref_type)] } {
      set opts(pref_type) [get_hedeby_pref_type]
   }
   if { ![info exists opts(raise_error)] } {
      set opts(raise_error) 1
   }

   return
}

#****** util/get_hedeby_proc_opt_arg() ******************************************
#  NAME
#     get_hedeby_proc_opt_arg() -- mix user and default optional procedure arguments
#
#  SYNOPSIS
#     get_hedeby_proc_opt_arg { user_opt opt } {
#
#  FUNCTION
#     This procedure should be used in any hedeby function that uses optional
#     arguments. It takes the user specified options in user_opt and returns in
#     opt all options by mixing the user and default options.
#
#     An option given by a user overwrites any of the default options. The
#     following paragraph shows the precedence rules in detail.
#
#     Precedence of options:
#       1) User options in user_opt (highest)
#       2) Function defaults (set by the calling function) handed in via opt
#       3) Global defaults set via get_hedeby_proc_default_opt_args()
#
#     An error is logged with ts_log_severe if a user_opt tries to set an
#     unkown option (not part of function or global defaults). This is done to
#     catch typoes in option names.
#
#  INPUTS
#     user_opt - name of the opts array given by user (2 levels up),
#                this variable is only read and remains unchanged
#
#     opt      - name of the output array to store the default values in
#
#  RESULT
#     opt array set with default values. Any options in user_opt OVERWRITE default values.
#
#     See get_hedeby_proc_default_opt_args() for default values.
#
#  EXAMPLE
#     proc hedeby_procedure { req_opt1 req_opt2 {opt ""} } {
#        
#        # set function default values
#        set opts(my_own_arg) "my_own_default_value"
#        get_hedeby_proc_opt_arg $opt opts
#
#        # do something, using e.g. $opts(user) or $opts(host) or $opts(my_own_arg)
#
#        return
#     }
#
#  NOTES
#     General notes for the optional argument passing:
#
#     The idea is to have a mechanism (by convention) in TCL to use optional
#     named arguments for procedures. This is useful for all procedures that
#     use a standard set of default parameters (see get_hedeby_proc_default_opt_args())
#     and/or have a big number of optional parameters.
#
#     The procedures can still have a number of required positional arguments,
#     these should come first. The array with the optional named arguments is
#     ALWAYS the last parameter.
#
#     The documentation must contain a description of all function-specific
#     optional arguments. There should be a link to the default optional
#     arguments description. Any speciality like a not (or differently) used
#     default optional argument MUST be documented explicitly.
#
#     All function-specific optional arguments must have their default values
#     set in the function before the call to get_hedeby_proc_opt_arg, see
#     example above.
#
#     This mechanism is not introduced in a big bang change but gradually.
#     Existing procedures that could benefit from optional argument passing are
#     not changed directly. Instead a thin wrapper with the suffix _opt (to
#     disambiguate) is created that calls the original procedure (see e.g.
#     sdmadm_command and sdmadm_command_opt). New procedures can of course use
#     the new convention directly and don't need two versions (nor the suffix).
#
#  SEE ALSO
#     util/get_hedeby_proc_default_opt_args()
#     util/copy_hedeby_proc_opt_arg()
#     util/copy_hedeby_proc_opt_arg_exclude()
#*******************************************************************************
proc get_hedeby_proc_opt_arg { user_opt opt } {
   global hedeby_config
   upvar $opt opts
   get_hedeby_proc_default_opt_args opts

   if { $user_opt != "" } {
      # go up 2 level as this function is called 
      upvar 2 $user_opt user_opts
   } else {
      # no user opts, so return default values
      return
   }

   foreach opt_name [array names user_opts] {
      if { [info exists opts($opt_name)] } {
         set opts($opt_name) $user_opts($opt_name)
      } else {
        ts_log_severe "Error in get_hedeby_proc_opt_arg:\
               Unknown optional argument '$opt_name' with value '$user_opts($opt_name)' found.\
               Maybe you mistyped an optional argument name?"
      }
   }

   ts_log_finest [format_array opts]

   return
}

#****** util/copy_hedeby_proc_opt_arg() ******************************************
#  NAME
#     copy_hedeby_proc_opt_arg() -- copy optional arguments
#
#  SYNOPSIS
#     copy_hedeby_proc_opt_arg { old_opts new_opts { copy_what "all" } }
#
#  FUNCTION
#     This is a helper function for optional named argument passing, see
#     get_hedeby_proc_opt_arg().
#
#     Copy old_opts to new_opts (both TCL arrays).
#
#     The parameter copy_what controls which elements (key-value pairs) are
#     copied. By default, all elements are copied. Single or multiple keys can
#     be given as well, only the given keys will be copied. The key "default"
#     has a special meaning, see below.
#
#     Unknown keys specified in copy_what are silently ignored.
#
#     This function is useful when a function with optional named arguments is
#     calling another function with optional named arguments - and some of the
#     arguments should be reused in the call. It is NOT ALWAYS possible to
#     simply hand through the options to the called function, as
#     get_hedeby_proc_opt_arg() does not allow unused surplus options. Then a
#     copy of the options can be created with this function.
#
#     The function copy_hedeby_proc_opt_arg_exclude() has similar
#     functionality, see there.
#
#  INPUTS
#     old_opts  - options to copy from (name of TCL array)
#     new_opts  - options to copy to (name of TCL array) - contents are deleted first
#     copy_what - which keys to copy from old_opts to new_opts (TCL list)
#                 (default: all keys)
#                 special value "default" is replaced by all the keys defined
#                 by get_hedeby_proc_default_opt_args(). This can be used in
#                 conjunction with other keys.
#
#  RESULT
#     copy of old_opts is in array new_opts, no return value
#
#  EXAMPLE
#     ## in a function using optional named argument passing:
#     # set function default values
#     set opts(key1) "val1"
#     set opts(key2) "val2"
#     get_hedeby_proc_opt_arg $opt opts
#
#     # opts now contains key1 and key2, plus the default keys: host, user, raise_error, system_name and pref_type
#     copy_hedeby_proc_opt_arg opts new_opts                ;# new_opts is a 100% copy of opts
#     copy_hedeby_proc_opt_arg opts new_opts "default"      ;# new_opts contains: host, user, raise_error, system_name, pref_type
#     copy_hedeby_proc_opt_arg opts new_opts "default key2" ;# new_opts contains: key2, host, user, raise_error, system_name, pref_type
#     copy_hedeby_proc_opt_arg opts new_opts "key2 default" ;# new_opts contains: key2, host, user, raise_error, system_name, pref_type (equivalent)
#     copy_hedeby_proc_opt_arg opts new_opts "key1 user"    ;# new_opts contains: key1, user
#
#     # and call some other function with the new options
#     some_other_function_opt $param1 $param2 new_opts
#
#  SEE ALSO
#     util/get_hedeby_proc_opt_arg()
#     util/get_hedeby_proc_default_opt_args()
#     util/copy_hedeby_proc_opt_arg_exclude()
#*******************************************************************************
proc copy_hedeby_proc_opt_arg { old_opts new_opts { copy_what "all" } } {
   upvar $old_opts old
   upvar $new_opts new

   # delete new options
   unset -nocomplain new

   # set up key_list according to copy_what
   if { $copy_what == "all" } {
      set key_list [array names old]
   } elseif { [set idx [lsearch $copy_what "default"]] >= 0 } {
      # replace default value with keys from get_hedeby_proc_default_opt_args()
      get_hedeby_proc_default_opt_args def_opts
      set key_list [lreplace $copy_what $idx $idx [array names def_opts]]
      set key_list [join $key_list] ;# flatten list as the lreplace introduced a sub-list
   } else {
      set key_list $copy_what
   }

   foreach key $key_list {
      if {[info exists old($key)]} {
         set new($key) $old($key)
      }
   }

   ts_log_finest [format_array new]
   return
}

#****** util/copy_hedeby_proc_opt_arg_exclude() ******************************************
#  NAME
#     copy_hedeby_proc_opt_arg_exclude() -- copy optional arguments, excluding some keys
#
#  SYNOPSIS
#     copy_hedeby_proc_opt_arg_exclude { old_opts new_opts { exclude_what "" } }
#
#  FUNCTION
#     This is a helper function for optional named argument passing, see
#     get_hedeby_proc_opt_arg().
#
#     Copy old_opts to new_opts (both TCL arrays), excluding some keys.
#
#     The parameter exclude_what controls which elements (key-value pairs) are
#     NOT copied. By default, all elements are copied. Single or multiple keys can
#     be given: these keys will be excluded, i.e. NOT copied.
#
#     This function is useful when a function with optional named arguments is
#     calling another function with optional named arguments - and some of the
#     arguments should be reused in the call. It is NOT ALWAYS possible to
#     simply hand through the options to the called function, as
#     get_hedeby_proc_opt_arg() does not allow unused surplus options. Then a
#     copy of the options can be created with this function.
#
#     The function copy_hedeby_proc_opt_arg() has similar functionality, see
#     there.
#
#  INPUTS
#     old_opts     - options to copy from (name of TCL array)
#     new_opts     - options to copy to (name of TCL array) - contents are deleted first
#     exclude_what - which keys NOT to copy from old_opts to new_opts (TCL list)
#                    (default: all keys)
#
#  RESULT
#     copy of old_opts is in array new_opts, no return value
#
#  EXAMPLE
#     ## in a function using optional named argument passing:
#     # set function default values
#     set opts(key1) "val1"
#     set opts(key2) "val2"
#     get_hedeby_proc_opt_arg $opt opts
#
#     # opts now contains key1 and key2, plus the default keys: host, user, raise_error, system_name and pref_type
#     copy_hedeby_proc_opt_arg_exclude opts new_opts             ;# new_opts is a 100% copy of opts
#     copy_hedeby_proc_opt_arg_exclude opts new_opts "key1"      ;# new_opts contains: key2, host, user, raise_error, system_name, pref_type
#     copy_hedeby_proc_opt_arg_exclude opts new_opts "key2 host" ;# new_opts contains: key1, user, raise_error, system_name, pref_type
#     copy_hedeby_proc_opt_arg_exclude opts new_opts "host key2" ;# new_opts contains: key1, user, raise_error, system_name, pref_type
#
#     # and call some other function with the new options
#     some_other_function_opt $param1 $param2 new_opts
#
#  SEE ALSO
#     util/get_hedeby_proc_opt_arg()
#     util/get_hedeby_proc_default_opt_args()
#     util/copy_hedeby_proc_opt_arg()
#*******************************************************************************
proc copy_hedeby_proc_opt_arg_exclude { old_opts new_opts { exclude_what "" } } {
   upvar $old_opts old
   upvar $new_opts new

   # delete new options
   unset -nocomplain new

   # copy all old keys ...
   foreach key [array names old] {
      if { [lsearch -exact $exclude_what $key] >= 0 } {
         # ... excluding the keys in exclude_what
         continue
      }
      set new($key) $old($key)
   }

   ts_log_finest [format_array new]
   return
}

#****** util/add_hedeby_ge_service_for_cluster() *******************************
#  NAME
#     add_hedeby_ge_service_for_cluster() -- add a GE service for a cluster 
#
#  SYNOPSIS
#     add_hedeby_ge_service_for_cluster { cluster_config_number opts } 
#
#  FUNCTION
#     Add a GE service for a cluster to the Hedeby system. The configuration for
#     the GE service is constructed out of the settings of the cluster config.
#
#     The GE service is started automatically.
#
#  INPUTS
#     cluster_config_number - number of the cluster config 
#     opt                   - optional args for the sdmadm commands
#
#  RESULT
# 
#     -1 if cluster configuration has not been found 
#     else the exit code of the "sdmadm ags" command 
#     
#
#  SEE ALSO
#    util/add_hedeby_ge_service
#    cluster_procedures/set_current_cluster_config_nr
#*******************************************************************************
proc add_hedeby_ge_service_for_cluster { cluster_config_number {opt ""} } {
   global hedeby_config
   get_hedeby_proc_opt_arg $opt opts

   set org_ccn [get_current_cluster_config_nr]

   if {[set_current_cluster_config_nr $cluster_config_number] != 0} {
      ts_log_severe "Cluster configure with number '$cluster_config_number' not found" $opts(raise_error)
      return -1
   }
  
   get_current_cluster_config_array ts_config
   
   set sopts(service_name) $ts_config(cluster_name) 
   set sopts(host)         $ts_config(master_host)
   set sopts(master_port)  $ts_config(commd_port)
   set sopts(execd_port)   [expr $ts_config(commd_port) + 1]
   set sopts(sge_root)     $ts_config(product_root)
   set sopts(cell)         $ts_config(cell)
   set sopts(jmx_port)     $ts_config(jmx_port)
   set sopts(cluster_name) $ts_config(cluster_name) 
   set sopts(user)         [get_hedeby_admin_user]

   # We can start only the service if the jvm is already running
   # This is the case for the simple install use case and
   # if the hedeby_master_host is a gridengine master host
   if {[is_simple_install_system] || $ts_config(master_host) == $hedeby_config(hedeby_master_host) } {
      set sopts(start)        "true"
   }

   if {$ts_config(jmx_ssl) == "true"} {
      set sopts(use_ssl) "true"
      set sopts(keystore_file)  "/var/sgeCA/port$sopts(master_port)/$sopts(cell)/userkeys/$sopts(user)/keystore"
      set sopts(keystore_pw) $ts_config(jmx_ssl_keystore_pw)
      if { [is_simple_install_system] == 1 } {
         copy_certificates $hedeby_config(hedeby_master_host) 0
      }
      
   } else {
      set msg "JMX server of the qmaster of cluster '$ts_config(cluster_name)' is not running in ssl mode\n"
      append msg "Authentication with a keystore will not work. User name/password authentication can not be used\n"
      append msg "because TS does not know the password of user '$sopts(user)'\n"
      append msg "=> The connection from  GE service to qmaster will fail"
      ts_log_warning $msg $opts(raise_error)
      # Use a dummy password
      set sopts(password) "password"
   }

   set_current_cluster_config_nr $org_ccn

   return [add_hedeby_ge_service sopts opts]
}

#****** util/add_hedeby_ge_service() *******************************************
#  NAME
#     add_hedeby_ge_service() -- add a GE service to the Hedeby system 
#
#  SYNOPSIS
#     add_hedeby_ge_service { service_opts { opt "" } } 
#
#  FUNCTION
#     
#     This function adds a GE service to Hedeby system by calling "sdmadm ags".
#     The configuration for the GE service is defined in the tcl array
#     service_opts parameters.
#
#  INPUTS
#     service_opts - tcl array with the options for the GE service
#       service_opts(service_name)  - defines the name of the service (mandatory)
#       service_opts(host)          - host where the GE service should run (mandatory)
#       service_opts(master_port)   - qmaster port (mandatory)
#       service_opts(execd_port)    - execd port (mandatory)
#       service_opts(sge_root)      - path to sge_root (mandatory)
#       service_opts(cell)          - name of the Grid Engine cell (mandatory)
#       service_opts(jmx_port)      - port of qmaster jmx service (mandatory)
#       service_opts(cluster_name)  - name of the Grid Engine cluster (mandatory)
#       service_opts(user)          - user name used for connecting to qmaster
#       service_opts(use_ssl)       - if set to true GE service will use a ssl protected
#                                     connection to qmaster (optional, default is true)
#       service_opts(keystore_file) - path to the keystore file. This keystore file contains
#                                     the private key and the certificate of the user
#                                     (mandatory for ssl mode)
#       service_opts(keystore_pw)   - password for the keystore file (mandatory for ssl mode)
#       service_opts(password)      - password of the user (mandatory for non ssl mode)
#       service_opts(start)         - if set to true start the service automatically
# 
#     { opt "" } - general purpose options for sdmadm command (see get_hedeby_proc_default_opt_args)
#
#  RESULT
#
#     the exit code of the 'sdmadm ags' command
#
#  EXAMPLE
#
#   set sopts(service_name) "foo_service"
#   set sopts(host)         "foo.bar"
#   set sopts(master_port)  "8015"
#   set sopts(execd_port)   "8016"
#   set sopts(sge_root)     "/opt/sge"
#   set sopts(cell)         "default"
#   set sopts(jmx_port)     "8017"
#   set sopts(cluster_name) "foo"
#   set sopts(user)         "sge_admin"
#   set sopts(use_ssl)      "true"
#   set sopts(keystore_file)"/var/sgeCA/port8015/default/userkeys/sge_admin/keystore"
#   set sopts(keystore_pw)  ""
#   set sopts(start"        "true"
#
#   set opt(host)  "foo.bar" ;# execute the 'sdmadm ags' command on host foo.bar
#   add_hedeby_ge_service sopts opt
#
#
#  SEE ALSO
#     util/get_hedeby_proc_default_opt_arg
#     util/sdmadm_command_opt
#*******************************************************************************
proc add_hedeby_ge_service { service_opts { opt "" } } {

   upvar $service_opts sopts

   get_hedeby_proc_opt_arg $opt opts

   set errors {}

   # ---------------------------------------------------------------------------
   # check the sopts array
   # ---------------------------------------------------------------------------
   foreach param { service_name host master_port execd_port sge_root cell jmx_port cluster_name user } {
      if {![info exists sopts($param)]} {
         lappend errors "Mandatory service options sopts($param) is missing"
      }
   }

   if {![info exists sopts(use_ssl)]} {
      set sopts(use_ssl) "true"
   }

   if { $sopts(use_ssl) == "true" } {
     if {![info exists sopts(keystore_file)]} {
        lappend errors "Service options keystore_file is mandatory for ssl mode"
     } 
     if {![info exists sopts(keystore_pw)]} {
        lappend errors "Service options keystore_pw is mandatory for ssl mode"
     }
   } else {
      if {![info exists sopts(password)]} {
         lappend errors "parameter password is mandatory for non ssl mode"
      }
   }

   if {[llength $errors] != 0 } {
      set msg "Found errors in the sopts option array:\n\n"
      foreach error $errors {
         append msg "  o $error\n"
      }
      append msg "\n"
      ts_log_severe $error $opts(raise_error)
   }

   if {[info exists sopts(start)] && $sopts(start) == "true"} {
       set start_opt "-start"
   } else {
       set start_opt ""
   }

   # ---------------------------------------------------------------------------
   # Start the sdmadm ags command
   # ---------------------------------------------------------------------------
   ts_log_fine "adding GE service \"$sopts(service_name)\" for cluster on host \"[get_service_host $sopts(host)]\" ..."
   set ispid [hedeby_mod_setup_opt "ags -h [get_service_host $sopts(host)] -j [get_service_jvm] -s $sopts(service_name) $start_opt" error_text opts]

   set sequence {}
   lappend sequence "[format "%c" 27]" ;# ESC


   # ---------------------------------------------------------------------------
   # Define the connection settings
   # ---------------------------------------------------------------------------
   if {$sopts(use_ssl) == "true"} {
      ts_log_fine "using keystore file: \"$sopts(keystore_file)\""
      lappend sequence ":%s#keystore=\"\"#keystore=\"$sopts(keystore_file)\"#\n"
      lappend sequence ":%s/password=\"\"/password=\"$sopts(keystore_pw)\"/\n"
   } else {
      lappend sequence ":%s/password=\"\"/password=\"$sopts(password)\"/\n"
      ts_log_config "installing GE adapter without jmx_ssl not supported!"
   }
   lappend sequence ":%s/username=\"username\"/username=\"$sopts(user)\"/\n"
   lappend sequence ":%s/jmxPort=\"0\"/jmxPort=\"$sopts(jmx_port)\"/\n"
   lappend sequence ":%s/execdPort=\"0\"/execdPort=\"$sopts(execd_port)\"/\n"
   lappend sequence ":%s/masterPort=\"0\"/masterPort=\"$sopts(master_port)\"/\n"
   lappend sequence ":%s/cell=\"default\"/cell=\"$sopts(cell)\"/\n"
   set path [split $sopts(sge_root) {/}]
   set sge_root_val [join $path {\/}]
   lappend sequence ":%s/root=\"\"/root=\"$sge_root_val\"/\n"
   lappend sequence ":%s/clusterName=\"sge\"/clusterName=\"$sopts(cluster_name)\"/\n"

   
   lappend sequence "[format "%c" 27]" ;# ESC

   # ---------------------------------------------------------------------------
   # Define the default SLOs
   # ---------------------------------------------------------------------------
   # delete <slos>...</slos>
   lappend sequence "/<common:slos>\n"
   lappend sequence "ma/<\\/common:slos>\n:'a,.d\n"
   lappend sequence "i"
   lappend sequence "<common:slos>\n"
   lappend sequence [create_fixed_usage_slo 50 "fixed_usage"] 
   lappend sequence "\n"
   lappend sequence "</common:slos>\n"

   lappend sequence "[format "%c" 27]" ;# ESC

   # ---------------------------------------------------------------------------
   # Define the execd installation parameters
   # ---------------------------------------------------------------------------
   if {[info exists sopts(execd_install_params)] } {
      # use the provided execd_install_params
      upvar $sopts(execd_install_params) execd_install_params
   } else {
      # if the execd_install_params has no entries get_hedeby_execd_install_params_sequence
      # will use the default values
      set execd_install_params(count) 0
   }

   foreach line [get_hedeby_execd_install_params_sequence execd_install_params] {
      lappend sequence $line
   }

   lappend sequence "[format "%c" 27]" ;# ESC

   hedeby_mod_sequence $ispid $sequence error_text
   hedeby_mod_cleanup $ispid error_text

   return $prg_exit_state
}
#****** util/hedeby_unzip() ***************************************************
#  NAME
#     hedeby_unzip() -- decompress with unzip the specified archive to destination directory
#
#  SYNOPSIS
#     hedeby_unzip { archive target_dir { host "" } { user "" } } 
#
#  FUNCTION
#     This procedure is used to decompress zip file.
#
#  INPUTS
#     archive 		- path to the compressed zip file
#     target_dir 	- destination directory where decompressed files should be put
#     host 		- hostname on which decompression should be performed
#     user 		- the owner of decompress operation
#
#  RESULT
#     0  - success 
#     -1 - on errors
#
#*******************************************************************************
proc hedeby_unzip { archive target_dir { host "" } { user "" } } {
   global hedeby_config CHECK_USER
   if { "$archive" == "" } {
      ts_log_severe "Path to the archive is not set"
      return -1
   }
   if { "$target_dir" == "" } {
      ts_log_severe "Target directory for unzipping is not set"
      return -1
   }
   if { "$host" == "" } {
      set host [fs_config_get_server_for_path $archive]
      if { $host == "" } {
         set host $hedeby_config(hedeby_master_host)
      }
   }
   if { "$user" == "" } {
      set user $CHECK_USER
   }
   set unzip [get_binary_path $host "unzip" 0]
   start_remote_prog $host $user "$unzip" "$archive -d $target_dir" res
   if { $res != 0 } {
      ts_log_severe "Failed to unzip file: $archive into directory: $target_dir on host: $host as user $user"
      return -1
   }
   return 0
}
#****** util/hedeby_gunzip() ***************************************************
#  NAME
#     hedeby_gunzip() -- decompress with gunzip the specified archive (gz file)
#
#  SYNOPSIS
#     hedeby_gunzip { archive{ host "" } { user "" } } 
#
#  FUNCTION
#     This procedure is used to decompress gz file.
#
#  INPUTS
#     archive 		- path to the gzip file
#     host 		- hostname on which decompression should be performed
#     user 		- the owner of decompress operation
#
#  RESULT
#     0  - success 
#     -1 - on errors
#     As a result operation of this procedure "gunzip filename.gz" is done. This means
#     that result file will be filename
#
#*******************************************************************************
proc hedeby_gunzip { archive { host "" } { user "" } } {
   global hedeby_config CHECK_USER
   if { "$archive" == "" } {
      ts_log_severe "Path to the archive is not set"
      return -1
   }
   if { "$host" == "" } {
      set host [fs_config_get_server_for_path $archive]
      if { "$host" == "" } {
         set host $hedeby_config(hedeby_master_host)
      }
   }
   if { "$user" == "" } {
      set user $CHECK_USER
   }
   set gunzip [get_binary_path $host "gunzip" 0]
   
   start_remote_prog $host $user "$gunzip" "$archive" "res"
   if { $res != 0 } {
      ts_log_severe "Failed to unpack with gunzip file: $archive on host: $host as user $user"
      return -1
   }
   return 0
}
#****** util/hedeby_guntar() ***************************************************
#  NAME
#     hedeby_guntar() -- decompress with gtar the specified archive to destination directory
#
#  SYNOPSIS
#     hedeby_guntar { archive target_dir { host "" } { user "" } } 
#
#  FUNCTION
#     This procedure is used to decompress tar file.
#
#  INPUTS
#     archive 		- path to the compressed tar file
#     target_dir 	- destination directory where decompressed files should be put
#     host 		- hostname on which decompression should be performed
#     user 		- the owner of decompress operation
#
#  RESULT
#     0  - success 
#     -1 - on errors
#     As a result of this procedure "cd $target; gtar xvf file.tar" will be executed. 
#
#*******************************************************************************
proc hedeby_guntar { archive target_dir { host "" } { user "" } } {
   global hedeby_config CHECK_USER
   if { "$archive" == "" } {
      ts_log_severe "Path to the archive is not set"
      return -1
   }
   if { "$target_dir" == "" } {
      ts_log_severe "Target directory for untarring with gtar is not set"
      return -1
   }
   if { "$host" == "" } {
      set host [fs_config_get_server_for_path $archive]
      if { "$host" == "" } {
         set host $hedeby_config(hedeby_master_host)
      }
   }
   if { "$user" == "" } {
      set user $CHECK_USER
   }
   
   set gtar [get_binary_path $host "gtar" 0]
   
   start_remote_prog $host $user "$gtar" "xvf $archive" "res" "60" "0" "$target_dir"
   if { $res != 0 } {
      ts_log_severe "Failed to unpack with gtar file: $archive into directory: $target_dir on host: $host as user $user"
      return -1
   }
   return 0
}

#****** util/hedeby_master_jvm_name() ***************************************************
#  NAME
#     hedeby_master_jvm_name() -- return string which is representing master jvm name of current system
#
#  SYNOPSIS
#     hedeby_master_jvm_name {} 
#
#  FUNCTION
#     return string which is representing master jvm name of current system
#
#  INPUTS
#     none
#
#  RESULT
#     string - name of master jvm (by default "cs_vm")
#
#*******************************************************************************
proc hedeby_master_jvm_name { } {
   #currently our system is supporting "cs_vm", names of jvm in hedeby should be accessed by utility functions
   return "cs_vm"
}

#****** util/get_expected_jvms() ***************************************************
#  NAME
#     get_expected_jvms() -- return string which is representing master jvm name of current system
#
#  SYNOPSIS
#     get_expected_jvms { host } 
#
#  FUNCTION
#     return string which is representing master jvm name of current system
#
#  INPUTS
#     host - name of the host
#
#  RESULT
#     string - name of master jvm (by default "cs_vm")
#
#*******************************************************************************
proc get_expected_jvms { host } {
   global hedeby_config
   #currently our system is supporting "cs_vm", names of jvm in hedeby should be accessed by utility functions
   if { [is_simple_install_system] == 0 } {
      if { $hedeby_config(hedeby_master_host) == $host } {
	 return "cs_vm rp_vm executor_vm"
      } else {
	 return "executor_vm"
      }
   } else {
      return "cs_vm"
   }
}

#****** util/get_service_jvm() ***************************************************
#  NAME
#     get_service_jvm() -- return name of jvm in which service adapter should run
#
#  SYNOPSIS
#     get_service_jvm { } 
#
#  FUNCTION
#     return name of jvm in which service adapter should run
#
#  INPUTS
#     none
#
#  RESULT
#     string - name of jvm in which service adapter should run
#
#*******************************************************************************
proc get_service_jvm { } {
 
   if { [is_simple_install_system] == 1 } {
      return "cs_vm"
   } else {
      return "rp_vm"
   }
}

#****** util/get_service_host() ***************************************************
#  NAME
#     get_service_host() -- return host on which adapter for service should be running
#
#  SYNOPSIS
#     get_service_host { host } 
#
#  FUNCTION
#     return host on which adapter for service should be running
#
#  INPUTS
#     host - name of the host where service is running
#
#  RESULT
#     string - host on which adapter is runing
#
#*******************************************************************************
proc get_service_host { service_host } {
   global hedeby_config
   #currently our system is supporting "cs_vm", names of jvm in hedeby should be accessed by utility functions
   if { [is_simple_install_system] == 0 } {
      return $service_host
   } else {
      return $hedeby_config(hedeby_master_host)
   }
}


#****** util/get_RP_jvm() ***************************************************
#  NAME
#     get_RP_jvm() -- return string which is representing jvm name where resource provider resides
#
#  SYNOPSIS
#     get_RP_jvm { } 
#
#  FUNCTION
#     return string which is representing jvm name where resource provider resides
#
#  INPUTS
#     NONE
#
#  RESULT
#     string - name of jvm for RP ("normal" system - "rp_vm", simple system "cs_vm")
#
#*******************************************************************************
proc get_RP_jvm { } {
	
   if { [is_simple_install_system] == 1 } {
      return "cs_vm"
   } else {
      return "rp_vm"
   }
}

#****** util/get_reporter_jvm() ***************************************************
#  NAME
#     get_reporter_jvm() -- return string which is representing reporter jvm name of current system
#
#  SYNOPSIS
#     get_reporter_jvm { } 
#
#  FUNCTION
#     return string which is representing jvm name where reporter component resides
#
#  INPUTS
#     NONE
#
#  RESULT
#     string - name of jvm for reporter ("normal" system - "rp_vm", simple system "cs_vm")
#
#*******************************************************************************
proc get_reporter_jvm { } {
   
   if { [is_simple_install_system] == 1 } {
      return "cs_vm"
   } else {
      return "rp_vm"
   }
}

#****** util/get_jvm_owner() ***************************************************
#  NAME
#****** util/get_jvm_owner() ***************************************************
#  NAME
#     get_jvm_owner() -- return string which is representing reporter jvm name of current system
#
#  SYNOPSIS
#     get_jvm_owner { jvm } 
#
#  FUNCTION
#     return string which is representing jvm name where RP resides
#
#  INPUTS
#     jvm - name of jvm for which owner should be determined
#
#  RESULT
#     string - containing owner from global.xml
#
#*******************************************************************************
proc get_jvm_owner { jvm } {
   global hedeby_config ts_config
   
   set script "$ts_config(testsuite_root_dir)/scripts/hedeby_config_parser.sh"
   set spool [get_hedeby_local_spool_dir $hedeby_config(hedeby_master_host)]
   set tmp_file [get_tmp_file_name $hedeby_config(hedeby_master_host)]
   set res [start_remote_prog $hedeby_config(hedeby_master_host) [get_hedeby_admin_user] $script "$spool/spool/cs/global.xml $tmp_file user $jvm" prg_exit_state 120 0 "" "" 1 0 0 1 1]
   if { $res == "" } {
      ts_log_severe "Could not get owner of jvm: $jvm"
      return
   }
   #we should get just one element
   set tmp [split $res "\n"]
   set res ""
   foreach e $tmp {
      if { $e != "" } {
	 if { $res != "" } {
            ts_log_severe "Found more than one owner elements for jvm $jvm. Found: $res and $e"
	 } else {
	    set res [string trim $e]
	 }
      }
   }		   
   if { $res == "" } {	
      ts_log_severe "Found no valid users for $jvm."
      return
   }
   
   return $res
}
#****** util/is_simple_install_system() ***************************************************
#  NAME
#     is_simple_install_system() -- check if system is simple installation system
#
#  SYNOPSIS
#     is_simple_install_system { } 
#
#  FUNCTION
#     return 1 if system is using simple_install
#
#  INPUTS
#     none
#
#  RESULT
#     int - 0 normal installation, 1 simple installation
#
#*******************************************************************************
proc is_simple_install_system { } {
   global hedeby_config
   if { $hedeby_config(hedeby_install_mode) == "normal" } {
      return 0
   } else {
      return 1
   }
}


#****** util/hedeby_remove_service() *******************************************
#  NAME
#     hedeby_remove_service() -- remove a service from the SDM system
#
#  SYNOPSIS
#     hedeby_remove_service { service_name } 
#
#  FUNCTION
#
#     Stop the service component (sdmadm sdc) and removes the service (sdmadm rs)
#
#  INPUTS
#     service_name - the name of the service
#     { service_host ""} - the host where the service is running. If the value of this parameters
#                          is an empty string the service host will determined by call
#                          get_service_info
#
#  RESULT
#
#     0 -- if the service has been removed
#     else error
#
#*******************************************************************************
proc hedeby_remove_service { service_name {service_host ""} } {

   if { $service_host == "" } {
      get_service_info si

      if {[info exists si($service_name,host)]} {
         set service_host $si($service_name,host)
      } else {
         ts_log_severe "Service '$service_name' not found"
         return -1
      }
      unset si
   }
   sdmadm_command_opt "sdc -c $service_name -h $service_host" ;# shutdown_component
   if {$prg_exit_state != 0} {
      return -2
   }
   set eci($service_name,$service_host,state) "STOPPED" 
   if {[wait_for_component_info_opt eci] != 0} {
      return -3
   }
   sdmadm_command_opt "rs -s $service_name"  ;# remove_service
   if {$prg_exit_state != 0} {
      return -4
   }
   return 0
}

#****** util/hedeby_add_resources_to_service() *********************************
#  NAME
#     hedeby_add_resources_to_service() -- add resources to a hedeby service
#
#  SYNOPSIS
#     hedeby_add_resources_to_service { res_names target_service { opt "" } } 
#
#  FUNCTION
#
#     Add all resources defined in the res_names list to a service.  Waits
#     until the resources go into ASSIGNED state.  Optionally it stores the
#     resource ids of the resource in a tcl array.
#
#  INPUTS
#     res_names      - list of unbound_names for resource that will be added
#     target_service - the target service for the resource
#     { opt "" }     - options array for the add
#
#     In addtion to the default hedeby options (see sdmadm_command_opt) 
#     this method knows the following options:
#
#     opt(res_id_array)   name of the tcl array where the ids of the added resources will be
#                         stored (key is the unbound_name of the resource, value is the id)
#
#     opt(res_prop_array) name of the tcl array where additional resource properties for the
#                         resources are stored. The keys in the array must have the form
#                         <unbound_name>,<res_property_name>
#
#     opt(timeout)        waiting time for resources going into ASSIGNED state (default 60s)
#
#  RESULT
#     0 -- All resource have been assigned to the service, the resource ids are stored in
#          opt(res_id_array)
#     else -- error occurred (reason has been reported)
#
#  EXAMPLE
#
#    set res_names { "res1" "res2" }
#    set res_props(res1,foo) "foo"
#    set res_props(res2,foo) "foo"
#
#    set opts(res_id_array)    res_id_array
#    set opts(res_prop_array)  res_prop_array
#
#    hedeby_add_resources_to_service $res_names "service" opts
#
#    foreach res [array names res_id_array] {
#       puts "res $res has id $res_id_array($res)"
#    }
#
#  NOTES
#
#   !!!Attention!!! 
#
#   Storing the resource ids in the res_id_array will not work if the resource
#   properties from res_prop_array changes the resource name. 
#
#*******************************************************************************
proc hedeby_add_resources_to_service { res_names target_service { opt "" } } {

   set opts(timeout)        60
   set opts(res_prop_array) ""
   set opts(res_id_array)   ""

   get_hedeby_proc_opt_arg $opt opts

   if {$opts(res_prop_array) != ""} {
      upvar $opts(res_prop_array) res_prop_array
   }
   if {$opts(res_id_array) != ""} {
      upvar $opts(res_id_array) res_id_array
   }

   set tasks(STANDARD_IN) ""
   set res_count [llength $res_names]
   foreach res $res_names {
      append tasks(STANDARD_IN) "unbound_name=$res\n"
      if {$opts(res_prop_array) != ""} {
         foreach res_prop_def [array names res_prop_array] {
            set prop_def [split $res_prop_def ","]
            if {[llength $prop_def] != 2} {
               set msg    "Invalid resource property definition '$res_prop_def'.\n"
               append msg "Entries in res_id_array must have the form <res_name>,<prop_name>"
               ts_log_severe $msg $opts(raise_error)
               return -1
            }

            if {[lindex $prop_def 0] == $res} {
               set key [lindex $prop_def 1]
               set value $res_prop_array($res_prop_def)
               append tasks(STANDARD_IN) "$key=$value\n"
            }
         }
      }
      append tasks(STANDARD_IN) "====\n"
      set ri($res,service) "$target_service" 
      set ri($res,state) "ASSIGNED"
   }

   # Prepare options for sdmadm ar
   copy_hedeby_proc_opt_arg_exclude sopts sdmadm_opts { "timeout" "res_prop_array" "res_id_array" }
   set sdmadm_opts(interactive_tasks) tasks

   sdmadm_command_opt "ar -s $target_service -f -" sdmadm_opts
   unset sdmadm_opts
   if {$prg_exit_state != 0} {
      return -2
   }

   # Prepare options for wait_for_resource_info_opt
   copy_hedeby_proc_opt_arg_exclude sopts wait_opts { "res_prop_array" "res_id_array" }
   if {$opts(res_id_array) != ""} {
      set wait_opts(res_info) res_info
   }
   if {[wait_for_resource_info_opt ri wait_opts] != 0} {
       return -3
   }
   unset ri
   if {$opts(res_id_array) != ""} {
      foreach res $res_names {
         set res_id_array($res) $res_info($res,id)
      }
   }
   ts_log_fine "Resources successfully added to service '$target_service'"
   return 0
}

#****** util/hedeby_move_resources() *******************************************
#  NAME
#     hedeby_move_resources() -- Move resources
#
#  SYNOPSIS
#     hedeby_move_resources { res_names target_service opt } 
#
#  FUNCTION
#
#   Moves resources to a service and wait until the resources reach
#   a final state.
#
#  INPUTS
#     res_ids_or_names  - list of resource ids or names
#     target_service   - the target service
#     { opt ""  }      - option for the command
#
#         opt(timeout)     - max. waiting time until the resource must reach the
#                            final state (default 60s)
#         opt(final_state) - the final state of the resource (default ASSIGNED)
#         opt(final_flags) - the final flags of the resource (default "{}")
#
#  RESULT
#
#    0    -  all resource moved and reached their final state
#    else -  error
#
#  EXAMPLE
#
#   set opts(timeout)     60
#   set opts(final_flags) "U"
#   set opts(final_state) "ASSIGNED"
#   hedeby_move_resources res#123 spare_pool opts
#
#*******************************************************************************
proc hedeby_move_resources { res_ids_or_names target_service { opt "" } } {

   set opts(timeout)     60          ;# timeout for the wait_for_resource_info
   set opts(final_state) "ASSIGNED"
   set opts(final_flags) "{}"

   get_hedeby_proc_opt_arg $opt opts

   set rarg [join $res_ids_or_names ","]

   copy_hedeby_proc_opt_arg opts sdmadm_opts "default"
   sdmadm_command_opt "mvr -r $rarg -s $target_service" sdmadm_opts ;# move_resource
   if {$prg_exit_state != 0} {
      return -1
   }
   
   foreach res $res_ids_or_names {
      set ri($res,service) $target_service
      set ri($res,flags) $opts(final_flags)
      set ri($res,state) $opts(final_state)
   }
   copy_hedeby_proc_opt_arg opts wait_opts "default timeout"
   if {[wait_for_resource_info_opt ri wait_opts] != 0} {
       return -2
   }
   return 0
}

#****** util/hedeby_remove_resources() *****************************************
#  NAME
#     hedeby_remove_resources() -- Remove resources from the SDM system
#
#  SYNOPSIS
#     hedeby_remove_resources { res_ids_or_names {opt ""} } 
#
#  FUNCTION
#
#    Removes (or purges) a set of the resource from the SDM system. The
#    resources can be addressed by resource name or resource id.
#
#    The method blocks until the resources are actually removed from the
#    system.
#
#  INPUTS
#     res_ids_or_names - list if resource ids or names
#     {opt ""}         - options for the removal
#
#       opt(purge)        if 1, use purge_resource command instead of remove_resource,
#                         by default resources are removed, not purged
#       opt(timeout)      max. waiting time for the RESORUCE_REMOVED event
#
#  RESULT
#
#     0   -  all resources are removed, all RESOURCE_REMOVED event found in history
#     else error
#
#  EXAMPLE
#     # Purge the two resource foo.bar and foo1.bar from the system
#     set opt(timeout) 20
#     set opt(purge)   1
#     hedeby_remove_resources { foo.bar foo1.bar } opt
#   
#*******************************************************************************
proc hedeby_remove_resources { res_ids_or_names {opt ""} } {
   set opts(purge)       0
   set opts(timeout)     60
   get_hedeby_proc_opt_arg $opt opts

   copy_hedeby_proc_opt_arg opts sdmadm_opts "default"

   set start_time [clock seconds]

   set rarg [join $res_ids_or_names ","]
   if { $opts(purge) } {
      sdmadm_command_opt "pr -r $rarg" sdmadm_opts ;# purge_resource
   } else {
      sdmadm_command_opt "rr -r $rarg" sdmadm_opts ;# remove_resource
   }
   if { $prg_exit_state != 0 } {
      return -1
   }

   # wait for removal
   copy_hedeby_proc_opt_arg opts call_opts "default"
   return [wait_for_resource_removal $res_ids_or_names call_opts]
}


#****** util/hedeby_change_sge_root_in_ge_service() *********************************
#  NAME
#     hedeby_change_sge_root_in_ge_service() -- Change sge_root for ge service
#
#  SYNOPSIS
#     hedeby_change_sge_root_in_ge_service { new_root } 
#
#  FUNCTION
#     Changes the root attribute (containing the path to SGE_ROOT) in the configuration
#     of a ge service. Does not update the service.
#
#  INPUTS
#     new_root the new SGE_ROOT
#
#  RESULT
#
#     -1  if hedeby_mod_setup_opt failed
#     else exit status of the 'sdmadm mc' command
#
#*******************************************************************************
proc hedeby_change_sge_root_in_ge_service { ge_service new_root } {

   set seq {}
   lappend seq "/ge_adapter:connection\n"  ;# Search for connection tag
   lappend seq "/root=\n"                  ;# Search for root attribute
   lappend seq "ct "                       ;# change to blank
   lappend seq "root=\"$new_root\""        ;# insert the new root attribute
   lappend seq "[format "%c" 27]"          ;# ESC  

   set opt(do_update) 0
   return [hedeby_change_component $ge_service $seq opt]
}



#****** util/hedeby_change_component() *****************************************
#  NAME
#     hedeby_change_component() -- changes and updates a service or component
#
#  SYNOPSIS
#     hedeby_change_component { component sequence {opt ""} } 
#
#  FUNCTION
#     This function bundles the steps necessary to change the configuration of
#     a service, does an update component afterwards and finally waits until
#     the service is running again.
#
#     If the optional named argument do_update is set to 0, then the update
#     component and wait step is skipped.
#
#     If do_update is true and do_wait_for_state is 0, the update component
#     is done but no waiting for component state is performed.
#
#     The waiting step always raises errors, no matter how the optional argument
#     raise_error is set.
#
#  INPUTS
#     component - name of the service or component to change
#     sequence  - vi sequence that changes the configuration
#     {opt ""}  - optional named arguments, see get_hedeby_proc_default_opt_args()
#       opt(do_update)         if set to 1 update the component and
#                              (potentially) wait for given state, by default set to 1
#       opt(do_wait_for_state) if set to 1 wait for given state, by default set to 1
#                              Only relevant if do_update is 1
#       opt(component_state)   the expected component state after update, by default STARTED
#       opt(service_state)     the expected service state after update, by default RUNNING,
#                              only relevant if the component is a service.
#       opt(update_on_host)    if set, the sdmadm uc will use the -h switch, by default not set
#
#  RESULT
#     0 on success, else error
#
#  SEE ALSO
#     util/hedeby_mod_setup()
#     util/hedeby_mod_sequence()
#     util/hedeby_mod_cleanup()
#     util/hedeby_is_component_also_service()
#*******************************************************************************
proc hedeby_change_component { component sequence {opt ""} } {
   set opts(do_update)         1
   set opts(do_wait_for_state) 1
   set opts(component_state)   "STARTED"
   set opts(service_state)     "RUNNING"
   set opts(update_on_host)    ""
   get_hedeby_proc_opt_arg $opt opts

   # for all called commands, just use the default option keys
   copy_hedeby_proc_opt_arg opts sdmadm_opts "default"

   ts_log_fine "Changing configuration of component '$component' ..."

   set ispid [hedeby_mod_setup_opt "mc -c $component" error_text sdmadm_opts]
   if { $error_text != "" } {
      ts_log_severe "Could not start sdmadm mc: $error_text" $opts(raise_error)
      return -1
   }

   hedeby_mod_sequence $ispid $sequence error_text
   hedeby_mod_cleanup  $ispid error_text prg_exit_state $opts(raise_error)
   if { $prg_exit_state != 0 } {
      return $prg_exit_state
   }

   if { ! $opts(do_update) } {
      # don't do the update and waiting step
      return 0
   }

   set is_service [hedeby_is_component_also_service $component]
   if { $is_service } {
      # the component is a service
      if { $opts(update_on_host) != "" } {
         set msg    "hedeby_change_component:\n"
         append msg "Named optional parameter update_on_host is set to '$opts(update_on_host)'. This does not make sense for service '$component'."
         ts_log_severe $msg $opts(raise_error)
         return -2
      }
   } else {
      # the component is no service
      if { $opts(service_state) != "RUNNING" } {
         set msg    "hedeby_change_component:\n"
         append msg "Named optional parameter service_state is set to '$opts(service_state)'. This does not make sense for component '$component'."
         ts_log_severe $msg $opts(raise_error)
         return -3
      }
   }

   # update component
   if { $opts(update_on_host) != "" } {
      sdmadm_command_opt "uc -c $component -h $opts(update_on_host)" sdmadm_opts
   } else {
      sdmadm_command_opt "uc -c $component" sdmadm_opts
   }
   if { $prg_exit_state != 0 } {
      return $prg_exit_state
   }

   if { ! $opts(do_wait_for_state) } {
      # don't do the waiting step
      return 0
   }

   # and wait for given state
   if { $is_service } {
      set exp_serv_info($component,cstate) $opts(component_state)
      set exp_serv_info($component,sstate) $opts(service_state)
      # always raise error at wait_command
      return [wait_for_service_info exp_serv_info 60 1]
   } else {
      # for a component we need the host
      if { $opts(update_on_host) == "" } {
         set msg    "hedeby_change_component:\n"
         append msg "Cannot wait for component state without info about the host. Set update_on_host parameter."
         ts_log_severe $msg $opts(raise_error)
      }
      set exp_comp_info($component,$opts(update_on_host),state) $opts(component_state)
      # always raise error at wait_command
      set sdmadm_opts(raise_error) 1
      return [wait_for_component_info_opt exp_comp_info sdmadm_opts]
   }
}

#****** util/hedeby_is_component_also_service() ********************************
#  NAME
#     hedeby_is_component_also_service() -- checks if component is also a service
#
#  SYNOPSIS
#     hedeby_is_component_also_service { component } 
#
#  FUNCTION
#     This functions checks if the given component is also registered as a
#     service in the SDM system. Components like ca, resource_provider or
#     executor return false.
#
#     The sdmadm show_services command is called to get a list of SDM services
#     to compare to. Therefore, this does NOT work if the service is not or has
#     never been started.
#
#  INPUTS
#     component - the name of the component to check
#
#  RESULT
#     1 - if component is also a service
#     0 - otherwise
#
#  EXAMPLE
#     if { [hedeby_is_component_also_service $component] } {
#        # do service stuff
#     } else {
#        # do component stuff
#     }
#
#  SEE ALSO
#     util/get_service_info
#*******************************************************************************
proc hedeby_is_component_also_service { component } {
   get_service_info "" "" sinfo

   if { [lsearch -exact $sinfo(service_list) $component] >= 0 } {
      # component found in services
      return 1
   } else {
      return 0
   }
}



#****** util/hedeby_shutdown_jvm() *********************************************
#  NAME
#     hedeby_shutdown_jvm() -- Shutdown a hedeby jvm
#
#  SYNOPSIS
#     hedeby_shutdown_jvm { jvm_name host {timeout 60} } 
#
#  FUNCTION
#
#     This method shuts down a hedeby jvm via sdmadm sdj command. It checks
#     that the pid file has been deleted and that the process disappeared
#
#  INPUTS
#     jvm_name     - the name of the jvm
#     host         - the host where the jvm is running
#     {timeout 60} - timeout for the shutdown
#
#  RESULT
#
#     0 -  jvm has been stopped, pid file is deleted, process died
#     1 -  pid for the jvm does not exist, may be the jvm is not running
#     2 -  sdmadm sdj reported an error
#     3 -  the pid file did not disappear within the timeout
#     4 -  pid file has been deleted, but process did not die within the timeout  
#
#     Any result != 0 already did a ts_log_severe
#
#*******************************************************************************
proc hedeby_shutdown_jvm { jvm_name host {timeout 60} } {

   set pid_file [get_pid_file_for_jvm $host $jvm_name]
   if {[read_hedeby_jvm_pid_file  pid_info $host [get_hedeby_startup_user] $pid_file ] != 0} {
      ts_log_severe "Can not shutdown jvm '$jvm_name' at host '$host', pid file '$pid_file' not found"
      return 1
   }

   sdmadm_command_opt "sdj -j $jvm_name -h $host"
   if {$prg_exit_state != 0} {
      return 2
   }

   set end_time [expr [clock seconds] + $timeout]

   # Wait until the pid file has been removed
   set to_go_away 1
   set raise_error 1
   if {[wait_for_remote_file $host [get_hedeby_admin_user] $pid_file $timeout  $raise_error $to_go_away] != 0} {
      ts_log_severe "Pid file '$pid_file' for jvm '$jvm_name' on host '$host' did not dissapear in $timeout seconds"
      return 3
   }

   while {$end_time > [clock seconds]} {
      if {[is_hedeby_process_running $host $pid_info(pid)] == 0} {
         return 0 
      }
      ts_log_fine "jvm '$jvm_name' on host '$host' is still running (pid $pid_info(pid))"
      after 1000
   }
   ts_log_severe "jvm '$jvm_name' on host '$host' did not stop (pid $pid_info(pid))"
   return 4
}

#****** util/hedeby_startup_jvm() **********************************************
#  NAME
#     hedeby_startup_jvm() -- Startup a hedeby jvm
#
#  SYNOPSIS
#     hedeby_startup_jvm { jvm_name host {timeout 60} } 
#
#  FUNCTION
#
#     This methods startup a hedeby jvm, waits until the PID file appears and
#     the process is started.
#
#  INPUTS
#     jvm_name     - the name of the jvm
#     host         - the host
#     {timeout 60} - timout of the jvm
#
#  RESULT
#
#     0  -   jvm started
#     1  -   sdmadm suj reported an error
#     2  -   the pid file has not been created
#     3  -   pid file of the jvm could not be read
#     4  -   process in the pid file does not exist 
#
#     Any result != 0 already did a ts_log_severe
#
#*******************************************************************************
proc hedeby_startup_jvm { jvm_name host {timeout 60} } {

   set opts(user) [get_hedeby_startup_user]

   sdmadm_command_opt "suj -j $jvm_name" opts
   if {$prg_exit_state != 0} {
      return 1
   }
   set pid_file [get_pid_file_for_jvm $host $jvm_name]

   set to_go_away 0
   set raise_error 1
   if {[wait_for_remote_file $host [get_hedeby_admin_user] $pid_file $timeout $raise_error $to_go_away] != 0} {
      ts_log_severe "Pid file '$pid_file' for jvm '$jvm_name' on host '$host' has not been created in $timeout seconds"
      return 2
   }
   
   if {[read_hedeby_jvm_pid_file  pid_info $host $opts(user) $pid_file ] != 0} {
      return 3
   }

   if {[is_hedeby_process_running $host $pid_info(pid)] != 1} {
      ts_log_severe "jvm '$jvm_name' on host '$host' did not start up. Process with pid $pid_info(pid) is not running."
      return 4
   }
 
   return 0
}

#****** util/hedeby_restart_jvm() **********************************************
#  NAME
#     hedeby_restart_jvm() -- Restart a hedeby jvm
#
#  SYNOPSIS
#     hedeby_restart_jvm { jvm_name host {shutdown_timeout 60} 
#     {startup_timeout 60} } 
#
#  FUNCTION
#
#     This method restarts a hedeby jvm with hedeby_shutdown_jvm and
#     hedeby_startup_jvm
#
#  INPUTS
#     jvm_name              - the name of the jvm
#     host                  - the host
#     {shutdown_timeout 60} - shutdown timeout for the jvm
#     {startup_timeout 60}  - startup timeout for the jvm
#
#  RESULT
#
#     0  -   jvm successfully restarted
#     1  -   shutdown of the jvm failed
#     2  -   startup of the jvm failed
#
#*******************************************************************************
proc hedeby_restart_jvm { jvm_name host {shutdown_timeout 60} {startup_timeout 60} } {
   
   if {[hedeby_shutdown_jvm $jvm_name $host $shutdown_timeout] != 0} {
      return 1
   }

   if {[hedeby_startup_jvm $jvm_name $host $startup_timeout] != 0} {
      return 2
   }
   return 0
}
