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


global ts_host_config               ;# new testsuite host configuration array
global actual_ts_host_config_version      ;# actual host config version number
set    actual_ts_host_config_version "1.11"

if {![info exists ts_host_config]} {
   # ts_host_config defaults
   set parameter "version"
   set ts_host_config($parameter)            "$actual_ts_host_config_version"
   set ts_host_config($parameter,desc)       "Testuite host configuration setup"
   set ts_host_config($parameter,default)    "$actual_ts_host_config_version"
   set ts_host_config($parameter,setup_func) ""
   set ts_host_config($parameter,onchange)   "stop"
   set ts_host_config($parameter,pos)        1

   set parameter "hostlist"
   set ts_host_config($parameter)            ""
   set ts_host_config($parameter,desc)       "Testsuite cluster host list"
   set ts_host_config($parameter,default)    ""
   set ts_host_config($parameter,setup_func) "host_config_$parameter"
   set ts_host_config($parameter,onchange)   "install"
   set ts_host_config($parameter,pos)        4

   set parameter "NFS-ROOT2NOBODY"
   set ts_host_config($parameter)            ""
   set ts_host_config($parameter,desc)       "NFS shared directory with root to nobody mapping"
   set ts_host_config($parameter,default)    ""
   set ts_host_config($parameter,setup_func) "host_config_$parameter"
   set ts_host_config($parameter,onchange)   "install"
   set ts_host_config($parameter,pos)        2

   set parameter "NFS-ROOT2ROOT"
   set ts_host_config($parameter)            ""
   set ts_host_config($parameter,desc)       "NFS shared directory with root read/write rights"
   set ts_host_config($parameter,default)    ""
   set ts_host_config($parameter,setup_func) "host_config_$parameter"
   set ts_host_config($parameter,onchange)   "install"
   set ts_host_config($parameter,pos)        3
}

#****** config/host/host_config_hostlist() *******************************************
#  NAME
#     host_config_hostlist() -- host configuration setup
#
#  SYNOPSIS
#     host_config_hostlist { only_check name config_array } 
#
#  FUNCTION
#     Testsuite host configuration setup - called from verify_host_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_host_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup_host_config()
#     check/verify_host_config()
#*******************************************************************************
proc host_config_hostlist { only_check name config_array } {
   global CHECK_OUTPUT CHECK_HOST CHECK_USER

   upvar $config_array config

   set description   $config($name,desc)

   if {$only_check == 0} {
      set not_ready 1
      while {$not_ready} {
         clear_screen
         puts $CHECK_OUTPUT "----------------------------------------------------------"
         puts $CHECK_OUTPUT "Global host configuration setup"
         puts $CHECK_OUTPUT "----------------------------------------------------------"
         puts $CHECK_OUTPUT "\n    hosts configured: [llength $config(hostlist)]"
         host_config_hostlist_show_hosts config
         puts $CHECK_OUTPUT "\n\n(1)  add host"
         puts $CHECK_OUTPUT "(2)  edit host"
         puts $CHECK_OUTPUT "(3)  delete host"
         puts $CHECK_OUTPUT "(4)  try nslookup scan"
         puts $CHECK_OUTPUT "(10) exit setup"
         puts -nonewline $CHECK_OUTPUT "> "
         set input [ wait_for_enter 1]
         switch -- $input {
            1 {
               set result [host_config_hostlist_add_host config]
               if { $result != 0 } {
                  wait_for_enter
               }
            }
            2 {
               set result [host_config_hostlist_edit_host config]
               if { $result != 0 } {
                  wait_for_enter
               }
            }
            3 {
               set result [host_config_hostlist_delete_host config]
               if { $result != 0 } {
                  wait_for_enter
               }
            }
            10 {
               set not_ready 0
            }
            4 {
               set result [start_remote_prog $CHECK_HOST $CHECK_USER "nslookup" $CHECK_HOST prg_exit_state 60 0 "" "" 1 0]
               if {$prg_exit_state == 0} {
                  set pos1 [string first $CHECK_HOST $result]
                  set ip [string range $result $pos1 end]
                  set pos1 [string first ":" $ip]
                  incr pos1 1
                  set ip [string range $ip $pos1 end]
                  set pos1 [string last "." $ip]
                  incr pos1 -1
                  set ip [string range $ip 0 $pos1]
                  set ip [string trim $ip]
                  puts $CHECK_OUTPUT "ip: $ip"

                  for {set i 1} {$i <= 254} {incr i 1} {
                     set ip_run "$ip.$i"
                     puts -nonewline $CHECK_OUTPUT "\r$ip_run"
                     set result [start_remote_prog $CHECK_HOST $CHECK_USER "nslookup" $ip_run prg_exit_state 25 0 "" "" 1 0]
                     set pos1 [string first "Name:" $result]   
                     if {$pos1 >= 0} {
                        incr pos1 5
                        set name [string range $result $pos1 end]
                        set pos1 [string first "." $name]
                        incr pos1 -1
                        set name [string range $name 0 $pos1]
                        set name [string trim $name]
                        puts $CHECK_OUTPUT "\nHost: $name"
                        set result [host_config_hostlist_add_host config $name]
                     }
                  }
               }

               wait_for_enter
            }
         } 
      }
   }

   # check host configuration
   debug_puts "host_config_hostlist:"
   foreach host $config(hostlist) {
      debug_puts "      host: $host"
   }

   return $config(hostlist)
}


