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

#****** config/verify_config() *************************************************
#  NAME
#     verify_config() -- verify testsuite configuration setup
#
#  SYNOPSIS
#     verify_config { config_array only_check parameter_error_list } 
#
#  FUNCTION
#     This procedure will verify or enter setup configuration
#
#  INPUTS
#     config_array         - array name with configuration (ts_config)
#     only_check           - if 1: don't ask user, just check
#     parameter_error_list - returned list with error information
#
#  RESULT
#     number of errors
#
#  SEE ALSO
#     check/verify_host_config()
#     check/verify_user_config()
#*******************************************************************************
proc verify_config { config_array only_check parameter_error_list } {
   global actual_ts_config_version
   upvar $config_array config
   upvar $parameter_error_list error_list

   return [verify_config2 config $only_check error_list $actual_ts_config_version]
}

proc verify_config2 { config_array only_check parameter_error_list expected_version } {
   global be_quiet

   upvar $config_array config
   upvar $parameter_error_list error_list

   set errors 0
   set error_list ""
   
   if { ! [ info exists config(version) ] } {
      puts "Could not find version info in configuration file"
      lappend error_list "no version info"
      incr errors 1
      return -1
   }

   if { $config(version) != $expected_version } {
      # CR: TODO implement update hook for additional checktrees 
      #          They are called when the version doesn't match
      #          The update hook may be implemented like in setup2 which is
      #          calling update_ts_config_version() till the version matches
      #          the setup_hooks_0_version specified in additional checktree.tcl file
      #          It seems to be the case that some checktrees (arco) already have
      #          a configuration update procedure. But this is not defined global.
      #          It has to be evaluated if this solution should be used in general!
      puts "Configuration file version \"$config(version)\" not supported."
      puts "Expected version is \"$expected_version\""
      lappend error_list "unexpected version"
      incr errors 1
      return -1      
   } else {
      ts_log_finest "Configuration Version: $config(version)"
   }

   set max_pos [get_configuration_element_count config]
   
   set uninitalized ""
   if { $be_quiet == 0 } { 
      ts_log_fine ""
   }

   for { set param 1 } { $param <= $max_pos } { incr param 1 } {
      set par [ get_configuration_element_name_on_pos config $param ]
      set status "ok"
      if { $be_quiet == 0 } { 
         puts -nonewline "   $config($par,desc) ..."
         ts_log_progress
      }
      if { $config($par) == "" } {
         set status "not initialized"
         lappend uninitalized $param
         if { $only_check != 0 } {
            lappend error_list ">$par< configuration not initalized"
            incr errors 1
         }
      } else {
         set procedure_name  $config($par,setup_func)
         set default_value   $config($par,default)
         set description     $config($par,desc)
         if { [string length $procedure_name] == 0 } {
             ts_log_finest "no procedure defined"
             set status "no check"
         } else {
            if { [info procs $procedure_name ] != $procedure_name } {
               ts_log_warning "unkown procedure name: \"$procedure_name\" !!!"
               lappend uninitalized $param
               set status "unknown check function"
               if { $only_check == 0 } { wait_for_enter }
            } else {
               # call procedure only_check == 1
               ts_log_finest "starting >$procedure_name< (verify mode) ..."
               set value [ $procedure_name 1 $par config ]
               if { $value == -1 } {
                  set status "failed"
                  incr errors 1
                  lappend error_list $par
                  lappend uninitalized $param
                  ts_log_warning "verify error in procedure \"$procedure_name\" !!!"
               } 
            }
         }
      }
      if { $be_quiet == 0 } { 
         ts_log_fine "\r   $config($par,desc) ... $status"
      }
   } 
   if { [set count [llength $uninitalized]] != 0 && $only_check == 0} {
      puts "$count parameters are not initialized!"
      ts_log_fine "Entering setup procedures ..."
      foreach pos $uninitalized {
         wait_for_enter
         clear_screen
         set p_name [get_configuration_element_name_on_pos config $pos]
         set procedure_name  $config($p_name,setup_func)
         set default_value   $config($p_name,default)
       
         ts_log_finest "Starting configuration procedure for parameter \"$p_name\" ($config($p_name,pos)) ..."
         set use_default 0
         if { [string length $procedure_name] == 0 } {
            puts "no procedure defined"
            set use_default 1
         } else {
            if { [info procs $procedure_name ] != $procedure_name } {
               ts_log_warning "unkown procedure name: \"$procedure_name\" !!!"
               if { $only_check == 0 } { wait_for_enter }
               set use_default 1
            }
         } 

         if { $use_default != 0 } {
            # we have no setup procedure
            if { $default_value != "" } {
               puts "using default value: \"$default_value\"" 
               set config($p_name) $default_value 
            } else {
               puts "No setup procedure and no default value found!!!"
               if { $only_check == 0 } {
                  puts -nonewline "Enter value for parameter \"$p_name\": "
                  set value [wait_for_enter 1]
                  puts "using value: \"$value\"" 
                  set config($p_name) $value
               } 
            }
         } else {
            # call setup procedure ...
            ts_log_finest "starting >$procedure_name< (setup mode) ..."
            set value [ $procedure_name 0 $p_name config ]
            if { $value != -1 } {
               puts "using value: \"$value\"" 
               set config($p_name) $value
            }
         }
         if { $config($p_name) == "" } {
            ts_log_warning "no value for \"$p_name\" !!!"
            incr errors 1
            lappend error_list $p_name
         }
      }
   }

   return $errors
}

#****** config/edit_setup() ****************************************************
#  NAME
#     edit_setup() -- edit testsuite/host/user configuration setup
#
#  SYNOPSIS
#     edit_setup { array_name verify_func mod_string } 
#
#  FUNCTION
#     This procedure is used to change the testsuite setup configuration
#
#  INPUTS
#     array_name  - ts_config, ts_host_config or ts_user_config array name
#     verify_func - procedure used for verify changes
#     mod_string  - name of string to report changes
#
#  SEE ALSO
#     check/verify_config()
#     check/verify_host_config()
#     check/verify_user_config()
#*******************************************************************************
proc edit_setup { array_name verify_func mod_string } {

   upvar $array_name org_config
   upvar $mod_string onchange_values

   set onchange_values ""
   set org_names [ array names org_config ]
   foreach name $org_names {
      ts_log_finest "config $name = $org_config($name)"
      set config($name) $org_config($name)
   }

   set no_changes 1
   while { 1 } {
      clear_screen
      puts "----------------------------------------------------------"
      puts "$config(version,desc)"
      puts "----------------------------------------------------------"

      set max_pos [get_configuration_element_count config]
      set index 1
      for { set param 1 } { $param <= $max_pos } { incr param 1 } {
         set par [ get_configuration_element_name_on_pos config $param ]
     
         set procedure_name  $config($par,setup_func)
         if { $procedure_name == "" } {
            continue
         }
          
         if { [info procs $procedure_name ] == $procedure_name } {
            set index_par_list($index) $par
   
            if { $index <= 9 } {
               puts "    $index) $config($par,desc)"
            } else {
               puts "   $index) $config($par,desc)"
            }
            incr index 1
         }
      }
      puts "\nEnter the number of the configuration parameter"
      puts -nonewline "you want to change or return to exit: "
      set input [ wait_for_enter 1]
   
      if { [ info exists index_par_list($input) ] } {
         set no_changes 0
         set back [$config($index_par_list($input),setup_func) 0 $index_par_list($input) config ]
         if { $back != -1 } {
            puts "setting $index_par_list($input) to:\n\"$back\"" 
            set config($index_par_list($input)) $back
            wait_for_enter
         } else {
            puts "setup error"
            wait_for_enter
         }
      } else {
         if { $input == "" } {
            break
         }
         puts "\"$input\" is not a valid number"
      }
   }

   if { $no_changes == 1 } {
      return -1
   }

   puts ""
   # modified values
   set no_changes 0
   set org_names [ array names org_config ]
   foreach name $org_names {
      if { [ info exists config($name) ] != 1 } {
         incr no_changes 1
         break
      }
      if { [ string compare $config($name) $org_config($name)] != 0 } {
         incr no_changes 1
         break
      }
   }
   # added values
   set new_names [ array names config ]      
   foreach name $new_names {
      if { [ info exists org_config($name)] != 1 } {
         incr no_changes 1
         break
      }
   }
   if { $no_changes == 0 } {
      return -1
   }

   puts "Verify new settings..."
   set verify_state "-1"
   lappend errors "edit_setup(): verify func not found"
   if { [info procs $verify_func ] == $verify_func } {
      set errors ""
      set verify_state [$verify_func config 1 errors ]
   }
   if { $verify_state == 0 } {
      puts ""
      # modified values
      set org_names [ array names org_config ]
      foreach name $org_names {
         if { [ info exists config($name) ] != 1 } {
            puts "removed $name:"
            puts "old value: \"$org_config($name)\""
            continue
         }
         if { [ string compare $config($name) $org_config($name)] != 0 } {
            puts "modified $name:"
            puts "old value: \"$org_config($name)\""
            puts "new value: \"$config($name)\"\n"
         }
      }
      # added values
      set new_names [ array names config ]      
      foreach name $new_names {
         if { [ info exists org_config($name)] != 1 } {
            puts "added $name:"
            puts "value: \"$config($name)\"\n"
         }
      }

      while {1} {
         puts -nonewline "Do you want to use your changes? (y/n) > "
         set input [ wait_for_enter 1 ]
         if { [string compare $input "n"] == 0 } {
            break
         }
         if { [ string compare $input "y" ] == 0 } {
            # save values (modified, deleted)
            set org_names [ array names org_config ]
            foreach name $org_names {
               if { [ info exists config($name) ] != 1 } {
                  unset org_config($name)
                  if { [ info exists config($name,onchange)] } {
                     append onchange_values $config($name,onchange)
                  }
                  continue
               }
               if { [ string compare $config($name) $org_config($name)] != 0 } {
                  set org_config($name) $config($name)
                  if { [ info exists config($name,onchange)] } {
                     append onchange_values $config($name,onchange)
                  }
               }
            }
            # save values (added)
            set new_names [ array names config ]
            foreach name $new_names {
               if { [ info exists org_config($name)] != 1 } {
                  set org_config($name) $config($name)
                  if { [ info exists config($name,onchange)] } {
                     append onchange_values $config($name,onchange)
                  }
               }
            }


            return 0
         }
      }
   } else {
      puts "Verify errros:"
      foreach elem $errors {
         puts "error in: $elem"
      }
      wait_for_enter
   }
   puts "resetting old values ..."
   $verify_func org_config 1 errors 
   return -1
}

#****** config/show_config() ***************************************************
#  NAME
#     show_config() -- show configuration settings
#
#  SYNOPSIS
#     show_config { conf_array {short 1} { output "not_set" } } 
#
#  FUNCTION
#     This procedure will print the current configuration settings for the
#     global configuration arrays: ts_config, ts_user_config or ts_host_config
#
#  INPUTS
#     conf_array - ts_config, ts_user_config or ts_host_config
#     {short 1}  - if 0: show long parameter names
#     {output "not_set"} - if set this string will contain the output
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc show_config { conf_array {short 1} { output "not_set" } } {

   set do_standard_output 1
   upvar $conf_array config
   if { $output != "not_set" } {
      upvar $output output_string
      set do_standard_output 0
   }

   set max_pos [get_configuration_element_count config]
   set max_par_length 0
   set max_description_length 0
   for { set param 1 } { $param <= $max_pos } { incr param 1 } {
      set par [ get_configuration_element_name_on_pos config $param ]
      set description     $config($par,desc)
      
      set par_length [string length $par]
      set description_length [string length $description]
      if { $max_par_length < $par_length } {
         set max_par_length $par_length
      }
      if { $max_description_length < $description_length} {
         set  max_description_length $description_length
      }
   }
   for { set param 1 } { $param <= $max_pos } { incr param 1 } {
      set par [ get_configuration_element_name_on_pos config $param ]
      set procedure_name  $config($par,setup_func)
      set default_value   $config($par,default)
      set description     $config($par,desc)
      set value           $config($par)
      if { $do_standard_output == 1 } {
         if { $short == 0 } {
            puts "$description:[get_spaces [expr ( $max_description_length - [ string length $description ] ) ]] \"$config($par)\""
         } else {
            puts "$par:[get_spaces [expr ( $max_par_length - [ string length $par ] ) ]] \"$config($par)\""
         }
      } else {
         if { $short == 0 } {
            append output_string "$description:[get_spaces [expr ( $max_description_length - [ string length $description ] ) ]] \"$config($par)\"\n"
         } else {
            append output_string "$par:[get_spaces [expr ( $max_par_length - [ string length $par ] ) ]] \"$config($par)\"\n"
         }
      }
   }
}

