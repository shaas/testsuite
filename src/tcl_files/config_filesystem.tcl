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

global ts_fs_config                       ;# new testsuite filesystem config array
global actual_ts_fs_config_version      ;# actual filesystem config version number
set    actual_ts_fs_config_version "1.0"

if {![info exists ts_fs_config]} {
   # ts_fs_config defaults
   set parameter "version"
   set ts_fs_config($parameter)            "$actual_ts_fs_config_version"
   set ts_fs_config($parameter,desc)       "Testuite filesystem configuration setup"
   set ts_fs_config($parameter,default)    "$actual_ts_fs_config_version"
   set ts_fs_config($parameter,setup_func) ""
   set ts_fs_config($parameter,onchange)   "stop"
   set ts_fs_config($parameter,pos)        1

   set parameter "fsname_list"
   set ts_fs_config($parameter)            ""
   set ts_fs_config($parameter,desc)       "Testsuite filesystem list"
   set ts_fs_config($parameter,default)    ""
   set ts_fs_config($parameter,setup_func) "fs_config_$parameter"
   set ts_fs_config($parameter,onchange)   ""
   set ts_fs_config($parameter,pos)        2

}


#****** config_filesystem/fs_config_display_params() *****************************
#  NAME
#     fs_config_display_params() -- display the filesystem configuration
#
#  SYNOPSIS
#     fs_config_display_params { name config_array }
#
#  FUNCTION
#     display the list of parameters and it's values
#
#  INPUTS
#     name         - the name of filesystem from filesystem configuration
#     config_array - ts_fs_config
#
#*******************************************************************************
proc fs_config_display_params { name config_array } {

   upvar $config_array config

   set max_length 0

   puts "\n"
   foreach param "[fs_config_get_filesystem_parameters] filesystem " {
      if { [string length $param] > $max_length } { set max_length [string length $param] }
   }

   puts "   filesystem      [get_spaces [expr ( $max_length - [ string length filesystem ] ) ]] : $name"
   foreach param [fs_config_get_filesystem_parameters] {
      set space "     [get_spaces [expr ( $max_length - [ string length $param ] ) ]]"
      puts "   $param $space : $config($name,$param)"
   }
   puts "\n"
}


#****** config_filesystem/fs_config_filesystemlist() *******************************
#  NAME
#     fs_config_filesystemlist() -- filesystem list setup
#
#  SYNOPSIS
#     fs_config_filesystemlist { only_check name config_array } 
#
#  FUNCTION
#     Testsuite filesystem configuration setup - called from verify_fs_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_user_config array)
#     config_array - config array name (ts_fs_config)
#
#  SEE ALSO
#     check/setup_fs_config()
#     check/verify_fs_config()
#
#*******************************************************************************
proc fs_config_fsname_list { only_check name config_array } {

   upvar $config_array config

   set description   $config($name,desc)

   if { $only_check == 0 } {
      set not_ready 1
      while { $not_ready } {
         clear_screen
         puts "\nGlobal filesystem configuration setup"
         puts "====================================="
         puts "\n\n    filesystems configured: [llength $config(fsname_list)]"
         fs_config_filesystemlist_show_filesystems config
         puts "\n\n(1)  add filesystem"
         puts "(2)  edit filesystem"
         puts "(3)  delete filesystem"
         puts "(10) exit setup"
         puts -nonewline "> "
         set input [ wait_for_enter 1]
         switch -- $input {
             1 {
                set result [fs_config_filesystemlist_add_filesystem config]
                if { $result != 0 } { wait_for_enter }
                }
             2 {
                set result [fs_config_filesystemlist_edit_filesystem config]
                if { $result != 0 } { wait_for_enter }
                }
             3 {
               set result [fs_config_filesystemlist_delete_filesystem config]
                if { $result != 0 } { wait_for_enter }
                }
             10 { set not_ready 0 }
             }
             }
         }

   # check filesystem configuration
   ts_log_finest "fs_config_filesystemlist:"
   foreach fs $config(fsname_list) { ts_log_finest "checking filesystem \"$fs\" ... " }

   return $config(fsname_list)
}

