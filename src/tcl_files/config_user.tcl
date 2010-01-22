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


global ts_user_config                  ;# new testsuite user configuration array
global actual_ts_user_config_version        ;# actual user config version number
set    actual_ts_user_config_version "1.0"

if {![info exists ts_user_config]} {
   # ts_user_config defaults
   set parameter "version"
   set ts_user_config($parameter)            "$actual_ts_user_config_version"
   set ts_user_config($parameter,desc)       "Testuite user configuration setup"
   set ts_user_config($parameter,default)    "$actual_ts_user_config_version"
   set ts_user_config($parameter,setup_func) ""
   set ts_user_config($parameter,onchange)   "stop"
   set ts_user_config($parameter,pos)        1

   set parameter "userlist"
   set ts_user_config($parameter)            ""
   set ts_user_config($parameter,desc)       "Grid Engine cluster user list"
   set ts_user_config($parameter,default)    ""
   set ts_user_config($parameter,setup_func) "user_config_$parameter"
   set ts_user_config($parameter,onchange)   ""
   set ts_user_config($parameter,pos)        2

   set parameter "first_foreign_user"
   set ts_user_config($parameter)            ""
   set ts_user_config($parameter,desc)       "First testsuite cluster user name"
   set ts_user_config($parameter,default)    ""
   set ts_user_config($parameter,setup_func) "user_config_$parameter"
   set ts_user_config($parameter,onchange)   ""
   set ts_user_config($parameter,pos)        3

   set parameter "second_foreign_user"
   set ts_user_config($parameter)            ""
   set ts_user_config($parameter,desc)       "Second testsuite cluster user name"
   set ts_user_config($parameter,default)    ""
   set ts_user_config($parameter,setup_func) "user_config_$parameter"
   set ts_user_config($parameter,onchange)   ""
   set ts_user_config($parameter,pos)        4
    
   set parameter "first_foreign_group"
   set ts_user_config($parameter)            ""
   set ts_user_config($parameter,desc)       "First testsuite cluster user's group names"
   set ts_user_config($parameter,default)    ""
   set ts_user_config($parameter,setup_func) "user_config_$parameter"
   set ts_user_config($parameter,onchange)   ""
   set ts_user_config($parameter,pos)        5

   set parameter "second_foreign_group"
   set ts_user_config($parameter)            ""
   set ts_user_config($parameter,desc)       "Second testsuite cluster user's group name"
   set ts_user_config($parameter,default)    ""
   set ts_user_config($parameter,setup_func) "user_config_$parameter"
   set ts_user_config($parameter,onchange)   ""
   set ts_user_config($parameter,pos)        6
}

#****** config_user/user_config_first_foreign_user() ***************************
#  NAME
#     user_config_first_foreign_user() -- edit first foreign user
#
#  SYNOPSIS
#     user_config_first_foreign_user { only_check name config_array } 
#
#  FUNCTION
#     Testsuite user configuration setup - called from verify_user_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_user_config array)
#     config_array - config array name (ts_user_config)
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#
#*******************************************************************************
proc user_config_first_foreign_user { only_check name config_array } {
   global CHECK_USER
   global CHECK_FIRST_FOREIGN_SYSTEM_USER
   global CHECK_SECOND_FOREIGN_SYSTEM_USER

   upvar $config_array config
   
   set help_text { "Enter the name of the first testsuite user. This user must"
                   "have access to the testsuite directory and must exist on all"
                   "cluster hosts."
                   "This user must differ from the actual check user and from"
                   "the second testsuite user."
                   "Press >RETURN< to use the default value." }

   array set params {}
   set params(exclude_list) "$CHECK_USER"
      if { [ info exists CHECK_SECOND_FOREIGN_SYSTEM_USER ] } {
      lappend params(exclude_list) "$CHECK_SECOND_FOREIGN_SYSTEM_USER"
         }
   set value [config_generic $only_check $name config $help_text "user" 0 1 "" params]
      
   if { $value != -1 } { set CHECK_FIRST_FOREIGN_SYSTEM_USER $value }

   return $value
}

