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

global ts_checktree, hedeby_config
global CHECK_OUTPUT
global hedeby_checktree_nr
global hedeby_passwd
global ACT_CHECKTREE

# ts_source $ACT_CHECKTREE/sql_util
ts_source $ACT_CHECKTREE/util

set  hedeby_config(initialized) 0
set  hedeby_checktree_nr $ts_checktree($ACT_CHECKTREE)

set ts_checktree($hedeby_checktree_nr,setup_hooks_0_name)         "Hedeby configuration"
set ts_checktree($hedeby_checktree_nr,setup_hooks_0_config_array) hedeby_config
set ts_checktree($hedeby_checktree_nr,setup_hooks_0_init_func)    hedeby_init_config
set ts_checktree($hedeby_checktree_nr,setup_hooks_0_verify_func)  hedeby_verify_config
set ts_checktree($hedeby_checktree_nr,setup_hooks_0_save_func)    hedeby_save_configuration
set ts_checktree($hedeby_checktree_nr,setup_hooks_0_filename)     $ACT_CHECKTREE/hedeby_defaults.sav
set ts_checktree($hedeby_checktree_nr,setup_hooks_0_version)      "1.0"

set ts_checktree($hedeby_checktree_nr,checktree_clean_hooks_0)  "hedeby_clean"
set ts_checktree($hedeby_checktree_nr,compile_hooks_0)        "hedeby_compile"
set ts_checktree($hedeby_checktree_nr,compile_clean_hooks_0)  "hedeby_compile_clean"
set ts_checktree($hedeby_checktree_nr,install_binary_hooks_0) "hedeby_install_binaries"

set ts_checktree($hedeby_checktree_nr,required_hosts_hook)    "hedeby_get_required_hosts"
set ts_checktree($hedeby_checktree_nr,passwd_hook)    "hedeby_get_required_passwords"

set ts_checktree($hedeby_checktree_nr,shutdown_hooks_0)       "hedeby_shutdown"
set ts_checktree($hedeby_checktree_nr,startup_hooks_0)       "hedeby_startup"


proc hedeby_startup { { hostname "--" } { debugmode "0" } } {
   return [hedeby_gstat $hostname start root]
}

proc hedeby_get_system_name {} {
   global ts_config
   return "testsuite_$ts_config(commd_port)"
}

proc hedeby_shutdown { { hostname "--" } }  {
   if { [hedeby_gstat $hostname "shutdown" root] != 0 } {
      return -1
   }
   return 0
}



proc hedeby_gstat { hostname gstat_args { user "--" } } {
   return [hedeby_run_cli $hostname "gstat" $gstat_args $user]
}

proc hedeby_gconf { hostname gconf_args { user "--" } } {
   return [hedeby_run_cli $hostname "gconf" $gconf_args $user]
}

proc hedeby_run_cli { hostname cmd cmd_args { user "--" } } {
   
   global CHECK_OUTPUT CHECK_HOST CHECK_USER hedeby_config

   if { $cmd == "gconf" } {
      set cmd "$hedeby_config(dist)/bin/gconf"
   } elseif { $cmd == "gstat" } {
      set cmd "$hedeby_config(dist)/bin/gstat"
   } else {
      add_proc_error "hedeby_run_cli" -1 "unknown cli command \"$cmd\""
      return -1
   }
   set local_cmd_args  "--system "
   append local_cmd_args [hedeby_get_system_name]
   append local_cmd_args " -p SYSTEM "
   append local_cmd_args $cmd_args
   
   if { $hostname == "--" } {
      set hostname $CHECK_HOST
   }
   
   if { $user == "--" } {
      set user $CHECK_USER
   }
   
   set open_spawn [ open_remote_spawn_process $hostname $user "$cmd" "$local_cmd_args"]   
   set spawn_list [lindex $open_spawn 1]
   set timeout 60
   set result -1
   set output ""
   set error_count 0
   expect {
      -i $spawn_list full_buffer {
         add_proc_error "hedeby_run_cli" -1 "full_buffer error \"$hostname\""
      }
      -i $spawn_list timeout {
         add_proc_error "hedeby_run_cli" -1 "got timeout for host \"$hostname\""
      }
      -i $spawn_list eof {
         add_proc_error "hedeby_run_cli" -1 "got eof \"$hostname\""
      }
      -i $spawn_list "_exit_status_:(*)" {
         set result [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]         
      }
      -i $spawn_list -re {^ERROR:.*?\n} {
         puts $CHECK_OUTPUT "$expect_out(0,string)"
         incr error_count
         exp_continue
      }
      -i $spawn_list -re {^.*?\n} {
         puts $CHECK_OUTPUT "$expect_out(0,string)"
         exp_continue
      }
      
   }

   close_spawn_process $open_spawn
   
   if { $error_count > 0 } {
      return -1
   }
   return $result
   
}