#****** config/modify_setup2() *************************************************
#  NAME
#     modify_setup2() -- modify testsuite setup files
#
#  SYNOPSIS
#     modify_setup2 { } 
#
#  FUNCTION
#     This procedure is called to let the user change testsuite settings
#
#  INPUTS
#
#  SEE ALSO
#     check/setup2()
#*******************************************************************************
proc modify_setup2 {} {
   global ts_checktree ts_config ts_host_config ts_user_config ts_db_config ts_fs_config
   global CHECK_ACT_LEVEL CHECK_PACKAGE_DIRECTORY check_name
   global CHECK_CUR_CONFIG_FILE CHECK_DEFAULTS_FILE

   lock_testsuite

   set old_exed $ts_config(execd_hosts)
   set old_master $ts_config(master_host)
   set old_root $ts_config(product_root)

   set change_level ""
   
   set check_name "setup"
   set CHECK_ACT_LEVEL "0"
   
   
   set setup_hook(1,name) "Testsuite configuration"
   set setup_hook(1,config_array) "ts_config"
   set setup_hook(1,verify_func)  "verify_config"
   set setup_hook(1,save_func)    "save_configuration"
   set setup_hook(1,filename)     "$CHECK_DEFAULTS_FILE"
   
   set setup_hook(2,name) "Host file configuration"
   set setup_hook(2,config_array) "ts_host_config"
   set setup_hook(2,verify_func)  "verify_host_config"
   set setup_hook(2,save_func)    "save_host_configuration"
   set setup_hook(2,filename)     "$ts_config(host_config_file)"
   
   set setup_hook(3,name) "User file configuration"
   set setup_hook(3,config_array) "ts_user_config"
   set setup_hook(3,verify_func)  "verify_user_config"
   set setup_hook(3,save_func)    "save_user_configuration"
   set setup_hook(3,filename)     "$ts_config(user_config_file)"

   set setup_hook(4,name) "Filesystem file config."
   set setup_hook(4,config_array) "ts_fs_config"
   set setup_hook(4,verify_func)  "verify_fs_config"
   set setup_hook(4,save_func)    "save_fs_configuration"
   set setup_hook(4,filename)     "$ts_config(fs_config_file)"
   
   if { [info exists ts_config(db_config_file)] && [ string compare $ts_config(db_config_file) "none" ] != 0 } {
   set setup_hook(5,name) "Database file configuration"
   set setup_hook(5,config_array) "ts_db_config"
   set setup_hook(5,verify_func)  "verify_db_config"
   set setup_hook(5,save_func)    "save_db_configuration"
   set setup_hook(5,filename)     "$ts_config(db_config_file)"

   set numSetups 5
   } else {
      set numSetups 4
   }

   for {set i 0} { $i < $ts_checktree(act_nr)} {incr i 1 } {
      for {set ii 0} {[info exists ts_checktree($i,setup_hooks_${ii}_name)]} {incr ii 1} {
         incr numSetups 1
         ts_log_fine "found setup hook $ts_checktree($i,setup_hooks_${ii}_name)"
         set setup_hook($numSetups,name)         $ts_checktree($i,setup_hooks_${ii}_name)
         set setup_hook($numSetups,config_array) $ts_checktree($i,setup_hooks_${ii}_config_array)
         global $setup_hook($numSetups,config_array)
         set setup_hook($numSetups,init_func)   $ts_checktree($i,setup_hooks_${ii}_init_func)
         set setup_hook($numSetups,verify_func)  $ts_checktree($i,setup_hooks_${ii}_verify_func)
         set setup_hook($numSetups,save_func)    $ts_checktree($i,setup_hooks_${ii}_save_func)
         set setup_hook($numSetups,init_func) $ts_checktree($i,setup_hooks_${ii}_init_func)

         if {[info exists ts_checktree($i,setup_hooks_${ii}_filename)]} {
            set setup_hook($numSetups,filename) $ts_checktree($i,setup_hooks_${ii}_filename)
         }
      }
   }
   

    while { 1 } {
      clear_screen
      puts "--------------------------------------------------------------------"
      puts "Modify testsuite configuration"
      puts "--------------------------------------------------------------------"
      
      for { set i 1 } { $i <= $numSetups } { incr i 1 } {
         puts [format "    (%d) %-27s (%ds) %s" $i $setup_hook($i,name) $i $setup_hook($i,name)]
      }   
         
      puts ""
      if { [string compare $ts_config(additional_config) "none" ] != 0 } {
         set numAddConfigs [llength $ts_config(additional_config)]
      } else { set numAddConfigs 0 }
      if { $numAddConfigs > 0 } { puts "    Additional configurations:" }
      for { set a 1 } { $a <= $numAddConfigs } { incr a 1 } {
         set key [expr ($numSetups + $a)]
         set addConfig($key,name) [file tail [lindex $ts_config(additional_config) [expr ($a -1)]]]
         set addConfig($key,fullName) [lindex $ts_config(additional_config) [expr ($a -1)]]
         puts [format "    (%d) %-27s (%ds) %s" $key $addConfig($key,name) $key $addConfig($key,name)]
      }
      puts ""
      puts -nonewline "Enter a number or press return to exit: "
      set input [ wait_for_enter 1]
      if { [string compare $input ""] == 0 } {
         break
      }
      set do_show 0
      if { [set pos [string first "s" $input ]] > 0 } {
         set do_show 1
         incr pos -1
         set input [string range $input 0 $pos]
      }
      if { $input > 0 && $input <= $numSetups && [info exists setup_hook($input,config_array)] } {
         if { [info exists setup_hook($input,filename)] } {
            set CHECK_CUR_CONFIG_FILE $setup_hook($input,filename)
         } else { set CHECK_CUR_CONFIG_FILE "" }
         if { $do_show == 0 } {
            set do_save [edit_setup $setup_hook($input,config_array) $setup_hook($input,verify_func) tmp_string]
            if { $do_save == 0 } {
               if { [info exists setup_hook($input,filename)] } {
                  $setup_hook($input,save_func) $setup_hook($input,filename) 
               } else {
                  $setup_hook($input,save_func)
               }
               append change_level $tmp_string
            }
            break
         } else {
            ts_log_fine "show_config $setup_hook($input,config_array)"
            show_config $setup_hook($input,config_array)
         }
      } else {
         if { $input > $numSetups && $input <= [expr ($numAddConfigs+$numSetups)]} {
            get_additional_config $addConfig($input,fullName) add_configuration
            set CHECK_CUR_CONFIG_FILE $addConfig($input,fullName)
            if { $do_show == 0 } {
               set do_save [edit_setup add_configuration $setup_hook(1,verify_func) tmp_string]
               if { $do_save == 0 } {
                  $setup_hook(1,save_func) $addConfig($input,fullName) add_configuration
               }
            break
         } else {
               puts "configuration for additional config file:\n$addConfig($input,fullName)"
               show_config add_configuration
         }
      }
      }
      wait_for_enter
   }


   # onchange:   "", "compile", "install", "stop"
   ts_log_finest "change_level: \"$change_level\""

   if { [string length $change_level] != 0 } { 
      puts "modification needs shutdown of old grid engine system"
      set new_exed $ts_config(execd_hosts)
      set new_master $ts_config(master_host)
      set new_root $ts_config(product_root)
      set ts_config(execd_hosts)  $old_exed
      set ts_config(master_host)  $old_master
      set ts_config(product_root) $old_root
      shutdown_core_system 0 1
      delete_tests $ts_config(checktree_root_dir)/install_core_system
      set ts_config(execd_hosts)  $new_exed
      set ts_config(master_host)  $new_master
      set ts_config(product_root) $new_root
   }

   if { [ string first "stop" $change_level ] >= 0 } {
      puts "modification needs restart of testsuite."
      exit 1
   }

   if { [ string first "compile" $change_level ] >= 0 } {
      if { $CHECK_PACKAGE_DIRECTORY != "none" } {
         puts "modification needs reinstallation of packages"
         prepare_packages ;# reinstall tar binaries
      } else { 
         puts "modification needs compilation of new grid engine system"
         compile_source
      }
   }
   unlock_testsuite
   return $change_level
}

#****** config/config_generic() ************************************************
#  NAME
#     config_generic() -- Get generic configuration values
#
#  SYNOPSIS
#     config_generic { only_check name config_array help_text check_type } 
#
#  FUNCTION
#     This procedure is used to get standard (generic) testsuite configuration
#     values for setting up the testsuite. It uses either user input configuration
#     mode, or selection from the list of values. The count of entered values can
#     be specified.
#
#  INPUTS
#     only_check   - If set no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#     help_text    - A description of the configuration value for the user
#     check_type   - The values data type requested from the user.
#                    Input types:
#                    "string":    request a string value
#                    "directory": request a directory path
#                    "directory+":request a directory path, create if doesn't exist
#                    "filename":  request a path to existing file
#                    "filename+": request a path to a file, if file doesn't exist,
#                                 it will allow the parent procedure to create 
#                                 a new file
#                    "user" :     request an existing user on localhost
#                    Selection types:
#                    "choice" :   request a value from the list $choice_list
#                                 the parameter choice_list is mandatory
#                    "host":      request a host from host config
#                    "port":      request a valid port number
#                    "database":  request a database from database config
#     { allow_null 1 }   - indicates if the null value is allowed
#                          1 : allows null values
#                                none : for string values
#                                   0 : for numeric values
#                          0 : doesn't allow null values
#     { count 1 }        - required number of entered values
#                        - see config_verify_count() for more information
#     { choice_list "" } - see config_choose_value() for more information
#                        - mandatory for "choice" check_type
#                        - optional for "host", "port", "database" check_types
#                          if not specified, the possibility to add a new value
#                          to the configuration is added
#                          procedures used to get value list by default:
#                             o "host"     - host_config_get_hostlist()
#                             o "port"     - user_config_get_portlist()
#                             o "database" - db_config_get_databaselist()
#                        - for other check_types no use
#     { add_params "" }  - array for additional parameters
#                          reserved parameters:
#                          - "port_type"    : see user_config_get_portlist()
#                                             for more information
#                                             useful for "port" check_type
#                          - "exclude_list" : the list of values to exclude
#                          - "patterns"     : list of string patterns which the
#                                             input values must match
#                                             useful for "string" check_type
#                                             (see string match for more information)
#                          - "verify"       : list of values for verification
#                                             valid values: compile, spooldir
#                                             for "host"
#                                             for other checks - no usage
#                          - screen_clear   : for multiple selection the screen is
#                                             automatically cleared
#                                             set it to 0 if not clear screen
#                                             (example: compile, java compile 
#                                              option in host configurtion)
#                         - selected        : set it to 1 if there is only one
#                                             possible value in the list
#                                             (example: master host)
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#     If no value entered, null value will be returned
#
#  SEE ALSO
#     config_host/host_config_get_hostlist()
#     config_host/host_config_add_newhost()
#     config_user/user_config_get_portlist()
#     config_user/user_config_add_newport()
#     config_database/db_config_get_databaselist()
#     config_database/db_config_add_newdatabase()
#     config/config_display_list()
#     config/config_choose_value()
#     config/config_verify_*()
#*******************************************************************************
proc config_generic { only_check name config_array help_text check_type 
                      {allow_null 1} {count 1} {choice_list ""} {add_params ""} } {
   global CHECK_USER ts_host_config ts_user_config ts_db_config fast_setup

   set allowed_check_types "host port database directory directory+ string filename filename+ choice user"
   if { [lsearch $allowed_check_types $check_type] < 0 } {
      puts "unexpected generic config type: $check_type"
      return -1
   }

   upvar $config_array config
   upvar $choice_list choices
   upvar $add_params params

   set screen_clear 0     ;# indicates if the screen should be cleared before displaying data (0 no, 1 yes)
   set null_value "none"  ;# null value
   set add_proc_name ""   ;# the name of procedure which adds a new value to the list
   set usage 0            ;# display usage (0 no, 1 yes)
   set value_type "value" ;# value type
   set display_method_name "config_display_list" ;# the name of method which display list of values

   switch -- $check_type {
      "host" {
         if { ![array exists choices] } {
            host_config_get_hostlist ts_host_config choices 0  ;# exclude unsupported hosts
         }
         set value_type "host"
         if { $only_check == 0 } {
            set screen_clear 1
            if { [info exists params(selected)] && $params(selected) == 1 } {
               # display value for information
            } else {
               set choices(usage) ""
               set choices(new) ""
               config_check_all_usages choices config host
               set add_proc_name host_config_add_newhost
               set display_method_name "config_display_hosts"
            }
         }
      }
      "port" {
         set port_type "all"
         set value_type "port"
         if { [info exists params(port_type)] } { set port_type $params(port_type) }
         if { ![array exists choices] } {
            user_config_get_portlist ts_user_config choices $port_type
         }
         set null_value 0
         if { $only_check == 0 } {
            set add_proc_name user_config_add_newport
            config_check_all_usages choices config port
            set choices(new) ""
            set screen_clear 1
         }
      }
      "database" {
         set value_type "database"
         if { ![info exists choices] } {
            db_config_get_databaselist ts_db_config choices
         }
         if { $only_check == 0 } {
            set add_proc_name db_config_add_newdatabase
            set choices(new) ""
            set screen_clear 1
         }
      }
      "choice" {
         if { [info exists params(screen_clear)] } {
            set screen_clear $params(screen_clear)
         } else {
            set screen_clear 1
         }
      }
   }

   if { [array exists choices] } {
      # add null value if not in list
      if { $allow_null && [lsearch [array names choices] $null_value] < 0 } {
         set choices($null_value) ""
      }
   }

   set actual_value $config($name)
   if { [info exists config($name,default)] && $config($name,default) != "" } {
      set default_value $config($name,default)
   } else {
      set default_value $null_value
   }

   if { [info exists config($name,desc)] } {
      set description $config($name,desc)
   } else {
      set description ""
   }

   set values $actual_value
   if { $values == "" } {
      set values $default_value
      }
  
   # request the user input values
   if { $only_check == 0 } {
      while {1} {
         if { $screen_clear == 1 } { clear_screen }
         if { $description != "" } {
            puts "----------------------------------------------------------"
            puts $description
            puts "----------------------------------------------------------"
         }
         foreach elem $help_text { puts $elem }
         if { [array exists choices] } {
            set old_values $values
            set output [ config_choose_value choices $null_value $count values $value_type $display_method_name $usage]
            # add a new value to the list
            if { $values == "new" } {
               puts -nonewline "Specify new $value_type which you want to add to the list: "
               set new_value [wait_for_enter 1]
               if { [string trim $new_value] != "" } {
                  $add_proc_name $new_value
               }
               # call again config_generic function
               return [config_generic $only_check $name config $help_text $check_type $allow_null $count "" params]
            }
            # show/hide usages
            if { $values == "usage" } {
               if { $usage == 0 } { set usage 1 } else { set usage 0 }
               set values $old_values
               continue
            }
            # selection finished
            if { $output == 0 || $screen_clear == 0 } {
               break
            }

         } else {
            puts "(default: $values)"
            puts -nonewline "> "
            set val [ wait_for_enter 1]
            if { $val == "" } {
               puts "using default value"
            } else {
               set values $val
            }
            break
         }
      }
   } 

   # input values verification
   if {!$fast_setup} {
      # verify count of values
      if { [config_verify_count $count [llength $values]] == -1 } { return -1 }
      # verify null value
      if { $allow_null } {
         if { $null_value == $values } {
            return $values
         }
      } else {
         if { $null_value == $values } {
            puts "$values value is not allowed."
            return -1
         }
      }
      # set the excluded values
      set exclude ""
      if { [info exists params(exclude_list)] } {
         set exclude $params(exclude_list)
      }
      # set the verification paramteres
      set verify_params ""
      if { [info exists params(verify)] } {
         set verify_params $params(verify)
      }

      foreach value $values {
         # excluded value not allowed
         if { [lsearch $exclude $value] >= 0 } {
            puts "Value $value not allowed."
            return -1
         }
         # only values from the list allowed
         if { [array exists choices] } {
            set items [array names choices]
            if { [ lsearch $items $value ] < 0 } {
               puts "value \"$value\" not found in list"
               return -1
            }
         }
         # check_type specific verification
      switch -- $check_type {
            "port" {
               if { [config_verify_port $value] == -1 } {
                  return -1
         }
            }
            "directory+" -
            "directory" {
               set create_new 0
               if { $check_type == "directory+" } {
                  set create_new 1
               }
               if { [config_verify_directory $value $create_new] == -1 } {
                  return -1
               }
            }
            "filename+" -
            "filename" {
               set allow_create_new 0
               if { $check_type == "filename+" } {
                  set allow_create_new 1
               }
               if { [config_verify_filename $value $allow_create_new] == -1 } {
                  return -1
               }
            }
         "host" {
               if { [info exists config(host_config_file)] } {
                  set host_config_file $config(host_config_file)
               } else {
                  set host_config_file ""
         }
               if { [config_verify_host $value $verify_params $host_config_file] == -1 } {
                  return -1
               }
            }
            "user" {
               if { [config_verify_user $value] == -1 } {
                  return -1
               }
            }
            "string" {
               set pattern ""
               if { [info exists params(patterns)] } {
                  set pattern $params(patterns)
               }
               if { [config_verify_string $value $pattern] == -1 } {
                  return -1
               }
            }
         }
      }
   }

   return $values
}