#****** config_user/user_config_second_foreign_user() **************************
#  NAME
#     user_config_second_foreign_user() -- setup second foreign user
#
#  SYNOPSIS
#     user_config_second_foreign_user { only_check name config_array } 
#
#  FUNCTION
#     Testsuite user configuration setup - called from verify_user_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_user_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#
#*******************************************************************************
proc user_config_second_foreign_user { only_check name config_array } {
   global CHECK_USER
   global CHECK_SECOND_FOREIGN_SYSTEM_USER
   global CHECK_FIRST_FOREIGN_SYSTEM_USER
   global fast_setup
   upvar $config_array config
   
   set help_text { "Enter the name of the second testsuite user. This user must"
                   "have access to the testsuite directory and must exist on all"
                   "cluster hosts."
                   "This user must differ from the actual check user and from"
                   "the first testsuite user."
                   "Press >RETURN< to use the default value." }

   array set params {}
   set params(exclude_list) "$CHECK_USER"
      if { [ info exists CHECK_FIRST_FOREIGN_SYSTEM_USER ] } {
      lappend params(exclude_list) "$CHECK_FIRST_FOREIGN_SYSTEM_USER"
         }

   set value [config_generic $only_check $name config $help_text "user" 0 1 "" params]

   if { $value != -1 } { set CHECK_SECOND_FOREIGN_SYSTEM_USER $value }

   return $value
}

#****** config_user/user_config_first_foreign_group() **************************
#  NAME
#     user_config_first_foreign_group() -- first foreign user configuration setup
#
#  SYNOPSIS
#     user_config_first_foreign_group { only_check name config_array } 
#
#  FUNCTION
#     Testsuite user configuration setup - called from verify_user_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_user_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#
#*******************************************************************************
proc user_config_first_foreign_group { only_check name config_array } {
   global CHECK_USER
   global CHECK_FIRST_FOREIGN_SYSTEM_GROUP CHECK_FIRST_FOREIGN_SYSTEM_USER
   global CHECK_SECOND_FOREIGN_SYSTEM_GROUP
   global fast_setup

   upvar $config_array config
   
   set help_text { "Enter the name of main group, and additional group where user"
                   "$CHECK_FIRST_FOREIGN_SYSTEM_USER is a member."
                   "First testsuite user's group must differ from the second"
                   "testsuite user's group."
                   "Seperate the names by space."
                   "Press >RETURN< to use the default value." }

   array set params {}
   if { [info exists CHECK_SECOND_FOREIGN_SYSTEM_GROUP ] } {
      lappend params(exclude_list) "$CHECK_SECOND_FOREIGN_SYSTEM_GROUP"
   }

   set value [config_generic $only_check $name config $help_text "string" 0 "!2" "" params]

   if { $value == -1 } { return -1 }
   
   # now verify
   if { !$fast_setup } {
      set local_host [gethostname]
      if {$local_host == "unknown"} {
         puts "Could not get local host name" 
           return -1
      }

      set group1 [lindex $value 0]
      set group2 [lindex $value 1]
      
      set result [start_remote_prog $local_host $CHECK_USER "id" "$CHECK_FIRST_FOREIGN_SYSTEM_USER" prg_exit_state 60 0 "" "" 1 0]
      ts_log_finest $result
      if { [string first $group1 $result ] < 0 } {
         puts "first testsuite user ($CHECK_FIRST_FOREIGN_SYSTEM_USER) has not \"$group1\" as main group"
         return -1
      }

      set result [start_remote_prog $local_host $CHECK_USER "groups" "$CHECK_FIRST_FOREIGN_SYSTEM_USER" prg_exit_state 60 0 "" "" 1 0]
      ts_log_finest $result
      if { $prg_exit_state == 0 } {
         if { [string first $group2 $result] < 0 } { 
            puts "first testsuite user ($CHECK_FIRST_FOREIGN_SYSTEM_USER) has not \"$group2\" as secondary group"
            return -1
         }
      }

      }

   # set global variables to value
   set CHECK_FIRST_FOREIGN_SYSTEM_GROUP $value

   return $value
}

