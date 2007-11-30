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
#     util/shutdown_hedeby_host()
#     util/startup_hedeby_host()
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
   foreach host [get_all_hedeby_managed_hosts] {
      remove_prefs_on_hedeby_host $host $raise_error
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
   global CHECK_OUTPUT
   global hedeby_config

   set ret_val 0
   set shutdown_user [get_hedeby_startup_user]

   # first step: shutdown all managed hosts
   foreach host [get_all_hedeby_managed_hosts] {
      set val [shutdown_hedeby_host "managed" $host $shutdown_user $only_raise_cannot_kill_error]
      if { $val != 0 } {
         set ret_val 1
      }
   }

   # second step: shutdown hedeby master host
   set val [shutdown_hedeby_host "master" $hedeby_config(hedeby_master_host) $shutdown_user $only_raise_cannot_kill_error]
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
   global CHECK_OUTPUT
   global hedeby_config

   set ret_val 0
   set startup_user [get_hedeby_startup_user]

   # first step: startup hedeby master host
   set val [startup_hedeby_host "master" $hedeby_config(hedeby_master_host) $startup_user]
   if { $val != 0 } {
      set ret_val 1
   }


   # second step: startup all managed hosts
   foreach host [get_all_hedeby_managed_hosts] {
      set val [startup_hedeby_host "managed" $host $startup_user]
      if { $val != 0 } {
         set ret_val 1
      }
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
#     add_host_resource { host_resource { on_host "" } { as_user ""} 
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
#     {raise_error 1} - if set to 1 testsuite reports errors on failure 
#
#  RESULT
#     the prg_exit_state of the sdmadm command
#
#*******************************************************************************
proc add_host_resource { host_resource { on_host "" } { as_user ""} {raise_error 1} } {
   global hedeby_config
   global CHECK_OUTPUT
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
   set osName [string trim [start_remote_prog $host_resource $exec_user uname -s]]
   set osRel  [string trim [start_remote_prog $host_resource $exec_user uname -r]]

   set data(0) 4
   set data(1) "hardwareCpuArchitecture=$osArch"
   set data(2) "operatingSystemName=$osName"
   set data(3) "operatingSystemRelease=$osRel"
   set data(4) "resourceHostname=$host_resource"
   write_remote_file $host_resource $exec_user $file_name data

   # print out created file
   set file_content [start_remote_prog $exec_host $exec_user cat $file_name]
   puts $CHECK_OUTPUT "adding host resource \"$host_resource\" to hedeby system ..."
   puts $CHECK_OUTPUT "properties file:"
   puts $CHECK_OUTPUT $file_content

   # now use sdmadm command ...
   sdmadm_command $exec_host $exec_user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] add_resource -pf $file_name" prg_exit_state "" $raise_error
   return $prg_exit_state
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
   global CHECK_OUTPUT
   if {$CHECK_ADMIN_USER_SYSTEM == 0} {
      return $hedeby_config(preferences_mode)
   } else {
      if { $hedeby_config(preferences_mode) == "system" } {
         set error_text "WARNING: It is not possible to save \"system\" preferences without having root permissions!\n"
         append error_text "Please provide root password OR modify hedeby configuration to use preferences_mode \"user\"!\n"
         append error_text "INFO: Testsuite will store bootstrap information in \"user\" preferences!!!"
         puts $CHECK_OUTPUT $error_text
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
   global CHECK_OUTPUT
   global CHECK_USER
   global hedeby_config
   global ts_config

   # TODO: reparse messages if one file timestamp is newer than the file stamp
   #       of the cached files (same as for GE message files)        
   if {[info exists bundle_cache]} {
      unset bundle_cache
   }
   set filename [get_properties_messages_file_name]
   if {[is_remote_file $hedeby_config(hedeby_master_host) $CHECK_USER $filename]} {
      delete_remote_file $hedeby_config(hedeby_master_host) $CHECK_USER $filename

      # fix for hedeby testsuite issue #81
      wait_for_remote_file $ts_config(master_host) $CHECK_USER $filename 70 1 1
   }

   puts $CHECK_OUTPUT "looking for properties files in dir \"$source_dir\" ..."
   
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
   global CHECK_OUTPUT
   global hedeby_config
  
   puts $CHECK_OUTPUT "checking properties file ..."
   if { [ file isdirectory $CHECK_PROTOCOL_DIR] != 1 } {
      file mkdir $CHECK_PROTOCOL_DIR
      puts $CHECK_OUTPUT "creating directory: $CHECK_PROTOCOL_DIR"
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
   global CHECK_OUTPUT
   upvar $params_array params
   # get bundle string
   set bundle_string [get_bundle_string $id]
   set result_string $bundle_string

   # puts $CHECK_OUTPUT "bundle string: \"$result_string\""
   # get number of params in bundle string
   set i 0
   while { [string match "*{$i}*" $bundle_string] } {
      incr i 1
   }
   # puts $CHECK_OUTPUT "bundle string has $i parameter"
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
      #puts $CHECK_OUTPUT "result $x: \"$result_string\""
   }
   # puts $CHECK_OUTPUT "output string: \"$result_string\""
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
   global CHECK_OUTPUT
   upvar $params_array par

   if { [info exists par] } {
      unset par
   }

   set par(count) 0

   set bundle_string [get_bundle_string $id]
   #puts $CHECK_OUTPUT "output: $output"
   #puts $CHECK_OUTPUT "bundle: $bundle_string"
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
      #puts $CHECK_OUTPUT "before $x ($irange_start - $irange_end): \"$par($x,before)\""
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
   #puts $CHECK_OUTPUT "rest string: \"$restString\""

   

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
            #puts $CHECK_OUTPUT "remaining parse string: \"$parse_string\"" 
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
      #puts $CHECK_OUTPUT "par($x) = \"$par($x)\""
      #puts $CHECK_OUTPUT "remaining parse string: \"$parse_string\"" 
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
   global CHECK_OUTPUT
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
   global CHECK_OUTPUT 
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
         puts $CHECK_OUTPUT "${host}($chown_user): doing chown $comargs ..."
         set output [start_remote_prog $host $chown_user "chown" $comargs]
         puts $CHECK_OUTPUT $output
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
#     the specified GE clusters including all hedeby (host) resources.
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
   global CHECK_OUTPUT
   set host_list $hedeby_config(hedeby_host_resources) 
   
   foreach host [get_all_execd_hosts] {
      if {[lsearch $host_list $host] < 0 && $host != $hedeby_config(hedeby_master_host) } {
         lappend host_list $host
      }
   }
   return $host_list
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
   global CHECK_OUTPUT

   puts $CHECK_OUTPUT "checking pid $pid on host $host ..."
   get_ps_info $pid $host ps_info

   set result 0
   if {$ps_info($pid,error) == 0} {
        puts $CHECK_OUTPUT "process string of pid $pid is $ps_info($pid,string)"
        set result 1
   } else {
        puts $CHECK_OUTPUT "pid $pid not found!"
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
#     util/shutdown_hedeby_host()
#     util/startup_hedeby_host()
#     util/shutdown_hedeby()
#     util/startup_hedeby()
#*******************************************************************************
proc kill_hedeby_process { host user component pid {atimeout 60}} {
   global CHECK_OUTPUT

   set del_pid_file [get_hedeby_local_spool_dir $host]
   append del_pid_file "/run/$component"
   if { [is_remote_file $host $user $del_pid_file] == 0 } {
      puts $CHECK_OUTPUT "cannot find pid file of component $component in the hedeby run directory"
   }

   set delete_pid_file 0
   puts $CHECK_OUTPUT "***********************************************************************"
   puts $CHECK_OUTPUT "killing component \"$component\" with pid \"$pid\" using SIGTERM ..."
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
      puts $CHECK_OUTPUT "***********************************************************************"
      puts $CHECK_OUTPUT "killing component \"$component\" with pid \"$pid\" using SIGKILL ..."
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
      puts $CHECK_OUTPUT "delete pid file \"$del_pid_file\"\nfor component \"$component\" on host \"$host\" as user \"$user\" ..."
      delete_remote_file $host $user $del_pid_file
   }
}

#****** util/shutdown_hedeby_host() ********************************************
#  NAME
#     shutdown_hedeby_host() -- shutdown complete hedeby host
#
#  SYNOPSIS
#     shutdown_hedeby_host { type host user } 
#
#  FUNCTION
#     This procedure is used to shutdown all hedeby components on the specified
#     host. First try will shutdown components using sdmadm command. If this
#     doesn't help SIGTERM and if also this does not help SIGKILL is send to
#     the java processes on the specified host.
#
#  INPUTS
#     type - type of hedeby host: "master" or "managed"
#     host - name of the host where the components should be stopped
#     user - user which should stop the components
#
#  RESULT
#     0 - on success
#     1 - on error
#
#  SEE ALSO
#     util/is_hedeby_process_running()
#     util/kill_hedeby_process()
#     util/shutdown_hedeby_host()
#     util/startup_hedeby_host()
#     util/shutdown_hedeby()
#     util/startup_hedeby()
#*******************************************************************************
proc shutdown_hedeby_host { type host user { only_raise_cannot_kill_error 0 } } {
   global CHECK_OUTPUT 
   global hedeby_config

   set ret_val 0
   puts $CHECK_OUTPUT "check if \"$type\" host \"$host\" has running components ..."
   
   set pid_list {}
   set run_dir [get_hedeby_local_spool_dir $host]
   append run_dir "/run"
   if { [remote_file_isdirectory $host $run_dir] } {
      set running_components [start_remote_prog $host $user "ls" "$run_dir"]
      if { [llength $running_components] == 0 } {
         debug_puts "no hedeby component running on host $host!"
         return $ret_val
      }
      foreach component $running_components {
         if {[read_hedeby_jvm_pid_file pid_info $host $user $run_dir/$component] != 0} {
            return 1
         }
         set pid $pid_info(pid)
         set port $pid_info(port)
         
         lappend pid_list $pid
         set run_list($pid,comp) $component
         puts $CHECK_OUTPUT "component $run_list($pid,comp) has pid \"$pid\""
         puts $CHECK_OUTPUT "component $run_list($pid,comp) has port \"$port\""
      }
   } else {
      debug_puts "no hedeby run directory found on host $host!"
      return $ret_val
   }
   puts $CHECK_OUTPUT "shutting down \"$type\" host \"$host\" ..."

   if {$only_raise_cannot_kill_error} {
      set raise_error 0
   } else {
      set raise_error 1
   }

   switch -exact -- $type {
      "managed" {
         if { $host == $hedeby_config(hedeby_master_host) } {
            add_proc_error "shutdown_hedeby_host" -1 "host \"$host\" is the master host!"
            return 1
         }

         set output [sdmadm_command $host $user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] shutdown -h $host" prg_exit_state "" $raise_error]
         if { $prg_exit_state != 0 } {
            set ret_val 1
         }
      }
      "master" {
         if { $host != $hedeby_config(hedeby_master_host) } {
            add_proc_error "shutdown_hedeby_host" -1 "host \"$host\" is NOT the master host!"
            return 1
         }
         set output [sdmadm_command $host $user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] shutdown -h $host" prg_exit_state "" $raise_error]
         if { $prg_exit_state != 0 } {
            set ret_val 1
         }
      }
      default {
         add_proc_error "shutdown_hedeby_host" -1 "unexpected host type: \"$type\" supported are \"managed\" or \"master\""
         set ret_val 1
      }
   }
   if { $ret_val != 0 } {
      puts $CHECK_OUTPUT "try to kill all components ..."
      foreach pid $pid_list {
         set delete_pid_file 0
         set is_pid_running [is_hedeby_process_running $host $pid]
         if { $is_pid_running } {
            kill_hedeby_process $host $user $run_list($pid,comp) $pid
         } else {
            # there was an old pid file without running component -> delete the pid file
            set delete_pid_file 1
         }
         if { $delete_pid_file } {
            set del_pid_file "$run_dir/$run_list($pid,comp)"
            puts $CHECK_OUTPUT "delete pid file \"$del_pid_file\"\nfor component \"$run_list($pid,comp)\" on host \"$host\" as user \"$user\" ..."
            delete_remote_file $host $user $del_pid_file
         }
      }
   } else {
      # check pid files and processes
      puts $CHECK_OUTPUT "check that no pid is running after sdmadm shutdown and pid files are removed ..."
      set my_timeout [timestamp]
      incr my_timeout 60

      set pids_to_check {}
      foreach pid $pid_list {
         lappend pids_to_check $pid
      }
      while { [timestamp] < $my_timeout } {
         set not_removed_pids {}
         foreach pid $pids_to_check {
            set is_pid_running [is_hedeby_process_running $host $pid]
            if { $is_pid_running } {
               lappend not_removed_pids $pid
            }
         }
         set pids_to_check {}
         foreach pid $not_removed_pids {
            lappend pids_to_check $pid
         }

         if { [llength $pids_to_check] == 0 } {
            break
         }

         puts $CHECK_OUTPUT "waiting ..."
         after 1000
      }
      foreach pid $pids_to_check {
         set ret_val 1
         add_proc_error "shutdown_hedeby_host" -1 "cannot shutdown component \"$run_list($pid,comp)\" on host \"$host\" as user \"$user\".\n(process with pid \"$pid\" is still running)"
         kill_hedeby_process $host $user $run_list($pid,comp) $pid
      }

      foreach pid $pid_list {
         set pid_file "$run_dir/$run_list($pid,comp)"
         if { [is_remote_file $host $user $pid_file] } {
            add_proc_error "shutdown_hedeby_host" -1 "cannot shutdown component \"$run_list($pid,comp)\" on host \"$host\" as user \"$user\"\n(pid file \"$pid_file\" wasn't removed)"
         }
      }
   }
   return $ret_val
}

#****** util/startup_hedeby_host() *********************************************
#  NAME
#     startup_hedeby_host() -- startup all components on the hedeby host
#
#  SYNOPSIS
#     startup_hedeby_host { type host user } 
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
#     util/shutdown_hedeby_host()
#     util/startup_hedeby_host()
#     util/shutdown_hedeby()
#     util/startup_hedeby()
#*******************************************************************************
proc startup_hedeby_host { type host user } {
   global CHECK_OUTPUT 
   global hedeby_config
    
   set ret_val 0
   puts $CHECK_OUTPUT "startup \"$type\" host \"$host\" ..."

   # TODO: add more checking for "managed" and "master"
   # TODO: test with get_ps_info if the processes have started
   # TODO: check that all pid are written and no one is missing

   if { $hedeby_config(security_disable) == "true" } {
      puts $CHECK_OUTPUT "WARNING! Setting security disable property for host $host"
      set output [sdmadm_command $host $user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] set_system_property -n ssl_disable -v true"]
      if { $prg_exit_state != 0 } {
         return $prg_exit_state
      }
   }

   switch -exact -- $type {
      "managed" {
         set output [sdmadm_command $host $user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] start"]
         if { $prg_exit_state != 0 } {
            set ret_val 1
         } 
         set match_string [create_bundle_string "bootstrap.log.info.jvm_started" xyz "*"]
      }
      "master" {
         set output [sdmadm_command $host $user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] start"]
         if { $prg_exit_state != 0 } {
            set ret_val 1
         }
         set help [create_bundle_string "bootstrap.log.info.jvm_started" xzy "*"]
         set match_string "$help\r\n$help"  ;# we expect 2
      }
      default {
         add_proc_error "startup_hedeby_host" -1 "unexpected host type: \"$type\" supported are \"managed\" or \"master\""
         set ret_val 1
      }
   }
   if { [string match "*$match_string*" $output]} {
      puts $CHECK_OUTPUT "output matches expected result"
   } else {
      set error_text ""
      append error_text "startup hedeby host ${host} failed:\n"
      append error_text "\"$output\"\n"
      append error_text "The expected output doesn't match and exit value should not be 0:\n"
      append error_text "match string:\n"
      append error_text "\"$match_string\"\n"
      add_proc_error "startup_hedeby_host" -1 $error_text
      set ret_val 1
   }
   return $ret_val
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
   global CHECK_OUTPUT 

   set pref_type [get_hedeby_pref_type]
   set sys_name [get_hedeby_system_name]
   puts $CHECK_OUTPUT "removing \"$pref_type\" preferences for hedeby system \"$sys_name\" on host \"$host\" ..."

   set remove_user [get_hedeby_startup_user]
   sdmadm_command $host $remove_user "-p $pref_type -s $sys_name remove_system" prg_exit_state "" $raise_error
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
proc reset_hedeby {} {
   add_proc_error "reset_hedeby" -3 "not implemented"
   # TODO: reset all resources to install state = OK
   # TODO: all resources which are added by install test should be in the spare
   #       pool after reset_hedeby()
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
#
#  RESULT
#     The output of the sdmadm command
#
#  SEE ALSO
#     util/sdmadm_command()
#*******************************************************************************
proc sdmadm_command { host user arg_line {exit_var prg_exit_state} { interactive_tasks "" } {raise_error 1} } {
   global CHECK_OUTPUT
   upvar $exit_var back_exit_state
   if { $interactive_tasks != "" } {
      upvar $interactive_tasks tasks
   }
   set sdmadm_path [get_hedeby_binary_path "sdmadm" $user]
   set my_env(JAVA_HOME) [get_java_home_for_host $host "1.5"]

   if { $interactive_tasks == "" } {
      puts $CHECK_OUTPUT "${host}($user): starting binary not interactive \"sdmadm $arg_line\" ..."
      set output [start_remote_prog $host $user $sdmadm_path $arg_line back_exit_state 60 0 "" my_env 1 0 0 $raise_error]
      if { $back_exit_state != 0 } {
         add_proc_error "sdmadm_command" -1 "${host}(${user}): sdmadm $arg_line failed:\n$output" $raise_error
      }
      puts $CHECK_OUTPUT $output
      return $output
   } else {
      set back_exit_state -1
      puts $CHECK_OUTPUT "${host}($user): starting binary INTERACTIVE \"sdmadm $arg_line\" ..."
      set pr_id [open_remote_spawn_process $host $user $sdmadm_path $arg_line 0 "" my_env 0]
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
              puts $CHECK_OUTPUT "script terminated!" 
              set help $token
              set st [string first "(" $help]
              set ed [string first ")" $help]
              incr st 1
              incr ed -1
              set back_exit_state [string range $help $st $ed]
              puts $CHECK_OUTPUT "found exit status of client: ($back_exit_state)"
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
                       puts $CHECK_OUTPUT ".....found \"$name\", sending \"$tasks($name)\" ..."
                       ts_send $sp_id "$tasks($name)\n"
                    } else {
                       log_user 0  ;# in any case before sending password
                       ts_send $sp_id "[get_root_passwd]\n" "" 1
                       log_user 1
                       puts $CHECK_OUTPUT ".....found \"$name\", sent \"$tasks($name)\" without prompt ..."
                    }
                 }
              }
           }
           if {[string first "_start_mark_:" $token]} {
              set found_start 1
           }
           if { $do_stop == 0 } {
              exp_continue
           }
        }
      }
      close_spawn_process $pr_id
      if { $error_text != "" } {
         add_proc_error "sdmadm_command" -1 "interacitve errors:\n$error_text\noutput:\n$output\nexit state: $back_exit_state" $raise_error
      }
      if { $back_exit_state != 0 } {
         add_proc_error "sdmadm_command" -1 "${host}(${user}): sdmadm $arg_line failed:\n$output" $raise_error
      }
      return $output
   }
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
   global CHECK_OUTPUT
   set retval 0
   
   set output [sdmadm_command $execute_host $execute_user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] remove_admin_user $user_name" prg_exit_state "" $raise_error]
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
   global CHECK_OUTPUT
   set retval 0
   
   set output [sdmadm_command $execute_host $execute_user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] add_admin_user $user_name" prg_exit_state "" $raise_error ]
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
   global CHECK_OUTPUT
   upvar $result_list user_list
   set retval 0
   
   set output [sdmadm_command $execute_host $execute_user "-p [get_hedeby_pref_type] -s [get_hedeby_system_name] show_admin_users" prg_exit_state "" $raise_error ]
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

#****** util/parse_show_component_output() *********************************
#  NAME
#     parse_show_component_output() -- parse sdmadm show_status output
#
#  SYNOPSIS
#     parse_show_component_output { output_var {status_array "ss_out" } } 
#
#  FUNCTION
#     This procedure is used to parse the output of the sdmadm show_status
#     command and return the parsed values in the specified result array.
#
#  INPUTS
#     output_var               - output of the sdmadm show_status cli command
#     {status_array "ss_out" } - name of the array were the parsed information
#                                should be stored. 
#                                The array (default="ss_out") has the following
#                                settings:
#                                ss_out(HOSTNAME,COMPONENT_NAME,status)
#                                ss_out(HOSTNAME,COMPONENT_NAME,section)
#
#  RESULT
#     number of parsed rows or -1 if the output could not be parsed
#
#  EXAMPLE
#     
#   set component_count [parse_show_component_output output]
#   
#   for {set i 0} {$i < $component_count} {incr i} {
#      set host   $ss_out($i,host)
#      set jvm    $ss_out($i,jvm)
#      set comp   $ss_out($i,component)
#      set state  $ss_out($i,state)
#      set type   $ss_out($i,type)
#   }
#
#  SEE ALSO
#     util/sdmadm_command()
#*******************************************************************************
proc parse_show_component_output { output_var {status_array "ss_out" } } {
   global CHECK_OUTPUT
   upvar $output_var out
   upvar $status_array ss

   set help [split $out "\n"]
   set line_count -1
   set col_count 0
   array set last_values {}
   
   set known_colums(host)  [create_bundle_string "ShowComponentStatusCliCommand.HostCol"]
   set known_colums(jvm)  [create_bundle_string "ShowComponentStatusCliCommand.JvmCol"]
   set known_colums(component)  [create_bundle_string "ShowComponentStatusCliCommand.NameCol"]
   set known_colums(state)  [create_bundle_string "ShowComponentStatusCliCommand.StateCol"]
   set known_colums(type)  [create_bundle_string "ShowComponentStatusCliCommand.TypeCol"]
   
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
                  add_proc_error "parse_show_component_output" -1 "Found unknown column $col_name in output of \"sdmadm show_status\""
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
            if {[string length $tvalue] == 0} {
               set tvalue $last_values($col_name)
            } else {
               set last_values($col_name) $tvalue
            }
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
#      puts $CHECK_OUTPUT "pid file for jvm $jvm_name at $host not found"
#   } else {
#      puts $CHECK_OUTPUT "pid is $pid_info(pid)"
#      puts $CHECK_OUTPUT "url is $pid_info(url)"
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
   global CHECK_OUTPUT 
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
   
   global CHECK_OUTPUT 
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