#****** config/config_choose_value() *******************************************
#  NAME
#     config_choose_value() -- Choose values from the list
#
#  SYNOPSIS
#     config_choose_value { choice_list {count 1} {sel_values ""} }
#
#  FUNCTION
#     This function is used to choose values from the list
#
#  INPUTS
#     choice_list - the array of values and its descriptions
#                 - if only one value is in the list, it's choosed automatically
#                   without user's input
#                 - \"new\" is reserved for adding a new value to the list
#                   it's useful for the lists which are generated from the
#                   testsuite configuration files
#                   host, port and database lists have this option by default,
#                   for other lists add it to the choice_list and specify the method
#                   to add a new choice to the list
#                 - \"usage\" is reserved for displaying the value usage in detail
#                   implemented only for hosts
#                 examples:
#                 array set choice_list1 {
#                    ssh   "secure shell without passwords"
#                    ssh_with_password "secure shell with passwords"
#                    rlogin  "rlogin"
#                 }  or
#                 array set choice_list2 { }
#                 set choice_list2(ssh) "secure shell without passwords"
#                 set choice_list2(ssh_with_password) "secure shell with passwords"
#                 set choice_list2(rlogin)  "rlogin"
#     null_value  - none for string values
#                   0 for numeric values
#     { count 1 }        - see config_verify_count() for more information
#     {sel_values ""}    - the variable which contains the list of selected values
#     {display_method_name config_display_list} - the name of the method which
#                          displays the list of values *
#  * this method must have the following interface:
#  { choice_list choice_index {selected ""} {null_value "none"} {disp_usage 0} }
#  see config_display_list(), config_display_hosts() for method examples
#
#  RESULT
#     -1 error occured while choosing the values
#      0 selection finished
#      1 continue
#
#  SEE ALSO
#      config/config_generic()
#      config/config_verify_count()
#      config/config_display_list()
#      config/config_display_hosts()
#*******************************************************************************
proc config_choose_value { choice_list null_value {count 1} {sel_values ""} 
                           {value_type value} {display_method_name config_display_list} {usage 0} } {

            upvar $choice_list choices
   upvar $sel_values selected

   # is there anything to display?
   if { [array size choices] == 0 } {
      puts "\nno value in list.\n"
      return 0
            }
   # display information of requested values
   if { $count != 1 && $count != 0 && $selected != $null_value } {
      puts "([config_verify_count $count])\n"
   } else {
      puts ""
               }   
   # assign the indexes to each value in the list
   if { [config_assign_indexes choices indexes $null_value] == -1 } {
      return -1
            }
   # display the list of values
   $display_method_name choices indexes $selected $null_value $usage
   # there is only one value in list, choose this value automatically
   if { [array size choices] == 1 && [lsearch [array names choices] "new"] < 0
        && [lsearch [array names choices] "usage"] < 0 } {
      set selected [lindex [array names choices] 0]
      puts ""
      return 0
   }

   puts "\nEnter"
   if { [lsearch [array names choices] "new"] >= 0 } {
      puts "  - \"new\" to add new $value_type to the list,"
   }
   if { [lsearch [array names choices] "usage"] >= 0 } {
      if { $usage == 1 } {
         puts "  - \"usage\" to hide detailed usage of ${value_type}s in configurations,"
      } else {
         puts "  - \"usage\" to display detailed usage of ${value_type}s in configurations,"
      }
   }
   if { $count != 1} {
      if { [lsearch [array names choices] "$null_value"] >= 0 } {
         puts "  - \"all\" to select all ${value_type}s in the list expect from \"$null_value\","
      } else {
         puts "  - \"all\" to select all ${value_type}s in the list,"
      }
      puts "  - \"$null_value\" to remove all ${value_type}s from the list,"
      puts "  - >RETURN< to exit, or"
      puts -nonewline "  - ${value_type}(s)/number(s) to mark/unmark the ${value_type}(s): "

   } else {
      puts "  - >RETURN< for selected item, or"
      puts -nonewline "  - ${value_type}/number: "
   }
   # request the output value from the user
   set output [ wait_for_enter 1 ]

   # user pressed enter to return, quit the selection
   if { $output == "" } {
      puts ""
      return 0
   }

   set output_value ""
   # convert the number to value, if value index was selected
   foreach val $output {
      if { [string is integer $val] && $val > 0 && $val <= [array size choices] } {
         lappend output_value $indexes($val)
      } else { lappend output_value $val }
      if { $count == 1 } { break }                   ;# we expect only one value
   }
   # if only one value expected and it's in the list, quit the selection
   if { $count == 1 } {
      if { [lsearch -exact [array names choices] $output_value] >= 0 } {
         set selected $output_value
      }
               return -1
            }
   # reset all previously set values and set it to null value, if null value choosed
   if { $output_value == $null_value } {
      set selected $output_value
      return 1
         }

   foreach val $output_value {
      # mark all values expect from reserved choices, if all selected
      if { $val == "all" } {
         set selected [array names choices]
         if { [set index [lsearch $selected "new"]] >= 0 } {
            set selected [lreplace $selected $index $index]
         }
         if { [set index [lsearch $selected "usage"]] >= 0 } {
            set selected [lreplace $selected $index $index]
         }
         break
      }
      # if new selected, quit the selection and add new value to the list
      if { $val == "new" && [lsearch -exact [array names choices] "new"] >= 0 } {
         set selected "new"
         return 0
      }
      # if usage selected, quit the selection and display usage
      if { $val == "usage" && [lsearch -exact [array names choices] "usage"] >= 0 } {
         set selected "usage"
         return 0
      }
      # set the value, or remove it if it was set
      if {[lsearch -exact $selected $val] < 0} {
         if { [lsearch -exact [array names choices] $val] >= 0 } {
            lappend selected $val
         }
            } else {
         set index [lsearch $selected $val]
         set selected [lreplace $selected $index $index]
            }
         }
   # remove none value if anything is set
   if { [llength $selected] > 1 && [lsearch $selected $null_value] >= 0 } {
      set index [lsearch $selected $null_value]
      set selected [lreplace $selected $index $index]
      }

   return 1
   } 

#****** config/config_assign_indexes() *****************************************
#  NAME
#     config_assign_indexes() -- Assign the ordinal numbers to values
#
#  SYNOPSIS
#     config_assign_indexes { choice_list {choice_index ""} {null_value "none"} }
#
#  FUNCTION
#     This function assigns the indexes to the values in the choice_list.
#     See config_list_order() for more information on list sorting.
#     $null_value will be displayed as the last one.
#
#  INPUTS
#     choice_list         - The array of values
#     {choice_index ""}   - the array of indexes and it's assigned values
#                         - if the array is empty, procedure will generate the
#                           list of indexes automatically, otherwise it will set
#                           the indexes only for not assigned values
#                         - $null_value will be displayed as the last one
#     {null_value "none"} - see config_choose_value() for more information
#
#  RESULT
#      1 error
#      0 ok
#
#  SEE ALSO
#      config/config_choose_value()
#      config/config_list_order()
#*******************************************************************************
proc config_assign_indexes { choice_list {choice_index ""} {null_value "none"} } {

   upvar $choice_list choices
   upvar $choice_index indexes

   if { ![array exists indexes] } {
      array set indexes {}
   }

   # list of assigned values
   set values ""
   foreach item [array names indexes] {
      lappend values "$indexes($item)"
   }

   # assign the ordinal numbers to values
   set not_assigned ""
   foreach item [array names choices] {
      # for case there is one of the ordinal numbers among the choices ...
      if { [string is integer $item] && $item > 0 && $item <= [array size choices] } {
         if { [lsearch -exact $values $item] >= 0 } {
            ts_log_severe "Not a unique list! Value $item must be assigned to index $item."
            wait_for_enter
               return -1
            }
         set indexes($item) "$item"
      } else {
         # skip the value which is already assigned, new and usages
         if { [lsearch -exact $values $item] >= 0 || $item == "new" || $item == "usage" } {
            continue
            }
         if { $item == $null_value } {
            # display null_value as the last one (ignore if index is occupied)
            set index [array size choices]
            if { [lsearch -exact [array names choices] "new"] >= 0 } { incr index -1 }
            if { [lsearch -exact [array names choices] "usage"] >= 0 } { incr index -1 }
            if { ![info exists indexes($index)] } {
               set indexes($index) "$item"
            } else {
               lappend not_assigned $item
            }
         } else {
            # the value is not assigned to any ordinal number
            lappend not_assigned $item
            }
      }
   }
   set index 1
   foreach item [lsort -command config_list_order -unique [array names choices]] {
      if { [lsearch $not_assigned $item] < 0 } { continue }
      while {1} {
         if { [info exists indexes($index)] } { incr index 1 } else { break }
      }
      set indexes($index) $item
   }

   return 0
}

#****** config/config_list_order() *********************************************
#  NAME
#     config_list_order() -- Comparison method
#
#  SYNOPSIS
#     config_list_order { a b }
#
#  FUNCTION
#     This function represents a comparison method for lists.
#     It sorts the values alphabetically by default, if the null_value is 0,
#     it uses integer comparison.
#
#  INPUTS
#     a, b - values to compare
#
#  SEE ALSO
#     tcl lsort built-in command
#*******************************************************************************
proc config_list_order { a b } {
   if { [string is integer $a] && [string is integer $b] } {
      if { $a < $b } { return -1 } else { return 1 }   
   } elseif {[string is integer $a] && ![string is integer $b]} { 
      return 1
   } elseif {![string is integer $a] && [string is integer $b]} {
                     return -1
                  }
   return [string compare $a $b]
}

#****** config/config_display_list() *******************************************
#  NAME
#     config_display_list() -- Display the list of values
#
#  SYNOPSIS
#     config_display_list { choice_list choice_index {selected ""} }
#
#  FUNCTION
#     This function is used to display values of the choice_list. The order
#     is given by indexes in choice_index.
#
#  INPUTS
#     choice_list         - the array of values to display
#     {choice_index ""}   - the array of indexes and it's assigned values
#                           see config_assign_indexes() for more information
#     {selected ""}       - the list of selected values
#                           use this variable to mark it in the list
#     {null_value "none"} - null value *
#     {disp_usage 0}    - 1 to display detail of host usages in configurations
#                         0 to hide it *
#     * these parameters are not used in this function, however it should have the
#       interface described in config_choose_value()
#
#  SEE ALSO
#      config/config_choose_value()
#      config_host/config_display_hosts()
#*******************************************************************************
proc config_display_list { choice_list choice_index 
                           {selected ""} {null_value "none"} {disp_usage 0} } {

   upvar $choice_list choices
   upvar $choice_index indexes

   set indent " "
   set max_length 0
   # get the maximum length of displayed values
   foreach item [array names choices] {
      if {[string length $item] > $max_length} {
         set max_length [string length $item]
      }
   }
   # display the list
   foreach index [lsort -integer [array names indexes]] {
      set item $indexes($index)
      if { $index <= 9 } { set ind " $index)" } else { set ind "$index)" }
      set sel " "
      if { [info exists selected] && [ lsearch $selected $item ] >= 0 } {
         set sel "*"                                   ;# mark the selected item
      }
      if { "$choices($item)" == "" } {
         puts "$indent $sel $ind $item"
               } else {
         set space "[get_spaces [expr ( $max_length - [string length $item] ) ]]"
         puts "$indent $sel $ind $item $space $choices($item)"
      }
   }

}

#****** config/config_verify_count() *******************************************
#  NAME
#     config_verify_count() -- Verify the count of input values
#
#  SYNOPSIS
#     config_verify_count { count_allowed count_values }
#
#  FUNCTION
#     This function verify the count of input values
#
#  INPUTS
#     count_allowed - allowed count of values
#                     examples: 0  ... unlimited count of values required
#                              !n  ... exactly n values required
#                               n  ... number of required values is limited to n
#                               n+ ... at least n values required
#                               1  ... one value required
#     { count_values "" } - count of input values
#                           if not specified, message with required count printed
#
#  RESULT
#     -1 the count of values doesn't match
#      0 ok
#      message with the expected count of values
#
#  SEE ALSO
#      config/config_generic()
#*******************************************************************************
proc config_verify_count { count_allowed { count_values "" } } {

   if { "[string range $count_allowed 0 0]" == "!" } {
      set len [string range $count_allowed 1 end]
      set msg "expected $len values"
      if { $count_values == "" } {
         return $msg
      }
      if { [string is integer $len] } {
         if { $count_values != $len } {
            puts "wrong number of entered values - $msg."
                     return -1
                  }
               }
   } elseif { [string last "+" "$count_allowed"] != -1 } {
      set last [string length $count_allowed]
      incr last -2
      set len [string range $count_allowed 0 $last]
      set msg "expected at least $len values"
      if { $count_values == "" } {
         return $msg
            }
      if { [string is integer $len] } {
         if { $count_values < $len } {
            puts "wrong number of entered values - $msg."
            return -1
         }
      }
   } else {
      if { [string is integer $count_allowed] } {
         set msg "$count_allowed is the maximum of expected values"
         if { $count_values == "" } {
            if { $count_allowed == 0 } { return "" } else { return $msg }
         }
         if { $count_values > $count_allowed && $count_allowed != 0 } {
            puts "wrong number of entered values - $msg."
               return -1
            }
      }
   }
   return 0
}
       
#****** config/config_verify_*() ***********************************************
#  NAME
#     config_verify_directory() -- Verify directory input
#     config_verify_filename() -- Verify filename input
#     config_verify_host() -- Verify host input
#     config_verify_port() -- Verify port input
#     config_verify_user() -- Verify if user exists on the system
#     config_verify_string() -- Verify string input
#
#  SYNOPSIS
#     config_verify_directory { value { create_new 0 } }
#     config_verify_filename { value { allow_create_new 0 } }
#     config_verify_host { value verify {host_config_file ""} }
#     config_verify_port { value }
#     config_verify_user { value }
#     config_verify_string { value { pattern "" } }
#
#  FUNCTION
#     These functions verify the input value
#
#  INPUTS
#     value - value which will be checked
#     verify - verification parameters
#     { create_new 0 } - 0 check only
#                        1 create directory if doesn't exist
#     { allow_create_new 0 } - 0 check only
#                              1 allow create filename if doesn't exist
#     { pattern "" } - string pattern
#
#  RESULT
#     -1 error
#      0 ok
#
#  SEE ALSO
#      config/config_generic()
#*******************************************************************************
proc config_verify_directory { value { create_new 0 } } {

   if { [ string first "/" $value ] != 0 } {
      puts "Path \"$value\" doesn't start with \"/\""
      return -1
   }
            if { [tail_directory_name $value] != $value } {
      puts "\nPath \"$value\" is not a valid directory name, try \"[tail_directory_name $value]\""
               return -1
            }
   if { $create_new == 1 && [ file isdirectory $value ] != 1 } { file mkdir $value }
            if { [ file isdirectory $value ] != 1 } {
      puts "Directory \"$value\" not found"
               return -1
            }
   return 0
         }

proc config_verify_filename { value { allow_create_new 0 } } {

            if {[file isfile $value] != 1} {
      if { $allow_create_new == 1 } {
         puts -nonewline "File doesn't exist. Create it? (y/n) "
         if { [ wait_for_enter 1 ] == "y" } {
            return 0
         } else { return -1 }
      }
               puts "no such file $value"
               return -1
            }
   return 0
         }

proc config_verify_host { value verify {host_config_file ""} } {

   if { [lsearch $verify "compile"] >= 0 } {
      if {[compile_check_compile_hosts $value] != 0} {
         puts "Press enter to edit global host configuration ..."
         wait_for_enter
         if { $host_config_file == "" } {
            global ts_config
            set host_config_file $ts_config(host_config_file)
         }
         setup_host_config $host_config_file hostlist
         if {[compile_check_compile_hosts $value] != 0} { return -1 }
         }
         }

   if { [lsearch $verify "spooldir"] >= 0 } {
      global ts_host_config
      if { ![file isfile $ts_host_config($value,spooldir)] } {
         puts "Spool directory must be specified for this host!"
               return -1
            }
         }

   return 0
         }