#****** config_user/user_config_second_foreign_group() *************************
#  NAME
#     user_config_second_foreign_group() -- setup second foreign group
#
#  SYNOPSIS
#     user_config_second_foreign_group { only_check name config_array } 
#
#  FUNCTION
#     Testsuite user configuration setup - called from verify_user_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_user_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#
#*******************************************************************************
proc user_config_second_foreign_group { only_check name config_array } {
   global CHECK_USER
   global CHECK_FIRST_FOREIGN_SYSTEM_GROUP CHECK_SECOND_FOREIGN_SYSTEM_USER
   global CHECK_SECOND_FOREIGN_SYSTEM_GROUP do_nomain
   global fast_setup

   upvar $config_array config
   
   set help_text { "Enter the name of main group where user"
                   "$CHECK_SECOND_FOREIGN_SYSTEM_USER is a member."
                   "Second testsuite user's group must differ from the first"
                   "testsuite user's groups."
                   "Press >RETURN< to use the default value." }

  array set params {}
   if { [info exists CHECK_FIRST_FOREIGN_SYSTEM_GROUP ] } {
      lappend params(exclude_list) "$CHECK_FIRST_FOREIGN_SYSTEM_GROUP"
   }

   set value [config_generic $only_check $name config $help_text "string" 0 1 "" params]

   if { $value == -1 } { return -1 }

   if { !$fast_setup } {
   set local_host [gethostname]
   if {$local_host == "unknown"} {
         puts "Could not get local host name" 
      return -1
   }

      set result [start_remote_prog $local_host $CHECK_USER "id" "$CHECK_SECOND_FOREIGN_SYSTEM_USER" prg_exit_state 60 0 "" "" 1 0]
      ts_log_finest $result
      if { [string first $value $result ] < 0 && $do_nomain == 0 } {
         puts "second testsuite user ($CHECK_SECOND_FOREIGN_SYSTEM_USER) has not \"$value\" as main group"
         return -1
      }
      }

   # set global variables to value
   set CHECK_SECOND_FOREIGN_SYSTEM_GROUP $value

   return $value
}

#****** config_user/user_config_userlist() *************************************
#  NAME
#     user_config_userlist() -- user list setup
#
#  SYNOPSIS
#     user_config_userlist { only_check name config_array } 
#
#  FUNCTION
#     Testsuite user configuration setup - called from verify_user_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_user_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#
#*******************************************************************************
proc user_config_userlist { only_check name config_array } {
   global CHECK_USER
   global CHECK_REMOTE_ENVIRONMENT
   
   upvar $config_array config

   set description   $config($name,desc)

   if { $only_check == 0 } {
       set not_ready 1
       while { $not_ready } {
          clear_screen
          puts "\nGlobal user configuration setup"
          puts "==============================="
          puts "\n\n    users configured: [llength $config(userlist)]"
          user_config_userlist_show_users config
          puts "\n\n(1)  add user"
          puts "(2)  edit user"
          puts "(3)  delete user"
          puts "(10) exit setup"
          puts -nonewline "> "
          set input [ wait_for_enter 1]
          switch -- $input {
             1 {
                set result [user_config_userlist_add_user config]
                if { $result != 0 } { wait_for_enter }
                }
             2 {
                set result [user_config_userlist_edit_user config]
                if { $result != 0 } { wait_for_enter }
                }
             3 {
               set result [user_config_userlist_delete_user config]
                if { $result != 0 } { wait_for_enter }
                }
             10 { set not_ready 0 }
             }
             }
          } 

   # check user configuration
   ts_log_finest "user_config_userlist:"
   foreach user $config(userlist) { ts_log_finest "checking user \"$user\" ... " }

   if { [ info exists config($CHECK_USER,envlist) ] } {
      set CHECK_REMOTE_ENVIRONMENT $config($CHECK_USER,envlist)
   } else { set CHECK_REMOTE_ENVIRONMENT "" }

   return $config(userlist)
}

#****** config_user/user_config_userlist_show_users() **************************
#  NAME
#     user_config_userlist_show_users() -- show testsuite user configuration
#
#  SYNOPSIS
#     user_config_userlist_show_users { array_name } 
#
#  FUNCTION
#     This procedure will show the current testsuite user configuration
#
#  INPUTS
#     array_name - ts_user_config
#
#  RESULT
#     the list of configured hosts
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#*******************************************************************************
proc user_config_userlist_show_users { array_name } {
   upvar $array_name config

   puts "\nUser list:\n"
   if { [llength $config(userlist)] == 0 } {
      puts "no users defined"
      return ""
   }

   set index 0
   foreach user $config(userlist) {
      incr index 1 
      puts "($index) $user (ports: $config($user,portlist))"
   }
   return $config(userlist)
}