#****** config_filesystem/fs_config_filesystemlist_show_filesystems() ****************
#  NAME
#     fs_config_filesystemlist_show_filesystems() -- show testsuite filesystem 
#                                                configuration
#
#  SYNOPSIS
#     fs_config_filesystemlist_show_filesystems { array_name } 
#
#  FUNCTION
#     This procedure will show the current testsuite filesystem configuration
#
#  INPUTS
#     array_name - ts_fs_config
#
#  RESULT
#     the list of configured filesystems 
#  SEE ALSO
#     check/setup_fs_config()
#     check/verify_fs_config()
#*******************************************************************************
proc fs_config_filesystemlist_show_filesystems { array_name } {
   upvar $array_name config

   puts "\nFilesystem list:\n"
   if { [llength $config(fsname_list)] == 0 } {
      puts "no filesystems defined"
      return ""
   }

   set index 0
   foreach fs $config(fsname_list) {
      incr index 1 
      puts "($index) $fs     (Server: $config($fs,fsserver), Type: $config($fs,fstype), Root2Nobody: $config($fs,fssuwrite), Root login: $config($fs,fssulogin))"
   }
   return $config(fsname_list)
}

#****** config_filesystem/fs_config_get_filesystem_parameters() ********************
#  NAME
#     fs_config_get_filesystem_parameters() -- get the list of filesystem parameters
#
#  SYNOPSIS
#     fs_config_get_filesystem_parameters { } 
#
#  FUNCTION
#     get the list of all parameters needed to configure a filesystem entry 
#
#  RESULT
#     the list of filesystem parameters
#
#*******************************************************************************
proc fs_config_get_filesystem_parameters { } {

   set params ""
   lappend params fsserver 
   lappend params fstype 
   lappend params fssuwrite 
   lappend params fssulogin 

   return $params
}

#****** config_filesystem/fs_config_filesystemlist_add_filesystem() ******************
#  NAME
#     fs_config_filesystemlist_add_filesystem() -- add filesystem to filesystem 
#                                              configuration
#
#  SYNOPSIS
#     fs_config_filesystemlist_add_filesystem { array_name { have_filesystem "" } } 
#
#  FUNCTION
#     Add filesystem to testsuite filesystem configuration
#
#  INPUTS
#     array_name       - ts_fs_config
#     { have_filesystem "" } - if not "": add this filesystem 
#
#  SEE ALSO
#     check/setup_fs_config()
#     check/verify_fs_config()
#
#*******************************************************************************
proc fs_config_filesystemlist_add_filesystem { array_name { have_filesystem "" } } {

   upvar $array_name config
   global ts_config CHECK_USER
  
   if { $have_filesystem == "" } {
      clear_screen
      puts "\nAdd filesystem to global filesystem configuration"
      puts "================================================="
      fs_config_filesystemlist_show_filesystems config
      puts "\n"
      puts -nonewline "Enter new filesystem path: "
      set new_filesystem [wait_for_enter 1]
   } else { set new_filesystem $have_filesystem }

   if { [ string length $new_filesystem ] == 0 } {
      puts "no filesystem entered"
      return -1
   }
   
   if { [ file isdirectory $new_filesystem ] == 0 } {
      puts "invalid filesystem path entered, directory does not exist"
      return -1
   }
  
   if { [ lsearch $config(fsname_list) $new_filesystem ] >= 0 } {
      puts "filesystem \"$new_filesystem\" is already in list"
      return -1
   }

   lappend config(fsname_list) $new_filesystem
   foreach param [fs_config_get_filesystem_parameters] {
      set config($new_filesystem,$param)      ""
      switch -- $param {
         "fsserver" {
            if {$have_filesystem == ""} {
               set input_ok 0
               while {$input_ok != 1} {
                  puts "\n"
                  puts -nonewline "Enter filesystem servername: "
                  set new_servername [wait_for_enter 1]
                  if {[string compare $new_servername ""] != 0} {
                     set input_ok 1
                  }
               }
            }
            set config($new_filesystem,$param)      "$new_servername"
         }

         "fstype" {
            if {$have_filesystem == ""} {
               set input_ok 0
               while {$input_ok != 1} {
                  puts "\n"
                  puts -nonewline "Enter a supported filesystemtype (nfs,nfs4,xfs,ufs,ext,ext2,ext3,zfs): "
                  set new_fstype [wait_for_enter 1]
                  foreach choice [fs_config_get_supported_filesystem_list] {
                     if {[string compare $new_fstype $choice] == 0} {
                        set input_ok 1
                        break
                     }  
                  }
               }
            }
            set config($new_filesystem,$param)      "$new_fstype"
            
         }

         "fssuwrite" {
            if {$have_filesystem == ""} {
               set input_ok 0
               while {$input_ok != 1} {
                  puts "\n"
                  puts -nonewline "Filesystem Root2Nobody mount (y/n):"
                  set new_fssuwrite [wait_for_enter 1]
                  if {[string compare $new_fssuwrite "y"] == 0 || [string compare $new_fssuwrite "n"] == 0} {
                     set input_ok 1
                  }
               }
            }
            set config($new_filesystem,$param)      "$new_fssuwrite"

         }

         "fssulogin" {
            if {$have_filesystem == ""} {
               set input_ok 0
               while {$input_ok != 1} {
                  puts "\n"
                  puts -nonewline "Filesystem server root login (y/n): "
                  set new_fssulogin [wait_for_enter 1]
                  if {[string compare $new_fssulogin "y"] == 0 || [string compare $new_fssulogin "n"] == 0} {
                     set input_ok 1
                  }
               }
            }
            set config($new_filesystem,$param)      "$new_fssulogin"

         }
      }
   }
   if { $have_filesystem == "" } { fs_config_filesystemlist_edit_filesystem config $new_filesystem }
   return 0   
}