proc config_verify_port { value } {

   if { $value < 0  } {
      puts "Port \"$value\" is not >= 0"
            return -1
         }
   if { [string is integer $value] == 0 } {
      puts "Port \"$value\" is not a integer"
      return -1
      }
   if { $value > 65535 } {
      puts "Port \"$value\" is > 65535"
      return -1
   }
   return 0
}

proc config_verify_user { value } {
   global CHECK_USER

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts "Could not get local host name" 
      return -1
   }
   set result [start_remote_prog $local_host $CHECK_USER "id" "$value" prg_exit_state 60 0 "" "" 1 0]
   if { $prg_exit_state != 0 } {
      puts "id $value returns error. User $value not existing?"
      return -1
   }
   return 0
}

proc config_verify_string { value { patterns "" } } {

   if { $patterns == "" } {
      return 0
   }

   foreach pattern $patterns {
      if { ![string match $pattern $value] } {
         puts "Value $value doesn't match the pattern \"$pattern\"."
         return -1
      }
   }
   return 0
}

#****** config/config_check_all_usages() ***************************************
#  NAME
#     config_check_all_usages() -- get all usages in configuration
#
#  SYNOPSIS
#     config_check_all_usages { check_list config_array type }
#
#  FUNCTION
#     This function gets the usages in all defined configurations with the
#     current configuration. This include - main, hedeby, additional(s) configurations.
#     The usage can be either of ports, or hosts
#
#  INPUTS
#     check_list    - the array of all values in configuration
#     config_array  - current configuration array
#                     (main, hedeby, arco, additional(s) configurations)
#     type          - host or port
#
#  SEE ALSO
#      config/config_choose_value()
#      config/config_display_list()
#*******************************************************************************
proc config_check_all_usages { check_list config_array type } {
   global CHECK_CUR_CONFIG_FILE CHECK_DEFAULTS_FILE

   upvar $check_list checks
   upvar $config_array config
   set main_list ""
   set hedeby_list ""
   set arco_list ""

   switch -- $type {
      "host" {
         set main_list "source_cvs_hostname master_host shadowd_hosts execd_hosts 
                        submit_only_hosts bdb_server"
         set hedeby_list "hedeby_master_host hedeby_host_resources"
         set arco_list "dbwriter_host swc_host"
      }
      "port" {
         set main_list "commd_port jmx_port reserved_port"
         set hedeby_list "hedeby_cs_port hedeby_user_jvm_port"
         set arco_list ""
      }
      default { return }
   }

   # find all files
   set hedeby_config_file [ get_additional_config_file_path "hedeby" ]
   set arco_config_file [ get_additional_config_file_path "arco" ]
   array set filenames {
      testsuite ""
      arco ""
      hedeby ""
   }

   # append main config
   lappend filenames(testsuite) "$CHECK_DEFAULTS_FILE"
   # append additional configs
   read_array_from_file "$CHECK_DEFAULTS_FILE" "testsuite configuration" tmp_config
   foreach fl $tmp_config(additional_config) {
      if { $fl == "none" } { continue }
      if { [lsearch $filenames(testsuite) $fl] == -1 } {
         lappend filenames(testsuite) $fl
         # append additional config files of additional config
         if { [info exists add_tmp_config] } { unset add_tmp_config }
         read_array_from_file $fl "testsuite configuration" add_tmp_config
         foreach add_fl $add_tmp_config(additional_config) {
            if { $add_fl == "none" } { continue }
            if { [lsearch $filenames(testsuite) $add_fl] == -1 } {
               lappend filenames(testsuite) $add_fl
            }
         }
      }
   }
   # append arco and hedeby confirugations
   foreach fl $filenames(testsuite) {
      if { [info exists tmp_config] } { unset tmp_config }
      read_array_from_file "$fl" "testsuite configuration" tmp_config
      if { [string match "*hedeby*" $tmp_config(additional_checktree_dirs)] == 1 } {
         set add_tmp_file [ get_additional_config_file_path "hedeby" $fl]
         if { [lsearch $filenames(hedeby) $add_tmp_file] == -1 } { 
            lappend filenames(hedeby) $add_tmp_file
         }
      }
      if { [string match "*arco*" $tmp_config(additional_checktree_dirs)] == 1 } {
         set add_tmp_file [ get_additional_config_file_path "arco" $fl]
         if { [lsearch $filenames(arco) $add_tmp_file] == -1 } { 
            lappend filenames(arco) $add_tmp_file
         }
      }
   }

   # check the usages
   foreach project [array names filenames] {
      switch -exact $project {
         testsuite {
            set curr_list $main_list
            set config_name "testsuite configuration"
         }
         arco {
            set curr_list $arco_list
            set config_name "ARCo configuration"
         }
         hedeby {
            set curr_list $hedeby_list
            set config_name "Hedeby configuration"
         }
         default { continue }
      }
      foreach fl $filenames($project) {
         if { $fl == "$CHECK_CUR_CONFIG_FILE" } {
            config_check_usage checks $curr_list config $fl $config_name
         } else {
            config_check_usage checks $curr_list "" $fl $config_name
         }
      }
   }

}

#****** config/config_check_usage() ********************************************
#  NAME
#     config_check_usage() -- check the value usage in configuration
#
#  SYNOPSIS
#     config_check_usage { name check_list config_array {global_config_array ""} }
#
#  FUNCTION
#     This function checks the usage of value in the given configuration. First
#     it checks config_array, and if the parameter $name is not found, it searches
#     the corresponding global configuration.
#     examples of values: port, host
#     examples of configurations: main, hedeby, arco, additional(s))
#
#  INPUTS
#     check_list   - the searched list of values
#     check_params - searched configuration parameters
#     config_array - searched configuration array
#     config_file  - the file name of corresponding global configuration
#     config_name  - the name of corresponding global configuration
#
#  SEE ALSO
#      config/config_display_list()
#      config_host/config_display_hosts()
#*******************************************************************************
proc config_check_usage { check_list check_params config_array config_file config_name } {

   upvar $config_array config
   upvar $check_list checks

   if { [array exists config] == 0 } {
      read_array_from_file $config_file $config_name check_config
      if { [array exists check_config] == 0 } {
         ts_log_finest "Can't get usages from $config_file"
         return
      }
   } else { upvar 0 config check_config }

   set index [string last "/" $config_file]
   if { $index != -1 } {
      incr index 1
      set file_name_short [string range $config_file $index end]
   }

   foreach name $check_params {
      set value ""
      if { [info exists check_config($name)] } { set value $check_config($name) }
      # can be multiple value
      foreach val $value {
         if { [lsearch -exact [array names checks] $val] >= 0 
              && [string first "$file_name_short: $name" "$checks($val)"] == -1 } {
            append checks($val) "| $file_name_short: $name "
         }
      }
   }

}

#****** config/config_check_host_in_hostlist() *********************************
#  NAME
#     config_check_host_in_hostlist() -- ensure given hostname is first in list
#
#  SYNOPSIS
#     config_check_host_in_hostlist { hostlist {first_host ""}} 
#
#  FUNCTION
#     The function ensures, that $first_host is the first host in a given
#     host list. If first_host not set, [gethostname] must be at the first position.
#
#  INPUTS
#     hostlist - host list to verify
#     {first_host ""} - the name of the host which must be the first on the list
#
#  RESULT
#     a new host list, with $first_host as first element
#*******************************************************************************
proc config_check_host_in_hostlist {hostlist { first_host ""} } {

   if { $first_host == "" } {
      # make sure, [gethostname] is the first host in list
      set first_host [gethostname]
      if {$first_host == "unknown"} {
         puts "Could not get local host name" 
         return -1
      }
   }

   set index [lsearch $hostlist $first_host]
   if {$index >= 0} { set hostlist [lreplace $hostlist $index $index] }
   set hostlist [linsert $hostlist 0 $first_host]

   return $hostlist
}

#****** config/config_testsuite_root_dir() *************************************
#  NAME
#     config_testsuite_root_dir() -- testsuite root directory setup
#
#  SYNOPSIS
#     config_testsuite_root_dir { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_root_dir { only_check name config_array } {
   global CHECK_USER
   global CHECK_GROUP
   global env fast_setup

   upvar $config_array config
   
   set help_text { "Enter the full pathname of the testsuite root directory,"
                   "or press >RETURN< to use the default value."
                   "If you want to test with root permissions (which is neccessary"
                   "for a full testing) the root user must have read permissions"
                   "for this directory." }

   set value [config_generic $only_check "$name" config $help_text "directory" 0]

   if { $value == -1 } { return -1 }

   if { ! $fast_setup } {
      if { [ file isfile $value/check.exp ] != 1 } {
         puts "File \"$value/check.exp\" not found"
         return -1
      }
   }

   # set global variables to value

   if {[catch {set CHECK_USER [set env(USER)] }] != 0} {
      set CHECK_USER [file attributes $value/check.exp -owner]
      puts "\nNo USER is set!\n(default: $CHECK_USER)\n"
      set env(USER) $CHECK_USER
   } 

   # if USER env. variable is empty
   if { $CHECK_USER == "" } {
      set CHECK_USER [file attributes $value/check.exp -owner]
      puts "\nNo USER is set!\n(default: $CHECK_USER)\n"
      set env(USER) $CHECK_USER
   }

   if {[catch {set CHECK_GROUP [set env(GROUP)] }] != 0} {
      set CHECK_GROUP [file attributes $value/check.exp -group]
      puts "\nNo GROUP is set!\n(default: $CHECK_GROUP)\n"
      set env(GROUP) $CHECK_GROUP
   }

   return $value
}

#****** config/config_checktree_root_dir() *************************************
#  NAME
#     config_checktree_root_dir() -- checktree root setup
#
#  SYNOPSIS
#     config_checktree_root_dir { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_checktree_root_dir { only_check name config_array } {

   upvar $config_array config
   
   set help_text { "Enter the full pathname of the testsuite checktree directory,"
                   "or press >RETURN< to use the default value."
                   "The checktree directory contains all tests in its subdirectory"
                   "structure." }

   if { $config($name,default) == "" } {
      set config($name,default) "$config(testsuite_root_dir)/checktree"
      }

   return [config_generic $only_check "$name" config $help_text "directory" 0]

      }

#****** config/config_additional_checktree_dirs() ******************************
#  NAME
#     config_additional_checktree_dirs() -- additional checktree root setup
#
#  SYNOPSIS
#     config_additional_checktree_dirs { only_check name config_array } 
#
#  FUNCTION
#     Testsuite additional configuration(s) setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_additional_checktree_dirs { only_check name config_array } {

   upvar $config_array config
   
   set help_text { "Choose the path to the additional checktree directory."
                   "The checktree directory contains all tests in its subdirectory"
                   "structure."
                   "Enter \"none\" for no additional checktree." }

   # aja: TODO: add the possibility to add new checktree directory to the list
   #            for storing these path ~/.testsuite private file could be used

#   set arco "$config(testsuite_root_dir)/checktree_arco"
#   set hedeby "$config(testsuite_root_dir)/checktree_hedeby"
#   array set dirs { }
#   set dirs($arco) ""
#   set dirs($hedeby) ""

#   set value [config_generic $only_check "$name" config $help_text "choice" 1 0 dirs]
   set value [config_generic $only_check "$name" config $help_text "directory" 1 0]

   if { $value == -1 } { return -1 }

   set dep_par db_config_file
   if { [string match "*checktree_arco" $value] == 1 && "$config($dep_par)" == "none" } {
      puts ""
      set ret [ $config($dep_par,setup_func) $only_check $dep_par config ]
      if { $ret != -1 } {
         set config($dep_par) $ret
         ts_log_fine "setting $dep_par to $ret"
         puts ""
      } else { return -1 }
   }

   if { [string match "*checktree_hedeby" $value] == 1 } {
      if { "$config(additional_config)" == "none" } {
         puts ""
         set ret [ $config(additional_config,setup_func) $only_check additional_config config ]
         if { $ret != -1 } {
            set config(additional_config) $ret
            ts_log_fine "setting additional_config to $ret"
            puts ""
         } else { return -1 }
         # if hedeby is set, be sure that the cluster will compile on additional config parameter change
         set config(additional_config,onchange)   "compile"
         }
      if { "$config(jmx_ssl)" == "false" } {
         puts "Need enabled jmx_ssl option for GE installation for Hedeby!"
         wait_for_enter
         set config(jmx_ssl) "true"
         ts_log_fine "setting jmx_ssl to $config(jmx_ssl)"
         puts ""
            }
      } else {
      # if hedeby is not set, there is no need to compile on additional config parameter change
      set config(additional_config,onchange)   ""
      }

   return $value
}