#****** checktree/hedeby_compile() **************************************************
#  NAME
#    hedeby_compile() -- ???
#
#  SYNOPSIS
#    hedeby_compile { compile_hosts a_mail_body a_html_body  } 
#
#  FUNCTION
#     Compile hook for the Hedeby packages 
#
#  INPUTS
#    compile_hosts -- list of all compile host
#    a_mail_body   -- buffer for mail error reporting
#    a_html_body   -- buffer for html error reporting
#
#  RESULT
#     0  -- on succes
#     else  error
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc hedeby_compile { compile_hosts a_report } {
   upvar $a_report report
   
   
   
   set java_build_host [host_conf_get_java_compile_host]
   
   foreach build_host $compile_hosts {
      if { $build_host != $java_build_host } {
         set ret [hedeby_build $build_host "native.build" report]
         if { $ret != 0 } {
            add_proc_error "hedeby_compile" -1 "Native build on $build_host failed"
            return -1
         }
      }
   }
   
   set ret [hedeby_build $java_build_host "tar" report]
   if { $ret != 0 } {
      add_proc_error "hedeby_compile" -1 "Java compile run failed (return code $ret)"
      return -1
   }
   
   
   return 0
}


# This should reset the hedeby system (testsuite install re_init)
proc hedeby_clean {} {
   global CHECK_OUTPUT

   puts $CHECK_OUTPUT ""

   puts $CHECK_OUTPUT "--------------------------------"
   puts $CHECK_OUTPUT "hedeby_clean: NOT IMPLEMENTED!"
   puts $CHECK_OUTPUT "--------------------------------"

   return 0;
}


#****** checktree/hedeby_compile_clean() **************************************************
#  NAME
#    hedeby_compile_clean() -- compile clean hook for Hedeby
#
#  SYNOPSIS
#    hedeby_compile_clean { compile_hosts a_report } 
#
#  FUNCTION
#
#    call the hedeby build script with target clean
#
#  INPUTS
#    compile_hosts -- list of compile hosts
#    a_report      -- the report object
#
#  RESULT
#      0  --  successfull build
#      else -- failure
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
proc hedeby_compile_clean { compile_hosts a_report } {
   global CHECK_OUTPUT 
   upvar $a_report report

   return [hedeby_build $compile_hosts "clean" report]
}


#****** checktree/hedeby_build() **************************************************
#  NAME
#    hedeby_build() -- start the hedeby build script
#
#  SYNOPSIS
#    hedeby_build { compile_hosts target a_report } 
#
#  FUNCTION
#     starts the hedeby build script
#
#  INPUTS
#    build_host -- the  build hosts
#    target        -- the ant target
#    a_report      -- the report object
#
#  RESULT
#     0    -- succesfull build
#     else -- failure