#****** config_filesystem/fs_config_filesystemlist_edit_filesystem() *****************
#  NAME
#     fs_config_filesystemlist_edit_filesystem() -- edit filesystem configuration
#
#  SYNOPSIS
#     fs_config_filesystemlist_edit_filesystem { array_name { have_filesystem "" } } 
#
#  FUNCTION
#     This procedure is used to edit the testsuite filesystem configuration
#
#  INPUTS
#     array_name       - ts_fs_config
#     { have_filesystem "" } - if not "": add this filesystem 
#
#  SEE ALSO
#     check/setup_fs_config()
#     check/verify_fs_config()
#
#*******************************************************************************
proc fs_config_filesystemlist_edit_filesystem { array_name { have_filesystem "" } } {
   global CHECK_USER ts_fs_config
   upvar $array_name config

   set goto 0

   if { $have_filesystem != "" } { set goto $have_filesystem } 

   while { 1 } {
      clear_screen
      puts "\nEdit filesystem in global filesystem configuration"
      puts "=============================================="
      fs_config_filesystemlist_show_filesystems config
      puts "\n"
      puts -nonewline "Enter filesystem/number or return to exit: "
      if { $goto == 0 } {
         set filesystem [wait_for_enter 1]
         set goto $filesystem
      } else {
         set filesystem $goto
         ts_log_fine $filesystem
      }
 
      if { [ string length $filesystem ] == 0 } { break }
     
      if { [string is integer $filesystem] } {
         incr filesystem -1
         set filesystem [ lindex $config(fsname_list) $filesystem ]
      }

      if { [ lsearch $config(fsname_list) $filesystem ] < 0 } {
         puts "filesystem \"$filesystem\" not found in list"
         wait_for_enter
         set goto 0
         continue
      }

      fs_config_display_params $filesystem config

      puts -nonewline "Enter category to edit or hit return to exit > "
      set input [ wait_for_enter 1]
      if { [ string length $input ] == 0 } {
         set goto 0
         continue
      }

      if { [ string compare $input "filesystem"] == 0 } {
         puts "Setting \"$input\" is not allowed"
         wait_for_enter
         continue
      }

      if { [ info exists config($filesystem,$input) ] != 1 } {
         puts "Not a valid category"
         wait_for_enter
         continue
      }

      set extra 0
      if { [info exists add_param] } { array unset add_param }
      switch -- $input {
         "fsserver"     { set extra 1 }
         "fstype"       { set extra 2 }
         "fssuwrite"   { set extra 3 }
         "fssulogin"    { set extra 4 }
      }

      if { $extra == 0 } {
         puts "\nEnter new $input value: "
         set value [ wait_for_enter 1 ]
      }

      if { $extra == 1 } {
         set input_ok 0
         while {$input_ok != 1} {
            puts "\n"
            puts -nonewline "Enter filesystem servername: "
            set new_servername [wait_for_enter 1]
            if {[string compare $new_servername ""] != 0} {
               set input_ok 1
            }
         }
         set config($new_filesystem,$fsserver)      "$new_servername"
         continue
      }

      if { $extra == 2} {

         set input_ok 0
         while {$input_ok != 1} {
            puts "\n"
            puts -nonewline "Enter a supported filesystemtype (nfs,nfs4,xfs,ufs,ext,ext2,ext3,zfs): "
            set new_fstype [wait_for_enter 1]
            foreach choice [fs_config_get_supported_filesystem_list] {
               if {[string compare $new_fstype $choice] == 0} {
                  set input_ok 1
                  break
               }  
            }
         }
         set config($filesystem,fstype) $new_fstype
         continue
      }

      if { $extra == 3 } {
         set input_ok 0
         while {$input_ok != 1} {
            puts "\n"
            puts -nonewline "Filesystem Root2Nobody mount (y/n):"
            set new_fssuwrite [wait_for_enter 1]
            if {[string compare $new_fssuwrite "y"] == 0 || [string compare $new_fssuwrite "n"] == 0} {
               set input_ok 1
            }
         }
         set config($new_filesystem,fssuwrite)      "$new_fssuwrite"
         continue
      }

      if { $extra == 4 } {
         set input_ok 0
         while {$input_ok != 1} {
            puts "\n"
            puts -nonewline "Filesystem server root login (y/n): "
            set new_fssulogin [wait_for_enter 1]
            if {[string compare $new_fssulogin "y"] == 0 || [string compare $new_fssulogin "n"] == 0} {
               set input_ok 1
            }
         }
         set config($new_filesystem,fssulogin)      "$new_fssulogin"
         continue
      }
   }
   return 0   
}