proc config_additional_config { only_check name config_array } {
   global fast_setup
   global CHECK_CUR_CONFIG_FILE

   upvar $config_array config
   
   set allow_null 1
   set hedeby_is_set 0
   set config($name,onchange)   ""
   if { $config(additional_checktree_dirs) != "none" } {
      foreach dir $config(additional_checktree_dirs) {
         if { [string match "*checktree_hedeby" $dir] == 1 } {
            set allow_null 0
            set hedeby_is_set 1
            set config($name,onchange)   "compile"
            break
      }
   }
      }

   set help_text { "Enter the full pathname(s) of additional testsuite configuration(s)"
                   "used for installing a secondary Grid Engine cluster(s)."
                   "Multiple values separate by space."
                   "All configurations must use the same testsuite root directory,"
                   "and both global user and host configuration files."
                   "The result directories of configurations must be different."
                   "Hedeby requires at least one cell cluster, and one independent cluster"
                   "configuration." }
   if { $allow_null } { lappend help_text "Enter \"none\" for no additional configuration." }

   set add_param(exclude_list) "$CHECK_CUR_CONFIG_FILE"
   set value [config_generic $only_check "$name" config $help_text "filename" $allow_null 0 "" add_param]

   if { $value == -1 || "$value" == "none" } { return $value }

   # now verify
   if {!$fast_setup} {
      # this is a verification for hedeby. Once we use additional configurations
      # also for another purposes than for hedeby testsuite setup, this should be changed.

         foreach filename $value {

            if { $only_check == 0 } {
            ts_log_fine "checking configuration:\n\"$filename\""
            }

            # clear previously read config
            if {[info exists add_config]} {
               unset add_config
            }
            # read additional config file
            if {[read_array_from_file $filename "testsuite configuration" add_config] != 0} {
            puts "cannot read configuration file \"$filename\""
               return -1
            }
         # check if the required parameters are same for additional configuration
         foreach param "host_config_file user_config_file testsuite_root_dir" {
            if { $add_config($param) != $config($param) } {
               puts "Parameter $param must be same for additional configuration $filename."
               return -1
            }
         }
         if { $hedeby_is_set == 1 } {
            # jmx_ssl must be enabled
            if { $add_config(jmx_ssl) == "false" } {
               puts "Additional configuration $filename: SSL server authentication for qmaster JMX mbean server must be enabled."
               return -1
            }

            #  cell or independed cluster support?
            #  o if cluster have the same cvs source directory AND the same SGE_ROOT the
            #    compilation is done in the main cluster (ts with additional config)
            #
            #  o if SGE_ROOT is different the cvs source has also to be different
            #    (complete independed additional cluster config). Then the compilation
            #    is done via operate_additional_clusters call. This means
            #    gridengine version, and cvs release may be different

            set allow_master_as_execd 1
            if { $add_config(product_root) == $config(product_root) && 
                 $add_config(source_dir)   == $config(source_dir) } {
               if { $only_check == 0 } {
                  puts -nonewline "   (cell cluster) ..."
               }
               # now make sure that the additional configurations can work together
               # the following parameters have to be the same for all configs
               set same_params "gridengine_version source_dir source_cvs_release product_root product_feature aimk_compile_options dist_install_options qmaster_install_options execd_install_options package_directory package_type"
               # the following parameters have to differ between all configs
               # TODO (Issue #139): remove master_host and execd_hosts from this list if issue #139 is fixed
               set diff_params "results_dir commd_port cell master_host execd_hosts"

               # TODO (Issue #139): also remove this allow_master_as_execd check if issue #139 is fixed
               # since testsuite has problems with shutdown different cell clusters (because of same SGE_ROOT directory)
               # we also don't allow the qmaster host be an exed host in an additional cluster
               set allow_master_as_execd 0
            } else {
               if { $only_check == 0 } {
                  puts -nonewline "   (independent cluster) ..."
               }
               # now make sure that the additional configurations can work together
               # the following parameters have to be the same for all configs
               set same_params ""
               # the following parameters have to differ between all configs
               set diff_params "results_dir commd_port product_root"
            }

            # clear previously joined_config
            if { [info exists joined_config ] } {
               unset joined_config
            }

            # create joined_config
            foreach param "$same_params $diff_params" {
               set helpval {}
               lappend helpval $config($param) 
               set joined_config($param) $helpval
            }

            # add the params to be checked to our joined config
            foreach param "$same_params $diff_params" {
               set helpval {}
               lappend helpval $add_config($param)
               lappend joined_config($param) $helpval
            }

            # now we check for equality or difference
            foreach param $same_params {
               if {[llength [lsort -unique $joined_config($param)]] != 1} {
                  puts "\nThe parameter \"$param\" has to be the same for configuration\n\"$filename\","
                  puts "but has the following values:\n$joined_config($param)"
                  return -1
               }
            }
            foreach param $diff_params {
               if {[llength [lsort -unique $joined_config($param)]] != 2} {
                  puts "\nThe parameter \"$param\" (=\"$config($param)\") has to be different for configuration\n\"$filename\","
                  puts "but has the following values:\n$joined_config($param)"
                  return -1
               }
               # now if param is a list check content
               if {[llength $add_config($param)] > 1 || [llength $config($param)] > 1} {
                  foreach val $add_config($param) {
                     if { [string first $val $config($param)] >= 0 } {
                        puts "\nFound value \"$val\" of configuration\n\"$filename\"\nin configuration for parameter \"$param\" in testsuite config"
                        return -1
                     }
                  }
               }
            }

            if {$allow_master_as_execd == 0} {
               # since testsuite has problems with shutdown different cell clusters (because of same SGE_ROOT directory)
               # we also don't allow the qmaster host be an exed host in an additional cluster
               if { [string first $config(master_host) $add_config(execd_hosts) ] >= 0 } {
                  puts "\nThe master host ($config(master_host)) of the testsuite configuration"
                  puts "is not a supported cell execd host for config \"$filename\""
                  return -1
               }
            }

            if { $only_check == 0 } {
               puts "ok"
            }
         }
      }
   }

   return $value
}

#****** config/config_results_dir() ********************************************
#  NAME
#     config_results_dir() -- results directory setup
#
#  SYNOPSIS
#     config_results_dir { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_results_dir { only_check name config_array } {
   global CHECK_TESTSUITE_LOCKFILE
   global CHECK_MAIN_RESULTS_DIR
   global CHECK_PROTOCOL_DIR
   global CHECK_JOB_OUTPUT_DIR
   global CHECK_RESULT_DIR 
   global CHECK_BAD_RESULT_DIR 
   global CHECK_REPORT_FILE 
   global fast_setup

   upvar $config_array config

   if { $config($name,default) == "" } {
      set config($name,default) $config(testsuite_root_dir)/results
   }

   set help_text { "Enter the full pathname of the testsuite results directory, or"
                   "press >RETURN< to use the default value."
                   "The testsuite will use this directory to save test results and"
                   "internal data." }

   set value [config_generic $only_check $name config $help_text "directory+" 0]

   if { $value == -1 } { return -1 }

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts "Could not get local host name" 
         return -1
      }

   # set global values
   set CHECK_MAIN_RESULTS_DIR $value
   set CHECK_PROTOCOL_DIR $CHECK_MAIN_RESULTS_DIR/protocols
   set CHECK_JOB_OUTPUT_DIR "$CHECK_MAIN_RESULTS_DIR/testsuite_job_outputs"

   set CHECK_RESULT_DIR "$CHECK_MAIN_RESULTS_DIR/$local_host.completed"
   set CHECK_BAD_RESULT_DIR "$CHECK_MAIN_RESULTS_DIR/$local_host.uncompleted"
   set CHECK_REPORT_FILE "$CHECK_MAIN_RESULTS_DIR/$local_host.report"
   set CHECK_TESTSUITE_LOCKFILE "$value/testsuite_lockfile"
 
   if {[file isdirectory "$CHECK_RESULT_DIR"] != 1} {
        file mkdir "$CHECK_RESULT_DIR"
   }
   if {[file isdirectory "$CHECK_BAD_RESULT_DIR"] != 1} {
        file mkdir "$CHECK_BAD_RESULT_DIR"
   }
   if {[file isdirectory "$CHECK_JOB_OUTPUT_DIR"] != 1} {
        file mkdir "$CHECK_JOB_OUTPUT_DIR"
   }
   return $value
}

#****** config/config_connection_type() ****************************************
#  NAME
#     config_connection_type() -- configurate the remote connect starter
#
#  SYNOPSIS
#     config_connection_type { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_connection_type {only_check name config_array} {
   global CHECK_USER
   global fast_setup
   global have_ssh_access_state

   upvar $config_array config

   array set conn_types {
      ssh   "secure shell without passwords"
      ssh_with_password "secure shell with passwords"
      rlogin  "rlogin"
   }

   set help_text { "Choose the client which you want to use for connecting"
                   "to the cluster hosts:" }
   set value [config_generic $only_check $name config $help_text "choice" 0 1 conn_types]

   if { $value == -1 } { return -1 }

   if {$only_check == 0} {
      # reset global variable for have_ssh_access() procedure !!
      set have_ssh_access_state -1 
   }

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts "Could not get local host name" 
      return -1
   }

   if {!$fast_setup} {
      # test the new connection type 
      set old_value $config($name)
      set config($name) $value
      set result [start_remote_prog $local_host $CHECK_USER "echo" "\"hello $local_host\"" prg_exit_state 60 0 "" "" 1 0]
      if { $prg_exit_state != 0 } {
         puts "$value to host $local_host doesn't work correctly"
         set config($name) $old_value
         return -1
      }
      if { [ string first "hello $local_host" $result ] < 0 } {
         puts "$result"
         puts "echo \"hello $local_host\" doesn't work"
         set config($name) $old_value
         return -1
      }
   }

   return $value
}


#****** config/config_source_dir() *********************************************
#  NAME
#     config_source_dir() -- source directory setup
#
#  SYNOPSIS
#     config_source_dir { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_source_dir { only_check name config_array } {
   global fast_setup

   upvar $config_array config

   set help_text { "Enter the full pathname of the Grid Engine source directory, or"
                   "press >RETURN< to use the default value."
                   "The testsuite needs this directory to call aimk (to compile source code)"
                   "and for resolving the host names (util scripts)." }
 
   if { $config($name,default) == "" } {
      set pos [string first "/testsuite" $config(testsuite_root_dir)]
      set config($name,default) "[string range $config(testsuite_root_dir) 0 $pos]source"
      }
   set old_value $config($name)

   set value [config_generic $only_check $name config $help_text "directory" 0]

   if { $value == -1 } { return -1 }

   if {!$fast_setup} {
      if { [ file isfile $value/aimk ] != 1 } {
         puts "File \"$value/aimk\" not found"
         return -1
      }
   }
 
   set local_arch [ resolve_arch "none" 1 $value]
   if { $local_arch == "unknown" } {
      puts "Could not resolve local system architecture" 
      return -1
   }

   if { $old_value != $value } {
      set config(source_dir) $value
      # in case the source_cvs_release parameter was already set before (this is not a new configuration),
      # change the source_cvs_release parameter according to the new source_dir
      if { $config(source_cvs_release) != "" } {
         set config(source_cvs_release) [$config(source_cvs_release,setup_func) $only_check source_cvs_release config]
      }
   }

   return $value
}

#****** config/config_source_cvs_hostname() ************************************
#  NAME
#     config_source_cvs_hostname() -- cvs hostname setup
#
#  SYNOPSIS
#     config_source_cvs_hostname { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_source_cvs_hostname { only_check name config_array } {
   global CHECK_USER fast_setup

   upvar $config_array config

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts "Could not get local host name" 
      return -1
   }

   if { $config($name,default) == "" } {
      set config($name,default) $local_host
      }

   set value [config_generic $only_check $name config "" "host" 0]

   if { $value == -1 } { return -1 }

   if {!$fast_setup} {
      set result [start_remote_prog $value $CHECK_USER "$config(testsuite_root_dir)/scripts/mywhich.sh" "cvs" prg_exit_state 60 0 "" "" 1 0]
      if { $prg_exit_state != 0 } {
         ts_log_finest $result
         puts "cvs not found on host $host. Enhance your PATH envirnoment"
         return -1
      } else {
         ts_log_finest $result
         ts_log_finest "found cvs command"
      }
   }
   return $value
}

#****** config/config_source_cvs_release() *************************************
#  NAME
#     config_source_cvs_release() -- cvs release setup
#
#  SYNOPSIS
#     config_source_cvs_release { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_source_cvs_release {only_check name config_array} {
   global CHECK_USER 

   upvar $config_array config

   # fix "maintrunc" typo - it will be written the next time the config is modified
   if {$config($name) == "maintrunc"} { set config($name) "maintrunk" }

   array set tags {}
   
   if {[file isdirectory $config(source_dir)]} {
      set cvs_tag [start_remote_prog $config(source_cvs_hostname) $CHECK_USER "cat" "$config(source_dir)/CVS/Tag" prg_exit_state 60 0 "" "" 1 0]
      set cvs_tag [string trim $cvs_tag]
      set tag "maintrunk"
         if {$prg_exit_state == 0} {
            if {[string first "T" $cvs_tag] == 0 || [string first "N" $cvs_tag] == 0} {
               set tag [string range $cvs_tag 1 end]
            }
         }
      set config($name,default) $tag
      set tags($tag) ""
      }

   set help_text { "Enter cvs release tag (\"maintrunk\" specifies no tag)"
                   "or press >RETURN< to use the default value." }

   set value [config_generic $only_check $name config $help_text "choice" 0 1 tags]

   if {![file isdirectory $config(source_dir)]} { puts "source directory $config(source_dir) doesn't exist!!!" }

   return $value
}

#****** config/config_host_config_file() ***************************************
#  NAME
#     config_host_config_file() -- host config file setup
#
#  SYNOPSIS
#     config_host_config_file { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_host_config_file { only_check name config_array } {

   upvar $config_array config
   
   set help_text { "Enter the full pathname of the host configuration file,"
                   "or press >RETURN< to use the default value."
                   "The host configuration file is used to define the cluster"
                   "hosts setup configuration needed by the testsuite." }
   
   while {1} {
      set value [config_generic $only_check $name config $help_text "filename+" 0]

      if { $value != -1 } {
            setup_host_config $value
         break
      } elseif { $only_check } { break }
      clear_screen
         }
   return $value
}

#****** config/config_user_config_file() ***************************************
#  NAME
#     config_user_config_file() -- user configuration file setup
#
#  SYNOPSIS
#     config_user_config_file { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_user_config_file { only_check name config_array } {

   upvar $config_array config
   
   set help_text { "Enter the full pathname of the user configuration file,"
                   "or press >RETURN< to use the default value."
                   "The user configuration file is used to define the cluster"
                   "user needed by the testsuite." }
   
   while {1} {
      set value [config_generic $only_check $name config $help_text "filename+" 0]

      if { $value != -1 } {
            setup_user_config $value
         break
      } elseif { $only_check } { break }
      clear_screen
         }
   return $value
}

#****** config/config_fs_config_file() ***************************************
#  NAME
#     config_fs_config_file() -- filesystem configuration file setup
#
#  SYNOPSIS
#     config_fs_config_file { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_fs_config_file { only_check name config_array } {

   upvar $config_array config
   
   set help_text { "Enter the full pathname of the filesystem configuration file,"
                   "or press >RETURN< to use the default value."
                   "The filesystem configuration file is used to provide"
                   "different types of filesystems needed by the testsuite."
                   "eg. nfs4 mounted fs or root2nobody mounted fs" }
   
   while {1} {
      set value [config_generic $only_check $name config $help_text "filename+" 0]

      if { $value != -1 } {
         setup_fs_config $value
         break
      } elseif { $only_check } {
         break 
      }
      clear_screen
   }
   return $value
}

#****** config/config_db_config_file() *****************************************
#  NAME
#     config_db_config_file() -- database configuration file setup
#
#  SYNOPSIS
#     config_db_config_file { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_db_config_file { only_check name config_array } {
   global fast_setup

   upvar $config_array config
   
   set allow_null 1                       ;# path to config database is optional
         if { $config(additional_checktree_dirs) != "none" } {
            foreach dir $config(additional_checktree_dirs) {
               if { [string match "*checktree_arco" $dir] == 1 } {
            set allow_null 0             ;# path to config database is mandatory
               }
            }
         }

   set help_text { "Enter the full pathname of the database configuration file."
                   "The database configuration file is used to define the cluster"
                   "database needed for the ARCo testsuite, therefore this parameter"
                   "is mandatory for ARCo tests." }
   if { $allow_null == 1 } { lappend help_text "Enter \"none\" for no database configuration file." }

   set value [config_generic $only_check $name config $help_text "filename+" $allow_null]

   if { !$allow_null && $value == "none" } { return -1 }

   if { $value != "none" && $value != -1 } {
            setup_db_config $value
         }

   return $value
}

#****** config/config_master_host() ********************************************
#  NAME
#     config_master_host() -- master host setup
#
#  SYNOPSIS
#     config_master_host { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_master_host { only_check name config_array } {
   global do_nomain fast_setup
   global CHECK_CUR_CONFIG_FILE CHECK_DEFAULTS_FILE

   upvar $config_array config

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts "Could not get local host name" 
      return -1
   }

   if { $config($name,default) == "" } {
      set config($name,default) $local_host
      }
   set old_value $config($name)

   array set params { verify compile }

   set value [config_generic $only_check $name config "" "host" 0 1 "" params]

   if { $value != $old_value } {
      # qmaster host must be first in the shadowd and execd hostlist
      set config(execd_hosts) [config_check_host_in_hostlist $config(execd_hosts) $value]
      set config(shadowd_hosts) [config_check_host_in_hostlist $config(shadowd_hosts) $value]
      return $value
   }

}

