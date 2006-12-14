
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
set ts_checktree($hedeby_checktree_nr,setup_hooks_0_version)      "1.1"

set ts_checktree($hedeby_checktree_nr,checktree_clean_hooks_0)  "hedeby_clean"
set ts_checktree($hedeby_checktree_nr,compile_hooks_0)        "hedeby_compile"
set ts_checktree($hedeby_checktree_nr,compile_clean_hooks_0)  "hedeby_compile_clean"
set ts_checktree($hedeby_checktree_nr,install_binary_hooks_0) "hedeby_install_binaries"

set ts_checktree($hedeby_checktree_nr,required_hosts_hook)    "hedeby_get_required_hosts"
set ts_checktree($hedeby_checktree_nr,passwd_hook)    "hedeby_get_required_passwords"

set ts_checktree($hedeby_checktree_nr,shutdown_hooks_0)       "shutdown_hedeby"
set ts_checktree($hedeby_checktree_nr,startup_hooks_0)       "startup_hedeby"


proc startup_hedeby { { hostname "--" } { debugmode "0" } } {
   global ts_config hedeby_config CHECK_USER CHECK_OUTPUT
 
   puts $CHECK_OUTPUT "----------------------------------"
   puts $CHECK_OUTPUT "startup_hedeby: NOT IMPLEMENTED!"
   puts $CHECK_OUTPUT "----------------------------------"
   return 0
}