#****** config_user/user_config_get_all_used_ports() ***************************
#  NAME
#     user_config_get_all_used_ports() -- get list containing all assigned ports
#
#  SYNOPSIS
#     user_config_get_all_used_ports { } 
#
#  FUNCTION
#     This procedure returns a list which contains all ports assigned to users
#     in the user configuration.
#
#  INPUTS
#
#  RESULT
#     tcl list with port numbers
#
#  SEE ALSO
#     config_user/user_config_get_unused_port()
#     config_user/user_config_get_all_used_ports()
#*******************************************************************************
proc user_config_get_all_used_ports {} {
   global ts_user_config
   set all_port_list {}
   foreach user $ts_user_config(userlist) {
      foreach port $ts_user_config($user,portlist) {
         lappend all_port_list $port
         # also append execd port which is qmaster port + 1
         lappend all_port_list [expr $port + 1]
      }
   } 
   return $all_port_list
}

#****** config_user/user_config_get_unused_port() ******************************
#  NAME
#     user_config_get_unused_port() -- get a not reserved port
#
#  SYNOPSIS
#     user_config_get_unused_port {{port_range "1024-65535"} {exclude_list {}}} 
#
#  FUNCTION
#     This procedure selects randomly within the specified port range. All ports
#     defined in the user configuration are excluded. It is also possible to
#     specify a list which ports should be also excluded from the range.
#
#  INPUTS
#     {port_range "1024-65535"} - allowed port range
#     {exclude_list {}}         - list with ports that are also excluded from
#                                 selection
#
#  RESULT
#     A free usable port number
#
#  SEE ALSO
#     config_user/user_config_get_unused_port()
#     config_user/user_config_get_all_used_ports()
#*******************************************************************************
proc user_config_get_unused_port {{port_range "1024-65535"} {exclude_list {}}} {
   set free_port -1
   set help [split $port_range "-"] 
   set min_port [lindex $help 0]
   set max_port [lindex $help 1]
   ts_log_finer "try to find unused port between $min_port and $max_port"
   ts_log_finer "excluded ports: $exclude_list"
   set used_ports [user_config_get_all_used_ports]

   # first try to get random port
   set range [expr $max_port - $min_port]
   set random_port [expr int(rand()*$range) + $min_port]  

   set port $random_port
   set complete 0
   
   # We start with random port.
   while {$complete == 0} {
      if {[lsearch -exact $exclude_list $port] < 0} {
         if {[lsearch -exact $used_ports $port] < 0} {
            # This port is free - fine we made it!
            set free_port $port
            break
         }
      }
      if {$port == $max_port} {
         # If port reached end of port range: start from begin
         set port $min_port
      } else {
         # Otherwise increase port and check again if this one is free
         incr port 1
      }

      # If we did a complete loop - terminate!
      if {$port == $random_port} {
         set complete 1
      }
   }
   if {$free_port == -1} {
      ts_log_severe "Cannot find a free usable port for port range $port_range"
   }
   return $free_port
}

#****** config_user/user_config_userlist_add_user() ****************************
#  NAME
#     user_config_userlist_add_user() -- add user to user configuration
#
#  SYNOPSIS
#     user_config_userlist_add_user { array_name { have_user "" } } 
#
#  FUNCTION
#     Add user to testsuite user configuration
#
#  INPUTS
#     array_name       - ts_user_config
#     { have_user "" } - if not "": add this user
#
#  RESULT
#     -1 error
#      0 ok
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#*******************************************************************************
proc user_config_userlist_add_user { array_name { have_user "" } } {
   global CHECK_USER
  
   upvar $array_name config
  
   if { $have_user == "" } {
      clear_screen
      puts "\nAdd user to global user configuration"
      puts "====================================="
      user_config_userlist_show_users config
      puts -nonewline "\nEnter new username: "
      set new_user [wait_for_enter 1]
   } else { set new_user $have_user }

   if { [ string length $new_user ] == 0 } {
      puts "no username entered"
      return -1
   }
     
   if { [ lsearch $config(userlist) $new_user ] >= 0 } {
      puts "user \"$new_user\" is already in list"
      return -1
   }

   lappend config(userlist) $new_user
   set config($new_user,portlist) ""
   set config($new_user,envlist)  ""
   if { $have_user == "" } { user_config_userlist_edit_user config $new_user }
   return 0   
}