#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc hedeby_build { build_host target a_report { ant_options "" } { hedeby_build_timeout 300 } } {
   global CHECK_OUTPUT CHECK_USER
   global CHECK_HTML_DIRECTORY CHECK_PROTOCOL_DIR
   global ts_config ts_host_config hedeby_config
   
   upvar $a_report report
   
   set task_nr [report_create_task report "hedeby_build_$target" $build_host]
   
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "-> starting hedeby ant $target on host $build_host ..."
   
   set env(JAVA_HOME) [get_java15_home_for_host $build_host]
   
   if { $env(JAVA_HOME) == "" } {
      report_task_add_message report $task_nr "Error: hededy build requires java15. It is not available on host $build_host"
      report_finish_task report $task_nr -1
      return -1
   }
   
   set env(ARCH)      [resolve_arch $build_host]
   

   report_task_add_message report $task_nr "using JAVA_HOME = $env(JAVA_HOME)"
   report_task_add_message report $task_nr "using ARCH = $env(ARCH)"

   if { [string length ant_options] > 0 } {
      set env(ANT_OPTS) "$ant_options"
      report_task_add_message report $task_nr "using ANT_OPTS = $env(ANT_OPTS)"
   }

   set open_spawn [ open_remote_spawn_process $build_host $CHECK_USER "ant" "-q $target" 0 "$hedeby_config(hedeby_source_dir)" env]
   set spawn_list [lindex $open_spawn 1]
   set timeout $hedeby_build_timeout
   set error -1
   set use_output 0
   expect {
      -i $spawn_list full_buffer {
         report_task_add_message report $task_nr "full_buffer error \"$build_host\""
      }
      -i $spawn_list timeout {
         report_task_add_message report $task_nr "got timeout for host \"$build_host\""
      }
      -i $spawn_list eof {
         report_task_add_message report $task_nr "got eof \"$build_host\""
      }
      -i $spawn_list "_exit_status_:(*)" {            
         set error [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]
         report_task_add_message report $task_nr "hedeby build script exited with status $error"
      }
      -i $spawn_list "_start_mark_:(0)" {
         set use_output 1
         report_task_add_message report $task_nr "cd $hedeby_config(hedeby_source_dir); ./build.sh $target"
         exp_continue
      }
      -i $spawn_list -re {^.*?\n} {
         if { $use_output == 1 } {
            set line [ string trimright $expect_out(buffer) "\n\r" ]
            report_task_add_message report $task_nr "$line"
         }
         exp_continue
      }
   }

   
   close_spawn_process $open_spawn
   report_finish_task report $task_nr $error

   if { $error != 0 } {
      puts $CHECK_OUTPUT "------------------------------------------\n"
      puts $CHECK_OUTPUT "return state: $error\n"
      puts $CHECK_OUTPUT "------------------------------------------\n"
      return -1
   }      
   return 0
}



proc hedeby_save_configuration { filename } {
   global hedeby_config ts_checktree hedeby_checktree_nr
   global CHECK_OUTPUT

   set conf_name $ts_checktree($hedeby_checktree_nr,setup_hooks_0_name)
   
   if { [ info exists hedeby_config(version) ] == 0 } {
      puts $CHECK_OUTPUT "no version"
      wait_for_enter
      return -1
   }

   # first get old configuration
   read_array_from_file  $filename $conf_name old_config
   # save old configuration 
   spool_array_to_file $filename "$conf_name.old" old_config
   spool_array_to_file $filename $conf_name hedeby_config  
   puts $CHECK_OUTPUT "new $conf_name saved"

   wait_for_enter

   return 0
}


proc config_generic { only_check name config_array help_text } {
   global CHECK_OUTPUT 
   global CHECK_USER 
   global CHECK_SOURCE_HOSTNAME
   global CHECK_HOST
   global fast_setup

   upvar $config_array config
   
#   puts $CHECK_OUTPUT "$name"
#   foreach name [array names config] {
#      puts $CHECK_OUTPUT "config($name)=$config($name)"
#   }
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
      if { $default_value == "" } {
         set value "none"
      }
   }
  
   if { $only_check == 0 } {
      # do setup  
      foreach elem $help_text { puts $CHECK_OUTPUT $elem }
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   return $value
}



proc config_hedeby_source_dir { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the path to Hedeby source directory, or press >RETURN<"
                    "to use the default value." }
                    
   return [ config_generic $only_check $name config $help_text ]
}

proc hedeby_config_dist { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the directory GRM dist directory >RETURN<" }
                    
   return [ config_generic $only_check $name config $help_text ]
}

proc hedeby_config_shared { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the directory GRM shared directory >RETURN<" }
                    
   return [ config_generic $only_check $name config $help_text ]
}

proc hedeby_config_master { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the GRM master host >RETURN<"
                    "The bootstrap installation will be performed on the master host" }
                    
   return [ config_generic $only_check $name config $help_text ]
}

proc hedeby_config_executors { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the GRM excutors hosts >RETURN<" }
                    
   return [ config_generic $only_check $name config $help_text ]
}