#****** config_filesystem/fs_config_filesystemlist_delete_filesystem() ***************
#  NAME
#     fs_config_filesystemlist_delete_filesystem() -- delete filesystem from filesystem 
#                                                 configuration
#
#  SYNOPSIS
#     fs_config_filesystemlist_delete_filesystem { array_name } 
#
#  FUNCTION
#     This procedure is called to delete filesystem from the filesystem configuration.
#
#
#  INPUTS
#     array_name       - ts_fs_config
#
#  SEE ALSO
#     check/setup_fs_config()
#     check/verify_fs_config()
#
#*******************************************************************************
proc fs_config_filesystemlist_delete_filesystem { array_name } {
   upvar $array_name config

   while { 1 } {

      clear_screen
      puts "\nDelete filesystem from global filesystem configuration"
      puts "=================================================="
      fs_config_filesystemlist_show_filesystems config
      puts "\n"
      puts -nonewline "Enter filesystem/number or return to exit: "
      set filesystem [wait_for_enter 1]
 
      if { [ string length $filesystem ] == 0 } { break }
     
      if { [string is integer $filesystem] } {
         incr filesystem -1
         set filesystem [ lindex $config(fsname_list) $filesystem ]
      }

      if { [ lsearch $config(fsname_list) $filesystem ] < 0 } {
         puts "\"$filesystem\" not found in list"
         wait_for_enter
         continue
      }

      fs_config_display_params $filesystem config

      puts -nonewline "Delete this filesystem? (y/n): "
      set input [ wait_for_enter 1]
      if { [ string length $input ] == 0 } {
         continue
      }
 
      if { [ string compare $input "y"] == 0 } {
         set index [lsearch $config(fsname_list) $filesystem]
         set config(fsname_list) [ lreplace $config(fsname_list) $index $index ]
         foreach param [fs_config_get_filesystem_parameters] {
            unset config($filesystem,$param)
         }
         wait_for_enter
         continue
      }
   }
   return 0   
}