#****** config_user/user_config_userlist_edit_user() ***************************
#  NAME
#     user_config_userlist_edit_user() -- edit user configuration
#
#  SYNOPSIS
#     user_config_userlist_edit_user { array_name { has_user "" } } 
#
#  FUNCTION
#     This procedure is used to edit the testsuite user configuration
#
#  INPUTS
#     array_name      - ts_user_config
#     { has_user "" } - if not "": edit this user
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#*******************************************************************************
proc user_config_userlist_edit_user { array_name { has_user "" } } {
   upvar $array_name config
   global CHECK_USER
   global CHECK_REMOTE_ENVIRONMENT

   set goto 0

   if { $has_user != "" } { set goto $has_user } 

   set local_host [gethostname]

   while { 1 } {
      clear_screen
      puts "\nEdit user in global user configuration"
      puts "======================================"   
      user_config_userlist_show_users config
      puts -nonewline "\nEnter username/number or return to exit: "
      if { $goto == 0 } {
         set user [wait_for_enter 1]
         set goto $user
      } else {
         set user $goto
         puts $user
      }
 
      if { [ string length $user ] == 0 } { break }
     
      if { [string is integer $user] } {
         incr user -1
         set user [ lindex $config(userlist) $user ]
      }

      if { [ lsearch $config(userlist) $user ] < 0 } {
         puts "user \"$user\" not found in list"
         wait_for_enter
         set goto 0
         continue
      }
      puts ""
      puts "   user     : $user"
      puts "   portlist : $config($user,portlist)"
      puts "   envlist  : $config($user,envlist)"
   
      puts -nonewline "\nEnter category to edit or hit return to exit > "
      set input [ wait_for_enter 1]
      if { [ string length $input ] == 0 } {
         set goto 0
         continue
      }

      if { [ string compare $input "user"] == 0 } {
         puts "Setting \"$input\" is not allowed"
         wait_for_enter
         continue
      }

      if { [ info exists config($user,$input) ] != 1 } {
         puts "Not a valid category"
         wait_for_enter
         continue
      }

      set extra 0
      switch -- $input {
         "portlist"  { set extra 1 }
         "envlist"   { set extra 2 }
      }      

      if { $extra == 0 } {
         puts -nonewline "\nEnter new $input value: "
         set value [ wait_for_enter 1 ]
      }
      
      if { $extra == 1 } {
         puts -nonewline "\nEnter new $input value: "
         set value [ wait_for_enter 1 ]
         set errors [user_config_userlist_set_portlist config $user $value]
         if { $errors != 0 } {
            wait_for_enter
         }
         continue
      }

      if { $extra == 2 } {
         puts "The envlist has following syntax:"
         puts "variable=value \[...\] or local environment name to export e.g. DISPLAY"
         puts -nonewline "\nEnter new $input value: "
         set value [ wait_for_enter 1 ]
         set CHECK_REMOTE_ENVIRONMENT $value
         set back [ set_users_environment $local_host]
         if { $back == 0 } {
            set config($user,$input) $value
         }
         wait_for_enter
         continue
      }

      set config($user,$input) $value
   }
   return 0   
}

#****** config_user/user_config_userlist_set_portlist() ************************
#  NAME
#     user_config_userlist_set_portlist() -- set protlist for testsuite user
#
#  SYNOPSIS
#     user_config_userlist_set_portlist { array_name user value } 
#
#  FUNCTION
#     This procedure will set the portlist in the user configuration
#
#  INPUTS
#     array_name - ts_user_config
#     user       - user
#     value      - new portlist
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#
#*******************************************************************************
proc user_config_userlist_set_portlist { array_name user value } {
   global ts_user_config

   upvar $array_name config

   set had_error 0 

   set ok_value ""
   set value [ lsort $value ]
         
   foreach port $value { 
      set had_error 0 
      if { [string is integer $port ] != 1 } {
         puts "$port is not a valid port number"
         set had_error 1
      } 
      if { [info exists config($port)] } {
         if { [ string compare $config($port) $user ] != 0 } {
            puts "user \"$config($port)\" has already reserved port $port"
            set had_error 1
         }
      } 
      if { [ lsearch -exact $ok_value $port ] >= 0 } {
          puts "ignoring double entry of port $port"
          set had_error 1
      }

      if { $had_error == 0 } { lappend ok_value $port } 
      } 

   foreach port $config($user,portlist) {
      if { [lsearch -exact $ok_value $port] < 0 } {
         puts "removing port $port"
         unset config($port)
         unset config($port,$user) 
      }
   }
   set tmp_port_list ""
   foreach port $ok_value {
      set config($port) $user
      set config($port,$user) [user_config_userlist_create_gid_port config $port $user]
      set tmp_port_list "$tmp_port_list $port"
      set config($user,portlist) $tmp_port_list
   }
   set config($user,portlist) $ok_value
   return $had_error
}