#****** config/config_execd_hosts() ********************************************
#  NAME
#     config_execd_hosts() -- execd daemon host setup
#
#  SYNOPSIS
#     config_execd_hosts { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_execd_hosts { only_check name config_array } {
   global ts_host_config fast_setup

   upvar $config_array config

   set master_host $config(master_host)

   if { $config($name,default) == "" } {
      set config($name,default) $master_host
   }

   array set params { verify "compile" }

   set value [config_generic $only_check $name config "" "host" 0 "2+" "" params]

   if { $value == -1 } { return -1 }

   # put the master_host at the first place in the list
   set value [config_check_host_in_hostlist $value $master_host]

   # set host lists
   # we need a mapping from node to physical hosts
   foreach host $ts_host_config(hostlist) {
      node_set_host $host $host
      set nodes [host_conf_get_nodes $host]
      foreach node $nodes {
         node_set_host $node $host
      }
   }

   # create list of all (execd) nodes
   set config(all_nodes) [host_conf_get_all_nodes $value]
   set config(execd_nodes) [host_conf_get_nodes $value]

   # create a list of unique nodes (one node per physical host)
   set config(unique_execd_nodes) [host_conf_get_unique_nodes $value]

   # create a list of nodes unique per architecture
   set config(unique_arch_nodes) [host_conf_get_unique_arch_nodes $config(unique_execd_nodes)]

   # now sort these lists for convenience
   set config(all_nodes) [lsort -dictionary $config(all_nodes)]
   set config(execd_nodes) [lsort -dictionary $config(execd_nodes)]
   set config(unique_execd_nodes) [lsort -dictionary $config(unique_execd_nodes)]
   set config(unique_arch_nodes) [lsort -dictionary $config(unique_arch_nodes)]

   return $value
}

#****** config/config_submit_only_hosts() **************************************
#  NAME
#     config_submit_only_hosts() -- submit only hosts setup
#
#  SYNOPSIS
#     config_submit_only_hosts { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_submit_only_hosts { only_check name config_array } {
   global ts_host_config fast_setup

   upvar $config_array config

   array set params {}
   set params(verify) "compile"
   set params(exclude_list) [lsort -unique "$config(master_host) $config(shadowd_hosts) $config(execd_hosts)"]

   return [config_generic $only_check $name config "" "host" 1 0 "" params]
      }

#****** config/config_commd_port() *********************************************
#  NAME
#     config_commd_port() -- commd port option setup
#
#  SYNOPSIS
#     config_commd_port { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_commd_port { only_check name config_array } {
   global CHECK_COMMD_PORT

   upvar $config_array config
   
   set help_text {
      "Enter the port number value the testsuite should use for COMMD_PORT,"
      "or press >RETURN< to use the default value."
      ""
      "(IMPORTANT NOTE: COMMD_PORT must be a even number, because for"
      "SGE/EE 6.0 sytems or later COMMD_PORT is used for SGE_QMASTER_PORT and"
      "COMMD_PORT + 1 is used for SGE_EXECD_PORT)"
   }   

   array set params { port_type even }
   if { [info exists config(jmx_port)] } { 
      set params(exclude_list) $config(jmx_port)
   }

   set value [config_generic $only_check $name config $help_text "port" 0 1 "" params]
   
   if { $value < 1024 } {
      puts "Need COMMD_PORT value >= 1024"
      return -1
   }

   if { $value != -1 } {
      set CHECK_COMMD_PORT $value
   }
}

#****** config/config_jmx_port() ***********************************************
#  NAME
#     config_jmx_port() -- jmx port option setup
#
#  SYNOPSIS
#     config_jmx_port { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_jmx_port { only_check name config_array } {

   upvar $config_array config
   
   set help_text {
      "Enter the port number for qmaster JMX mbean server"
      "or press >RETURN< to use the default value."
      "Value 0 means that the mbean server is not started."
   }   

   array set params { }
   if { [info exists config(commd_port)] } {
      set params(exclude_list) $config(commd_port)
      set params(exclude_list) [expr $config(commd_port) + 1]
   }

   set value [config_generic $only_check $name config $help_text "port" 1 1 "" params ]

   if { $value != 0 && $value < 1024 } {
      puts "Need JMX_PORT value >= 1024"
      return -1
   }
   
   return $value
}

#****** config/config_jmx_ssl() ************************************************
#  NAME
#     config_jmx_ssl() -- jmx ssl server authentication option setup
#
#  SYNOPSIS
#     config_jmx_ssl { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_jmx_ssl { only_check name config_array } {

   upvar $config_array config
   
   array set jmx {
      "true" "enable SSL server authentication for qmaster JMX mbean server"
      "false" "no SSL server authentication for qmaster JMX mbean server"
   }   
   set value [config_generic $only_check $name config "" "choice" 0 1 jmx ] 

   return $value
}

#****** config/config_jmx_ssl_client() *****************************************
#  NAME
#     config_jmx_ssl_client() -- jmx ssl client authentication option setup
#
#  SYNOPSIS
#     config_jmx_ssl_client { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_jmx_ssl_client { only_check name config_array } {

   upvar $config_array config
   
   array set jmx {
      "true" "enable SSL client authentication for qmaster JMX mbean server"
      "false" "no SSL client authentication for qmaster JMX mbean server"
   }   
   set value [config_generic $only_check $name config "" "choice" 0 1 jmx ] 

   return $value
}

#****** config/config_jmx_ssl_keystore_pw() ************************************
#  NAME
#     config_jmx_ssl_keystore_pw() -- jmx ssl keystore password
#
#  SYNOPSIS
#     config_jmx_ssl_keystore_pw { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_jmx_ssl_keystore_pw { only_check name config_array } {

   upvar $config_array config
   
   set helptext {
      "Enter the JMX SSL keystore pw for qmaster JMX mbean server"
      "or press >RETURN< to use the default value."
   }   
   set value [config_generic $only_check $name config $helptext "string"] 

   return $value
}

#****** config/config_reserved_port() ******************************************
#  NAME
#     config_reserved_port() -- reserved option setup
#
#  SYNOPSIS
#     config_reserved_port { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_reserved_port { only_check name config_array } {

   upvar $config_array config
   
   set help_text {
      "Enter an unused port number < 1024. This port is used to test"
      "port binding." 
   }
   
   array set params { port_type reserved }

   set value [config_generic $only_check $name config $help_text "port" 0 1 "" params]
   
   if { $value >= 1024 } {
      puts "Need an unused port number < 1024."
      return -1
   } 

   return $value
}

#****** config/config_product_root() *******************************************
#  NAME
#     config_product_root() -- product root setup
#
#  SYNOPSIS
#     config_product_root { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_product_root { only_check name config_array } {
   global fast_setup

   upvar $config_array config

   set help_text { "Enter the path where the testsuite should install Grid Engine,"
                   "or press >RETURN< to use the default value."
                   "You can also specify a current installed Grid Engine system path."
                   "WARNING: The compile option will remove the content of this directory"
                   "or store it to \"testsuite_trash\" directory with testsuite_trash"
                   "commandline option!!!" }

   set value [config_generic $only_check $name config $help_text "directory+" 0]

   if {!$fast_setup && $value != -1} {
      set path_length [ string length "/bin/sol-sparc64/sge_qmaster" ]
      if { !$fast_setup && $path_length > 60 } {
         puts "path for product_root_directory is too long (must be <= [expr ( 60 - $path_length )] chars)"
         puts "The testsuite tries to find processes via ps output most ps output is truncated"
         puts "for longer lines."
         return -1
      }
   }

   return $value
}

#****** config/config_product_type() *******************************************
#  NAME
#     config_product_type() -- product type setup
#
#  SYNOPSIS
#     config_product_type { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_product_type { only_check name config_array } {
   global CHECK_PRODUCT_TYPE

   upvar $config_array config

   array set sge_types {
      sgeee "Grid Engine Enterprise Edition"
   }

   if {$config(gridengine_version) < 60} {
      set sge_types(sge) "Grid Engine"
      }

   set value [config_generic $only_check $name config "" "choice" 0 1 sge_types]

   set CHECK_PRODUCT_TYPE $value

   return $value
}

#****** config/config_product_feature() ****************************************
#  NAME
#     config_product_feature() -- product feature setup
#
#  SYNOPSIS
#     config_product_feature { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_product_feature { only_check name config_array } {

   upvar $config_array config

   array set sge_features {
      csp "Certificate Security Protocol"
      none "no special product features"
   }

   set value [config_generic $only_check $name config "" "choice" 1 1 sge_features]

   return $value
}

#****** config/config_aimk_compile_options() ***********************************
#  NAME
#     config_aimk_compile_options() -- aimk compile option setup
#
#  SYNOPSIS
#     config_aimk_compile_options { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_aimk_compile_options { only_check name config_array } {

   upvar $config_array config

   set help_text { "Enter aimk compile options (use \"none\" for no options)"
                "or press >RETURN< to use the default value." }
   return [config_generic $only_check $name config $help_text "string" 1 0]
}

#****** config/config_dist_install_options() ***********************************
#  NAME
#     config_dist_install_options() -- distrib install options
#
#  SYNOPSIS
#     config_dist_install_options { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_dist_install_options { only_check name config_array } {

   upvar $config_array config

   set help_text { "Enter dist install options (use \"none\" for no options)"
                   "or press >RETURN< to use the default value." }

   return [config_generic $only_check $name config $help_text "string" 1 0]
}

#****** config/config_qmaster_install_options() *********************************
#  NAME
#     config_qmaster_install_options() -- master install options setup
#
#  SYNOPSIS
#     config_qmaster_install_options { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_qmaster_install_options { only_check name config_array } {
   global CHECK_QMASTER_INSTALL_OPTIONS

   upvar $config_array config

   set help_text { "Enter Grid Engine qmaster install options (use \"none\" for no options)"
                   "or press >RETURN< to use the default value." }

   set value [config_generic $only_check $name config $help_text "string" 1 0]

   if { $value == -1 } { return -1 }

   # set global values
   set CHECK_QMASTER_INSTALL_OPTIONS  $value
   if { $value == "none"  } {
      set CHECK_QMASTER_INSTALL_OPTIONS  ""
   }

   return $value
}

#****** config/config_execd_install_options() **********************************
#  NAME
#     config_execd_install_options() -- install options setup
#
#  SYNOPSIS
#     config_execd_install_options { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_execd_install_options { only_check name config_array } {
   global CHECK_EXECD_INSTALL_OPTIONS 

   upvar $config_array config

   set help_text { "Enter Grid Engine execd install options (use \"none\" for no options)"
                   "or press >RETURN< to use the default value." }

   set value [config_generic $only_check $name config $help_text "string" 1 0]

   if { $value == -1 } { return -1 }

   # set global values
   set CHECK_EXECD_INSTALL_OPTIONS   $value
   if { $value == "none" } {
      set CHECK_EXECD_INSTALL_OPTIONS  ""
   }

   return $value
}

#****** config/config_package_directory() **************************************
#  NAME
#     config_package_directory() -- package optiont setup
#
#  SYNOPSIS
#     config_package_directory { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_package_directory { only_check name config_array } {
   global CHECK_PACKAGE_DIRECTORY
   global fast_setup

   upvar $config_array config

   set help_text { "Enter directory path to Grid Engine packages (pkgadd or zip),"
                   "(use \"none\" if there are no packages available)"
                   "or press >RETURN< to use the default value." }

   set check_type "directory"
            if { $config(package_type) == "create_tar" } {
      set check_type "directory+"                 ;# create dir if doesn't exist
            }
   set value [config_generic $only_check $name config $help_text $check_type 1]

   if { $value == -1 || $value == "none" } { return $value }

   # package dir configured?
   if {!$fast_setup } {
      if { $config(package_type) == "tar" }    {
            if { [check_packages_directory $value check_tar] != 0 } {
            puts "error checking package_directory! are all package file installed?"
               return -1
            }
         } else {
         if { $config(package_type) == "tar" }    {
               if { [check_packages_directory $value check_zip] != 0 } {
               puts "error checking package_directory! are all package file installed?"
                  return -1
               }
            }
         }
      }

   set CHECK_PACKAGE_DIRECTORY $value

   return $value
}

#****** config/config_package_type() *******************************************
#  NAME
#     config_package_type() -- package type setup
#
#  SYNOPSIS
#     config_package_type { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_package_type { only_check name config_array } {
   global CHECK_PACKAGE_TYPE
   global fast_setup

   upvar $config_array config

   array set pkg_types {
      tar "precompiled tar packages"
      zip "precompiled sunpkg packages"
      create_tar "generate tar packages"
      }

   set value [config_generic $only_check $name config "" "choice" 0 1 pkg_types]

   if { $value != -1 } { set CHECK_PACKAGE_TYPE $value }

   return $value
}

#****** config/config_dns_domain() *********************************************
#  NAME
#     config_dns_domain() -- dns domain setup
#
#  SYNOPSIS
#     config_dns_domain { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_dns_domain { only_check name config_array } {
   global CHECK_DNS_DOMAINNAME
   global CHECK_USER
   global fast_setup

   upvar $config_array config

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts "Could not get local host name" 
      return -1
   }

   set help_text { "Enter your DNS domain name or"
                   "press >RETURN< to use the default value."
                   "The DNS domain is used in the qmaster complex test." }

   set value [config_generic $only_check $name config $help_text "string" 0]

   if { $value == -1 } { return -1 }

   if {!$fast_setup} {
      set result [start_remote_prog $local_host $CHECK_USER "echo" "\"hello $local_host\"" prg_exit_state 60 0 "" "" 1 0]
      if { $prg_exit_state != 0 } {
         puts "rlogin to host $local_host doesn't work correctly"
         return -1
      }
      if { [ string first "hello $local_host" $result ] < 0 } {
         puts "$result"
         puts "echo \"hello $local_host\" doesn't work"
         return -1
      }

      ts_log_finest "domain check ..."
      set host "$local_host.$value"
      ts_log_finest "hostname with dns domain: \"$host\""

      set result [start_remote_prog $host $CHECK_USER "echo" "\"hello $host\"" prg_exit_state 60 0 "" "" 1 0]
      if { $prg_exit_state != 0 } {
         puts "rlogin to host $host doesn't work correctly"
         return -1
      }
      if { [ string first "hello $host" $result ] < 0 } {
         puts "$result"
         puts "echo \"hello $host\" doesn't work"
         return -1
      }
   }

   # set global values
   set CHECK_DNS_DOMAINNAME $value

   return $value
}