proc shutdown_hedeby { { hostname "--" } } {
   global ts_config hedeby_config CHECK_USER CHECK_OUTPUT
   puts $CHECK_OUTPUT "-----------------------------------"
   puts $CHECK_OUTPUT "shutdown_hedeby: NOT IMPLEMENTED!"
   puts $CHECK_OUTPUT "-----------------------------------"
   return 0
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
   return [hedeby_build $compile_hosts "dist" report]
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
#    compile_hosts -- list of compile hosts
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
proc hedeby_build { compile_hosts target a_report { ant_options "" } { hedeby_build_timeout 60 } } {
   global CHECK_OUTPUT CHECK_USER
   global CHECK_HTML_DIRECTORY CHECK_PROTOCOL_DIR
   global ts_config ts_host_config hedeby_config
   
   upvar $a_report report
   
   set build_host [lindex $compile_hosts 0]
   
   set task_nr [report_create_task report "hedeby_build_$target" $build_host]
   
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "-> starting hedeby build.sh $target on host $build_host ..."
   
   set env(JAVA_HOME) [get_java15_home_for_host $build_host]
   set env(ARCH)      [resolve_arch $build_host]

   report_task_add_message report $task_nr "using JAVA_HOME = $env(JAVA_HOME)"
   report_task_add_message report $task_nr "using ARCH = $env(ARCH)"

   
   if { [string length ant_options] > 0 } {
      set env(ANT_OPTS) "$ant_options"
      report_task_add_message report $task_nr "using ANT_OPTS = $env(ANT_OPTS)"
   }

   set open_spawn [ open_remote_spawn_process $build_host $CHECK_USER "cd" "$hedeby_config(hedeby_source_dir); ant $target" 0 env]
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

proc config_n1sm_install_dir { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the path to the directory where the Haithabu packages should be installed or press >RETURN<"
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

proc config_n1sm_host { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the name of the N1 System Administrator host, or press >RETURN<"
                    "to use the default value." }
                    
   return [ config_generic $only_check $name config $help_text ]
}

proc config_n1sm_user { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the name of the user on N1 System Administrator host, or press >RETURN<"
                    "to use the default value." }
                    
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
   set config($parameter,desc)       "Haithabu configuration setup"
   set config($parameter,default)    "1.0"
   set config($parameter,setup_func) ""
   set config($parameter,onchange)   "stop"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "hedeby_source_dir"
   set config($parameter)            ""
   set config($parameter,desc)       "Path to Haithabu source directory"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "stop"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "n1sm_host"
   set config($parameter)            ""
   set config($parameter,desc)       "N1 System Manager host"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "n1sm_user"
   set config($parameter)            ""
   set config($parameter,desc)       "N1 System Manager user"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "n1sm_install_dir"
   set config($parameter)            ""
   set config($parameter,desc)       "N1 System Manager install directory"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1
   
   hedeby_config_upgrade_1_1 config
}

proc hedeby_config_upgrade_1_1 { config_array } {
   
   upvar $config_array config

   if { $config(version) == "1.0" } {
      global CHECK_HOST CHECK_OUTPUT   
   
      puts $CHECK_OUTPUT "Upgrade to version 1.1"
      # insert new parameter after hedeby_source_dir parameter
      set insert_pos $config(hedeby_source_dir,pos)
      incr insert_pos 1
      
      # move positions of following parameters
      set names [array names config "*,pos"]
      foreach name $names {
         if { $config($name) >= $insert_pos } {
            set config($name) [ expr ( $config($name) + 3 ) ]
         }
      }
   
      set parameter "dist"
      set config($parameter)            ""
      set config($parameter,desc)       "GRM dist directory"
      set config($parameter,default)    ""
      set config($parameter,setup_func) "hedeby_config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos
      incr insert_pos
      
      set parameter "shared"
      set config($parameter)            ""
      set config($parameter,desc)       "GRM shared directory"
      set config($parameter,default)    ""
      set config($parameter,setup_func) "hedeby_config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos
      incr insert_pos
      
      set parameter "master"
      set config($parameter)            ""
      set config($parameter,desc)       "GRM master host"
      set config($parameter,default)    ""
      set config($parameter,setup_func) "hedeby_config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos
      incr insert_pos
      
      set parameter "executors"
      set config($parameter)            ""
      set config($parameter,desc)       "GRM executor hosts"
      set config($parameter,default)    ""
      set config($parameter,setup_func) "hedeby_config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos
      incr insert_pos
   
      # now we have a configuration version 1.1
      set config(version) "1.1"
   }
}


proc hedeby_verify_config {config_array only_check parameter_error_list} {
   global ts_checktree hedeby_checktree_nr CHECK_OUTPUT
   upvar $config_array config
   upvar $parameter_error_list param_error_list
   
   hedeby_config_upgrade_1_1 config

   return [verify_config2 config $only_check param_error_list $ts_checktree($hedeby_checktree_nr,setup_hooks_0_version)]   
}


proc hedeby_get_required_hosts {} {
   global hedeby_config CHECK_OUTPUT
   set res {}
#   lappend res $arco_config(dbwriter_host)
#   lappend res $arco_config(swc_host)
   
   puts $CHECK_OUTPUT "Required hosts for hedeby: $res"
   return $res
}

proc hedeby_get_required_passwords {} {
   global hedeby_config CHECK_OUTPUT
   global hedeby_passwd CHECK_HOST CHECK_USER CHECK_SHELL_PROMPT

   puts "\npress return to skipp password setting (will cause errors for some tests)!\n"
   puts "user $hedeby_config(n1sm_user)'s password on host \"$hedeby_config(n1sm_host)\": "
   stty -echo
   set passwd [wait_for_enter 1]
   stty echo
   set hedeby_passwd($hedeby_config(n1sm_user),$hedeby_config(n1sm_host)) $passwd
   if {$passwd == ""} {
      puts "entering passwords skipped!"
      return 0
   }

   set id [open_remote_spawn_process "$CHECK_HOST" "$CHECK_USER" "ssh" "$hedeby_config(n1sm_user)@$hedeby_config(n1sm_host)" ]
   set sp_id [ lindex $id 1 ]

   set exit_state [do_ssh_login sp_id "n1sm_user" "n1sm_host"]
   set timeout 60
   puts $CHECK_OUTPUT "login exit state: $exit_state"  
   if { $exit_state == 0 } {
      set exit_state -1
      send -i $sp_id -- "exit\n"

      expect {
         -i $sp_id "_exit_status_:*\n" {
               set exit_state [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]
               puts $CHECK_OUTPUT "exit state is: \"$exit_state\""
            }
      }
   }
   close_spawn_process $id
   return $exit_state
}

proc hedeby_install_binaries { arch_list a_report } {
   global CHECK_OUTPUT CHECK_USER CHECK_HOST
   global ts_config ts_host_config hedeby_config CHECK_SHELL_PROMPT

   upvar $a_report report
   set task_nr [ report_create_task report "install_hedeby_binaries" $CHECK_HOST ]

   set tar $ts_host_config($CHECK_HOST,tar)
   set tar_args "-xvzf $hedeby_config(hedeby_source_dir)/dist/hedeby.tar.gz"
   set inst_user "root"
   
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
   
   set output [start_remote_prog $CHECK_HOST "$inst_user" "cp" "$hedeby_config(hedeby_source_dir)/dist/hedeby.class $hedeby_config(dist)"]
   if { $prg_exit_state != 0 } {
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "return state: $prg_exit_state"
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "output:\n$output"
      report_task_add_message report $task_nr "------------------------------------------"
      report_finish_task report $task_nr -1
      return -1
   }
   
   set output [start_remote_prog $CHECK_HOST "$inst_user" "cd" "$hedeby_config(dist)/bin; ln -f -s gconf gstat"]
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

proc hedeby_install_binaries_org { arch_list a_report } {
   global CHECK_OUTPUT CHECK_USER CHECK_HOST
   global ts_config ts_host_config hedeby_config CHECK_SHELL_PROMPT

   upvar $a_report report
   set task_nr [ report_create_task report "install_hedeby_binaries" $CHECK_HOST ]
   puts $CHECK_OUTPUT "------------------------------------------"
   puts $CHECK_OUTPUT "hedeby_install_binaries: NOT FULL IMPLEMENTED"
   puts $CHECK_OUTPUT "------------------------------------------"

   report_task_add_message report $task_nr "hedeby_install_binaries"

   set tar $ts_host_config($CHECK_HOST,tar)
   set tar_args "-cvf $hedeby_config(hedeby_source_dir)/testsuite/hedeby.tar ./util/* ./config/* ./build/*"
   # puts $CHECK_OUTPUT "doing: $tar $tar_args"

   report_task_add_message report $task_nr ""
   report_task_add_message report $task_nr "-> generate tarball from hedeby source dir:"
   report_task_add_message report $task_nr "$tar $tar_args"

   delete_file $hedeby_config(hedeby_source_dir)/testsuite/hedeby.tar 0
   delete_file $hedeby_config(hedeby_source_dir)/testsuite/hedeby.tar.gz 0

   set output [start_remote_prog $CHECK_HOST $CHECK_USER "cd" "$hedeby_config(hedeby_source_dir) ; $tar $tar_args"]
   if { $prg_exit_state != 0 } {
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "return state: $prg_exit_state"
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "output:\n$output"
      report_task_add_message report $task_nr "------------------------------------------"
      report_finish_task report $task_nr -1
      return -1
   }

   set gzip "gzip"
   set gzip_args "$hedeby_config(hedeby_source_dir)/testsuite/hedeby.tar"

   report_task_add_message report $task_nr ""
   report_task_add_message report $task_nr "-> gzip tarball:"
   report_task_add_message report $task_nr "$gzip $gzip_args"

   set output [start_remote_prog $CHECK_HOST $CHECK_USER "$gzip" "$gzip_args"]
   if { $prg_exit_state != 0 } {
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "return state: $prg_exit_state"
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "output:\n$output"
      report_task_add_message report $task_nr "------------------------------------------"
      report_finish_task report $task_nr -1
      return -1
   }

   report_task_add_message report $task_nr ""
   report_task_add_message report $task_nr "-> sftp file transfer as  $hedeby_config(n1sm_user)@$hedeby_config(n1sm_host):"
   
   report_task_add_message report $task_nr "copy files to $hedeby_config(n1sm_install_dir) on host $hedeby_config(n1sm_host)"


   set id [open_remote_spawn_process "$CHECK_HOST" "$CHECK_USER" "sftp" "$hedeby_config(n1sm_user)@$hedeby_config(n1sm_host)" ]
   set sp_id [ lindex $id 1 ]

   set exit_state [do_sftp_login sp_id "n1sm_user" "n1sm_host"]
   set timeout 60
   if { $exit_state == 0 } {
      set exit_state -1
      
      set timeout_error 0
      send -i $sp_id -- "cd $hedeby_config(n1sm_install_dir)\n"
      expect {
         -i $sp_id $CHECK_SHELL_PROMPT {
            puts $CHECK_OUTPUT "got shell prompt"
         }
         -i $sp_id timeout {
            set timeout_error 1
            send -i $sp_id -- "exit\n"
         }
      }

      if { $timeout_error == 0 } {
         send -i $sp_id -- "put $hedeby_config(hedeby_source_dir)/testsuite/hedeby.tar.gz\n"
         expect {
            -i $sp_id "sftp>" {
               puts $CHECK_OUTPUT "got shell prompt"
            }
            -i $sp_id timeout {
               set timeout_error 1
               send -i $sp_id -- "exit\n"
            }
         }
      }

      if { $timeout_error == 0 } {
         send -i $sp_id -- "exit\n"
         expect {
            -i $sp_id timeout {
               set timeout_error 1
               send -i $sp_id -- "exit\n"
            }
            -i $sp_id "_exit_status_:*\n" {
               set exit_state [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]
               puts $CHECK_OUTPUT "exit state is: \"$exit_state\""
            }
         }
      }

      if { $timeout_error != 0 } {
         puts $CHECK_OUTPUT "got timeout error"
         set exit_state -255
      }
   }
   close_spawn_process $id

   if { $exit_state != 0 } {
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "return state: $exit_state"
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "output:\n$output"
      report_task_add_message report $task_nr "------------------------------------------"
      report_finish_task report $task_nr -1
      return -1
   }

   delete_file $hedeby_config(hedeby_source_dir)/testsuite/hedeby.tar 0
   delete_file $hedeby_config(hedeby_source_dir)/testsuite/hedeby.tar.gz 0



   set id [open_remote_spawn_process "$CHECK_HOST" "$CHECK_USER" "ssh" "$hedeby_config(n1sm_user)@$hedeby_config(n1sm_host)" ]
   set sp_id [ lindex $id 1 ]

   set exit_state [do_ssh_login sp_id "n1sm_user" "n1sm_host"]
   set timeout 60

   if { $exit_state == 0 } {
      set exit_state -1
      set timeout_error 0
      send -i $sp_id -- "cd $hedeby_config(n1sm_install_dir)\n"
      expect {
         -i $sp_id $CHECK_SHELL_PROMPT {
            puts $CHECK_OUTPUT "got shell prompt"
         }
         -i $sp_id timeout {
            set timeout_error 1
            send -i $sp_id -- "exit\n"
         }
      }
      if { $timeout_error == 0 } {
         send -i $sp_id -- "gunzip hedeby.tar.gz\n"
         expect {
            -i $sp_id $CHECK_SHELL_PROMPT {
               puts $CHECK_OUTPUT "got shell prompt"
            }
            -i $sp_id timeout {
               set timeout_error 1
               send -i $sp_id -- "exit\n"
            }
         }
      }
      if { $timeout_error == 0 } {
         send -i $sp_id -- "rm -rf $hedeby_config(n1sm_install_dir)/util/*\n"
         expect {
            -i $sp_id $CHECK_SHELL_PROMPT {
               puts $CHECK_OUTPUT "got shell prompt"
            }
            -i $sp_id timeout {
               set timeout_error 1
               send -i $sp_id -- "exit\n"
            }
         }
      }
      if { $timeout_error == 0 } {
         send -i $sp_id -- "rm -rf $hedeby_config(n1sm_install_dir)/config/*\n"
         expect {
            -i $sp_id $CHECK_SHELL_PROMPT {
               puts $CHECK_OUTPUT "got shell prompt"
            }
            -i $sp_id timeout {
               set timeout_error 1
               send -i $sp_id -- "exit\n"
            }
         }
      }
      if { $timeout_error == 0 } {
         send -i $sp_id -- "rm -rf $hedeby_config(n1sm_install_dir)/build/*\n"
         expect {
            -i $sp_id $CHECK_SHELL_PROMPT {
               puts $CHECK_OUTPUT "got shell prompt"
            }
            -i $sp_id timeout {
               set timeout_error 1
               send -i $sp_id -- "exit\n"
            }
         }
      }
      
      if { $timeout_error == 0 } {
         send -i $sp_id -- "tar -xf hedeby.tar\n"
         expect {
            -i $sp_id $CHECK_SHELL_PROMPT {
               puts $CHECK_OUTPUT "got shell prompt"
            }
            -i $sp_id timeout {
               set timeout_error 1
               send -i $sp_id -- "exit\n"
            }
         }
      }
      if { $timeout_error == 0 } {
         send -i $sp_id -- "rm hedeby.tar\n"
         expect {
            -i $sp_id $CHECK_SHELL_PROMPT {
               puts $CHECK_OUTPUT "got shell prompt"
            }
            -i $sp_id timeout {
               set timeout_error 1
               send -i $sp_id -- "exit\n"
            }
         }
      }

      if { $timeout_error == 0 } {
         send -i $sp_id -- "exit\n"
         expect {
            -i $sp_id timeout {
               set timeout_error 1
               send -i $sp_id -- "exit\n"
            }
            -i $sp_id "_exit_status_:*\n" {
               set exit_state [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]
               puts $CHECK_OUTPUT "exit state is: \"$exit_state\""
            }
         }
      }

      if { $timeout_error != 0 } {
         puts $CHECK_OUTPUT "got timeout error"
         set exit_state -255
      }
   }
   close_spawn_process $id
   if { $exit_state != 0 } {
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "return state: $exit_state"
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "output:\n$output"
      report_task_add_message report $task_nr "------------------------------------------"
      report_finish_task report $task_nr -1
      return -1
   }



   report_finish_task report $task_nr 0
   return 0
}