#****** config_user/user_config_userlist_create_gid_port() *********************
#  NAME
#     user_config_userlist_create_gid_port() -- create gid-range for user/port
#
#  SYNOPSIS
#     user_config_userlist_create_gid_port { array_name port user } 
#
#  FUNCTION
#     Create new gid-range for user/port combination
#
#  INPUTS
#     array_name - ts_user_config
#     port       - user port
#     user       - user
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#*******************************************************************************
proc user_config_userlist_create_gid_port { array_name port user } {
   upvar $array_name config

   if { [ info exists config($port,$user) ] } {
      puts "user $user ($port) gid_range: $config($port,$user)"
      return $config($port,$user)
   }
   
   set highest_gid_start 12800
   if { [info exist config(userlist)] } {
      set userlist $config(userlist)
      foreach user_loop $userlist {
         set portlist $config($user_loop,portlist)
         foreach port_loop $portlist {
            set range $config($port_loop,$user_loop)
            set start_range [split $range "-"]
            set start_range [lindex $start_range 0]
            if { $start_range > $highest_gid_start } {
               set highest_gid_start $start_range
            }
         }
      }
   }

   set gid_start $highest_gid_start
   incr gid_start 200
   set gid_end $gid_start
   incr gid_end 199
   set gid_range "$gid_start-$gid_end"
   puts "user $user ($port) gid_range: $gid_range"
   return $gid_range
}

#****** config_user/user_config_userlist_delete_user() *************************
#  NAME
#     user_config_userlist_delete_user() -- delete user from user configuration
#
#  SYNOPSIS
#     user_config_userlist_delete_user { array_name } 
#
#  FUNCTION
#     This procedure is called to select an user from the user configuration and
#     delete it.
#
#  INPUTS
#     array_name - ts_user_config
#
#  SEE ALSO
#     check/setup_user_config()
#     check/verify_user_config()
#
#*******************************************************************************
proc user_config_userlist_delete_user { array_name } {
   upvar $array_name config
   global CHECK_USER

   while { 1 } {
      clear_screen
      puts "\nDelete user from global user configuration"
      puts "=========================================="
      user_config_userlist_show_users config
      puts -nonewline "\nEnter username/number or return to exit: "
      set user [wait_for_enter 1]
 
      if { [ string length $user ] == 0 } { break }
     
      if { [string is integer $user] } {
         incr user -1
         set user [ lindex $config(userlist) $user ]
      }

      if { [ lsearch $config(userlist) $user ] < 0 } {
         puts "user \"$user\" not found in list"
         wait_for_enter
         continue
      }

      puts ""
      puts "   user          : $user"
      puts "   portlist     : $config($user,portlist)"

      puts ""

      puts ""

      puts "\n"
      puts -nonewline "Delete this user? (y/n): "
      set input [ wait_for_enter 1]
      if { [ string length $input ] == 0 } { continue }

      if { [ string compare $input "y"] == 0 } {
         set index [lsearch $config(userlist) $user]
         set config(userlist) [ lreplace $config(userlist) $index $index ]

         foreach port $config($user,portlist) {
            puts "removing port $port"
            unset config($port)
         }
         unset config($user,portlist)
         wait_for_enter
         continue
      }
   }
   return 0   
}