#****** config_filesystem/verify_fs_config() *************************************
#  NAME
#     verify_fs_config() -- verify testsuite filesystem configuration setup
#
#  SYNOPSIS
#     verify_fs_config { config_array only_check parameter_error_list 
#     { force 0 } } 
#
#  FUNCTION
#     This procedure will verify or enter filesystem setup configuration
#
#  INPUTS
#     config_array         - array name with configuration (ts_fs_config)
#     only_check           - if 1: don't ask user, just check
#     parameter_error_list - returned list with error information
#     { force_params "" }  - the list of parameters to edit
#                            for allowed values see the configured parameters
#                            in filesystem configuration
#
#  RESULT
#     number of errors
#
#  SEE ALSO
#     check/verify_host_config()
#     check/verify_user_config()
#     check/verify_config()
#     
#*******************************************************************************
proc verify_fs_config { config_array only_check parameter_error_list { force_params "" } } {

   global actual_ts_fs_config_version be_quiet
   upvar $config_array config
   upvar $parameter_error_list error_list

   set errors 0
   set error_list ""

   if { [ info exists config(version) ] != 1 } {
      puts "Could not find version info in filesystem configuration file"
      lappend error_list "no version info"
      incr errors 1
      return -1
   }

   if { $config(version) != $actual_ts_fs_config_version } {
      ts_log_severe "Filesystem configuration file version \"$config(version)\" not supported."
      ts_log_severe "Expected version is \"$actual_ts_filesystem_config_version\""
      lappend error_list "unexpected version"
      incr errors 1
      return -1
   } else { ts_log_finest "Filesystem Configuration Version: $config(version)" }

   set elem "fsname_"
   set not_init ""
   foreach path $config(${elem}list) {
      foreach parami [fs_config_get_filesystem_parameters] {
         if { [string compare $config($path,$parami) ""] == 0 } {
            lappend not_init "$parami"
         }

      set found_type 0 
      foreach supported_fs_type [fs_config_get_supported_filesystem_list] {
         if { [string compare $config($path,fstype) $supported_fs_type] == 0 } {
            set found_type 1
            break 
         }
      }
      if { $found_type == 0 } {
         puts  $config($path,fstype)
         puts $supported_fs_type
         ts_log_severe "Found a unsupported fstype within the filesystem configuration!!!"
         incr errors 1 
         break
      }
   }
   if { [string length $not_init] != 0 } {
         ts_log_warning "no value for $name value(s): $not_init"
         incr errors 1
      }
   }

   set max_pos [get_configuration_element_count config]
   set uninitalized ""
   if { $be_quiet == 0 } { puts "" }

   for { set param 1 } { $param <= $max_pos } { incr param 1 } {
      set par [ get_configuration_element_name_on_pos config $param ]
      if { $be_quiet == 0 } { 
         puts -nonewline "      $config($par,desc) ..."
      }
      if { $config($par) == "" || [lsearch -exact $force_params $par] >= 0 } {
         ts_log_finest "not initialized or forced!"
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
         } else {
            if { [info procs $procedure_name ] != $procedure_name } {
               ts_log_warning "unkown procedure name: \"$procedure_name\" !!!"
               lappend uninitalized $param
               if { $only_check == 0 } { wait_for_enter }
            } else {
               # call procedure only_check == 1
               ts_log_finest "starting >$procedure_name< (verify mode) ..."
               set value [ $procedure_name 1 $par config ]
               if { $value == -1 } {
                  incr errors 1
                  lappend error_list $par
                  ts_log_warning "verify error in procedure \"$procedure_name\" !!!"
                  lappend uninitalized $param
               }
            }
         }
      }
      if { $be_quiet == 0 } { puts "\r      $config($par,desc) ... ok" }
      }
   if { [set count [llength $uninitalized]] != 0 && $only_check == 0 } {
      ts_log_warning "$count parameters are not initialized!"
      puts "Entering setup procedures ..."
      wait_for_enter
      
      foreach pos $uninitalized {
         set p_name [get_configuration_element_name_on_pos config $pos]
         set procedure_name  $config($p_name,setup_func)
         set default_value   $config($p_name,default)
       
         ts_log_finest "Starting configuration procedure for parameter \"$p_name\" ($config($p_name,pos)) ..."
         set use_default 0
         if { [string length $procedure_name] == 0 } {
            ts_log_fine "no procedure defined"
            continue
         } else {
            if { [info procs $procedure_name ] != $procedure_name } {
               ts_log_warning "unkown procedure name: \"$procedure_name\" !!!"
               if { $only_check == 0 } { wait_for_enter }
               set use_default 1
            }
         } 

         if { $use_default != 0 } {
            # check again if we have value ( force flag) 
            if { $config($p_name) == "" } {
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
         wait_for_enter
      } 
   }
   return $errors
}

#****** config_filesystem/setup_fs_config() **************************************
#  NAME
#     setup_fs_config() -- testsuite filesystem configuration initalization
#
#  SYNOPSIS
#     setup_fs_config { file { force 0 } } 
#
#  FUNCTION
#     This procedure will initalize the testsuite filesystem configuration
#
#  INPUTS
#     file        - filesystem filesystem file
#     { force_params "" }  - the list of parameters to edit
#                            for allowed values see the configured parameters
#                            in filesystem configuration
#
#  SEE ALSO
#
#*******************************************************************************
proc setup_fs_config { file { force_params "" }} {
   global ts_fs_config actual_ts_fs_config_version do_nomain
   global fast_setup

   if { [read_array_from_file $file "testsuite filesystem configuration" ts_fs_config ] == 0 } {
      if { $ts_fs_config(version) != $actual_ts_fs_config_version } {
         ts_log_fine "unknown filesystem configuration file version: $ts_fs_config(version)"
         exit -1
      }

      # got config
      if { $do_nomain == 0 } {
         if { [verify_fs_config ts_fs_config 1 err_list $force_params ] != 0 } {
            # configuration problems
            foreach elem $err_list { ts_log_fine "$elem" } 
            set not_ok 1
            while { $not_ok } {
               if { [verify_fs_config ts_fs_config 0 err_list $force_params ] != 0 } {
                  set not_ok 1
                  ts_log_fine "Filesystem configuration error. Stop."
                  foreach elem $err_list {
                     ts_log_fine "error in: $elem"
                  } 
                  ts_log_fine "try again? (y/n)"
                  set answer [wait_for_enter 1]
                  if { $answer == "n" } {
                     ts_log_fine "Do you want to save your changes? (y/n)"
                     set answer [wait_for_enter 1]
                     if { $answer == "y" } {
                        if { [ save_fs_configuration $file] != 0} {
                           ts_log_fine "Could not save filesystem configuration"
                           wait_for_enter
                        }
                     }
                     return
                  } else { continue }
               } else { set not_ok 0 }
                  }
            if { [ save_fs_configuration $file] != 0} {
               ts_log_fine "Could not save filesystem configuration"
               wait_for_enter
               return
            }

         }
         if { [string compare $force_params ""] != 0 } {
            if { [ save_fs_configuration $file] != 0} {
               ts_log_fine "Could not save filesystem configuration"
               wait_for_enter
            }
         }
         return
      }
      return 
   } else {
      ts_log_fine "could not open filesystem config file \"$file\""
      ts_log_fine "press return to create new filesystem configuration file"
      wait_for_enter 1
      if { [ save_fs_configuration $file] != 0} {
         return -1
      }
      setup_fs_config $file
   }
}

#****** config_filesystem/fs_config_get_filesystemlist() ***********************
#  NAME
#     fs_config_get_filesystemlist() -- get the filesystem list
#
#  SYNOPSIS
#     fs_config_get_filesystemlist { config_array result_array {port_type ""} } 
#
#  FUNCTION
#     Gets the array of filesystem configured in filesystem configuration
#
#  INPUTS
#     config_array - ts_fs_config
#     result_array - result array
#
#  RESULT
#     the list of filesystem 
#
#  SEE ALSO
#     config/config_generic()
#*******************************************************************************
proc fs_config_get_filesystemlist {config_array result_array} {

   upvar $config_array config
   upvar $result_array fs_list

   if {![array exists fs_list]} {
      array set fs_list {} 
   }

   foreach fs $config(fsname_list) {
      set fs_list($fs) "($config($fs,fspath) at $config($fs,fsserver))"
   }
   return [array names fs_list]
}

#****** config_filesystem/fs_config_has_root_write_perm_on_fs() ***************
#  NAME
#     fs_config_has_root_write_perm_on_fs() -- get root write permission info 
#
#  SYNOPSIS
#     fs_config_has_root_write_perm_on_fs {filesysstem_name} 
#
#  FUNCTION
#     Gets the root write permission flag from filesystem configurationfor given 
#     filesystem name 
#
#  INPUTS
#     filesysstem_name - this is the path of the filesystem (e.g. /scratch3/tmp)
#
#  RESULT
#     the the root write permission flag:    0 - if root has no permission to write 
#                                                to this filesystem  
#                                            1 - if root has write permission
#  ERROR
#     throwing a ts_log_servere, if any entry is not found. Empty fields are not 
#     possible, this is check from the configuration verification. Adding empty 
#     fields is also not possilbe, this is also checked.
#
#  SEE ALSO
#*******************************************************************************
proc fs_config_has_root_write_perm_on_fs {filesystem_name} {

   global ts_fs_config

   set ret 0
   set filesystem_found 0
   foreach fs $ts_fs_config(fsname_list) {
      if {[have_dirs_same_base_dir $fs $filesystem_name] == 1} {
         set filesystem_found 1
         set result $ts_fs_config($fs,fssuwrite)
         if {$result == 1 || $result == "y"} {
            set ret 1
         }
         break
      } 
   }
   if {$filesystem_found == 0} {
      ts_log_severe "Filesystem $filesystem_name not found in filesystem configuration!!!"
   }
   return $ret
}

#****** config_filesystem/fs_config_has_root_login_perm_on_nfs_server() *******
#  NAME
#     fs_config_has_root_login_perm_on_nfs_server() -- get root login permission
#                                                      for nfs server info 
#
#  SYNOPSIS
#     fs_config_has_root_login_perm_on_nfs_server {filesysstem_name} 
#
#  FUNCTION
#     Gets the root nfs server login permission flag for given filesystem name 
#
#  INPUTS
#     filesysstem_name - this is the path of the filesystem (e.g. /scratch3/tmp)
#
#  RESULT
#     the the root write permission flag:    0 - if root has no permission to login 
#                                                to this nfs server  
#                                            1 - if root has permission to login
#  ERROR
#     throwing a ts_log_servere, if any entry is not found. Empty fields are not 
#     possible, this is check from the configuration verification. Adding empty 
#     fields is also not possilbe, this is also checked.
#
#  SEE ALSO
#*******************************************************************************
proc fs_config_has_root_login_perm_on_nfs_server {filesystem_name} {

   global ts_fs_config

   set ret 0
   set filesystem_found 0
   foreach fs $ts_fs_config(fsname_list) {
      if {[have_dirs_same_base_dir $fs $filesystem_name] == 1} {
         set filesystem_found 1
         set result $ts_fs_config($fs,fssulogin)
         if {$result == 1 || $result == "y"} {
            set ret 1
         }
         break
      } 
   }
   if {$filesystem_found == 0} {
      ts_log_severe "Filesystem $filesystem_name not found in filesystem configuration!!!"
   }
   return $ret
}

#****** config_filesystem/fs_config_get_filesystem_type() ***********************
#  NAME
#     fs_config_get_filesystem_type() -- get filesystem type for given filesystem 
#
#  SYNOPSIS
#     fs_config_get_filesystem_type {filesysstem_name} 
#
#  FUNCTION
#     Gets the filesystem type given filesystem name 
#
#  INPUTS
#     filesysstem_name - this is the path of the filesystem (e.g. /scratch3/tmp)
#
#  RESULT
#     returns :    filesystem type eg nfs, nfs4, ufs  
#                                 
#  ERROR
#     throwing a ts_log_servere, if any entry is not found. Empty fields are not 
#     possible, this is check from the configuration verification. Adding empty 
#     fields is also not possilbe, this is also checked.
#
#  SEE ALSO
#*******************************************************************************
proc fs_config_get_filesystem_type {filesystem_name} {

   global ts_fs_config

   set ret ""
   set filesystem_found 0
   foreach fs $ts_fs_config(fsname_list) {
      if {[have_dirs_same_base_dir $fs $filesystem_name] == 1} {
         set filesystem_found 1
         set ret $ts_fs_config($fs,fstype)
         break
      } 
   }
   if {$filesystem_found == 0} {
      ts_log_severe "Filesystem $filesystem_name not found in filesystem configuration!!!"
   }
   return $ret
}

#****** config_filesystem/fs_config_get_filesystem_server() *********************
#  NAME
#     fs_config_get_filesystem_server() -- get server name for given filesystem 
#
#  SYNOPSIS
#     fs_config_get_filesystem_server {filesysstem_name} 
#
#  FUNCTION
#     Gets the filesystem server name for the given filesystem name 
#
#  INPUTS
#     filesysstem_name - this is the path of the filesystem (e.g. /scratch3/tmp)
#
#  RESULT
#     returns :    the hostname of the server, were the given filesystem is exported 
#                                 
#  ERROR
#     throwing a ts_log_servere, if any entry is not found. Empty fields are not 
#     possible, this is check from the configuration verification. Adding empty 
#     fields is also not possilbe, this is also checked.
#
#  SEE ALSO
#*******************************************************************************
proc fs_config_get_filesystem_server {filesystem_name} {

   global ts_fs_config

   set ret ""
   set filesystem_found 0
   foreach fs $ts_fs_config(fsname_list) {
      if {[have_dirs_same_base_dir $fs $filesystem_name] == 1} {
         set filesystem_found 1
         set ret $ts_fs_config($fs,fsserver)
         break
      } 
   }
   if {$filesystem_found == 0} {
      ts_log_severe "Filesystem $filesystem_name not found in filesystem configuration!!!"
   }
   return $ret
}

#****** config_filesystem/fs_config_get_filesystemlist_by_fstype() **************
#  NAME
#     fs_config_get_filesystemlist_by_fstype() -- get a list of filesystems with 
#                                                 given type 
#
#  SYNOPSIS
#     fs_config_get_filesystemlist_by_fstype {filesysstem_type} 
#
#  FUNCTION
#     Gets list of filesystems with given filesystem_type 
#
#  INPUTS
#     filesysstem_tpye - this is the type of the filesystem (e.g. nfs, nfs4,...)
#
#  RESULT
#     returns :   a list of filesystems 
#                                 
#  ERROR
#     throwing a ts_log_servere, if any entry is not found. Empty fields are not 
#     possible, this is check from the configuration verification. Adding empty 
#     fields is also not possilbe, this is also checked.
#
#  SEE ALSO
#*******************************************************************************
proc fs_config_get_filesystemlist_by_fstype {filesystem_type} {

   global ts_fs_config

   array set ret {} 
   set filesystem_type_found 0
   foreach fs $ts_fs_config(fsname_list) {
      if {[string compare $ts_fs_config($fs,fstype) $filesystem_type] == 0} {
         set filesystem_type_found 1 
         set ret($fs) $ts_fs_config($fs,fstype)
      }
   }
   if {$filesystem_type_found == 0} {
      ts_log_severe "Filesystemtype $filesystem_type not found in filesystem configuration!!!"
   }
   return [array names ret]
}

#****** config_filesystem/fs_config_get_supported_filesystem_list **************
#  NAME
#     fs_config_get_supported_filesystem_list() -- get a list of currently supported 
#                                                  filesystem_types 
#
#  SYNOPSIS
#     fs_config_get_supported_filesystem_list{} 
#
#  FUNCTION
#     Gets list of supported filesystem_types 
#
#  INPUTS
#      --- 
#
#  RESULT
#     returns :   a list of filesystem types 
#                                 
#
#  SEE ALSO
#*******************************************************************************
proc fs_config_get_supported_filesystem_list { } {

   set supported_fs_types {}

   lappend supported_fs_types "nfs"
   lappend supported_fs_types "nfs4"
   lappend supported_fs_types "xfs"
   lappend supported_fs_types "ufs"
   lappend supported_fs_types "ext"
   lappend supported_fs_types "ext2"
   lappend supported_fs_types "ext3"
   lappend supported_fs_types "zfs"

   return $supported_fs_types
}