proc hedeby_init_config { config_array } {
   global hedeby_config hedeby_checktree_nr ts_checktree
   global CHECK_CURRENT_WORKING_DIR CHECK_HOST
   
   upvar $config_array config
   # hedeby_config defaults 
   set ts_pos 1
   set parameter "version"
   set config($parameter)            "1.0"
   set config($parameter,desc)       "Hedeby configuration setup"
   set config($parameter,default)    "1.0"
   set config($parameter,setup_func) ""
   set config($parameter,onchange)   "stop"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "hedeby_source_dir"
   set config($parameter)            ""
   set config($parameter,desc)       "Path to Hedeby source directory"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "stop"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "dist"
   set config($parameter)            ""
   set config($parameter,desc)       "Hedeby dist directory"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "hedeby_config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos) $ts_pos
   incr ts_pos 1
      
   set parameter "shared"
   set config($parameter)            ""
   set config($parameter,desc)       "Hedeby shared directory"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "hedeby_config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos) $ts_pos
   incr ts_pos 1
      
   set parameter "master"
   set config($parameter)            ""
   set config($parameter,desc)       "Hedeby master host"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "hedeby_config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos) $ts_pos
   incr ts_pos 1
      
   set parameter "executors"
   set config($parameter)            ""
   set config($parameter,desc)       "GRM executor hosts"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "hedeby_config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos) $ts_pos
   incr ts_pos 1
}


proc hedeby_verify_config { config_array only_check parameter_error_list } {
   global ts_checktree hedeby_checktree_nr CHECK_OUTPUT
   upvar $config_array config
   upvar $parameter_error_list param_error_list
   
   return [verify_config2 config $only_check param_error_list $ts_checktree($hedeby_checktree_nr,setup_hooks_0_version)]   
}


proc hedeby_get_required_hosts {} {
   global hedeby_config CHECK_OUTPUT
   set res {}
   
   lappend res $hedeby_config(master)
   foreach host $hedeby_config(executors) {
      lappend res $host
   }
   
   puts $CHECK_OUTPUT "Required hosts for hedeby: $res"
   return $res
}

proc hedeby_get_required_passwords {} {
   global hedeby_config CHECK_OUTPUT
   global hedeby_passwd CHECK_HOST CHECK_USER CHECK_SHELL_PROMPT

   # TODO , may be we need passwords for the hedeby admin user
   return 0
}

#****** checktree/hedeby_install_binaries() ************************************
#  NAME
#    hedeby_install_binaries() -- Installs the hedeby binaries
#
#  SYNOPSIS
#    hedeby_install_binaries { arch_list a_report } 
#
#  FUNCTION
#     Installs the hedeby binaries
#
#  INPUTS
#    arch_list --  list of archicteures
#    a_report  --  report handler
#
#  RESULT
#     0 -- binaries installed
#     1 -- error, reason has been reported in report handler
#
#*******************************************************************************
proc hedeby_install_binaries { arch_list a_report } {
   global CHECK_OUTPUT CHECK_USER CHECK_HOST CHECK_SOURCE_HOSTNAME
   global ts_config ts_host_config hedeby_config CHECK_SHELL_PROMPT

   upvar $a_report report
   set task_nr [ report_create_task report "install_hedeby_binaries" $CHECK_HOST ]

   # ---------------------------------------------------------------------------
   # get CVS tag, it is part of the tarball
   # ---------------------------------------------------------------------------
   set result [start_remote_prog $CHECK_SOURCE_HOSTNAME $CHECK_USER "cat" "$hedeby_config(hedeby_source_dir)/CVS/Tag" prg_exit_state 60 0 "" "" 1 0]
   set result [string trim $result]
   if {$prg_exit_state == 0} {
      if {[string first "T" $result] == 0} {
         set cvstag [string range $result 1 end]
      } else {
         set cvstag "maintrunk"
      }
   } else {
      set cvstag "maintrunk"
   }
   
   set tar $ts_host_config($CHECK_HOST,tar)
   set tar_args "-xvzf $hedeby_config(hedeby_source_dir)/dist/hedeby_${cvstag}.tar.gz"
   set inst_user "$CHECK_USER"
   
   set output [start_remote_prog $CHECK_HOST "$inst_user" "cd" "$hedeby_config(dist) ; $tar $tar_args"]
   if { $prg_exit_state != 0 } {
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "return state: $prg_exit_state"
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "output:\n$output"
      report_task_add_message report $task_nr "------------------------------------------"
      report_finish_task report $task_nr -1
      return -1
   }
   
   report_finish_task report $task_nr 0
   return 0
}