#****** config_user/verify_user_config() ***************************************
#  NAME
#     verify_user_config() -- verify testsuite user configuration setup
#
#  SYNOPSIS
#     verify_user_config { config_array only_check parameter_error_list 
#     { force 0 } } 
#
#  FUNCTION
#     This procedure will verify or enter user setup configuration
#
#  INPUTS
#     config_array         - array name with configuration (ts_user_config)
#     only_check           - if 1: don't ask user, just check
#     parameter_error_list - returned list with error information
#     { force_params "" }  - the list of parameters to edit
#                            for allowed values see the configured parameters
#                            in user configuration
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
proc verify_user_config { config_array only_check parameter_error_list { force_params "" }} {
   global actual_ts_user_config_version be_quiet CHECK_USER
   upvar $config_array config
   upvar $parameter_error_list error_list

   set errors 0
   set error_list ""

   if { [ info exists config(version) ] != 1 } {
      puts "Could not find version info in user configuration file"
      lappend error_list "no version info"
      incr errors 1
      return -1
   }

   if { $config(version) != $actual_ts_user_config_version } {
      puts "User configuration file version \"$config(version)\" not supported."
      puts "Expected version is \"$actual_ts_user_config_version\""
      lappend error_list "unexpected version"
      incr errors 1
      return -1
   } else { ts_log_finest "User Configuration Version: $config(version)" }

   if { [lsearch -exact $config(userlist) $CHECK_USER] < 0 } {
      ts_log_warning "User $CHECK_USER doesn't exist in user configuration!"
      if { [lsearch -exact $force_params "userlist"] < 0 } { lappend force_params "userlist" }
   }

   set max_pos [get_configuration_element_count config]

   set uninitalized ""
   if { $be_quiet == 0 } { ts_log_fine "" }

   for { set param 1 } { $param <= $max_pos } { incr param 1 } {
      set par [ get_configuration_element_name_on_pos config $param ]
      if { $be_quiet == 0 } { 
         puts -nonewline "      $config($par,desc) ..."
         ts_log_progress
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
      if { $be_quiet == 0 } { ts_log_fine "\r      $config($par,desc) ... ok" }
      }

   if { [set count [llength $uninitalized]] != 0 && $only_check == 0 } {
      puts "$count parameters are not initialized!"
      puts "Entering setup procedures ..."
      wait_for_enter
      
      foreach pos $uninitalized {
         clear_screen
         set p_name [get_configuration_element_name_on_pos config $pos]
         set procedure_name  $config($p_name,setup_func)
         set default_value   $config($p_name,default)
       
         ts_log_finest "Starting configuration procedure for parameter \"$p_name\" ($config($p_name,pos)) ..."
         set use_default 0
         if { [string length $procedure_name] == 0 } {
            puts "no procedure defined"
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

#****** config_user/setup_user_config() ****************************************
#  NAME
#     setup_user_config() -- testsuite user configuration initalization
#
#  SYNOPSIS
#     setup_user_config { file { force 0 } } 
#
#  FUNCTION
#     This procedure will initalize the testsuite user configuration
#
#  INPUTS
#     file        - user configuration file
#     { force_params "" }  - the list of parameters to edit
#                            for allowed values see the configured parameters
#                            in host configuration
#
#  SEE ALSO
#     check/setup_host_config()
#*******************************************************************************
proc setup_user_config { file { force_params "" } } {
   global ts_user_config actual_ts_user_config_version do_nomain
   global fast_setup

   if { [read_array_from_file $file "testsuite user configuration" ts_user_config ] == 0 } {
      if { $ts_user_config(version) != $actual_ts_user_config_version } {
         puts "unkown user configuration file version: $ts_user_config(version)"
         return -1
      }

      # got config
      if { $do_nomain == 0 } {
         if { [verify_user_config ts_user_config 1 err_list $force_params ] != 0 } {
            # configuration problems
            foreach elem $err_list { puts "$elem" } 
            set not_ok 1
            while { $not_ok } {
               if { [verify_user_config ts_user_config 0 err_list $force_params ] != 0 } {
                  set not_ok 1
                  puts "User configuration error. Stop."
                  foreach elem $err_list {
                     puts "error in: $elem"
                  } 
                  puts "try again? (y/n)"
                  set answer [wait_for_enter 1]
                  if { $answer == "n" } {
                     puts "Do you want to save your changes? (y/n)"
                     set answer [wait_for_enter 1]
                     if { $answer == "y" } {
                        if { [ save_user_configuration $file] != 0} {
                           puts "Could not save user configuration"
                           wait_for_enter
                        } else {
                           # set the DISPLAY environment variable
                           if { [info exists CHECK_SET_USER_ENV_DISPLAY] &&  $CHECK_SET_USER_ENV_DISPLAY == 1 } {
                              user_config_set_env "DISPLAY" "CHECK_DISPLAY_OUTPUT"
                           }
                        }
                     }
                     return
                  } else { continue }
               } else { set not_ok 0 }
                  }
            if { [ save_user_configuration $file] != 0} {
               puts "Could not save user configuration"
               wait_for_enter
               return
            }

         }
         if { [string compare $force_params ""] != 0 } {
            if { [ save_user_configuration $file] != 0} {
               puts "Could not save user configuration"
               wait_for_enter
            }
         }
         return
      }
      return 
   } else {
      puts "could not open user config file \"$file\""
      puts "press return to create new user configuration file"
      wait_for_enter 1
      if { [ save_user_configuration $file] != 0} { return -1 }
      setup_user_config $file
   }
}

#****** config_user/user_config_get_portlist() *********************************
#  NAME
#     user_config_get_portlist() -- get the user's portlist in user configuration
#
#  SYNOPSIS
#     user_config_get_portlist { config_array result_array {port_type ""} } 
#
#  FUNCTION
#     Gets the array of ports used by user and it's usages
#     It uses global variable ts_user_portlist_usage
#
#  INPUTS
#     config_array - ts_user_config
#     result_array - result array
#     {port_type "all"} - "all" ... all ports
#                         "reserved" ... ports < 1024
#                         "even" ... even ports
#                         "odd" ... odd ports
#
#  RESULT
#     the list of ports
#
#  SEE ALSO
#     config/config_generic()
#*******************************************************************************
proc user_config_get_portlist { config_array result_array {port_type "all"} } {
   global CHECK_USER ts_user_config

   upvar $config_array config
   upvar $result_array portlist

   if { ![array exists portlist] } { array set portlist {} }

   if { [ info exists config($CHECK_USER,portlist) ] != 1 } { return -1 }

   foreach port $config($CHECK_USER,portlist) {

      if { $port_type == "reserved" && $port >= 1024 } { continue }
      if { $port_type == "even" && [ expr ( $port % 2 ) ] != 0 } { continue }
      if { $port_type == "odd" && [ expr ( $port % 2 ) ] == 0 } { continue }

      set portlist($port) ""
   }

   return [array names portlist]
}

#****** config_user/user_conf_get_cluster_users() ******************************
#  NAME
#     user_conf_get_cluster_users() -- get a list of cluster users
#
#  SYNOPSIS
#     user_conf_get_cluster_users { } 
#
#  FUNCTION
#     Returns a list of all users that will be used in the given test cluster.
#     The lists consists of
#     - the CHECK_USER
#     - root
#     - first and second "foreign" user
#
#  RESULT
#     user list
#*******************************************************************************
proc user_conf_get_cluster_users {} {
   global ts_user_config CHECK_USER

   set user_list $CHECK_USER
   lappend user_list "root"
   lappend user_list $ts_user_config(first_foreign_user)
   lappend user_list $ts_user_config(second_foreign_user)

   return $user_list
}

#****** config_user/user_config_add_newport() **********************************
#  NAME
#     user_config_add_newport() -- add new port to user's portlist
#
#  SYNOPSIS
#     user_config_add_newport { port { config_array "" } } 
#
#  FUNCTION
#     This procedure is used to add a new port to the user's configuration 
#
#  INPUTS
#     port               - port number
#     {config_array "" } - ts_config
#
#  SEE ALSO
#     config_user/user_config_userlist_set_portlist()
#     check/save_user_configuration()
#*******************************************************************************
proc user_config_add_newport { port {config_array "" } } {
   global CHECK_USER ts_user_config ts_config

   set new_value "$ts_user_config($CHECK_USER,portlist) $port"
   set errors 0

   incr errors [user_config_userlist_set_portlist ts_user_config $CHECK_USER $new_value]

   if { $errors == 0 }  {
      if { [info exists config(user_config_file)] } {
         set conf_file $config(user_config_file)
      } else { set conf_file $ts_config(user_config_file) }
       incr errors [save_user_configuration $conf_file]
   }

   wait_for_enter
   return
}

#****** config_user/user_config_get_env() **************************************
#  NAME
#     user_config_set_env() -- set user's environment variable from his envlist
#
#  SYNOPSIS
#     user_config_set_env { envname check_var_name}
#
#  FUNCTION
#     This procedure is used to set user's environment variable from his envlist
#
#  INPUTS
#     envname        - the name of variable, i. e. DISPLAY
#     check_var_name - corresponding global variable name
#
#*******************************************************************************
proc user_config_set_env { envname check_var_name } {
   global ts_user_config $check_var_name CHECK_USER

   if { [info exists ts_user_config($CHECK_USER,envlist)] } {
      set env_array [split $ts_user_config($CHECK_USER,envlist) " "]
      ts_log_finest "envlist = $env_array"

      foreach var $env_array {
         set rec [split $var "="]
         lassign $rec disVar disVal
         if {[string compare $disVar ""] != 0} {
            if {[string compare $disVar "$envname"] == 0} {
               ts_log_finest "set $check_var_name $disVal"
               set $check_var_name $disVal
            }
         }
      }
   }
   return
}