#****** config/config_dns_for_install_script() *********************************
#  NAME
#     config_dns_for_install_script() -- domain used for sge installation
#
#  SYNOPSIS
#     config_dns_for_install_script { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_dns_for_install_script { only_check name config_array } {
   global CHECK_DEFAULT_DOMAIN
   global CHECK_USER
   global fast_setup

   upvar $config_array config

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts "Could not get local host name" 
      return -1
   }

   set help_text { "Enter the DNS domain name used for installation script"
                   "or press >RETURN< to use the default value."
                   "Set this value to \"none\" if all your cluster hosts are"
                   "in the same DNS domain." }

   set value [config_generic $only_check $name config $help_text "string"]

   if { $value == -1 } { return -1 }

   if {!$fast_setup} {
      # only check domain if not none
      if { $value != "none" } {

         ts_log_finest "domain check ..."
         set host "$local_host.$value"
         ts_log_finest "hostname with dns domain: \"$host\""
      
         set result [start_remote_prog $host $CHECK_USER "echo" "\"hello $host\"" prg_exit_state 60 0 "" "" 1 0]
         if { $prg_exit_state != 0 } {
            puts "rlogin to host $host doesn't work correctly"
            return -1
         }
         if { [ string first "hello $host" $result ] < 0 } {
            puts "$result"
            puts "echo \"hello $host\" doesn't work"
            return -1
         }
      }
   }

   # set global values
   set CHECK_DEFAULT_DOMAIN $value

   return $value
}

#****** config/config_mail_application() ***************************************
#  NAME
#     config_mail_application() -- ??? 
#
#  SYNOPSIS
#     config_mail_application { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_mail_application { only_check name config_array } {

   upvar $config_array config

   set help_text { "Enter the name of the mail application used for sending"
                   "e-mails to the testsuite starter. The testsuite supports"
                   "mailx, sendmail and a path to a mail script. (see mail_application.sh"
                   "in testsuite/scripts directory for a mail wrapper script template)\n"
                   "Press >RETURN< to use the default value." }

   return [config_generic $only_check $name config $help_text "string" 0]

}

#****** config/config_mailx_host() *********************************************
#  NAME
#     config_mailx_host() -- mailx option setup
#
#  SYNOPSIS
#     config_mailx_host { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_mailx_host { only_check name config_array } {
   global CHECK_USER 
   global CHECK_MAILX_HOST
   global fast_setup

   upvar $config_array config

   set help_text { "Enter the name of the host used for sending e-mail reports"
                   "or press >RETURN< to use the default value."
                   "Set this value to \"none\" if you don't want get e-mails from the"
                   "testsuite." }

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts "Could not get local host name" 
      return -1
   }

   if { $config($name,default) == "" } {
      set config($name,default) $local_host
      }

   set value [config_generic $only_check $name config $help_text "host"]

   if { $value == -1 } { return -1 }

   if {!$fast_setup} {
      # only check domain if not none
      if { $value != "none" } {
         set host $value
         set result [start_remote_prog $host $CHECK_USER "echo" "\"hello $host\"" prg_exit_state 60 0 "" "" 1 0]
         if { $prg_exit_state != 0 } {
            puts "rlogin to host $host doesn't work correctly"
            return -1
         }
         if { [ string first "hello $host" $result ] < 0 } {
            puts "$result"
            puts "echo \"hello $host\" doesn't work"
            return -1
         }
         set result [start_remote_prog $host $CHECK_USER "$config(testsuite_root_dir)/scripts/mywhich.sh" $config(mail_application) prg_exit_state 60 0 "" "" 1 0]
         if { $prg_exit_state != 0 } {
            puts $result
            puts "$config(mail_application) not found on host $host. Enhance your PATH envirnoment"
            puts "or setup your mail application correctly."
            return -1
         } else {
            ts_log_finest $result
            ts_log_finest "found $config(mail_application)"
         }
      }
   }

   # set global values
   set CHECK_MAILX_HOST $value

   return $value
}

#****** config/config_report_mail_to() *****************************************
#  NAME
#     config_report_mail_to() -- mail to setup
#
#  SYNOPSIS
#     config_report_mail_to { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_report_mail_to { only_check name config_array } {
   global CHECK_REPORT_EMAIL_TO

   upvar $config_array config

   set help_text { "Enter e-mail address where the testsuite should send report mails"
                   "or press >RETURN< to use the default value."
                   "Set this value to \"none\" if you don't want to get e-mails from the"
                   "testsuite." }

      if { $config(mailx_host) == "none" } {
         set only_check 1
      }

   array set params { patterns "*" }
   set value [config_generic $only_check $name config $help_text "string" 1 1 "" params]

   # set global values
   if { $value != -1 } { set CHECK_REPORT_EMAIL_TO $value }

   return $value
}

#****** config/config_report_mail_cc() *****************************************
#  NAME
#     config_report_mail_cc() -- mail cc setup
#
#  SYNOPSIS
#     config_report_mail_cc { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_report_mail_cc { only_check name config_array } {
   global CHECK_REPORT_EMAIL_CC

   upvar $config_array config

   set help_text { "Enter e-mail address where the testsuite should cc report mails"
                   "or press >RETURN< to use the default value."
                   "Set this value to \"none\" if you don't want to cc e-mails from the"
                   "testsuite." }

      if { $config(mailx_host) == "none" } {
         set only_check 1
      }

   array set params { patterns "*" }
   set value [config_generic $only_check $name config $help_text "string" 1 1 "" params]

   # set global values
   if { $value != -1 } { set CHECK_REPORT_EMAIL_CC $value }

   return $value
}

#****** config/config_enable_error_mails() *************************************
#  NAME
#     config_enable_error_mails() -- error mail setup
#
#  SYNOPSIS
#     config_enable_error_mails { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_enable_error_mails { only_check name config_array } {
   global CHECK_USER 
   global CHECK_MAILX_HOST
   global CHECK_REPORT_EMAIL_TO
   global CHECK_REPORT_EMAIL_CC
   global CHECK_SEND_ERROR_MAILS
   global CHECK_MAX_ERROR_MAILS

   upvar $config_array config

   set help_text { "Enter the maximum number of e-mails you want to get from the"
                "testsuite or press >RETURN< to use the default value."
                "Set this value to \"none\" if you don't want to get e-mails from the"
                "testsuite." }

   if { $config(mailx_host) == "none" || $config(report_mail_to) == "none" } {
         set only_check 1
      }

   set value [config_generic $only_check $name config $help_text "string"]

   set enabled 1
      if { $CHECK_MAILX_HOST == "none" } {
      puts "mailx host not configured"
      set enabled 0
      }
   if { $CHECK_REPORT_EMAIL_TO == "none" } {
      puts "E-mail address for sending testsuite reports not set."
      set enabled 0
   }
   if { $value == "none" || $value == 0 } {
      set enabled 0
   }
   set mail_cc ""
   if {[string compare $CHECK_REPORT_EMAIL_CC "none"] != 0} {
      set mail_cc $CHECK_REPORT_EMAIL_CC
   }


   if { $enabled == 1 } {
      set CHECK_SEND_ERROR_MAILS 1
      set CHECK_MAX_ERROR_MAILS $value
      if { $only_check == 0 } {
         send_mail $CHECK_REPORT_EMAIL_TO $mail_cc "Welcome!" "Testsuite mail setup test mail"
         puts "Have you got the e-mail? (y/n) "
         set input [wait_for_enter 1]
         if { $input != "y" }  {
            set enabled 0
         }
      }
   }
   if { $enabled == 0 } {
      ts_log_warning "Sending e-mail reports disabled..."
            set CHECK_SEND_ERROR_MAILS 0
            set CHECK_MAX_ERROR_MAILS 0
            set value "none"
         }

   return $value
}

#****** config/config_l10n_test_locale() ***************************************
#  NAME
#     config_l10n_test_locale() -- l10n option setup
#
#  SYNOPSIS
#     config_l10n_test_locale { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_l10n_test_locale { only_check name config_array } {
   global CHECK_L10N ts_host_config
   global fast_setup

   upvar $config_array config

   array set locales {
      fr "French localization test"
      ja "Japanese localization test"
      zh "Chinese localization test"
      none "no l10n testing"
   }
   set value [config_generic $only_check $name config "" "choice" 1 1 locales]

   if { $value == -1 } { return -1 }

   set CHECK_L10N 0
   if { $value != "none" } {
        
           if {!$fast_setup} {
              set was_error 0

         if { [ info exist ts_host_config($config(master_host),${value}_locale)] != 1 } {
            puts "can't read ts_host_config($config(master_host),${value}_locale)"
                 return -1
              }

         if { $ts_host_config($config(master_host),${value}_locale) == "" } {
            puts "locale not defined for master host $config(master_host)"
                 incr was_error 1
              }
              foreach host $config(execd_hosts) {
                 if { $ts_host_config($host,${value}_locale) == "" } {
               puts "locale not defined for execd host $host"
                    incr was_error 1
                 }
              }
         foreach host $config(submit_only_hosts) {
            if { $host != "none" && $ts_host_config($host,${value}_locale) == "" } {
               puts "locale not defined for submit host $host"
                    incr was_error 1
                 }
              }
              if { $was_error != 0 } {
                 if { $only_check == 0 } {
               puts "Press enter to edit global host configuration ..."
                     wait_for_enter
               setup_host_config $config(host_config_file) hostlist
                 }
                 return -1
              }
           }
           set CHECK_L10N 1
      set mem_value $config(l10n_test_locale)
      set config(l10n_test_locale) $value
      set config(l10n_test_locale) $mem_value

           if {!$fast_setup} {
              set test_result [perform_simple_l10n_test]
              if { $test_result != 0 } {
            puts "l10n errors" 
                 set CHECK_L10N 0
                 return -1
              }
           }
        }

   return $value
}

#****** config/config_testsuite_gridengine_version() ***************************
#  NAME
#     config_testsuite_gridengine_version() -- version setup
#
#  SYNOPSIS
#     config_testsuite_gridengine_version { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_gridengine_version { only_check name config_array } {

   upvar $config_array config

   array set version_list {
      53 "SGE(EE) 5.3 systems (e.g. V53_beta2_BRANCH)"
      60 "N1GE 6.0 systems (e.g. V60s2_BRANCH)"
      61 "N1GE 6.1 systems (e.g. V61_BRANCH)"
      62 "N1GE 6.2 systems (e.g. maintrunk)"
   }

   return [config_generic $only_check $name config "" "choice" 0 1 version_list]
      }

#****** config/config_testsuite_spooling_method() ******************************
#  NAME
#     config_testsuite_spooling_method() -- spooling method setup
#
#  SYNOPSIS
#     config_testsuite_spooling_method { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_spooling_method { only_check name config_array } {

   upvar $config_array config

   set help_text { "Specify the spooling method that will be used in case"
                   "the binaries were build to support dynamic spooling." }

   array set spool_list {
      classic ""
      berkeleydb ""
      }

   return [config_generic $only_check $name config $help_text "choice" 0 1 spool_list]
      }

#****** config/config_testsuite_bdb_server() ***********************************
#  NAME
#     config_testsuite_bdb_server() -- bdb server setup
#
#  SYNOPSIS
#     config_testsuite_bdb_server { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_bdb_server { only_check name config_array } {

   upvar $config_array config

   set help_text { "Specify the host of a Berkeley DB RPC server\n"
                   "A Berkeley DB RPC server is used, if you want to run"
                   "the shadowd tests or if you don't want to configure"
                   "a database directory on a local filesystem\n"
                   "Enter \"none\" if you use local spooling,"
                   "or press >RETURN< to use the default value." }

   array set params { verify "compile" }
   return [config_generic $only_check $name config $help_text "host" 1 1 "" params]
      }

#****** config/config_testsuite_bdb_dir() **************************************
#  NAME
#     config_testsuite_bdb_dir() -- bdb database directory setup
#
#  SYNOPSIS
#     config_testsuite_bdb_dir { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_bdb_dir { only_check name config_array } {

   global check_do_not_use_spool_config_entries CHECK_USER
   upvar $config_array config

   set help_text { "Specify the database directory for spooling"
                   "with the Berkeley DB spooling framework\n"
                   "If your testsuite host configuration defines a local"
                   "spool directory for your master host, specify \"none\"\n"
                   "If no local spool directory is defined in the host"
                   "configuration, give the path to a local database"
                   "directory.\n"
                   "If you configured a Berkeley DB RPC server, enter"
                   "the database directory on the RPC server host.\n"
                   "Press >RETURN< to use the default value."  }

   set value [config_generic $only_check $name config $help_text "string"]
   set master_host [config_generic 1 "master_host" config $help_text "string"]
   if { $master_host == -1 } {
      set master_host [config_generic $only_check "master_host" config $help_text "string"]
   }

   set spooling_method [config_generic 1 "spooling_method" config $help_text "string"]
   if { $spooling_method == -1 } {
      set spooling_method [config_generic $only_check "spooling_method" config $help_text "string"]
   }

   set bdb_server [config_generic 1 "bdb_server" config $help_text "string"]
   if { $bdb_server == -1 } {
      set bdb_server [config_generic $only_check "bdb_server" config $help_text "string"]
   }

   if { $value != "none" } {
      if { [tail_directory_name $value] != $value } {
         puts "\nPath \"$value\" is not a valid directory name, try \"[tail_directory_name $value]\""
         return -1
      }
   }

   # when we have no_local_spool option set, berkeley db spooling only works on a local disk
   # except for the BDB server - it works on any filesystem
   if {$check_do_not_use_spool_config_entries != 0 && $spooling_method == "berkeleydb" && $bdb_server == "none"} {
      if {$value == "none"} {
         if {$check_do_not_use_spool_config_entries == 1} {
            set used_param_name "no_local_spool"
         } else {
            set used_param_name "no_local_qmaster_spool"
         }
         ts_log_severe "You are using the \"--${used_param_name}\" option and \"berkeleydb\" spooling, this needs a configured bdb_dir!"
         return -1
      }

      set spool_dir_ok 0
      if {$spooling_method == "classic"} {
         set spool_dir_ok 1
      } else {
         if {$spooling_method == "berkeleydb"} {
            if {$bdb_server != "none"} {
               set spool_dir_ok 1
            } else {
               set tmp_dir $value
               while {[is_remote_path $master_host $CHECK_USER $tmp_dir] != 1} {
                  set tmp_dir [file dirname $tmp_dir]
               }  
               set fstype [fs_config_get_filesystem_type $tmp_dir $master_host]
               if {$fstype == "nfs4"} {
                  set spool_dir_ok 1
               }
            }
         }
      }
      if {$spool_dir_ok == 0} {
         set value -1
      }
   }
   return $value
}

#****** config/config_testsuite_cell() *****************************************
#  NAME
#     config_testsuite_cell() -- cell name
#
#  SYNOPSIS
#     config_testsuite_cell { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_cell { only_check name config_array } {

   upvar $config_array config

   set help_text { "Specify the cell name (SGE_CELL), or press >RETURN<"
                   "to use the default value." }

   return [config_generic $only_check $name config $help_text "string" 0]
      }

#****** config/config_testsuite_cluster_name() *********************************
#  NAME
#     config_testsuite_cluster_name() -- cluster name
#
#  SYNOPSIS
#     config_testsuite_cluster_name { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_cluster_name { only_check name config_array } {

   upvar $config_array config

   set help_text { "Specify the cluster name (SGE_CLUSTER_NAME), or press >RETURN<"
                   "to use the default value." }

   if { $config($name,default) == "p" } {
      set config($name,default) "p$config(commd_port)"
   }

   return [config_generic $only_check $name config $help_text "string" 0]
      }

#****** config/config_add_compile_archs() **************************************
#  NAME
#     config_add_compile_archs() -- forced compilation setup
#
#  SYNOPSIS
#     config_add_compile_archs { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_add_compile_archs { only_check name config_array } {
   global ts_host_config

   upvar $config_array config

   array set archs { }
   host_config_hostlist_get_architectures ts_host_config archs

   return [config_generic $only_check $name config "" "choice" 1 0 archs]

}