#****** config_host/host_config_NFS-ROOT2NOBODY() ******************************
#  NAME
#     host_config_NFS-ROOT2NOBODY() -- nfs spooling dir setup
#
#  SYNOPSIS
#     host_config_NFS-ROOT2NOBODY { only_check name config_array } 
#
#  FUNCTION
#     NFS directory which is mounted with root to user nobody mapping setup
#     - called from verify_host_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_host_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup_host_config()
#     check/verify_host_config()
#*******************************************************************************
proc host_config_NFS-ROOT2NOBODY { only_check name config_array } {
   global CHECK_OUTPUT CHECK_HOST CHECK_USER
   global fast_setup

   upvar $config_array config

   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if {$actual_value == ""} {
      set value $default_value
   }

   if {$only_check == 0} {
       puts $CHECK_OUTPUT "" 
       puts $CHECK_OUTPUT "Please specify a NFS shared directory where the root"
       puts $CHECK_OUTPUT "user is mapped to user nobody or press >RETURN< to"
       puts $CHECK_OUTPUT "use the default value."
       puts $CHECK_OUTPUT "(default: $value)"
       puts -nonewline $CHECK_OUTPUT "> "
       set input [ wait_for_enter 1]
      if {[string length $input] > 0} {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {
      if {![file isdirectory $value]} {
         puts $CHECK_OUTPUT " Directory \"$value\" not found"
         return -1
      }
   }

   return $value
}


#****** config_host/host_config_NFS-ROOT2ROOT() ********************************
#  NAME
#     host_config_NFS-ROOT2ROOT() -- nfs spooling dir setup
#
#  SYNOPSIS
#     host_config_NFS-ROOT2ROOT { only_check name config_array } 
#
#  FUNCTION
#     NFS directory which is mounted with root to user root mapping setup 
#     - called from verify_host_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_host_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup_host_config()
#     check/verify_host_config()
#*******************************************************************************
proc host_config_NFS-ROOT2ROOT { only_check name config_array } {
   global CHECK_OUTPUT CHECK_HOST CHECK_USER
   global fast_setup

   upvar $config_array config

   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if {$actual_value == ""} {
      set value $default_value
   }

   if {$only_check == 0} {
       puts $CHECK_OUTPUT "" 
       puts $CHECK_OUTPUT "Please specify a NFS shared directory where the root"
       puts $CHECK_OUTPUT "user is NOT mapped to user nobody and has r/w access"
       puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
       puts $CHECK_OUTPUT "(default: $value)"
       puts -nonewline $CHECK_OUTPUT "> "
       set input [ wait_for_enter 1]
      if {[string length $input] > 0} {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {
      if {![file isdirectory $value]} {
         puts $CHECK_OUTPUT " Directory \"$value\" not found"
         return -1
      }
   }

   return $value
}




#****** config/host/host_config_hostlist_show_hosts() ********************************
#  NAME
#     host_config_hostlist_show_hosts() -- show host in host configuration
#
#  SYNOPSIS
#     host_config_hostlist_show_hosts { array_name } 
#
#  FUNCTION
#     Print hosts
#
#  INPUTS
#     array_name - ts_host_config
#
#  SEE ALSO
#     check/setup_host_config()
#     check/verify_host_config()
#     check/host_config_hostlist_show_compile_hosts()
#*******************************************************************************
proc host_config_hostlist_show_hosts {array_name} {
   global ts_config CHECK_OUTPUT

   upvar $array_name config

   set hostlist [lsort -dictionary $config(hostlist)]

   puts $CHECK_OUTPUT "\nHost list:\n"
   if {[llength $hostlist] == 0} {
      puts $CHECK_OUTPUT "no hosts defined"
   }

   set max_length 0
   foreach host $hostlist {
      if {[string length $host] > $max_length} {
         set max_length [string length $host]
      }
   }  


   set index 0
   foreach host $hostlist {
      incr index 1 

      set space ""
      for {set i 0} {$i < [expr ($max_length - [string length $host])]} {incr i 1} {  
         append space " "
      }
      set c_comp 0
      set j_comp 0
      set all_comp {}
      if {[host_conf_is_compile_host $host config]} {
         set c_comp 1
         lappend all_comp "c"
      }
      if {[host_conf_is_java_compile_host $host config]} {
         set j_comp 1
         lappend all_comp "java"
      }

      if {$c_comp || $j_comp} {
         set comp_host "(compile host: $all_comp)"
      } else {
         set comp_host "                      "
      }

      set conf_arch [host_conf_get_arch $host config]

      if {$index <= 9} {
         puts $CHECK_OUTPUT "    $index) $host $space ($conf_arch) $comp_host"
      } else {
         puts $CHECK_OUTPUT "   $index) $host $space ($conf_arch) $comp_host"
      }
   }

   return $hostlist
}

#****** config/host/host_config_hostlist_show_compile_hosts() ************************
#  NAME
#     host_config_hostlist_show_compile_hosts() -- show compile hosts
#
#  SYNOPSIS
#     host_config_hostlist_show_compile_hosts { array_name save_array } 
#
#  FUNCTION
#     This procedure shows the list of compile hosts
#
#  INPUTS
#     array_name - ts_host_config array
#     save_array - array to store compile host informations
#
#  RESULT
#     save_array(count)     -> number of compile hosts (starting from 1)
#     save_array($num,arch) -> compile architecture
#     save-array($num,host) -> compile host name
#
#  SEE ALSO
#     check/host_config_hostlist_show_hosts()
#*******************************************************************************
proc host_config_hostlist_show_compile_hosts {array_name save_array} {
   global ts_config CHECK_OUTPUT
   upvar $array_name config
   upvar $save_array back

   if {[info exists back]} {
      unset back
   }

   puts $CHECK_OUTPUT "\nCompile architecture list:\n"
   if {[llength $config(hostlist)] == 0} {
      puts $CHECK_OUTPUT "no hosts defined"
   }

   set index 0
  
   set max_arch_length 0
   foreach host $config(hostlist) {
      if {[host_conf_is_compile_host $host config]} {
         set arch [host_conf_get_arch $host config]
         if {$arch != "unsupported"} {
            lappend arch_list $arch
            set host_list($arch) $host
            set arch_length [string length $arch]
            if {$max_arch_length < $arch_length} {
               set max_arch_length $arch_length
            }
         }
      }
   }

   set arch_list [lsort $arch_list]
   foreach arch $arch_list {
      set host $host_list($arch)
      if {[host_conf_is_compile_host $host config]} {
         incr index 1 
         set back(count) $index
         set back($index,arch) [host_conf_get_arch $host config]
         set back($index,host) $host 

         set arch_length [string length $arch]
         if {$index <= 9} {
            puts $CHECK_OUTPUT "    $index) $arch [get_spaces [expr ( $max_arch_length - $arch_length ) ]] ($host)"
         } else {
            puts $CHECK_OUTPUT "   $index) $arch [get_spaces [expr ( $max_arch_length - $arch_length ) ]] ($host)" 
         }
      } 
   }
}



#****** config/host/host_config_hostlist_add_host() **********************************
#  NAME
#     host_config_hostlist_add_host() -- add host to host configuration
#
#  SYNOPSIS
#     host_config_hostlist_add_host { array_name { have_host "" } } 
#
#  FUNCTION
#     This procedure is used to add an host to the testsuite host configuration 
#
#  INPUTS
#     array_name       - ts_host_config
#     { have_host "" } - if not "": add this host without questions
#
#  SEE ALSO
#     check/setup_host_config()
#     check/verify_host_config()
#*******************************************************************************
proc host_config_hostlist_add_host {array_name {have_host ""}} {
   global ts_config CHECK_OUTPUT
   global CHECK_USER

   upvar $array_name config
  
   if {$have_host == ""} {
      clear_screen
      puts $CHECK_OUTPUT "\nAdd host to global host configuration"
      puts $CHECK_OUTPUT "====================================="

   
      host_config_hostlist_show_hosts config

      puts $CHECK_OUTPUT "\n"
      puts -nonewline $CHECK_OUTPUT "Please enter new hostname: "
      set new_host [wait_for_enter 1]
   } else {
      set new_host $have_host
   }

   if {[string length $new_host] == 0} {
      puts $CHECK_OUTPUT "no hostname entered"
      return -1
   }
     
   if {[lsearch $config(hostlist) $new_host] >= 0} {
      puts $CHECK_OUTPUT "host \"$new_host\" is already in list"
      return -1
   }

   set time [timestamp]
   set result [start_remote_prog $new_host $CHECK_USER "echo" "\"hello $new_host\"" prg_exit_state 12 0 "" "" 1 0]
   if {$prg_exit_state != 0} {
      if {$have_host == ""} {

         puts $CHECK_OUTPUT "connect timeout error\nPlease enter a timeout value > 12 or press return to abort"
         set result [ wait_for_enter 1 ]
         if {[string length $result] == 0  || $result < 12} {
            puts $CHECK_OUTPUT "aborting ..."
            return -1
         }
         set result [start_remote_prog $new_host $CHECK_USER "echo" "\"hello $new_host\"" prg_exit_state $result 0 "" "" 1 0]
      }
   }

   if {$prg_exit_state != 0} {
      puts $CHECK_OUTPUT "rlogin to host $new_host doesn't work correctly"
      return -1
   }
   if {[string first "hello $new_host" $result] < 0} {
      puts $CHECK_OUTPUT "$result"
      puts $CHECK_OUTPUT "echo \"hello $new_host\" doesn't work"
      return -1
   }

   set arch [resolve_arch $new_host]
   lappend config(hostlist) $new_host

   
   set expect_bin [start_remote_prog $new_host $CHECK_USER "which" "expect" prg_exit_state 12 0 "" "" 1 0]
   if {$prg_exit_state != 0} {
      set expect_bin "" 
   } 
   set vim_bin [start_remote_prog $new_host $CHECK_USER "which" "vim" prg_exit_state 12 0 "" "" 1 0]
   if {$prg_exit_state != 0} {
      set vim_bin  "" 
   }
   set tar_bin [start_remote_prog $new_host $CHECK_USER "which" "tar" prg_exit_state 12 0 "" "" 1 0]
   if {$prg_exit_state != 0} {
      set tar_bin "" 
   }
   set gzip_bin [start_remote_prog $new_host $CHECK_USER "which" "gzip" prg_exit_state 12 0 "" "" 1 0]
   if {$prg_exit_state != 0} {
      set gzip_bin "" 
   }
   set ssh_bin [start_remote_prog $new_host $CHECK_USER "which" "ssh" prg_exit_state 12 0 "" "" 1 0]
   if {$prg_exit_state != 0} {
      set ssh_bin "" 
   }

   set java14_bin [autodetect_java $new_host "1.4"]
   set java15_bin [autodetect_java $new_host "1.5"]
   set java16_bin [autodetect_java $new_host "1.6"]
   set ant_bin [autodetect_ant $new_host]

   set config($new_host,expect)        [string trim $expect_bin]
   set config($new_host,vim)           [string trim $vim_bin]
   set config($new_host,tar)           [string trim $tar_bin]
   set config($new_host,gzip)          [string trim $gzip_bin]
   set config($new_host,ssh)           [string trim $ssh_bin]
   set config($new_host,java14)        [string trim $java14_bin]
   set config($new_host,java15)        [string trim $java15_bin]
   set config($new_host,java16)        [string trim $java16_bin]
   set config($new_host,ant)           [string trim $ant_bin]
   set config($new_host,loadsensor)    ""
   set config($new_host,processors)    1
   set config($new_host,spooldir)      ""
   set config($new_host,arch,53)       "unsupported"
   set config($new_host,arch,60)       "unsupported"
   set config($new_host,arch,61)       "unsupported"
   set config($new_host,arch,62)       "unsupported"
   set config($new_host,arch,$ts_config(gridengine_version))          $arch
   set config($new_host,compile,53)    0
   set config($new_host,compile,60)    0
   set config($new_host,compile,61)    0
   set config($new_host,compile,62)    0
   set config($new_host,java_compile,53)    0
   set config($new_host,java_compile,60)    0
   set config($new_host,java_compile,61)    0
   set config($new_host,java_compile,62)    0
   set config($new_host,compile_time)  0
   set config($new_host,response_time) [ expr ( [timestamp] - $time ) ]
   set config($new_host,fr_locale)     ""
   set config($new_host,ja_locale)     ""
   set config($new_host,zh_locale)     ""
   set config($new_host,zones)         ""
   set config($new_host,send_speed)    0.001

   if {$have_host == ""} {
      host_config_hostlist_edit_host config $new_host
   }
      
   return 0   
}


#****** config/host/host_config_hostlist_edit_host() *********************************
#  NAME
#     host_config_hostlist_edit_host() -- edit host in host configuration
#
#  SYNOPSIS
#     host_config_hostlist_edit_host { array_name { has_host "" } } 
#
#  FUNCTION
#     This procedure is used for host edition in host configuration
#
#  INPUTS
#     array_name      - ts_host_config
#     { has_host "" } - if not "": just edit this host
#
#  SEE ALSO
#     check/setup_host_config()
#     check/verify_host_config()
#*******************************************************************************
proc host_config_hostlist_edit_host {array_name {has_host ""}} {
   global ts_config ts_host_config CHECK_OUTPUT
   global CHECK_USER 

   upvar $array_name config

   set goto 0

   if {$has_host != ""} {
      set goto $has_host
   } 

   while {1} {
      clear_screen
      puts $CHECK_OUTPUT "\nEdit host in global host configuration"
      puts $CHECK_OUTPUT "======================================"

      set hostlist [host_config_hostlist_show_hosts config]

      puts $CHECK_OUTPUT "\n"
      puts -nonewline $CHECK_OUTPUT "Please enter hostname/number or return to exit: "
      if {$goto == 0} {
         set host [wait_for_enter 1]
         set goto $host
      } else {
         set host $goto
         puts $CHECK_OUTPUT $host
      }
 
      if {[string length $host] == 0} {
         break
      }
     
      if {[string is integer $host]} {
         incr host -1
         set host [lindex $hostlist $host]
      }

      if {[lsearch $hostlist $host] < 0} {
         puts $CHECK_OUTPUT "host \"$host\" not found in list"
         wait_for_enter
         set goto 0
         continue
      }

      set arch [host_conf_get_arch $host config]
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "   host          : $host"
      puts $CHECK_OUTPUT "   arch          : $arch"
      puts $CHECK_OUTPUT "   expect        : $config($host,expect)"
      puts $CHECK_OUTPUT "   vim           : $config($host,vim)"
      puts $CHECK_OUTPUT "   tar           : $config($host,tar)"
      puts $CHECK_OUTPUT "   gzip          : $config($host,gzip)"
      puts $CHECK_OUTPUT "   ssh           : $config($host,ssh)"
      puts $CHECK_OUTPUT "   java14        : $config($host,java14)"
      puts $CHECK_OUTPUT "   java15        : $config($host,java15)"
      puts $CHECK_OUTPUT "   java16        : $config($host,java16)"
      puts $CHECK_OUTPUT "   ant           : $config($host,ant)"
      puts $CHECK_OUTPUT "   loadsensor    : $config($host,loadsensor)"
      puts $CHECK_OUTPUT "   processors    : $config($host,processors)"
      puts $CHECK_OUTPUT "   spooldir      : $config($host,spooldir)"
      puts $CHECK_OUTPUT "   fr_locale     : $config($host,fr_locale)"
      puts $CHECK_OUTPUT "   ja_locale     : $config($host,ja_locale)"
      puts $CHECK_OUTPUT "   zh_locale     : $config($host,zh_locale)"
      puts $CHECK_OUTPUT "   zones         : $config($host,zones)"

      if {[host_conf_is_compile_host $host config]} {
         puts $CHECK_OUTPUT "   compile       : compile host for \"$arch\" binaries ($ts_config(gridengine_version))"
      } else {
         puts $CHECK_OUTPUT "   compile       : not a compile host"
      }
      if {[host_conf_is_java_compile_host $host config]} {
         puts $CHECK_OUTPUT "   java_compile  : compile host for java ($ts_config(gridengine_version))"
      } else {
         puts $CHECK_OUTPUT "   java_compile  : not a java compile host"
      }
      puts $CHECK_OUTPUT "   send_speed    : $config($host,send_speed)"
      puts $CHECK_OUTPUT "   compile_time  : $config($host,compile_time)"
      puts $CHECK_OUTPUT "   response_time : $config($host,response_time)"


      puts $CHECK_OUTPUT ""
   
      puts $CHECK_OUTPUT "\n"
      puts -nonewline $CHECK_OUTPUT "Please enter category to edit or hit return to exit > "
      set input [wait_for_enter 1]
      if {[string length $input] == 0 } {
         set goto 0
         continue
      }

 
      set isfile 0
      set isdir 0
      set check_valid_java ""
      set check_ant 0
      set islocale 0
      set input_type "forbidden"
      switch -- $input {
         "expect" -
         "vim" -
         "tar" -
         "gzip" -
         "ssh" -
         "loadsensor" { 
            set input_type "simple"
            set isfile 1
         }
         "java14" {
	    set input_type "simple"
	    set isfile 1
            set check_valid_java "1.4"
         }
         "java15" {
	    set input_type "simple"
	    set isfile 1
            set check_valid_java "1.5"
         }
         "java16" {
	    set input_type "simple"
	    set isfile 1
            set check_valid_java "1.6"
         }
         "ant" {
	    set input_type "simple"
            set isfile 1
	    set check_ant 1
         }

         "spooldir" {
            set input_type "simple"
            set isdir 1 
         }

         "compile" -
         "java_compile" { 
            set input_type "compile"
         }

         "zones" { 
            set input_type "zones"
         }

         "fr_locale" -
         "ja_locale" -
         "zh_locale" { 
            set input_type "locale"
            set islocale 1
         }

         "processors" -
         "send_speed" {
            set input_type "simple"
         }
   
         "arch" {
            set input_type "arch"
         }

         "host" -
         "compile_time" -
         "response_time" {
            puts $CHECK_OUTPUT "Setting \"$input\" is not allowed"
            wait_for_enter
            continue
         }
         default {
            puts $CHECK_OUTPUT "Not a valid category"
            wait_for_enter
            continue
         }
      }

      switch -exact $input_type {
         "simple" {
            puts -nonewline $CHECK_OUTPUT "\nPlease enter new $input value: "
            set value [wait_for_enter 1]
         }

         "arch" {
            set input "arch,$ts_config(gridengine_version)"
            puts $CHECK_OUTPUT "Please enter a valid architecture name"
            puts $CHECK_OUTPUT "or \"unsupported\", if the hosts architecture is not"
            puts $CHECK_OUTPUT "supported on Gridengine $ts_config(gridengine_version) systems"
            puts -nonewline $CHECK_OUTPUT "\nNew architecture: "
            set value [wait_for_enter 1]
         }

         "compile" {
            puts -nonewline $CHECK_OUTPUT "\nShould testsuite use this host for $input of $ts_config(gridengine_version) version (y/n) :"
            set input "$input,$ts_config(gridengine_version)"
            set value [wait_for_enter 1]
            if {[string compare "y" $value] == 0} {
               set value 1
            } else {
               set value 0
            }
         }
         "locale" {
            puts $CHECK_OUTPUT "INFO:"
            puts $CHECK_OUTPUT "Please enter an environment list to get localized output on that host!"
            puts $CHECK_OUTPUT ""
            puts $CHECK_OUTPUT "e.g.: LANG=fr_FR.ISO8859-1 LC_MESSAGES=fr"
            puts -nonewline $CHECK_OUTPUT "\nPlease enter new locale: "
            set value [wait_for_enter 1]
         }
         "zones" {
            puts $CHECK_OUTPUT "Please enter a space separated list of zones: "
            set value [wait_for_enter 1]

            if { [llength $value] != 0 } {
               set host_error 0
               foreach zone $value {
                  set result [start_remote_prog $zone $CHECK_USER "id" "" prg_exit_state 12 0 "" "" 1 0]
                  if { $prg_exit_state != 0 } {
                     puts $CHECK_OUTPUT $result
                     puts $CHECK_OUTPUT "can't connect to zone $zone"
                     wait_for_enter
                     set host_error 1
                     break
                  }
               }
               if {$host_error} {
                  continue
               }
            }
         }
      }

      # check for valid file name
      if {$isfile} {
         set result [start_remote_prog $host $CHECK_USER "ls" "$value" prg_exit_state 12 0 "" "" 1 0]
         if {$prg_exit_state != 0} {
            puts $CHECK_OUTPUT $result
            puts $CHECK_OUTPUT "file $value not found on host $host"
            wait_for_enter
            continue
         }
      }
      
      # check for valid directory name
      if {$isdir} {
         set result [start_remote_prog $host $CHECK_USER "cd" "$value" prg_exit_state 12 0 "" "" 1 0]
         if {$prg_exit_state != 0} {
            puts $CHECK_OUTPUT $result
            puts $CHECK_OUTPUT "can't cd to directory $value on host $host"
            wait_for_enter
            continue
         }
      }

      # check java
      if { $check_valid_java != "" && [string trim $value] != "" } {
         set result [check_java_version $host $value $check_valid_java]
         if {$result != 0} {
            puts $CHECK_OUTPUT "Not a java $check_valid_java"
            wait_for_enter
            continue
         }
      }

      # check ant
      if { $check_ant && [string trim $value] != "" } {
         set result [check_ant_version $host $value]
         if {$result != 0} {
            puts $CHECK_OUTPUT "Not a valid ant for the testsuite"
            wait_for_enter
            continue
         }
      }

      # locale test
      if {$islocale == 1} {
         set mem_it $ts_host_config($host,$input)
         set mem_l10n $ts_config(l10n_test_locale)
       
         set ts_config(l10n_test_locale) [string range $input 0 1]
         set ts_host_config($host,$input) $value

         set test_result [perform_simple_l10n_test ]

         set ts_host_config($host,$input) $mem_it
         set ts_config(l10n_test_locale) mem_l10n

         if {$test_result != 0} {
            puts $CHECK_OUTPUT "l10n errors" 
            wait_for_enter
            continue
         }
         puts $CHECK_OUTPUT "you have to enable l10n in testsuite setup too!"
         wait_for_enter
      }

      set config($host,$input) $value
   }
   
   return 0   
}


#****** config/host/host_config_hostlist_delete_host() *******************************
#  NAME
#     host_config_hostlist_delete_host() -- delete host from host configuration
#
#  SYNOPSIS
#     host_config_hostlist_delete_host { array_name } 
#
#  FUNCTION
#     This procedure is called to delete a host from host configuration
#
#  INPUTS
#     array_name - ts_host_config
#
#  SEE ALSO
#     check/setup_host_config()
#     check/verify_host_config()
#*******************************************************************************
proc host_config_hostlist_delete_host { array_name } {
   global ts_config CHECK_OUTPUT
   global CHECK_USER

   upvar $array_name config

   while {1} {

      clear_screen
      puts $CHECK_OUTPUT "\nDelete host from global host configuration"
      puts $CHECK_OUTPUT "=========================================="

   
      set hostlist [host_config_hostlist_show_hosts config]

      puts $CHECK_OUTPUT "\n"
      puts -nonewline $CHECK_OUTPUT "Please enter hostname/number or return to exit: "
      set host [wait_for_enter 1]
 
      if {[string length $host] == 0} {
         break
      }
     
      if {[string is integer $host]} {
         incr host -1
         set host [lindex $hostlist $host]
      }

      if {[lsearch $hostlist $host] < 0} {
         puts $CHECK_OUTPUT "host \"$host\" not found in list"
         wait_for_enter
         continue
      }

      set arch [host_conf_get_arch $host config]
      
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "   host          : $host"
      puts $CHECK_OUTPUT "   arch          : $arch"
      puts $CHECK_OUTPUT "   expect        : $config($host,expect)"
      puts $CHECK_OUTPUT "   vim           : $config($host,vim)"
      puts $CHECK_OUTPUT "   tar           : $config($host,tar)"
      puts $CHECK_OUTPUT "   gzip          : $config($host,gzip)"
      puts $CHECK_OUTPUT "   ssh           : $config($host,ssh)"
      puts $CHECK_OUTPUT "   java14        : $config($host,java14)"
      puts $CHECK_OUTPUT "   java15        : $config($host,java15)"
      puts $CHECK_OUTPUT "   java16        : $config($host,java16)"
      puts $CHECK_OUTPUT "   ant           : $config($host,ant)"
      puts $CHECK_OUTPUT "   loadsensor    : $config($host,loadsensor)"
      puts $CHECK_OUTPUT "   processors    : $config($host,processors)"
      puts $CHECK_OUTPUT "   spooldir      : $config($host,spooldir)"
      puts $CHECK_OUTPUT "   fr_locale     : $config($host,fr_locale)"
      puts $CHECK_OUTPUT "   ja_locale     : $config($host,ja_locale)"
      puts $CHECK_OUTPUT "   zh_locale     : $config($host,zh_locale)"

      if {[host_conf_is_compile_host $host config]} {
         puts $CHECK_OUTPUT "   compile       : compile host for \"$arch\" binaries ($ts_config(gridengine_version))"
      } else {
         puts $CHECK_OUTPUT "   compile       : not a compile host"
      }
      if {[host_conf_is_java_compile_host $host config]} {
         puts $CHECK_OUTPUT "   compile_java  : compile host for java ($ts_config(gridengine_version))"
      } else {
         puts $CHECK_OUTPUT "   compile_java  : not a java compile host"
      }
      puts $CHECK_OUTPUT "   send_speed    : $config($host,send_speed)"
      puts $CHECK_OUTPUT "   compile_time  : $config($host,compile_time)"
      puts $CHECK_OUTPUT "   response_time : $config($host,response_time)"

      puts $CHECK_OUTPUT ""
   
      puts $CHECK_OUTPUT "\n"
      puts -nonewline $CHECK_OUTPUT "Delete this host? (y/n): "
      set input [wait_for_enter 1]
      if {[string length $input] == 0} {
         continue
      }

 
      if {[string compare $input "y"] == 0} {
         set index [lsearch $config(hostlist) $host]
         set config(hostlist) [lreplace $config(hostlist) $index $index]
         unset config($host,arch,53)
         unset config($host,arch,60)
         unset config($host,arch,61)
         unset config($host,arch,62)
         unset config($host,expect)
         unset config($host,vim)
         unset config($host,tar)
         unset config($host,gzip)
         unset config($host,ssh)
         unset config($host,java14)
         unset config($host,java15)
         unset config($host,java16)
         unset config($host,ant)
         unset config($host,loadsensor)
         unset config($host,processors)
         unset config($host,spooldir)
         unset config($host,fr_locale)
         unset config($host,ja_locale)
         unset config($host,zh_locale)
         unset config($host,compile,53)
         unset config($host,compile,60)
         unset config($host,compile,61)
         unset config($host,compile,62)
         unset config($host,java_compile,53)
         unset config($host,java_compile,60)
         unset config($host,java_compile,61)
         unset config($host,java_compile,62)
         unset config($host,send_speed)
         unset config($host,compile_time)
         unset config($host,response_time)
         unset config($host,zones)
         continue
      }
   }

   return 0   
}



#****** config/host/verify_host_config() *********************************************
#  NAME
#     verify_host_config() -- verify testsuite host configuration setup
#
#  SYNOPSIS
#     verify_host_config { config_array only_check parameter_error_list 
#     { force 0 } } 
#
#  FUNCTION
#     This procedure will verify or enter host setup configuration
#
#  INPUTS
#     config_array         - array name with configuration (ts_host_config)
#     only_check           - if 1: don't ask user, just check
#     parameter_error_list - returned list with error information
#     { force 0 }          - force ask user 
#
#  RESULT
#     number of errors
#
#  SEE ALSO
#     check/verify_host_config()
#     check/verify_user_config()
#     check/verify_config()
#*******************************************************************************
proc verify_host_config {config_array only_check parameter_error_list {force 0}} {
   global CHECK_OUTPUT actual_ts_host_config_version be_quiet
   upvar $config_array config
   upvar $parameter_error_list error_list

   set errors 0
   set error_list ""

   if {[info exists config(version)] != 1} {
      puts $CHECK_OUTPUT "Could not find version info in host configuration file"
      lappend error_list "no version info"
      incr errors 1
      return -1
   }

   if {$config(version) != $actual_ts_host_config_version} {
      puts $CHECK_OUTPUT "Host configuration file version \"$config(version)\" not supported."
      puts $CHECK_OUTPUT "Expected version is \"$actual_ts_host_config_version\""
      lappend error_list "unexpected host config file version $config(version)"
      incr errors 1
      return -1
   } else {
      debug_puts "Host Configuration Version: $config(version)"
   }

   set max_pos [get_configuration_element_count config]

   set uninitalized ""
   if {$be_quiet == 0} { 
      puts $CHECK_OUTPUT ""
   }

   for {set param 1} {$param <= $max_pos} {incr param 1} {
      set par [get_configuration_element_name_on_pos config $param]
      if {$be_quiet == 0} { 
         puts -nonewline $CHECK_OUTPUT "      $config($par,desc) ..."
         flush $CHECK_OUTPUT
      }
      if {$config($par) == "" || $force != 0} {
         debug_puts "not initialized or forced!"
         lappend uninitalized $param
         if { $only_check != 0 } {
            lappend error_list ">$par< configuration not initialized"
            incr errors 1
         }
      } else {
         set procedure_name  $config($par,setup_func)
         set default_value   $config($par,default)
         set description     $config($par,desc)
         if {[string length $procedure_name] == 0} {
             debug_puts "no procedure defined"
         } else {
            if {[info procs $procedure_name] != $procedure_name} {
               puts $CHECK_OUTPUT "error\n"
               puts $CHECK_OUTPUT "-->WARNING: unknown procedure name: \"$procedure_name\" !!!"
               puts $CHECK_OUTPUT "   ======="
               lappend uninitalized $param

               if {$only_check == 0} { 
                  wait_for_enter 
               }
            } else {
               # call procedure only_check == 1
               debug_puts "starting >$procedure_name< (verify mode) ..."
               set value [$procedure_name 1 $par config]
               if {$value == -1} {
                  incr errors 1
                  lappend error_list $par 
                  lappend uninitalized $param

                  puts $CHECK_OUTPUT "error\n"
                  puts $CHECK_OUTPUT "-->WARNING: verify error in procedure \"$procedure_name\" !!!"
                  puts $CHECK_OUTPUT "   ======="

               } 
            }
         }
      }
      if {$be_quiet == 0} { 
         puts $CHECK_OUTPUT "\r      $config($par,desc) ... ok"   
      }
   }
   if {[set count [llength $uninitalized]] != 0 && $only_check == 0} {
      puts $CHECK_OUTPUT "$count parameters are not initialized!"
      puts $CHECK_OUTPUT "Entering setup procedures ..."
      
      foreach pos $uninitalized {
         set p_name [get_configuration_element_name_on_pos config $pos]
         set procedure_name  $config($p_name,setup_func)
         set default_value   $config($p_name,default)
         set description     $config($p_name,desc)
       
         puts $CHECK_OUTPUT "----------------------------------------------------------"
         puts $CHECK_OUTPUT $description
         puts $CHECK_OUTPUT "----------------------------------------------------------"
         debug_puts "Starting configuration procedure for parameter \"$p_name\" ($config($p_name,pos)) ..."
         set use_default 0
         if {[string length $procedure_name] == 0} {
            puts $CHECK_OUTPUT "no procedure defined"
            set use_default 1
         } else {
            if {[info procs $procedure_name] != $procedure_name} {
               puts $CHECK_OUTPUT ""
               puts $CHECK_OUTPUT "-->WARNING: unknown procedure name: \"$procedure_name\" !!!"
               puts $CHECK_OUTPUT "   ======="
               if {$only_check == 0} {wait_for_enter}
               set use_default 1
            }
         } 

         if {$use_default != 0} {
            # check again if we have value ( force flag) 
            if {$config($p_name) == ""} {
               # we have no setup procedure
               if {$default_value != ""} {
                  puts $CHECK_OUTPUT "using default value: \"$default_value\"" 
                  set config($p_name) $default_value 
               } else {
                  puts $CHECK_OUTPUT "No setup procedure and no default value found!!!"
                  if {$only_check == 0} {
                     puts -nonewline $CHECK_OUTPUT "Please enter value for parameter \"$p_name\": "
                     set value [wait_for_enter 1]
                     puts $CHECK_OUTPUT "using value: \"$value\"" 
                     set config($p_name) $value
                  }
               }
            }
         } else {
            # call setup procedure ...
            debug_puts "starting >$procedure_name< (setup mode) ..."
            set value [$procedure_name 0 $p_name config]
            if {$value != -1} {
               puts $CHECK_OUTPUT "using value: \"$value\"" 
               set config($p_name) $value
            }
         }
         if {$config($p_name) == ""} {
            puts $CHECK_OUTPUT "" 
            puts $CHECK_OUTPUT "-->WARNING: no value for \"$p_name\" !!!"
            puts $CHECK_OUTPUT "   ======="
            incr errors 1
            lappend error_list $p_name
         }
      } 
   }
   return $errors
}


#****** config/update_ts_host_config_version() **********************************
#  NAME
#     update_ts_host_config_version() -- used for version update of ts_host_config
#
#  SYNOPSIS
#     update_ts_host_config_version { filename } 
#
#  FUNCTION
#     This procedure is called when the versions of the testsuite host configuration
#     are not equal.
#
#  INPUTS
#     filename - host configuration file
#
#  SEE ALSO
#     check/update_ts_config_version()
#*******************************************************************************
proc update_ts_host_config_version { filename } {
   global actual_ts_host_config_version
   global ts_host_config ts_config
   global CHECK_OUTPUT CHECK_USER

   if { [string compare $ts_host_config(version)  "1.0"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.0 to 1.1 ..."

      foreach host $ts_host_config(hostlist) {
         set ts_host_config($host,fr_locale) ""
         set ts_host_config($host,ja_locale) ""
         set ts_host_config($host,zh_locale) ""
      }
      set ts_host_config(version) "1.1"
     
      show_config ts_host_config
      wait_for_enter
      if { [ save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
   }

   if { [string compare $ts_host_config(version)  "1.1"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.1 to 1.2 ..."
wait_for_enter
         return
	
      foreach host $ts_host_config(hostlist) {
         set ts_host_config($host,ssh) ""
      }
      set ts_host_config(version) "1.2"
     
      show_config ts_host_config
      wait_for_enter
      if { [ save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
   }

   if { [string compare $ts_host_config(version)  "1.2"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.2 to 1.3 ..."

      foreach host $ts_host_config(hostlist) {
         set ts_host_config($host,java) ""
      }
      set ts_host_config(version) "1.3"
     
      show_config ts_host_config
      wait_for_enter
      if { [ save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
   }

   if { [string compare $ts_host_config(version)  "1.3"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.3 to 1.4 ..."

      foreach host $ts_host_config(hostlist) {
         set ts_host_config($host,zones) ""
      }
      set ts_host_config(version) "1.4"
     
      show_config ts_host_config
      wait_for_enter
      if { [ save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
   }

   if { [string compare $ts_host_config(version)  "1.4"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.4 to 1.5 ..."

      # insert new parameter after version parameter
      set insert_pos $ts_host_config(version,pos)
      incr insert_pos 1

      # move positions of following parameters for 2 steps
      set new_parameter_cont 2
      set names [array names ts_host_config "*,pos"]
      foreach name $names {
         if { $ts_host_config($name) >= $insert_pos } {
            set ts_host_config($name) [ expr ( $ts_host_config($name) + $new_parameter_cont ) ]
         }
      }

      # parameter 1
      set parameter "NFS-ROOT2NOBODY"
      set ts_host_config($parameter)            ""
      set ts_host_config($parameter,desc)       "NFS shared directory with root to nobody mapping"
      set ts_host_config($parameter,default)    ""
      set ts_host_config($parameter,setup_func) "host_config_$parameter"
      set ts_host_config($parameter,onchange)   "install"
      set ts_host_config($parameter,pos)        $insert_pos

       
      # increment position for the second parameter 
      incr insert_pos 1

      # parameter 2
      set parameter "NFS-ROOT2ROOT"
      set ts_host_config($parameter)            ""
      set ts_host_config($parameter,desc)       "NFS shared directory with root read/write rights"
      set ts_host_config($parameter,default)    ""
      set ts_host_config($parameter,setup_func) "host_config_$parameter"
      set ts_host_config($parameter,onchange)   "install"
      set ts_host_config($parameter,pos)        $insert_pos

 
      # now we have version 1.5
      set ts_host_config(version) "1.5"

      show_config ts_host_config
      wait_for_enter
      if { [ save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
   }

   if { [string compare $ts_host_config(version)  "1.5"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.5 to 1.6 ..."

      foreach host $ts_host_config(hostlist) {
         # convert the one architecture string to a version dependent one
         set arch $ts_host_config($host,arch)
         unset ts_host_config($host,arch)
         set ts_host_config($host,arch,53) [host_conf_53_arch $arch]
         set ts_host_config($host,arch,60) [host_conf_60_arch $arch]
         set ts_host_config($host,arch,61) [host_conf_61_arch $arch]

         # we now store compile host property depending on gridengine version
         # assume our current compile hosts compile for 53, 60, and 61
         if {$ts_host_config($host,compile) == 1} {
            set ts_host_config($host,compile,53) 1
            set ts_host_config($host,compile,60) 1
            set ts_host_config($host,compile,61) 1
         } else {
            set ts_host_config($host,compile,53) 0
            set ts_host_config($host,compile,60) 0
            set ts_host_config($host,compile,61) 0
         }
         unset ts_host_config($host,compile)
      }
      set ts_host_config(version) "1.6"
     
      show_config ts_host_config
      wait_for_enter
      if { [ save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
   }

   if { [string compare $ts_host_config(version)  "1.6"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.6 to 1.7 ..."

      foreach host $ts_host_config(hostlist) {
         # convert the java home string to a version dependent one
         puts -nonewline " ... "
         set myenv(EN_QUIET) "1"
         set java15_bin [start_remote_prog $host $CHECK_USER "/bin/csh" "-c \"source /vol2/resources/en_jdk15 ; which java\"" prg_exit_state 12 0 "" myenv 1 0]
         if { $prg_exit_state != 0 } {
            set java15_bin "" 
         }
         set java15_bin [string trim $java15_bin]
         if { ![file isfile $java15_bin] } {
            puts $CHECK_OUTPUT "file not found"
            set java15_bin ""
         }
         puts $CHECK_OUTPUT "setting java15 for host $host to \"$java15_bin\""
         set ts_host_config($host,java15) $java15_bin
      }
      set ts_host_config(version) "1.7"
     
      show_config ts_host_config
      wait_for_enter
      if {[save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
   }

   if { [string compare $ts_host_config(version)  "1.7"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.7 to 1.8 ..."

      foreach host $ts_host_config(hostlist) {
         # we now store java compile host property depending on gridengine version
         set ts_host_config($host,java_compile,53) 0
         set ts_host_config($host,java_compile,60) 0
         set ts_host_config($host,java_compile,61) 0
      }
      set ts_host_config(version) "1.8"
     
      show_config ts_host_config
      wait_for_enter
      if {[save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
   }

   if { [string compare $ts_host_config(version)  "1.8"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.8 to 1.9 ..."

      foreach host $ts_host_config(hostlist) {
         # we now expect send speed property - use a pretty slow default
         set ts_host_config($host,send_speed) 0.001
      }
      set ts_host_config(version) "1.9"
     
      show_config ts_host_config
      wait_for_enter
      if {[save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
   }

   if { [string compare $ts_host_config(version)  "1.9"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.9 to 1.10 ..."

      # we have to update all version dependent settings from 65 to 61
      foreach host $ts_host_config(hostlist) {
         set ts_host_config($host,arch,61) $ts_host_config($host,arch,65)
         set ts_host_config($host,arch,62) $ts_host_config($host,arch,65)
         unset ts_host_config($host,arch,65)

         set ts_host_config($host,compile,61) $ts_host_config($host,compile,65)
         set ts_host_config($host,compile,62) $ts_host_config($host,compile,65)
         unset ts_host_config($host,compile,65)

         set ts_host_config($host,java_compile,61) $ts_host_config($host,java_compile,65)
         set ts_host_config($host,java_compile,62) $ts_host_config($host,java_compile,65)
         unset ts_host_config($host,java_compile,65)
      }

      set ts_host_config(version) "1.10"

      show_config ts_host_config
      wait_for_enter
      if {[save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
   }

   if { [string compare $ts_host_config(version)  "1.10"] == 0 } {
      puts $CHECK_OUTPUT "\ntestsuite host configuration update from 1.10 to 1.11 ..."

      # we have to update all version dependent settings from 65 to 61
      foreach host $ts_host_config(hostlist) {
         puts $CHECK_OUTPUT "$host"
         #Remove java from host_config
         puts $CHECK_OUTPUT "---removing java for host $host"
         unset ts_host_config($host,java)
	 #Add java 1.4
         set ts_host_config($host,java14) [autodetect_java $host "1.4"]
         #Check if java1.5 is valid
         set java15_bin $ts_host_config($host,java15)
         if { [check_java_version $host $java15_bin "1.5"] != 0 } {
            set ts_host_config($host,java15) [autodetect_java $host "1.5"]
         }
         #Add java1.6
         set ts_host_config($host,java16) [autodetect_java $host "1.6"]
         #Add ant
         set ts_host_config($host,ant) [autodetect_ant $host]
         puts $CHECK_OUTPUT "================="
      }

      set ts_host_config(version) "1.11"
     
      show_config ts_host_config
      wait_for_enter
      if {[save_host_configuration $filename] != 0} {
         puts $CHECK_OUTPUT "Could not save host configuration"
         wait_for_enter
         return
      }
      return 0
   }

   puts $CHECK_OUTPUT "\nunexpected version"
   return -1
}


#****** config/check_ant_version() *********************************************
#  NAME
#     check_ant_version() -- checks if ant is at least of version 1.6 and has 
#                            junit.jar in it's lib directory
#
#  SYNOPSIS
#      check_ant_version { host ant_bin }
#
#  FUNCTION
#     This procedure is called when the the testsuite host configuration is 
#     updated to 1.11. And each time ant location is modified in host 
#     configuration.
#
#  INPUTS
#     host - host where we expect the ant_bin
#     ant_bin - whole path to ant binary
#
#  SEE ALSO
#
#*******************************************************************************
proc check_ant_version { host ant_bin } {
   global CHECK_USER CHECK_OUTPUT
   set output [start_remote_prog $host $CHECK_USER "$ant_bin" "-version" prg_exit_state 12 0 "" "" 1 0]
   set act_version [string trim [string range [get_string_value_between " version " " compiled" $output] 0 2]]
   if { [string length $act_version] != 3 } {
      puts $CHECK_OUTPUT "Error: 'ant -version' returned: \"$output\""
      return -1
   }
   if { $act_version >= 1.6 } {
      set input_len [ string length $ant_bin ]
      set ant_len  [ string length "/bin/ant" ]
      set last [ expr ( $input_len - $ant_len -1 ) ]
      set res [ string range $ant_bin 0 $last]

      set result [start_remote_prog $host $CHECK_USER "ls" "$res/lib/ant/junit.jar" prg_exit_state 12 0 "" "" 1 0]
      if {$prg_exit_state == 0} {
         return 0
      }
      puts $CHECK_OUTPUT "Warning: This ant version seems to have missing $res/lib/ant/junit.jar. Copy it there or update the ant version in host configuration manually!"
      return 0
   }
   return -1
}


#****** config/autodetect_ant() ********************************************
#  NAME
#     autodetect_ant() -- tries to find ant_bin
#
#  SYNOPSIS
#      check_ant_version { host }
#
#  FUNCTION
#     This procedure is called to autodetect ant
#
#  INPUTS
#     host - host where we expect the ant_bin
#
#  SEE ALSO
#
#*******************************************************************************
proc autodetect_ant { host } {
   global CHECK_USER CHECK_OUTPUT ts_host_config
   set ant_bin [start_remote_prog $host $CHECK_USER "which" "ant" prg_exit_state 12 0 "" myenv 1 0]
   set ant_bin [string trim $ant_bin]
   if { $prg_exit_state != 0 } {
      puts $CHECK_OUTPUT "Unable to autodetect ant for host $host. Set it manually in host configuration! Ant should have junit.jar copied to it's lib directory"
      set ant_bin ""
   } elseif  { [check_ant_version $host $ant_bin] != 0 } {
      puts $CHECK_OUTPUT "Invalid ant: \"$ant_bin\""
      set ant_bin ""
   }
   puts $CHECK_OUTPUT "---setting ant for host $host to \"$ant_bin\""
   return $ant_bin
}


#****** config/check_java_version() ********************************************
#  NAME
#     check_java_version() -- java_bin is of a version specified
#
#  SYNOPSIS
#      check_java_version { host java_bin version }
#
#  FUNCTION
#     This procedure is called each time java14 java15 and java16 locations are 
#     modified in host configuration.
#
#  INPUTS
#     host - host where we expect the java_bin
#     java_bin - whole path to java binary
#     version - expected java version of java_bin
#
#  SEE ALSO
#
#  TODO
#     Having valid java_bin is not enough. We also need JAVA_HOME/include dir.
#     E.g.: /usr/jdk/jre/bin/java is invalid, correct would be /usr/jdk/bin/java
#*******************************************************************************
proc check_java_version { host java_bin version } {
   global CHECK_USER
   if { [string trim $java_bin] == "" } {
      return -1
   }
   set output [start_remote_prog $host $CHECK_USER "$java_bin" "-version" prg_exit_state 12 0 "" "" 1 0]
   if { [string match "*java version \"$version.*" $output] == 1 } {
      return 0
   }
   return -1
}


#****** config/autodetect_java() ********************************************
#  NAME
#     autodetect_java() -- tries to find java_bin
#
#  SYNOPSIS
#      check_java_version { host version }
#
#  FUNCTION
#     This procedure is called to autodetect java14 java15 and java16
#
#  INPUTS
#     host - host where we expect the java_bin
#     version - expected java version of java_bin
#
#  SEE ALSO
#
#*******************************************************************************
proc autodetect_java { host {version "1.4"} } {
   global CHECK_OUTPUT CHECK_USER ts_host_config
   set ver [get_testsuite_java_version $version]
   set output [start_remote_prog $host $CHECK_USER "/bin/csh" "-c \"source /vol2/resources/en_jdk$ver ; which java\"" prg_exit_state 12 0 "" myenv 1 0]
   if  { [string match "* NOT SUPPORTED *" $output] == 1 } {
      puts $CHECK_OUTPUT "Error: [lindex [split $output "\n"] 0]"
      set bin ""
   } else {
      set output [split $output "\n"]
      set bin [string trim [lindex $output [expr [llength $output] - 2]]]
      if { $prg_exit_state != 0 } {
         puts $CHECK_OUTPUT "Error: Unable to autodetect java$ver  for host $host. Set it manually in host configuration!"
         set bin "" 
      } elseif { [check_java_version $host $bin $version] != 0 } {
         puts $CHECK_OUTPUT "Error: $bin does not point to valid java$ver"
         set bin ""
      }
   }
   puts $CHECK_OUTPUT "---setting java$ver for host $host to \"$bin\""
   return $bin
}


#****** config/host/setup_host_config() **********************************************
#  NAME
#     setup_host_config() -- testsuite host configuration initalization
#
#  SYNOPSIS
#     setup_host_config { file { force 0 } } 
#
#  FUNCTION
#     This procedure will initalize the testsuite host configuration
#
#  INPUTS
#     file        - host configuration file
#     { force 0 } - if 1: edit configuration setup
#
#  SEE ALSO
#     check/setup_user_config()
#*******************************************************************************
proc setup_host_config {file {force 0}} {
   global CHECK_OUTPUT
   global ts_host_config actual_ts_host_config_version

   if { [read_array_from_file $file "testsuite host configuration" ts_host_config ] == 0 } {
      if { $ts_host_config(version) != $actual_ts_host_config_version } {
         puts $CHECK_OUTPUT "unknown host configuration file version: $ts_host_config(version) actual version: $actual_ts_host_config_version"
         while { [update_ts_host_config_version $file] != 0 } {
            wait_for_enter
         }
      }
      # got config
      if { [verify_host_config ts_host_config 1 err_list $force ] != 0 } {
         # configuration problems
         foreach elem $err_list {
            puts $CHECK_OUTPUT "$elem"
         } 
         puts $CHECK_OUTPUT "Press enter to edit host setup configurations"
         set answer [wait_for_enter 1]

         set not_ok 1
         while { $not_ok } {
            if { [verify_host_config ts_host_config 0 err_list $force ] != 0 } {
               set not_ok 1
               foreach elem $err_list {
                  puts $CHECK_OUTPUT "error in: $elem"
               } 
               puts $CHECK_OUTPUT "try again? (y/n)"
               set answer [wait_for_enter 1]
               if { $answer == "n" } {
                  puts $CHECK_OUTPUT "Do you want to save your changes? (y/n)"
                  set answer [wait_for_enter 1]
                  if { $answer == "y" } {
                     if { [ save_host_configuration $file] != 0} {
                        puts $CHECK_OUTPUT "Could not save host configuration"
                        wait_for_enter
                     }
                  }
                  return
               } else {
                  continue
               }
            } else {
              set not_ok 0
            }
         }
         if { [ save_host_configuration $file] != 0} {
            puts $CHECK_OUTPUT "Could not save host configuration"
            wait_for_enter
            return
         }
      }
      if { $force == 1 } {
         if { [ save_host_configuration $file] != 0} {
            puts $CHECK_OUTPUT "Could not save host configuration"
            wait_for_enter
         }
      }
      return
   } else {
      puts $CHECK_OUTPUT "could not open host config file \"$file\""
      puts $CHECK_OUTPUT "press return to create new host configuration file"
      wait_for_enter 1
      if { [ save_host_configuration $file] != 0} {
         exit -1
      }
      setup_host_config $file
   }
}

#****** config/host/host_conf_get_nodes() **************************************
#  NAME
#     host_conf_get_nodes() -- return a list of exechosts and zones
#
#  SYNOPSIS
#     host_conf_get_nodes { host_list } 
#
#  FUNCTION
#     Iterates through host_list and builds a new node list, that contains
#     both hosts and zones.
#     If zones are available on a host, only the zones are contained in the new
#     node list,
#     if no zones are available on a host, the hostname will be contained in the
#     new node list.
#
#  INPUTS
#     host_list - list of physical hosts
#
#  RESULT
#     node list
#
#  SEE ALSO
#     config/host/host_conf_get_unique_nodes()
#*******************************************************************************
proc host_conf_get_nodes {host_list} {
   global ts_host_config

   set node_list {}

   foreach host $host_list {
      if {![info exists ts_host_config($host,zones)]} {
         add_proc_error "host_conf_get_nodes" -1 "host $host is not contained in testsuite host configuration!"
      } else {
         set zones $ts_host_config($host,zones)
         if {[llength $zones] == 0} {
            lappend node_list $host
         } else {
            set node_list [concat $node_list $zones]
         }
      }
   }

   return [lsort -dictionary $node_list]
}

#****** config/host/host_conf_get_unique_nodes() *******************************
#  NAME
#     host_conf_get_unique_nodes() -- return a unique list of exechosts and zones
#
#  SYNOPSIS
#     host_conf_get_unique_nodes { host_list } 
#
#  FUNCTION
#     Iterates through host_list and builds a new node list, that contains
#     both hosts and zones, but only one entry per physical host.
#     If zones are available on a host, only the first zone is contained in the new
#     node list,
#     if no zones are available on a host, the hostname will be contained in the
#     new node list.
#
#  INPUTS
#     host_list - list of physical hosts
#
#  RESULT
#     node list
#
#  SEE ALSO
#     config/host/host_conf_get_nodes()
#*******************************************************************************
proc host_conf_get_unique_nodes {host_list} {
   global ts_host_config

   set node_list {}

   foreach host $host_list {
      if {![info exists ts_host_config($host,zones)]} {
         add_proc_error "host_conf_get_unique_nodes" -1 "host $host is not contained in testsuite host configuration!"
      } else {
         set zones $ts_host_config($host,zones)
         if {[llength $zones] == 0} {
            lappend node_list $host
         } else {
            set node_list [concat $node_list [lindex $zones 0]]
         }
      }
   }

   return [lsort -dictionary $node_list]
}

proc host_conf_get_unique_arch_nodes {host_list} {
   global ts_host_config

   set node_list {}
   set covered_archs {}

   foreach node $host_list {
      set host [node_get_host $node]
      set arch [host_conf_get_arch $host]
      if {[lsearch -exact $covered_archs $arch] == -1} {
         lappend covered_archs $arch
         lappend node_list $node
      }
   }

   return $node_list
}

proc host_conf_get_all_nodes {host_list} {
   global ts_host_config

   set node_list {}

   foreach host $host_list {
      lappend node_list $host

      if {![info exists ts_host_config($host,zones)]} {
         add_proc_error "host_conf_get_all_nodes" -1 "host $host is not contained in testsuite host configuration!"
      } else {
         set zones $ts_host_config($host,zones)
         if {[llength $zones] > 0} {
            set node_list [concat $node_list $zones]
         }
      }
   }

   return [lsort -dictionary $node_list]
}

proc node_get_host {nodename} {
   global physical_host

   if {[info exists physical_host($nodename)]} {
      set ret $physical_host($nodename)
   } else {
      set ret $nodename
   }

   return $ret
}

proc node_set_host {nodename hostname} {
   global physical_host

   set physical_host($nodename) $hostname
}

proc node_get_processors {nodename} {
   global ts_host_config

   set host [node_get_host $nodename]

   return $ts_host_config($host,processors)
}

#****** config_host/host_conf_get_archs() **************************************
#  NAME
#     host_conf_get_archs() -- get all archs covered by a list of hosts
#
#  SYNOPSIS
#     host_conf_get_archs { nodelist } 
#
#  FUNCTION
#     Takes a list of hosts and returns a unique list of the architectures
#     of the hosts.
#
#  INPUTS
#     nodelist - list of nodes
#
#  RESULT
#     list of architectures
#*******************************************************************************
proc host_conf_get_archs {nodelist} {
   global ts_host_config

   set archs {}
   foreach node $nodelist {
      set host [node_get_host $node]
      lappend archs [host_conf_get_arch $host]
   }

   return [lsort -unique $archs]
}

#****** config_host/host_conf_get_arch_hosts() *********************************
#  NAME
#     host_conf_get_arch_hosts() -- find hosts of certain architectures
#
#  SYNOPSIS
#     host_conf_get_arch_hosts { archs } 
#
#  FUNCTION
#     Returns all hosts configured in the testuite host configuration,
#     that have one of the given architectures.
#
#  INPUTS
#     archs - list of architecture names
#
#  RESULT
#     list of hosts
#*******************************************************************************
proc host_conf_get_arch_hosts {archs} {
   global ts_host_config

   set hostlist {}

   foreach host $ts_host_config(hostlist) {
      if {[lsearch -exact $archs [host_conf_get_arch $host]] >= 0} {
         lappend hostlist $host
      }
   }

   return $hostlist
}

#****** config_host/host_conf_get_unused_host() ********************************
#  NAME
#     host_conf_get_unused_host() -- find a host not being referenced in our cluster
#
#  SYNOPSIS
#     host_conf_get_unused_host { {raise_error 1} } 
#
#  FUNCTION
#     Tries to find a host in the testsuite host configuration that
#     - is not referenced in the installed cluster (master/exec/submit/bdb_server)
#     - has an installed architecture
#
#  INPUTS
#     {raise_error 1} - raise an error (unsupported warning) if no such host is found
#
#  RESULT
#     The name of a host matching the above description.
#*******************************************************************************
proc host_conf_get_unused_host {{raise_error 1}} {
   global ts_config ts_host_config

   # return an empty string if we don't find a suited host
   set ret ""

   # get a list of all hosts referenced in the cluster
   set cluster_hosts [host_conf_get_cluster_hosts]

   # get a list of all available architectures
   set archs [host_conf_get_archs $cluster_hosts]
   if {$ts_config(add_compile_archs) != "none"} {
      append archs " $ts_config(add_compile_archs)"
   }
   set archs [lsort -unique $archs]

   # now search a host having an installed architecture
   # and not being part of our cluster
   set installed_hosts [host_conf_get_arch_hosts $archs]
   foreach host $installed_hosts {
      if {[lsearch -exact $cluster_hosts $host] == -1} {
         set ret $host
         break
      }
   }

   if {$ret == "" && $raise_error} {
      add_proc_error "host_conf_get_unused_host" -3 "cannot find an unused host having an installed architecture" 
   }

   return $ret
}

#****** config_host/get_java_home_for_host() **************************************************
#  NAME
#    get_java_home_for_host() -- Get the java home directory for a host. If no/unknown java 
#                                version specified returns java home for java 1.4.
#
#  SYNOPSIS
#    get_java_home_for_host { host {java_version "1.4"} } 
#
#  FUNCTION
#     Reads the java home directory for a host from the host configuration
#
#  INPUTS
#    host -- name of the host
#
#  RESULT
#     
#     the java home directory of an empty string if the java is not set 
#     in the host configuration
#
#  EXAMPLE
#
#     set java_home [get_java_home_for_host $CHECK_HOST "1.6"]
#
#     if { $java_home == "" } {
#         puts "java not configurated for host $CHECK_HOST"
#     }
#
#  NOTES
#     TODO: store JAVA_HOME in host config!
#
#  BUGS
#     Doesn't work for MAC OS X
#  SEE ALSO
#*******************************************************************************
proc get_java_home_for_host { host {java_version "1.4"} } {
    global ts_host_config CHECK_OUTPUT
    set version [get_testsuite_java_version $java_version]
    set input $ts_host_config($host,java$version)

    if { $input == "" } {
       puts $CHECK_OUTPUT "Error: java$version is not set for host: $host"
       return ""
    }
    
    set input_len [ string length $input ]
    set java_len  [ string length "/bin/java" ]
    
    set last [ expr ( $input_len - $java_len -1 ) ]
    
    set res [ string range $input 0 $last]
    
    return $res
}

proc get_testsuite_java_version { {version "1.4"} } {
   global CHECK_OUTPUT

   switch -exact $version {
     "1.4" {
        return "14"
     }
     "1.5" {
        return "15"
     }
     "1.6" {
        return "16"
     }
   }
   puts $CHECK_OUTPUT "Warning: Unknown java_version: $version. Java 1.4 will be used instead!"
   return "14"
}


#****** config_host/host_conf_get_cluster_hosts() ******************************
#  NAME
#     host_conf_get_cluster_hosts() -- get a list of cluster hosts
#
#  SYNOPSIS
#     host_conf_get_cluster_hosts { } 
#
#  FUNCTION
#     Returns a list of all hosts that are part of the given cluster.
#     The list contains
#     - the master host
#     - the execd hosts
#     - the execd nodes (execd hosts with Solaris zones resolved)
#     - submit only hosts
#     - a berkeleydb RPC server host
#
#     The list is sorted by hostname, hostnames are unique.
#
#  RESULT
#     hostlist
#*******************************************************************************
proc host_conf_get_cluster_hosts {} {
   global ts_config CHECK_OUTPUT

   set hosts "$ts_config(master_host) $ts_config(execd_hosts) $ts_config(execd_nodes) $ts_config(submit_only_hosts) $ts_config(bdb_server)"
   set cluster_hosts [lsort -dictionary -unique $hosts]
   set none_elem [lsearch $cluster_hosts "none"]
   if {$none_elem >= 0} {
      set cluster_hosts [lreplace $cluster_hosts $none_elem $none_elem]
   }

   return $cluster_hosts
}

#****** config_host/host_conf_is_compile_host() ********************************
#  NAME
#     host_conf_is_compile_host() -- is a given host compile host?
#
#  SYNOPSIS
#     host_conf_is_compile_host { host {config_var ""} } 
#
#  FUNCTION
#     Returns if a given host is used as compile host.
#     The information is retrieved from the ts_host_config array,
#     unless another array is specified (e.g. during configuration).
#
#  INPUTS
#     host            - the host
#     {config_var ""} - configuration array, default ts_host_config
#
#  RESULT
#     0: is not compile host
#     1: is compile host
#*******************************************************************************
proc host_conf_is_compile_host {host {config_var ""}} {
   global ts_config ts_host_config CHECK_OUTPUT
   
   # we might work on a temporary config
   if {$config_var == ""} { 
      upvar 0 ts_host_config config
   } else {
      upvar 1 $config_var config
   }

   set ret 0

   if {[info exists config($host,compile,$ts_config(gridengine_version))]} {
      set ret $config($host,compile,$ts_config(gridengine_version))
   }

   return $ret
}

#****** config_host/host_conf_is_java_compile_host() ********************************
#  NAME
#     host_conf_is_java_compile_host() -- is a given host compile host for java?
#
#  SYNOPSIS
#     host_conf_is_java_compile_host { host {config_var ""} } 
#
#  FUNCTION
#     Returns if a given host is used as java compile host.
#     The information is retrieved from the ts_host_config array,
#     unless another array is specified (e.g. during configuration).
#
#  INPUTS
#     host            - the host
#     {config_var ""} - configuration array, default ts_host_config
#
#  RESULT
#     0: is not java compile host
#     1: is compile host
#*******************************************************************************
proc host_conf_is_java_compile_host {host {config_var ""}} {
   global ts_config ts_host_config CHECK_OUTPUT
   
   # we might work on a temporary config
   if {$config_var == ""} { 
      upvar 0 ts_host_config config
   } else {
      upvar 1 $config_var config
   }

   set ret 0

   if {[info exists config($host,java_compile,$ts_config(gridengine_version))]} {
      set ret $config($host,java_compile,$ts_config(gridengine_version))
   }

   return $ret
}

#****** config_host/host_conf_get_arch() ***************************************
#  NAME
#     host_conf_get_arch() -- return a host's architecture
#
#  SYNOPSIS
#     host_conf_get_arch { host {config_var ""} } 
#
#  FUNCTION
#     Returns the architecture that is configured in the testsuite
#     host configuration.
#     The architecture string may be Grid Engine version dependent, that
#     means, the function may return different architecture strings for
#     different Grid Engine version (53, 60, 61, ...).
#     If a host is not supported platform for a certain Grid Engine version,
#     "unsupported" is returned as archictecture name.
#
#  INPUTS
#     host            - the host
#     {config_var ""} - configuration array, default ts_host_config
#
#  RESULT
#     an architecture string, e.g. sol-sparc64, darwin, ...
#*******************************************************************************
proc host_conf_get_arch {host {config_var ""}} {
   global ts_config ts_host_config CHECK_OUTPUT
   
   # we might work on a temporary config
   if {$config_var == ""} { 
      upvar 0 ts_host_config config
   } else {
      upvar 1 $config_var config
   }

   set ret ""

   if {[info exists config($host,arch,$ts_config(gridengine_version))]} {
      set ret $config($host,arch,$ts_config(gridengine_version))
   }

   # before the 6.0u4, we had no sol-amd64 port, but used the sol-x86 binaries
   if {$ts_config(gridengine_version) == 60 && $ret == "sol-amd64"} {
      switch -exact $ts_config(source_cvs_release) {
         "V60_TAG" -
         "V60u1_TAG" -
         "V60u2_TAG" -
         "V60u3_TAG" {
            set ret "sol-x86"
         }
      }
   }

   return $ret
}

#****** config_host/host_conf_is_known_host() **********************************
#  NAME
#     host_conf_is_known_host() -- is a host configured in testsuite host conf
#
#  SYNOPSIS
#     host_conf_is_known_host { host {config_var ""} } 
#
#  FUNCTION
#     Checks if a given host is configured in the testsuite host configuration.
#
#  INPUTS
#     host            - the host
#     {config_var ""} - configuration array, default ts_host_config
#
#  RESULT
#     0: host is not configured in testsuite host config
#     1: is a configured host
#
#  SEE ALSO
#     config_host/host_conf_is_supported_host()
#*******************************************************************************
proc host_conf_is_known_host {host {config_var ""}} {
   global ts_config ts_host_config CHECK_OUTPUT

   # we might work on a temporary config
   if {$config_var == ""} { 
      upvar 0 ts_host_config config
   } else {
      upvar 1 $config_var config
   }

   set ret 1

   if {[lsearch $config(hostlist) $host] < 0} {
      puts $CHECK_OUTPUT "Host \"$host\" is not in host configuration file"
      set ret 0
   }

   return $ret
}

#****** config_host/host_conf_is_supported_host() ******************************
#  NAME
#     host_conf_is_supported_host() -- is host supported for given GE version
#
#  SYNOPSIS
#     host_conf_is_supported_host { host {config_var ""} } 
#
#  FUNCTION
#     Checks if the given host is configured in the Grid Engine host
#     configuration and if it has an architecture, that is supported by the
#     given Grid Engine version.
#
#  INPUTS
#     host            - the host
#     {config_var ""} - configuration array, default ts_host_config
#
#  RESULT
#     0: host is not supported
#     1: is a supported host
#
#  SEE ALSO
#     config_host/host_conf_is_known_host()
#*******************************************************************************
proc host_conf_is_supported_host {host {config_var ""}} {
   global ts_config ts_host_config CHECK_OUTPUT

   # we might work on a temporary config
   if {$config_var == ""} { 
      upvar 0 ts_host_config config
   } else {
      upvar 1 $config_var config
   }

   set ret [host_conf_is_known_host $host config]

   if {$ret} {
      if {[host_conf_get_arch $host config] == "unsupported"} {
         puts $CHECK_OUTPUT "Host \"$host\" is not supported with Grid Engine $ts_config(gridengine_version)"
         set ret 0
      }
   }

   return $ret
}

#****** config_host/host_conf_53_arch() ****************************************
#  NAME
#     host_conf_53_arch() -- convert any arch string to 53 arch string
#
#  SYNOPSIS
#     host_conf_53_arch { arch } 
#
#  FUNCTION
#     Takes an architecture string and tries to convert it to a Grid Engine
#     5.3 architecture string.
#
#     If the given architecture string cannot be converted, "unknown" will
#     be returned.
#
#  INPUTS
#     arch - any arch string
#
#  RESULT
#     5.3 architecture string or "unknown"
#
#  SEE ALSO
#     config_host/host_conf_60_arch()
#     config_host/host_conf_61_arch()
#*******************************************************************************
proc host_conf_53_arch {arch} {
   switch -glob $arch {
      "sol-sparc" { return "solaris" }
      "sol-sparc64" { return "solaris64" }
      "sol-x86" { return "solaris86" }
      "lx??-x86" { return "glinux" }
      "lx??-alpha" { return "alinux" }
      "lx??-sparc" { return "slinux" }
      "lx??-ia64" { return "ia64linux" }
      "lx??-amd64" { return "lx24-amd64" }
      "irix65" { return "irix6" }

      "osf4" -
      "tru64" -
      "irix6" -
      "hp10" -
      "hp11" -
      "hp11-64" -
      "aix42" -
      "aix43" -
      "aix51" -
      "cray" -
      "crayts" -
      "craytsieee" -
      "necsx4" -
      "necsx5" -
      "sx" -
      "darwin" -
      "fbsd-*" -
      "nbsd-*" {
         return $arch
      }
   }

   return "unsupported"
}

#****** config_host/host_conf_60_arch() ****************************************
#  NAME
#     host_conf_60_arch() -- convert any arch string to 60 arch string
#
#  SYNOPSIS
#     host_conf_60_arch { arch } 
#
#  FUNCTION
#     Takes an architecture string and tries to convert it to a Grid Engine
#     6.0 architecture string.
#
#     If the given architecture string cannot be converted, "unknown" will
#     be returned.
#
#  INPUTS
#     arch - any arch string
#
#  RESULT
#     6.0 architecture string or "unknown"
#
#  SEE ALSO
#     config_host/host_conf_53_arch()
#     config_host/host_conf_61_arch()
#*******************************************************************************
proc host_conf_60_arch {arch} {
   # map old 5.3 names to 6.0
   # map 6.1 names to 6.0
   # allow all sol-, lx, fbsd, nbsd platforms for testsuite
   # allow selected architecture names
   # the rest will be unsupported
   switch -glob $arch {
      "solaris" { return "sol-sparc" }
      "solaris64" { return "sol-sparc64" }
      "solaris86" { return "sol-x86" }
      "glinux" { return "lx24-x86" }
      "alinux" { return "lx24-alpha" }
      "slinux" { return "lx24-sparc" }
      "ia64linux" { return "lx24-ia64" }
      "darwin-ppc" { return "darwin" }

      "sol-*" -
      "lx??-*" -
      "fbsd-*" -
      "nbsd-*" -

      "tru64" -
      "irix65" -
      "hp11" -
      "hp11-64" -
      "aix43" -
      "aix51" -
      "cray" -
      "crayts" -
      "craytsieee" -
      "craysmp" -
      "sx" -
      "darwin" -
      "win32-*" {
         return $arch
      }
   }

   return "unsupported"
}

#****** config_host/host_conf_61_arch() ****************************************
#  NAME
#     host_conf_61_arch() -- convert any arch string to 61 arch string
#
#  SYNOPSIS
#     host_conf_61_arch { arch } 
#
#  FUNCTION
#     Takes an architecture string and tries to convert it to a Grid Engine
#     6.1 architecture string.
#
#     If the given architecture string cannot be converted, "unknown" will
#     be returned.
#
#  INPUTS
#     arch - any arch string
#
#  RESULT
#     6.1 architecture string or "unknown"
#
#  SEE ALSO
#     config_host/host_conf_53_arch()
#     config_host/host_conf_60_arch()
#*******************************************************************************
proc host_conf_61_arch {arch} {
   # map old 5.3 names to 6.1
   # map 6.0 names to 6.1
   # allow all sol-, lx, fbsd, nbsd platforms for testsuite
   # allow selected architecture names
   # the rest will be unsupported
   switch -glob $arch {
      "solaris" { return "sol-sparc" }
      "solaris64" { return "sol-sparc64" }
      "solaris86" { return "sol-x86" }
      "glinux" { return "lx24-x86" }
      "alinux" { return "lx24-alpha" }
      "slinux" { return "lx24-sparc" }
      "ia64linux" { return "lx24-ia64" }

      "darwin" { return "darwin-ppc" }

      "sol-*" -
      "lx??-*" -
      "fbsd-*" -
      "nbsd-*" -

      "irix65" -
      "hp11" -
      "hp11-64" -
      "aix51" -
      "cray" -
      "crayts" -
      "craytsieee" -
      "craysmp" -
      "sx" -
      "darwin-ppc" -
      "darwin-x86" -
      "win32-*" {
         return $arch
      }
   }

   return "unsupported"
}

#****** config_host/host_conf_have_windows() ***********************************
#  NAME
#     host_conf_have_windows() -- do we have a windows host
#
#  SYNOPSIS
#     host_conf_have_windows { } 
#
#  FUNCTION
#     Returns whether we have a windows host in our testsuite cluster 
#     configuration.
#
#  RESULT
#     1 - if we have a windows host, else 0
#
#  SEE ALSO
#     config_host/host_conf_have_windows()
#     config_host/host_conf_get_cluster_hosts()
#     config_host/host_conf_get_arch()
#*******************************************************************************
proc host_conf_have_windows {} {
   set ret 0

   # get a list of all hosts referenced in the cluster
   set cluster_hosts [host_conf_get_cluster_hosts]

   # search for a windows host
   foreach host $cluster_hosts {
      if {[host_conf_get_arch $host] == "win32-x86"} {
         set ret 1
         break
      }
   }

   return $ret
}

#****** config_host/host_conf_get_windows_host() *******************************
#  NAME
#     host_conf_get_windows_host() -- get a windows host
#
#  SYNOPSIS
#     host_conf_get_windows_host { } 
#
#  FUNCTION
#     Returns the hostname of the first windows host in our testsuite cluster
#     configuration.
#
#  RESULT
#     A hostname of a windows host, or an empty string, if we don't have a 
#     windows host in our cluster.
#
#  SEE ALSO
#     config_host/host_conf_have_windows()
#     config_host/host_conf_get_cluster_hosts()
#     config_host/host_conf_get_arch()
#*******************************************************************************
proc host_conf_get_windows_host {} {
   set ret ""

   # get a list of all hosts referenced in the cluster
   set cluster_hosts [host_conf_get_cluster_hosts]
   
   # search and return the first windows host
   foreach host $cluster_hosts {
      if {[host_conf_get_arch $host] == "win32-x86"} {
         set ret $host
         break
      }
   }

   return $ret
}

#****** config_host/host_conf_get_windows_exec_host() **************************
#  NAME
#     host_conf_get_windows_exec_host() -- get a windows exec host
#
#  SYNOPSIS
#     host_conf_get_windows_exec_host { } 
#
#  FUNCTION
#     Returns the hostname of the first windows exec host in our testsuite
#     cluster configuration.
#
#  RESULT
#     A hostname of a windows exec host, or an empty string, if we don't have a 
#     windows exec host in our cluster.
#
#  SEE ALSO
#     config_host/host_conf_get_arch()
#*******************************************************************************
proc host_conf_get_windows_exec_host {} {
   global ts_config CHECK_OUTPUT
   set ret ""

   # get a list of all exec hosts referenced in the cluster
   set exec_hosts $ts_config(execd_nodes)

   # search for a windows host
   foreach host $exec_hosts {
      if {[host_conf_get_arch $host] == "win32-x86"} {
         set ret $host
         break
      }
   }

   return $ret
}

#****** config_host/host_conf_get_java_compile_host() **************************
#  NAME
#     host_conf_get_java_compile_host() -- get java compile host
#
#  SYNOPSIS
#     host_conf_get_java_compile_host { {raise_error 1} } 
#
#  FUNCTION
#     Returns the name of the java compile host configured in the host config.
#     If no compile host is found, an error is raised and an empty string
#     is returned.
#
#  INPUTS
#     {raise_error 1} - raise error condition or just output error message
#
#  RESULT
#     name of compile host or "", if no compile host was found
#
#  SEE ALSO
#     config_host/host_conf_is_java_compile_host()
#*******************************************************************************
proc host_conf_get_java_compile_host {{raise_error 1}} {
   global ts_config ts_host_config CHECK_OUTPUT

   set compile_host ""
   foreach host $ts_host_config(hostlist) {
      if {[host_conf_is_java_compile_host $host]} {
         set compile_host $host
         break
      }
   }

   if {$compile_host == ""} {
      add_proc_error "host_conf_get_java_compile_host" -1 "didn't find java compile host in host configuration" $raise_error
   }

   return $compile_host
}

#****** config_host/host_conf_get_send_speed() *********************************
#  NAME
#     host_conf_get_send_speed() -- get send speed for a certain host
#
#  SYNOPSIS
#     host_conf_get_send_speed {host} 
#
#  FUNCTION
#     Returns the send speed configured for a given host in the testsuite 
#     host configuration.
#
#     If the given hostname is a Solaris zone, the send speed configured
#     for the physical host is returned.
#
#     If the host is not (yet) known, e.g. while it is added to the host config,
#     a default value of 0.001 is returned.
#
#  INPUTS
#     host - name of the host or zone
#            if "" is given as hostname, the default value will be returned
#
#  RESULT
#     send_speed configured in host configuration, or default 0.001
#     Meant to set as "send_slow" before calls to "send -s".
#
#  SEE ALSO
#     remote_procedures/ts_send()
#*******************************************************************************
proc host_conf_get_send_speed {host_in} {
   global ts_host_config

   # if we don' know the host: return default
   if {$host_in == ""} {
      return 0.001
   }

   # remove domain part of hostname
   set host [lindex [split $host_in "."] 0]

   # resolve node (poss. zone) to physical host
   set host [node_get_host $host]
   if {[info exists ts_host_config($host,send_speed)]} {
      return $ts_host_config($host,send_speed)
   }

   # don't know the host yet (e.g. when adding a new host): return default
   return 0.001
}

#****** config_host/host_has_newgrp() ******************************************
#  NAME
#     host_has_newgrp() -- does host have newgrp
#
#  SYNOPSIS
#     host_has_newgrp {host {raise_error 1}} 
#
#  FUNCTION
#     Evaluate if a given host has a newgrp command.
#     On certain architectures (e.g. windows, netbsd), newgrp is not available.
#
#  INPUTS
#     host            - host on which we'd like to execute newgrp
#     {raise_error 1} - raise an unsupported warning, if no newgrp is available?
#
#  RESULT
#     0 - no newgrp is available
#     1 - newgrp is available
#*******************************************************************************
proc host_has_newgrp {host {raise_error 1}} {
   set ret 1

   set arch [resolve_arch $host]
   switch -exact $arch {
      "nbsd-i386" -
      "darwin*" -
      "win32-x86" {
         add_proc_error "host_has_newgrp" -3 "host $host ($arch) doesn't support newgrp" $raise_error
         set ret 0
      }
   }

   return $ret
}

#****** config_host/host_get_id_a_command() ************************************
#  NAME
#     host_get_id_a_command() -- return the id command for a host
#
#  SYNOPSIS
#     host_get_id_a_command { host } 
#
#  FUNCTION
#     Returns the id -a equivalent for the given host.
#     This is either "id -a", or "id", depending on hosts architecture.
#
#  INPUTS
#     host - host for which we need a valid id -a command
#
#  RESULT
#     The command.
#
#  EXAMPLE
#     host_get_id_a_command a_linux_host will return "/usr/bin/id -a"
#     host_get_id_a_command a_netbsd_host will return "/usr/bin/id"
#*******************************************************************************
proc host_get_id_a_command {host} {
   set arch [resolve_arch $host]

   switch -exact $arch {
      "aix42" -
      "aix43" -
      "darwin" -
      "darwin-ppc" -
      "darwin-x86" -
      "nbsd-i386" -
      "osf4" -
      "tru64" -
      "win32-x86" {
         set ret "/usr/bin/id"
      }
      default {
         set ret "/usr/bin/id -a"
      }
   }

   return $ret
}

#****** config_host/host_conf_get_suited_hosts() *******************************
#  NAME
#     host_conf_get_suited_hosts() -- get hosts suited for operation
#
#  SYNOPSIS
#     host_conf_get_suited_hosts { {num_hosts 1} {selected_archs {}} 
#     {excluded_archs {}} } 
#
#  FUNCTION
#     Returns hosts from the exec node list, selected by certain criteria.
#
#     For many checks, or for operations like calling a Grid Engine binary
#     (qstat, qconf, ...), we need to decide, on which host to do the check.
#     This can be done by calling host_conf_get_suited_host.
#     host_conf_get_suited_host allows filtering the host list following 
#     certain criteria:
#        - by preferred architecture:
#          Hosts will be returned matching these preferred architectures.
#          If more hosts are needed than provided with the preferred
#          architectures, other hosts will be returned as well.
#        - by selecting architectures:
#          In this case, only hosts of the selected architectures will
#          be returned.
#        - by excluding certain architectures:
#          Hosts having these architectures will excluded from the host list.
#
#     If no preferred architectures are specified at the function call,
#     but the preferred_archs commandline switch has been used, the archs
#     specified at the commandline will be used as preferred archs.
#
#     If multiple hosts are candiates for host selection, the host(s) will be
#     returned, that have not been used for the longest time period.
#
#  INPUTS
#     {num_hosts 1}        - number of hosts to return.
#     {preferred_archs {}} - if possible, select this architecture
#     {selected_archs {}}  - select this architecture
#     {excluded_archs {}}  - do not select this architecture
#
#  RESULT
#     A list of hosts matching the criteria.
#
#  EXAMPLE
#     host_conf_get_suited_hosts
#        will return one host (the one not being used for the longest time).
#
#     host_conf_get_suited_hosts 2
#        will return 2 hosts (the ones not being used for the longest time).
#
#     host_conf_get_suited_hosts 1 {sol-sparc64 sol-x86}
#        will return one host, if possible a sol-sparc64, or a sol-x86, or
#        if we have neither sol-sparc64 nor sol-x86 host, any other arch.
#
#     host_conf_get_suited_hosts 1 {} {sol-sparc64}
#        will return one sol-sparc64 host, or raise an error, if we don't
#        have sol-sparc64 in our cluster
#
#     host_conf_get_suited_hosts 1 {sol-sparc64} {sol-amd64 sol-sparc64}
#        will return one host, either sol-amd64 or sol-sparc, but we prefer
#        to get a sol-sparc64 host.
#
#     host_conf_get_suited_hosts 1 {} {sol-amd64 sol-sparc64} {sol-amd64}
#        error: selected and excluded architecture may not overlap
#
#     host_conf_get_suited_hosts 4 {} {} {lx24-ia64}
#        return 4 hosts of any architecture, but not on Linux on Itanic.
#
#     host_conf_get_suited_hosts 4 {sol-sparc64} {} {lx24-ia64}
#        return 4 hosts of any architecture, we prefer to get sol-sparc64 hosts,
#        but cannot use Linux on Itanic.
#*******************************************************************************
proc host_conf_get_suited_hosts {{num_hosts 1} {preferred_archs {}} {selected_archs {}} {excluded_archs {}}} {
   global ts_config CHECK_OUTPUT
   global CHECK_PREFERRED_ARCHS

   # preferred archs as option to the function call will override
   # globally defined preferred archs (through commandline option at testsuite start).
   if {$preferred_archs == {} && $CHECK_PREFERRED_ARCHS != {}} {
      set preferred_archs $CHECK_PREFERRED_ARCHS
   }

   # (re)build cache
   host_conf_get_suited_hosts_rebuild_cache

   # build a list of candidates from parameters
   host_conf_get_suited_hosts_candidates $preferred_archs $selected_archs $excluded_archs preferred_hosts remaining_hosts

   if {[expr [llength $preferred_hosts] + [llength $remaining_hosts]] < $num_hosts} {
      add_proc_error "host_conf_get_suited_hosts" -1 "host_selection doesn't return the required number of hosts ($num_hosts):\npreferred_archs:    $preferred_archs\nselected_archs:     $selected_archs\nexcluded_archs:     $excluded_archs\nresulting hostlist: $preferred_hosts $remaining_hosts"
      return {}
   }

   set hosts [host_conf_get_suited_hosts_select $num_hosts $preferred_hosts $remaining_hosts]
   return $hosts
}

#****** config_host/host_conf_get_suited_hosts_rebuild_cache() *****************
#  NAME
#     host_conf_get_suited_hosts_rebuild_cache() -- initialization (internal)
#
#  SYNOPSIS
#     host_conf_get_suited_hosts_rebuild_cache { } 
#
#  FUNCTION
#     Initializes the caches used by host_conf_get_suited_hosts
#     Internal - do not call in tests.
#
#  SEE ALSO
#     config_host/host_conf_get_suited_hosts()
#*******************************************************************************
proc host_conf_get_suited_hosts_rebuild_cache {} {
   global ts_config CHECK_OUTPUT
   global suited_host_cache suited_arch_cache
   global suited_exec_node_backup

   # first call, initialize some variables
   if {![info exists suited_exec_node_backup]} {
      set suited_exec_node_backup $ts_config(execd_nodes)
   } else {
      # if the exec_node_list changed, clear cache
      if {$suited_exec_node_backup != $ts_config(execd_nodes)} {
         puts $CHECK_OUTPUT "the exec node list was modified - rebuilding suited host cache"
         unset -nocomplain suited_host_cache
         unset -nocomplain suited_arch_cache
      }
   }

   # (re)build cache, if it doesn't exist
   if {![info exists suited_host_cache]} {
      foreach host $ts_config(execd_nodes) {
         set suited_host_cache($host) 0
         set arch [resolve_arch $host]
         if {![info exists suited_arch_cache($arch)]} {
            set suited_arch_cache($arch) {}
         }
         lappend suited_arch_cache($arch) $host
      }
   }
}

#****** config_host/host_conf_get_suited_hosts_candidates() ********************
#  NAME
#     host_conf_get_suited_hosts_candidates() -- select possible hosts (internal)
#
#  SYNOPSIS
#     host_conf_get_suited_hosts_candidates { preferred selected excluded 
#     preferred_var remaining_var } 
#
#  FUNCTION
#     Selects host matching certain criteria.
#     Internal use only in host_conf_get_suited_hosts.
#
#  INPUTS
#     preferred     - list of preferred architectures
#     selected      - list of selected architectures
#     excluded      - list of excluded architectures
#     preferred_var - return preferred hosts here
#     remaining_var - return all other possible hosts here
#
#  RESULT
#     List of hosts for preferred use, and a list of other hosts that match the
#     selection criteria, but are not the preferred ones.
#
#  SEE ALSO
#     config_host/host_conf_get_suited_hosts()
#*******************************************************************************
proc host_conf_get_suited_hosts_candidates {preferred selected excluded preferred_var remaining_var} {
   global suited_host_cache suited_arch_cache
   upvar $preferred_var preferred_hosts
   upvar $remaining_var remaining_hosts
   set preferred_hosts {}
   set remaining_hosts {}

   # check: selected and excluded may not overlap 
   foreach arch $selected {
      if {[lsearch -exact $excluded $arch] >= 0} {
         add_proc_error "" -1 "selected and excluded architecture list overlap:\nselected: $selected\nexcluded: $excluded"
         return
      }
   }

   # check: selected archs must exist in the cluster
   set all_archs [array names suited_arch_cache]
   foreach arch $selected {
      if {[lsearch -exact $all_archs $arch] < 0} {
         add_proc_error "" -1 "selected architecture is not available in our cluster:\nselected:  $selected\navailable: $all_archs"
         return
      }
   }

   # if we have selected archs, use these
   if {$selected != {}} {
      set all_archs $selected
   } else {
      # remove the excluded archs from all available
      foreach arch $excluded {
         set pos [lsearch -exact $all_archs $arch]
         if {$pos >= 0} {
            set all_archs [lreplace $all_archs $pos $pos]
         }
      }
   }

   # rebuild preferred arch list from the available archs
   # build the list of remaining_archs
   set new_preferred {}
   set remaining_archs {}
   foreach arch $all_archs {
      if {[lsearch $preferred $arch] >= 0} {
         lappend new_preferred $arch
      } else {
         lappend remaining_archs $arch
      }
   }
   set preferred $new_preferred

   # finally build the host lists
   foreach arch $preferred {
      foreach host $suited_arch_cache($arch) {
         lappend preferred_hosts $host
      }
   }
   foreach arch $remaining_archs {
      foreach host $suited_arch_cache($arch) {
         lappend remaining_hosts $host
      }
   }
}

#****** config_host/host_conf_get_suited_hosts_select() ************************
#  NAME
#     host_conf_get_suited_hosts_select() -- select hosts from candiates (internal)
#
#  SYNOPSIS
#     host_conf_get_suited_hosts_select { num_hosts preferred_hosts 
#     remaining_hosts } 
#
#  FUNCTION
#     Selects hosts from a list of preferred hosts and a list of other
#     possible hosts.
#     Internal function - only to be called from host_conf_get_suited_hosts.
#
#  INPUTS
#     num_hosts       - number of hosts to return
#     preferred_hosts - the preferred hosts
#     remaining_hosts - other hosts (second choice)
#
#  RESULT
#     List of selected hosts.
#
#  SEE ALSO
#     config_host/host_conf_get_suited_hosts()
#*******************************************************************************
proc host_conf_get_suited_hosts_select {num_hosts preferred_hosts remaining_hosts} {
   global suited_host_cache

   set ret {}

   # first take hosts from the preferred host list
   # sort the list by "not used for the longest time"
   set hosts [lsort -command host_conf_sort_suited $preferred_hosts]

   foreach host $hosts {
      if {$num_hosts <= 0} {
         break
      }
      lappend ret $host
      set suited_host_cache($host) [timestamp]
      incr num_hosts -1
   }

   # if we need more hosts than available in the preferred hosts, 
   # take hosts from the remaining_hosts
   if {$num_hosts > 0} {
      # sort the list by "not used for the longest time"
      set hosts [lsort -command host_conf_sort_suited $remaining_hosts]

      foreach host $hosts {
         if {$num_hosts <= 0} {
            break
         }
         lappend ret $host
         set suited_host_cache($host) [timestamp]
         incr num_hosts -1
      }
   }

   return $ret
}

#****** config_host/host_conf_sort_suited() ************************************
#  NAME
#     host_conf_sort_suited() -- sorting function (internal)
#
#  SYNOPSIS
#     host_conf_sort_suited { a b } 
#
#  FUNCTION
#     Used for sorting hosts by "last used" criteria.
#     Internal use only from host_conf_get_suited_host.
#
#  INPUTS
#     a - host a
#     b - host b
#
#  RESULT
#     -1, 0, 1 - similar to string compare
#
#  SEE ALSO
#     config_host/host_conf_get_suited_hosts()
#*******************************************************************************
proc host_conf_sort_suited {a b} {
   global suited_host_cache

   if {$suited_host_cache($a) < $suited_host_cache($b)} {
      return -1
   } elseif {$suited_host_cache($a) == $suited_host_cache($b)} {
      return 0
   } else {
      return 1
   }
}

proc test_host_conf_get_suited_host {} {
   global CHECK_OUTPUT

   # any host(s) - increase number of hosts until it failes
   set num_hosts 1
   while {1} {
      set hosts [host_conf_get_suited_hosts $num_hosts]
      puts $CHECK_OUTPUT "-> $num_hosts\t$hosts"
      if {$hosts == {}} {
         break
      }
      sleep 1
      incr num_hosts
   }

   # test preferred hosts
   # 1 which should match my test cluster
   set hosts [host_conf_get_suited_hosts 1 "sol-sparc64"]
   puts $CHECK_OUTPUT "-> $hosts" ; wait_for_enter
   # here we should see fillup with other archs
   set hosts [host_conf_get_suited_hosts 4 "sol-sparc64"]
   puts $CHECK_OUTPUT "-> $hosts" ; wait_for_enter
   # this one will fail
   set hosts [host_conf_get_suited_hosts 1 "nonexisting-arch"]
   puts $CHECK_OUTPUT "-> $hosts" ; wait_for_enter

   # test selected hosts
   # 1 which should match my test cluster
   set hosts [host_conf_get_suited_hosts 1 {} "sol-sparc64"]
   puts $CHECK_OUTPUT "-> $hosts" ; wait_for_enter
   # this one should fail due to lack of 4 sol-sparc64 hosts
   set hosts [host_conf_get_suited_hosts 4 {} "sol-sparc64"]
   puts $CHECK_OUTPUT "-> $hosts" ; wait_for_enter
   # this one will fail due to unknown arch
   set hosts [host_conf_get_suited_hosts 1 {} "nonexisting-arch"]
   puts $CHECK_OUTPUT "-> $hosts" ; wait_for_enter
   # multiple selected archs with a preferred one
   set hosts [host_conf_get_suited_hosts 2 "sol-sparc64" "sol-amd64 sol-sparc64"]
   puts $CHECK_OUTPUT "-> $hosts" ; wait_for_enter

   # test excluded archs
   set hosts [host_conf_get_suited_hosts 6 "" "" "sol-amd64"]
   puts $CHECK_OUTPUT "-> $hosts" ; wait_for_enter

   # this one should return a error
   set hosts [host_conf_get_suited_hosts 1 "" "sol-amd64 sol-sparc64" "sol-amd64"]
   puts $CHECK_OUTPUT "-> $hosts" ; wait_for_enter
}