#****** config/config_shadowd_hosts() ******************************************
#  NAME
#     config_shadowd_hosts() -- shadowd daemon host setup
#
#  SYNOPSIS
#     config_shadowd_hosts { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_shadowd_hosts { only_check name config_array } {
   global CHECK_CORE_SHADOWD
   global ts_host_config
   global fast_setup check_do_not_use_spool_config_entries

   set CHECK_CORE_SHADOWD ""

   upvar $config_array config

   set master_host $config(master_host)
 
   if { $config($name,default) == "" } {
      set config($name,default) $master_host
   }

   array set params { verify "compile" }
   set value [config_generic $only_check $name config "" "host" 0 0 "" params]

   if { $value == -1 } { return -1 }

   if {$only_check == 0} {
      # initialize value from defaults, if not yet set
      if { $value == "" } {
         set value $config($name,default)
         if { $value == "" } {
            set value $master_host
         }
      }
      # master_host must be first host in the list
      set value [config_check_host_in_hostlist $value $master_host]
   } 
   
   # at least one shadowd must run on qmaster host
   if {[lsearch -exact $value $config(master_host)] < 0 } {
      puts "master host $config(master_host) is not in shadowd list: $value"
      return -1
   }

   # check that each shadowd host has access to qmaster spool dir
   # get master spool dir
   #   1) host might be a virtual host - to query local spooldir we need the real host
   set physical_master_host [node_get_host $config(master_host)]
  
   #   2) read local spool dir from host config
   if {[info exist ts_host_config($physical_master_host,spooldir)] && $check_do_not_use_spool_config_entries == 0 } {
      set spooldir $ts_host_config($physical_master_host,spooldir)
   } else {
      set spooldir ""
   }

   #   3) check that every shadowd host has access to the master spool dir
   foreach host $value {
      if {$host == $config(master_host)} {
         # we skip this test for master host
         continue
      } else {
         # if qmaster has a local spool dir, skip this settings
         if {$spooldir != ""} {
            puts ""
            set error_text    "master host $config(master_host) has a local spool dir in \"$spooldir/..\"\n"
            append error_text "the configured shadowd host \"$host\" cannot access this directory!\n\n"
            append error_text "INFO: To solve this problem you might do one of the following actions:\n"
            append error_text "   - remove the shadowd host \"$host\" from your testsuite configuration\n"
            append error_text "   - use the global testsuite command line parameter \"no_local_qmaster_spool\"\n"
            append error_text "   - use the global testsuite command line parameter \"no_local_spool\"\n"
            puts $error_text
            ts_log_warning $error_text
            return -1
         }
      }
   }
    
   set CHECK_CORE_SHADOWD $value

   return $value
}

#****** config/config_build_ts_config*() ***************************************
#  NAME
#     config_build_ts_config*() -- version dependend menu configuration
#
#  SYNOPSIS
#     config_build_ts_config* { }
#
#  FUNCTION
#     Testsuite menu initialization.
#     For each parameter specify:
#     o $name       the name of parameter
#     o desc        description
#     o default     default value
#     o setup_func  the name of the setup function
#     o onchange    what happens when the parameter is changes
#                   (i.e. stop, install, compile)
#     o pos         position in menu
#
#*******************************************************************************
proc config_build_ts_config {} {
   global ts_config
   global CHECK_CURRENT_WORKING_DIR

   # ts_config defaults 
   set ts_pos 1
   set parameter "version"
   set ts_config($parameter)            "1.0"
   set ts_config($parameter,desc)       "Testsuite configuration setup"
   set ts_config($parameter,default)    "1.0"
   set ts_config($parameter,setup_func) ""
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "testsuite_root_dir"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's root directory"
   set ts_config($parameter,default)    $CHECK_CURRENT_WORKING_DIR
   set ts_config($parameter,setup_func) "config_testsuite_root_dir"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "checktree_root_dir"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's checktree directory"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir 
   set ts_config($parameter,setup_func) "config_checktree_root_dir"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "results_dir"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's directory to save test results (html/txt files)"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "use_ssh"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Using ssh to connect to cluster hosts"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "source_dir"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Path to Grid Engine source directory"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "source_cvs_hostname"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Host used for cvs commands"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "source_cvs_release"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Used cvs release tag"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "host_config_file"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's global cluster host configuration file"
   set ts_config($parameter,default)    $CHECK_CURRENT_WORKING_DIR/testsuite_host.conf
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "user_config_file"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's global user configuration file"
   set ts_config($parameter,default)    $CHECK_CURRENT_WORKING_DIR/testsuite_user.conf
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "master_host"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine master host"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "execd_hosts"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine execution daemon hosts"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "submit_only_hosts"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine submit only hosts"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "commd_port"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine COMMD_PORT"
   set ts_config($parameter,default)    "7778"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "product_root"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine directory"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1


   set parameter "product_type"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine product mode"
   set ts_config($parameter,default)    "sgeee"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "product_feature"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine features"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "aimk_compile_options"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Aimk compile options"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "compile"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "dist_install_options"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Distribution install options"
   set ts_config($parameter,default)    "-allall"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "compile"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "qmaster_install_options"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine qmaster install options"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "execd_install_options"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine execd install options"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "package_directory"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Directory with Grid Engine pkgadd or zip file packages"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "compile"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "package_type"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Default package type to test"
   set ts_config($parameter,default)    "tar"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "compile"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "dns_domain"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Local DNS domain name"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "dns_for_install_script"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "DNS domain name used in Grid Engine installation procedure"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "mailx_host"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Name of host used for sending mails (mailx/sendmail must work on this host)"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "report_mail_to"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "E-mail address used for report mails"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "report_mail_cc"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "E-mail address used for cc report mails"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "enable_error_mails"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Max number of e-mails send through one testsuite session"
   set ts_config($parameter,default)    "400"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

}

proc config_build_ts_config_1_1 {} {
   global ts_config

   # insert new parameter after product_feature parameter
   set insert_pos $ts_config(product_feature,pos)
   incr insert_pos 1
   
   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter l10n_test_locale
   set parameter "l10n_test_locale"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Specify localization environment (LANG)"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos) $insert_pos

   # now we have a configuration version 1.1
   set ts_config(version) "1.1"
}

proc config_build_ts_config_1_2 {} {
   global ts_config

   # insert new parameter after submit_only_hosts parameter
   set insert_pos $ts_config(submit_only_hosts,pos)
   incr insert_pos 1
   
   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter add_compile_archs
   set parameter "add_compile_archs"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Forced compilation for architectures"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos) $insert_pos

   # now we have a configuration version 1.2
   set ts_config(version) "1.2"
}

proc config_build_ts_config_1_3 {} {
   global ts_config

   # insert new parameter after version parameter
   set insert_pos $ts_config(version,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter gridengine_version
   set parameter "gridengine_version"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Gridengine Version"
   set ts_config($parameter,default)    "62"
   set ts_config($parameter,setup_func) "config_testsuite_gridengine_version"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.3
   set ts_config(version) "1.3"
}

proc config_build_ts_config_1_4 {} {
   global ts_config

   # insert new parameter after product_feature parameter
   set insert_pos $ts_config(product_feature,pos)
   incr insert_pos 1

   # move positions of following parameters by 2
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 2 ) ]
      }
   }

   # new parameter bdb_server
   set parameter "bdb_server"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Berkeley Database RPC server (none for local spooling)"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_testsuite_bdb_server"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   incr insert_pos 1

   # new parameter bdb_dir
   set parameter "bdb_dir"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Berkeley Database database directory"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_testsuite_bdb_dir"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.4
   set ts_config(version) "1.4"
}

proc config_build_ts_config_1_5 {} {
   global ts_config

   # insert new parameter after product_feature parameter
   set insert_pos $ts_config(product_feature,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter spooling method
   set parameter "spooling_method"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Spooling method for dynamic spooling"
   set ts_config($parameter,default)    "berkeleydb"
   set ts_config($parameter,setup_func) "config_testsuite_spooling_method"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.5
   set ts_config(version) "1.5"
}

proc config_build_ts_config_1_6 {} {
   global ts_config

   # insert new parameter after product_feature parameter
   set insert_pos $ts_config(product_feature,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter spooling method
   set parameter "cell"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "cell name (SGE_CELL)"
   set ts_config($parameter,default)    "default"
   set ts_config($parameter,setup_func) "config_testsuite_cell"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.6
   set ts_config(version) "1.6"
}
proc config_build_ts_config_1_7 {} {
   global ts_config

   # insert new parameter after commd_port parameter
   set insert_pos $ts_config(commd_port,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter reserved port
   set parameter "reserved_port"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Port < 1024 to test root bind() of this port"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_reserved_port"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.7
   set ts_config(version) "1.7"
}
  
proc config_build_ts_config_1_8 {} {
   global ts_config

   # insert new parameter after master_host parameter
   set insert_pos $ts_config(master_host,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   set parameter "shadowd_hosts"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine shadow daemon hosts"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.8
   set ts_config(version) "1.8"
}

proc config_build_ts_config_1_9 {} {
   global ts_config

   # insert new parameter after master_host parameter
   set insert_pos $ts_config(dns_for_install_script,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   set parameter "mail_application"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Name of mail application used for sending testsuite mails"
   set ts_config($parameter,default)    "mailx"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.9
   set ts_config(version) "1.9"
}

proc config_build_ts_config_1_91 {} {
   global ts_config

   # insert new parameter after checktree_root_dir
   set insert_pos $ts_config(checktree_root_dir,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "additional_checktree_dirs"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Additional Testsuite's checktree directories"
   set ts_config($parameter,default)    "none"   ;# depend on testsuite root dir 
   set ts_config($parameter,setup_func) "config_additional_checktree_dirs"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.91
   set ts_config(version) "1.91"
}

proc config_build_ts_config_1_10 {} {
   global ts_config

   # we renamed the version planned to be 6.5 to 6.1
   if {$ts_config(gridengine_version) == 65} {
      set ts_config(gridengine_version) 62
   }

   # now we have a configuration version 1.10
   set ts_config(version) "1.10"
}

proc config_build_ts_config_1_11 {} {
   global ts_config

   # we add a new parameter: additional_config
   # after additional_checktree_dirs
   set insert_pos $ts_config(additional_checktree_dirs,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "additional_config"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Additional Testsuite Configurations"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_additional_config"
   set ts_config($parameter,onchange)   "compile"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.11
   set ts_config(version) "1.11"
}

proc config_build_ts_config_1_12 {} {
   global ts_config

   # we override a the parameter: use_ssh
   set insert_pos $ts_config(use_ssh,pos)

   unset ts_config(use_ssh)
   unset ts_config(use_ssh,desc)
   unset ts_config(use_ssh,default)
   unset ts_config(use_ssh,setup_func)
   unset ts_config(use_ssh,onchange)
   unset ts_config(use_ssh,pos)
   
   set parameter "connection_type"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Starter method for remote connections"
   set ts_config($parameter,default)    "rlogin"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.11
   set ts_config(version) "1.12"
}

proc config_build_ts_config_1_13 {} {
   global ts_config

   
   # we override a the parameter: use_ssh
   set insert_pos $ts_config(commd_port,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "jmx_port"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Port of qmasters jmx mbean server"
   set ts_config($parameter,default)    "0"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.13
   set ts_config(version) "1.13"
}

proc config_build_ts_config_1_14 {} {
   global ts_config

   # we add a new parameter: cluster_name
   # after additional_checktree_dirs
   set insert_pos $ts_config(cell,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "cluster_name"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "cluster name (SGE_CLUSTER_NAME)"
   set ts_config($parameter,default)    "p$ts_config(commd_port)"
   set ts_config($parameter,setup_func) "config_testsuite_cluster_name"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.14
   set ts_config(version) "1.14"
}

proc config_build_ts_config_1_15 {} {
   global ts_config

   # insert new parameter after user_config_file
   set insert_pos $ts_config(user_config_file,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "db_config_file"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's global database configuration file"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.15
   set ts_config(version) "1.15"
}

proc config_build_ts_config_1_16 {} {
   global ts_config

   # we add two new parameters: jmx_ssl and jmx_ssl_client
   # after JMX port
   set insert_pos $ts_config(jmx_port,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 3]
      }
   }

   set parameter "jmx_ssl"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "JMX SSL server authentication"
   set ts_config($parameter,default)    "true"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   incr insert_pos 1

   set parameter "jmx_ssl_client"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "JMX SSL client authentication"
   set ts_config($parameter,default)    "true"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   incr insert_pos 1

   set parameter "jmx_ssl_keystore_pw"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "JMX SSL keystore pw"
   set ts_config($parameter,default)    "changeit"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.16
   set ts_config(version) "1.16"
}

proc config_build_ts_config_1_17 {} {
   global ts_config

   # use host list to choose the host for cvs, host configuration must be already
   # set, change the positions of configuration items
   set pos $ts_config(source_cvs_hostname,pos)

   set ts_config(host_config_file,pos) $pos
   set ts_config(user_config_file,pos) [incr pos 1]
   set ts_config(db_config_file,pos) [incr pos 1]
   set ts_config(source_cvs_hostname,pos) [incr pos 1]
   set ts_config(source_cvs_release,pos) [incr pos 1]

   # move additional testsuite configuration after host config
   set pos $ts_config(additional_config,pos)

   set ts_config(results_dir,pos) $pos
   set ts_config(connection_type,pos) [incr pos 1]
   set ts_config(source_dir,pos) [incr pos 1]
   set ts_config(host_config_file,pos) [incr pos 1]
   set ts_config(user_config_file,pos) [incr pos 1]
   set ts_config(db_config_file,pos) [incr pos 1]
   set ts_config(additional_config,pos) [incr pos 1]

   # now we have a configuration version 1.17
   set ts_config(version) "1.17"
}
        

proc config_build_ts_config_1_18 {} {
   global ts_config CHECK_CURRENT_WORKING_DIR

   # we add a new parameter: fs_config_file 
   # after user_config_file
   set insert_pos $ts_config(user_config_file,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "fs_config_file"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's global filesystem configuration file"
   set ts_config($parameter,default)    "$CHECK_CURRENT_WORKING_DIR/testsuite_fs.conf"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.18
   set ts_config(version) "1.18"
}     
################################################################################
#  MAIN                                                                        #
################################################################################

global actual_ts_config_version      ;# actual config version number
set actual_ts_config_version "1.18"

# first source of config.tcl: create ts_config
if {![info exists ts_config]} {
   config_build_ts_config
   config_build_ts_config_1_1
   config_build_ts_config_1_2
   config_build_ts_config_1_3
   config_build_ts_config_1_4
   config_build_ts_config_1_5
   config_build_ts_config_1_6
   config_build_ts_config_1_7
   config_build_ts_config_1_8
   config_build_ts_config_1_9
   config_build_ts_config_1_91
   config_build_ts_config_1_10
   config_build_ts_config_1_11
   config_build_ts_config_1_12
   config_build_ts_config_1_13
   config_build_ts_config_1_14
   config_build_ts_config_1_15
   config_build_ts_config_1_16
   config_build_ts_config_1_17
   config_build_ts_config_1_18
}
