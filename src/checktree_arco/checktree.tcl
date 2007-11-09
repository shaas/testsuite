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


global ts_checktree, arco_config
global CHECK_OUTPUT CHECK_DEFAULTS_FILE
global arco_checktree_nr
global ACT_CHECKTREE

ts_source $ACT_CHECKTREE/sql_util
ts_source $ACT_CHECKTREE/arcorun
ts_source $ACT_CHECKTREE/arco_queries

set arco_config(initialized) 0
set arco_checktree_nr $ts_checktree($ACT_CHECKTREE)

set ts_checktree($arco_checktree_nr,setup_hooks_0_name)         "ARCo configuration"
set ts_checktree($arco_checktree_nr,setup_hooks_0_config_array) arco_config
set ts_checktree($arco_checktree_nr,setup_hooks_0_init_func)    arco_init_config
set ts_checktree($arco_checktree_nr,setup_hooks_0_verify_func)  arco_verify_config
set ts_checktree($arco_checktree_nr,setup_hooks_0_save_func)    arco_save_configuration
#set ts_checktree($arco_checktree_nr,setup_hooks_0_filename)     $ACT_CHECKTREE/arco_defaults.sav
set ts_checktree($arco_checktree_nr,setup_hooks_0_filename)     [ get_additional_config_file_path "arco" ]
set ts_checktree($arco_checktree_nr,setup_hooks_0_version)      "1.3"

set ts_checktree($arco_checktree_nr,checktree_clean_hooks_0)  "arco_clean"

set ts_checktree($arco_checktree_nr,compile_hooks_0)        "arco_compile"
set ts_checktree($arco_checktree_nr,compile_clean_hooks_0)  "arco_compile_clean"
set ts_checktree($arco_checktree_nr,install_binary_hooks_0) "arco_install_binaries"
set ts_checktree($arco_checktree_nr,shutdown_hooks_0)       "shutdown_dbwriter"
set ts_checktree($arco_checktree_nr,startup_hooks_0)       "startup_dbwriter"

set ts_checktree($arco_checktree_nr,required_hosts_hook)    "arco_get_required_hosts"

global ARCO_TABLES
global ARCO_VIEWS
global ts_config

set ARCO_TABLES { sge_job_usage sge_job_log sge_job_request sge_job
                  sge_queue_values sge_queue
                  sge_host_values sge_host
                  sge_department_values sge_department
                  sge_project_values sge_project
                  sge_user_values sge_user 
                  sge_group_values sge_group
                  sge_share_log 
                  sge_version
                  sge_statistic_values
                  sge_statistic
}
if {$ts_config(gridengine_version) >= 62} {
  lappend ARCO_TABLES sge_ar_attribute
  lappend ARCO_TABLES sge_ar_usage
  lappend ARCO_TABLES sge_ar_log
  lappend ARCO_TABLES sge_ar_resource_usage
  lappend ARCO_TABLES sge_ar
}

set ARCO_VIEWS { view_job_times view_jobs_completed
                 view_job_log view_department_values view_group_values view_host_values
                 view_project_values view_queue_values view_user_values view_accounting
                 view_statistic
}

if {$ts_config(gridengine_version) >= 62} {
   set ARCO_VIEWS { view_ar_time_usage view_job_times view_jobs_completed
                 view_job_log view_department_values view_group_values view_host_values
                 view_project_values view_queue_values view_user_values view_user_values
                 view_ar_time_usage view_ar_attribute view_ar_log view_ar_usage 
                 view_ar_resource_usage view_accounting view_ar_attribute
   }
}

#****** checktree/arco_compile() **************************************************
#  NAME
#    arco_compile() -- ???
#
#  SYNOPSIS
#    arco_compile { compile_hosts a_mail_body a_html_body  } 
#
#  FUNCTION
#     Compile hook for the ARCo packages 
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
proc arco_compile { compile_hosts a_report } {
   upvar $a_report report
   return [arco_build $compile_hosts "all" report]
}

#****** checktree/arco_compile_clean() **************************************************
#  NAME
#    arco_compile_clean() -- compile clean hook for ARCo
#
#  SYNOPSIS
#    arco_compile_clean { compile_hosts a_report } 
#
#  FUNCTION
#
#    call the arco build script with target clean
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
proc arco_compile_clean { compile_hosts a_report } {
   upvar $a_report report
   return [arco_build $compile_hosts "clean" report]
}


#****** checktree/arco_build() **************************************************
#  NAME
#    arco_build() -- start the arco build script
#
#  SYNOPSIS
#    arco_build { compile_hosts target a_report } 
#
#  FUNCTION
#     starts the arco build script
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
proc arco_build { compile_hosts target a_report { ant_options "" } { arco_build_timeout 60 } } {
   global CHECK_OUTPUT CHECK_USER
   global CHECK_HTML_DIRECTORY CHECK_PROTOCOL_DIR
   global ts_config ts_host_config arco_config
   
   upvar $a_report report
   
   set build_host [host_conf_get_java_compile_host]
   
   set task_nr [report_create_task report "arco_build_$target" $build_host]
   
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "-> starting arco build.sh $target on host $build_host ..."
  
   # setup environment
   set env(JAVA_HOME) [get_java_home_for_host $build_host "1.5"]
   set env(ARCH)      [resolve_arch $build_host]

   append ant_options " -Dsge.root=$ts_config(product_root)"
   append ant_options " -Dsge.srcdir=$ts_config(source_dir)"
   set env(ANT_OPTS) "$ant_options"
   

   if {[coverage_enabled "emma"]} {
      set open_spawn [open_remote_spawn_process $build_host $CHECK_USER "./build.sh" "-emma $target" 0 $arco_config(arco_source_dir) env]
   } else {
      set open_spawn [open_remote_spawn_process $build_host $CHECK_USER "./build.sh" "$target" 0 $arco_config(arco_source_dir) env]
   }
   set spawn_list [lindex $open_spawn 1]
   set timeout $arco_build_timeout
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
         report_task_add_message report $task_nr "arco build script exited with status $error"
      }
      -i $spawn_list "_start_mark_:(0)" {
         set use_output 1
         report_task_add_message report $task_nr "cd $arco_config(arco_source_dir); ./build.sh $target"
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

#****** checktree/arco_get_required_hosts() **************************************************
#  NAME
#    arco_get_required_hosts() -- required hosts hook for arco
#
#  SYNOPSIS
#    arco_get_required_hosts { } 
#
#  FUNCTION
#    return a list of host which are required for the arco checktree
#
#  INPUTS
#
#  RESULT
#
#    List of required hosts
#
#
#  SEE ALSO
#     checktree_helper/checktree_get_required_hosts
#*******************************************************************************
proc arco_get_required_hosts {} {
   global arco_config CHECK_OUTPUT
   set res {}
   lappend res $arco_config(dbwriter_host)
   lappend res $arco_config(swc_host)
   
   puts $CHECK_OUTPUT "Required hosts for arco: $res"
   return $res
}

#****** checktree/arco_install_binaries() **************************************************
#  NAME
#    arco_install_binaries() -- ???
#
#  SYNOPSIS
#    arco_install_binaries { } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#    arch_list   --   list of architectures for which the binaries should be installed
#    a_mail_body --   buffer for mail error reporting
#    a_html_body --   buffer for html error reporting
#
#  RESULT
#     0  - on success
#     else failure
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc arco_install_binaries { arch_list a_report } {
   
   global CHECK_OUTPUT CHECK_USER
   global ts_config ts_host_config arco_config
   
   upvar $a_report report


   set task_nr [ report_create_task report "install_dbwriter_binaries" $ts_config(master_host) ]
   
   set tar $ts_host_config($ts_config(master_host),tar)
   set tar_args "xzf $arco_config(arco_source_dir)/dbwriter/dbwriter.tar.gz -C $ts_config(product_root)"
   
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "-> $tar $tar_args"
   set output [start_remote_prog $ts_config(master_host) $CHECK_USER "$tar" "$tar_args" prg_exit_state]
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

   set task_nr [ report_create_task report "install_reporting_binaries" $ts_config(master_host) ]
   
   set tar_args "xzf $arco_config(arco_source_dir)/reporting/reporting.tar.gz -C $ts_config(product_root)"
   
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "-> $tar $tar_args"
   set output [start_remote_prog $ts_config(master_host) $CHECK_USER "$tar" "$tar_args" prg_exit_state]
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

proc arco_verify_config {config_array only_check parameter_error_list} {
   global ts_checktree arco_checktree_nr CHECK_OUTPUT
   upvar $config_array config
   upvar $parameter_error_list param_error_list
   
   arco_config_upgrade_1_1 config
   arco_config_upgrade_1_2 config
   arco_config_upgrade_1_3 config
   
   return [verify_config2 config $only_check param_error_list $ts_checktree($arco_checktree_nr,setup_hooks_0_version)]   
}

proc arco_save_configuration { filename } {
   global arco_config ts_checktree arco_checktree_nr
   global CHECK_OUTPUT

   set conf_name $ts_checktree($arco_checktree_nr,setup_hooks_0_name)
   
   if { [ info exists arco_config(version) ] == 0 } {
      puts $CHECK_OUTPUT "no version"
      wait_for_enter
      return -1
   }

   # first get old configuration
   read_array_from_file  $filename $conf_name old_config
   # save old configuration 
   spool_array_to_file $filename "$conf_name.old" old_config
   spool_array_to_file $filename $conf_name arco_config  
   puts $CHECK_OUTPUT "new $conf_name saved"

   wait_for_enter

   return 0
}


proc arco_init_config { config_array } {
   global arco_config arco_checktree_nr ts_checktree
   global CHECK_CURRENT_WORKING_DIR
   
   upvar $config_array config
   # arco_config defaults 
   set ts_pos 1
   set parameter "version"
   set config($parameter)            "1.0"
   set config($parameter,desc)       "ARCo configuration setup"
   set config($parameter,default)    "1.0"
   set config($parameter,setup_func) ""
   set config($parameter,onchange)   "stop"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "arco_source_dir"
   set config($parameter)            ""
   set config($parameter,desc)       "Path to ARCo source directory"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "stop"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "dbwriter_host"
   set config($parameter)            ""
   set config($parameter,desc)       "Host where dbwriter should run"
   set config($parameter,default)    "check_host"   ;# config_arco_generic will resolve the host
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "stop"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1
   
   set parameter "database_type"
   set config($parameter)            ""
   set config($parameter,desc)       "ARCO database type"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "database_host"
   set config($parameter)            ""
   set config($parameter,desc)       "ARCO database host"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "database_port"
   set config($parameter)            ""
   set config($parameter,desc)       "ARCO database port"
   set config($parameter,default)    "5432"
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1
   
   set parameter "database_name"
   set config($parameter)            ""
   set config($parameter,desc)       "ARCO database name"
   set config($parameter,default)    "arco"
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "database_schema"
   set config($parameter)            ""
   set config($parameter,desc)       "ARCO database schema"
   set config($parameter,default)    "public"
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1
   
   set parameter "database_write_user"
   set config($parameter)            ""
   set config($parameter,desc)       "ARCo database user with write access"
   set config($parameter,default)    "arco_write"
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "database_write_pw"
   set config($parameter)            ""
   set config($parameter,desc)       "Password for the database user with write access"
   set config($parameter,default)    "arco_write"
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "database_read_user"
   set config($parameter)            ""
   set config($parameter,desc)       "ARCo database user with read access"
   set config($parameter,default)    "arco_read"
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "database_read_pw"
   set config($parameter)            ""
   set config($parameter,desc)       "Password for the database user with read access"
   set config($parameter,default)    "arco_read"
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1
   
   set parameter "arco_dbwriter_debug_level"
   set config($parameter)            ""
   set config($parameter,desc)       "dbwriter debug level"
   set config($parameter,default)    "INFO"
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "arco_dbwriter_interval"
   set config($parameter)            ""
   set config($parameter,desc)       "dbwriter interval"
   set config($parameter,default)    "60"
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1
   
   arco_config_upgrade_1_1 config
   arco_config_upgrade_1_2 config
   arco_config_upgrade_1_3 config
}

proc arco_config_upgrade_1_1 { config_array } {
   global CHECK_OUTPUT   

   upvar $config_array config

   if { $config(version) == "1.0" } {
      puts $CHECK_OUTPUT "Upgrade to version 1.1"
      # insert new parameter after arco_dbwriter_interval parameter
      set insert_pos $config(arco_dbwriter_interval,pos)
      incr insert_pos 1
      
      # move positions of following parameters
      set names [array names config "*,pos"]
      foreach name $names {
         if { $config($name) >= $insert_pos } {
            set config($name) [ expr ( $config($name) + 1 ) ]
         }
      }
   
      # new parameter l10n_test_locale
      set parameter "swc_host"
      set config($parameter)            ""
      set config($parameter,desc)       "Java Web Console Host"
      set config($parameter,default)    "check_host" ;# config_arco_generic will resolve the host
      set config($parameter,setup_func) "config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos
   
      # now we have a configuration version 1.1
      set config(version) "1.1"
   }
}

proc arco_config_upgrade_1_2 { config_array } {
   global CHECK_OUTPUT
   
   upvar $config_array config

   if { $config(version) == "1.1" } {
   
      puts $CHECK_OUTPUT "Upgrade to version 1.2"

      # delete parameter database_read_user
      set param "database_read_user"
      set pos $config($param,pos)  
      
      array unset config "$param"
      array unset config "$param,desc"
      array unset config "$param,default"
      array unset config "$param,setup_func"
      array unset config "$param,onchange"
      array unset config "$param,pos"
      set names [array names config "*,pos"]
      foreach name $names {
         if { $config($name) >= $pos } {
            set config($name) [ expr ( $config($name) - 1 ) ]
         }
      }
      
      # delete parameter database_read_pw
      set param "database_read_pw"
      set pos $config($param,pos)      
      array unset config "$param"
      array unset config "$param,desc"
      array unset config "$param,default"
      array unset config "$param,setup_func"
      array unset config "$param,onchange"
      array unset config "$param,pos"
      
      set names [array names config "*,pos"]
      foreach name $names {
         if { $config($name) >= $pos } {
            set config($name) [ expr ( $config($name) - 1 ) ]
         }
      }

      # delete parameter database_schema
      set param "database_schema"
      set pos $config($param,pos)      
      array unset config "$param"
      array unset config "$param,desc"
      array unset config "$param,default"
      array unset config "$param,setup_func"
      array unset config "$param,onchange"
      array unset config "$param,pos"
      
      set names [array names config "*,pos"]
      foreach name $names {
         if { $config($name) >= $pos } {
            set config($name) [ expr ( $config($name) - 1 ) ]
         }
      }
      
      # insert new parameter after swc_host parameter
      set insert_pos $config(swc_host,pos)
      incr insert_pos 1
      
      # move positions of following parameters
      set names [array names config "*,pos"]
      foreach name $names {
         if { $config($name) >= $insert_pos } {
            set config($name) [ expr ( $config($name) + 1 ) ]
         }
      }
   
      # new parameter l10n_test_locale
      set parameter "jdbc_driver"
      set config($parameter)            ""
      set config($parameter,desc)       "JDBC Driver"
      set config($parameter,default)    "NONE"
      set config($parameter,setup_func) "config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos
   
      # now we have a configuration version 1.2
      set config(version) "1.2"
   }
}

proc arco_config_upgrade_1_3 { config_array } {
   global CHECK_OUTPUT
   
   upvar $config_array config

   if { $config(version) == "1.2" } {

      puts $CHECK_OUTPUT "Upgrade to version 1.3"

      if { [string compare $config(database_type) "mysql"] != 0 } {
         # insert new parameter after jdbc_driver host parameter
         set insert_pos $config(jdbc_driver,pos)
         incr insert_pos 1

         # new parameter TABLESPACE
         set parameter "tablespace"
         set config($parameter)            ""
         set config($parameter,desc)       "TABLESPACE for tables"
         set config($parameter,default)    "USERS"
         set config($parameter,setup_func) "config_$parameter"
         set config($parameter,onchange)   "install"
         set config($parameter,pos) $insert_pos

         incr insert_pos 1

         # new parameter TABLESPACE_INDEX
         set parameter "tablespace_index"
         set config($parameter)            ""
         set config($parameter,desc)       "TABLESPACE for indexes"
         set config($parameter,default)    "USERS"
         set config($parameter,setup_func) "config_$parameter"
         set config($parameter,onchange)   "install"
         set config($parameter,pos) $insert_pos

      }

      # now we have a configuration version 1.3
      set config(version) "1.3"
   }

}

proc config_arco_source_dir { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the path to ARCo source directory, or press >RETURN<"
                    "to use the default value." }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "directory" ]
}

proc config_dbwriter_host { only_check name config_array } {
   global ts_checktree ts_host_config fast_setup arco_checktree_nr
   global CHECK_OUTPUT

   upvar $config_array config
   
   set help_text {  "Please enter hostname where dbwriter should run, or press >RETURN<"
                    "to use the default value." }
                    
   set dbwriter_host [ config_generic $only_check $name config $help_text "host" ]
   
   if {$fast_setup == 0} {
      if {![host_conf_is_known_host $dbwriter_host]} {
         puts $CHECK_OUTPUT "Host $dbwriter_host is not defined in the host configuration"
         return -1
      }
# AP: commented after removing the java property from host configuration
# (replaced by java14, java15, java16) 
# TODO: change the behaviour when java is not set -> now -> can't get to the testsuite setup 
#      if {[get_binary_path $dbwriter_host "java"] == "java"} { 
#         puts $CHECK_OUTPUT "Java is not configured for host $dbwriter_host"
#         return -1
#      }
   }

   return $dbwriter_host
}


proc config_database_type { only_check name config_array } {
   global CHECK_OUTPUT
   upvar $config_array config
   
   set help_text {  "Please enter the database type, or press >RETURN<"
                    "to use the default value."
                    "Valid values are \"postgres\", \"oracle\" or \"mysql\"" }
                    
       
   set db_type [config_generic $only_check $name config $help_text "string" ]

   if { $db_type == "postgres" || $db_type == "oracle" || $db_type == "mysql" } {
      return $db_type
   }
   return -1
}

proc config_database_host { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the name of your database host, or press >RETURN<"
                    "to use the default value." }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "string" ]
}

proc config_database_port { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the name of your database port, or press >RETURN<"
                    "to use the default value." }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "string" ]
}

proc config_database_name { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the name of your database, or press >RETURN<"
                    "to use the default value." }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "string" ]
}

proc config_database_schema { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the name of your database schema, or press >RETURN<"
                    "to use the default value." }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "string" ]
}

proc config_database_write_user { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the name of the user which has write permissions on the database, or press >RETURN<"
                    "to use the default value." }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "string" ]
}

proc config_database_read_user { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the name of the user which has read permissions on the database, or press >RETURN<"
                    "to use the default value." }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "string" ]
}

proc config_database_write_pw { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the password of the user which has write permissions on the database, or press >RETURN<"
                    "to use the default value." }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "string" ]
}

proc config_database_read_pw { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the password of the user which has read permissions on the database, or press >RETURN<"
                    "to use the default value." }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "string" ]
}

proc config_arco_spool_dir { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter path to the ARCo spool directory, or press >RETURN<"
                    "to use the default value." }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "directory" ]
}

proc config_arco_dbwriter_debug_level { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter debug level for dbwriter, or press >RETURN<"
                    "to use the default value."
                    "Valid values are \"WARNING\", \"INFO\", \"FINE\""}
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "string" ]
}



proc config_arco_dbwriter_interval { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the dbwriter interval in seconds, or press >RETURN<"
                    "to use the default value."  }
                    
   # TODO set global variables
   
   return [ config_generic $only_check $name config $help_text "string" ]
}

proc config_jdbc_driver { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the path to the JDBC driver or press >RETURN<"
                    "to use the default value."  }
     
   return [ config_generic $only_check $name config $help_text "string" ]
   
}

proc config_swc_host {only_check name config_array} {
   global ts_checktree ts_host_config fast_setup arco_checktree_nr
   global CHECK_OUTPUT CHECK_USER
   upvar $config_array config

   set help_text {"Please enter the name of your the host where the Java Web Console is installed, or press >RETURN<"
                  "to use the default value."}
   
   set swc_host [config_generic $only_check $name config $help_text "host" ]
      
   if {$fast_setup == 0} {
      if {![host_conf_is_known_host $swc_host]} {
         puts $CHECK_OUTPUT "Host $swc_host is not defined in the host configuration"
         return -1
      }
      
      array set swc_version {}
      
      if {[get_java_web_console_version swc_version $swc_host]  < 0} {
         puts $CHECK_OUTPUT "Can not determine version of java webconsole on host $swc_host"
         return -1
      }
   
      set num_version [expr $swc_version(major) * 10000 + $swc_version(minor) * 100 + $swc_version(micro)]  
      set exp_version [expr 2 * 10000 + 2 * 100 + 1]
      if {$num_version < $exp_version} {
         puts $CHECK_OUTPUT "Version 2.2.1 or higher is required"
         return -1
      }
   }

   return $swc_host
}

proc config_java_home { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Please enter the JAVA_HOME path or press >RETURN<"
                    "to use the default value."  }
     
   return [ config_generic $only_check $name config $help_text "directory" ]
   
}

proc config_tablespace { only_check name config_array } {

   upvar $config_array config

   set help_text {  "Please enter the name of TABLESPACE for tables"  }
     
   return [ config_generic $only_check $name config $help_text "string" ]

}

proc config_tablespace_index { only_check name config_array } {

   upvar $config_array config
   
   set help_text {  "Please enter the name of TABLESPACE for indexes"  }
     
   return [ config_generic $only_check $name config $help_text "string" ]

}

#****** checktree/startup_dbwriter() **************************************************
#  NAME
#    startup_dbwriter() -- startup the dbwriter
#
#  SYNOPSIS
#    startup_dbwriter { { hostname "--" } } 
#
#  FUNCTION
#    Starts the dbwriter.
#
#  INPUTS
#    hostname --  hostname where dbwriter should run. If the hostname has the
#                 value "--", the host from arco_config(dbwriter_host) is taken.
#    debug_mode -- If 0, then the dbwriter is started in debug mode. The user has
#                  to connect to the dbwriter with a jdpa debugger. When the connectioin
#                  has be established, the testsuite can continue.
#
#  RESULT
#       0 --  dbwriter has been started
#       else -- error, dbwriter could not be started, error has been reported
#               by add_proc_error
#
#  SEE ALSO
#     checktree/is_dbwriter_running
#*******************************************************************************
proc startup_dbwriter { { hostname "--" } { debugmode "0" } } {
   global ts_config arco_config CHECK_USER CHECK_OUTPUT
   
   if { $hostname == "--" } {
      set hostname $arco_config(dbwriter_host)
   }
   
   if { [file exists "$ts_config(product_root)/$ts_config(cell)/spool/dbwriter"] != 1 } {
      set output [start_remote_prog "$hostname" "$CHECK_USER" "mkdir" "-p $ts_config(product_root)/$ts_config(cell)/spool/dbwriter"]
      if { $prg_exit_state != 0 } {
         puts $CHECK_OUTPUT "Can not create spool directory for dbwriter"
         puts $CHECK_OUTPUT "--------------------------------------------------"
         puts $CHECK_OUTPUT $output
         puts $CHECK_OUTPUT "--------------------------------------------------"
         add_proc_error "startup_dbwriter" -1 "Can not create spool directory for dbwriter"
         return -1;
      }
   }

   # pass special environment variables to sgedbwriter
   # to allow code coverage analysis with EMMA
   if {[coverage_enabled "emma"]} {
      parse_properties_file properties "$arco_config(arco_source_dir)/build.properties"
      parse_properties_file properties "$arco_config(arco_source_dir)/build_private.properties" 1
      set dbwriter_env(DBWRITER_JVMARGS) "-Demma.coverage.out.file=$arco_config(arco_source_dir)/arco/dbwriter/coverage/dbwriter.emma -Demma.coverage.out.merge=true"
      set dbwriter_env(DBWRITER_CLASSPATH) "$properties(emma.dir)/emma.jar"
   }

   set prog "$ts_config(product_root)/$ts_config(cell)/common/sgedbwriter"
   
   if {[wait_for_remote_file "$hostname" "$CHECK_USER" "$prog"] == 0} {   
      set args ""
      if {$debugmode == 1} {
         append args "-debug_port 8000 -debug "
      }
      append args "start"
      
      set output [start_remote_prog "$hostname" "$CHECK_USER" "$prog" $args prg_exit_state 60 0 "" dbwriter_env]
      
      if {$debugmode == 1} {
        puts $CHECK_OUTPUT "dbwriter has been started in debug mode"
        puts $CHECK_OUTPUT "Please connect with a jpda debugger to $hostname (Port 8000)!"
        wait_for_enter
      } elseif {$prg_exit_state != 0} {
         puts $CHECK_OUTPUT "startup of dbwriter failed (exit code $prg_exit_state)"
         puts $CHECK_OUTPUT "--------------------------------------------------"
         puts $CHECK_OUTPUT $output
         puts $CHECK_OUTPUT "--------------------------------------------------"
         add_proc_error "startup_dbwriter" -1 "startup of dbwriter failed (exit code $prg_exit_state)"
      }
      return $prg_exit_state;
   } else {
      return -1
   }
}

#****** checktree/get_dbwriter_status() **************************************************
#  NAME
#    get_dbwriter_status() -- get the status of the dbwriter
#
#  SYNOPSIS
#    get_dbwriter_status { { hostname "--" } }
#
#  FUNCTION
#     Check the status of the dbwriter
#
#  INPUTS
#    hostname --  the host where the dbwriter is running. If this
#                 is an empty string the value from arco_config(dbwriter_host) is taken
#
#  RESULT
#     0     --  dbwriter is running
#     1     --  dbwriter is not running, but the pid file exists
#     2     --  Java Web Console is running, pid file does not exists
#     else  --  dbwriter is not installed on this host, or it is
#               not accessable by the CHECK_USER
#
#  EXAMPLE
#
#   set res [get_dbwriter_status]
#
#   if { $res == 0 } {
#      puts "dbwriter is running"
#   } else if { $res == 1 } {
#      puts "dbwriter is not running
#   } else if { $res == 2 } {
#      puts "dbwriter is not running, but the pid file exits
#   } else {
#      puts "Can not determine status of the Java Web Console"
#   }
#
#*******************************************************************************
proc get_dbwriter_status { { raise_error 1 } { hostname "--" } } {
   global ts_config arco_config CHECK_USER CHECK_OUTPUT
   
   if { $hostname == "--" } {
      set hostname $arco_config(dbwriter_host)
   }
   
   set prog "$ts_config(product_root)/$ts_config(cell)/common/sgedbwriter"
   
   if { $raise_error } {
      set timeout 60
   } else {
      set timeout 5
   }
   if { [wait_for_remote_file "$hostname" "$CHECK_USER" "$prog" $timeout $raise_error] == 0 } {
      start_remote_prog "$hostname" "$CHECK_USER" "$prog" "status"
      return $prg_exit_state
   } else {
      if { $raise_error } {
         add_proc_error "get_dbwriter_status" -1 "Can not startup dbwriter, $prog does not exists"
      }
      return -1
   }
}

#****** checktree/shutdown_dbwriter() **************************************************
#  NAME
#    shutdown_dbwriter() -- shutdown the dbwriter
#
#  SYNOPSIS
#    shutdown_dbwriter { { hostname "--" } } 
#
#  FUNCTION
#    This function stop the dbwriter
#
#  INPUTS
#    hostname -- host where the dbwriter is running. If set to "--" the host
#                is taken from arco_config(dbwriter_host)
#
#  RESULT
#     0    --  dbwriter has been stopped or is not running
#     else --  error, dbwriter can not be stopped
#
#  EXAMPLE
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
proc shutdown_dbwriter { { hostname "--" } } {
   global ts_config arco_config CHECK_USER CHECK_OUTPUT
   
   if { $hostname == "--" } {
      set hostname $arco_config(dbwriter_host)
   }
      
   set prog "$ts_config(product_root)/$ts_config(cell)/common/sgedbwriter"
   
   if { [ file exists $prog ] } {
      start_remote_prog "$hostname" "$CHECK_USER" "$prog" "stop"
      
      switch -- $prg_exit_state {
         "0" {
            puts $CHECK_OUTPUT "dbwriter has been stopped"
            return 0
         }
         "1" {
            puts $CHECK_OUTPUT "dbwriter has not been started"
            return 0
         }
         default {
            add_proc_error "shutdown_dbwriter" "-2" "shutdown of dbwriter failed, exit status $prg_exit_state"
            return -1
         }
      }
   } else {
      puts $CHECK_OUTPUT "Can not shutdown dbwriter, $prog does not exists"
      return -1
   }
}

proc arco_clean {} {
   
   if { [arco_clean_database] != 0 } {
      return -1
   }
   
   return 0
}

proc arco_clean_database { { drop 0 } } {
   global arco_config
   
   if { $arco_config(database_type) == "oracle" } {
      return [arco_clean_oracle_database $drop]
   } elseif { $arco_config(database_type) == "postgres" } {
      return [arco_clean_postgres_database $drop ]
   } elseif { $arco_config(database_type) == "mysql" } {
      return [arco_clean_mysql_database $drop ]
   }
} 

proc arco_clean_oracle_database { { drop 0 } } {
   global CHECK_OUTPUT ARCO_TABLES ARCO_VIEWS
   
   set id [sqlutil_create]
   if { $id == "-1" } {
      add_sql_error "arco_clean_oracle_database" "-2" "Can not create sqlutil"
      return -1
   }   
   set sp_id [ lindex $id 1 ]
   
   
   # first of all connect to the admin db and check wether the database exists
   if { [ sqlutil_connect $sp_id 1 ] != 0 } {
      add_sql_error "arco_clean_oracle_database" "-2" "Can not connect to admin database"
      close_spawn_process $id;
      return -2
   }
   
   # Ensure that the test database is available
   set arco_write_user [get_arco_write_user]
   set arco_read_user  [get_arco_read_user]
   set sql "SELECT username FROM dba_users WHERE username = '${arco_write_user}'";
   array set result_array {}
   set column_names {}
   
   set res [sqlutil_query $sp_id $sql result_array column_names]
   if { $res == 0 } {
      puts $CHECK_OUTPUT "user ${arco_write_user} does not exist => nothing to clean"
      close_spawn_process $id;
      return 0
   }
   
   set result 0
   
   if { $drop } {
      set synonyms [concat $ARCO_TABLES $ARCO_VIEWS]
      foreach synonym $synonyms {
         set synonym [string toupper $synonym]
         set sql "select SYNONYM_NAME from all_synonyms where SYNONYM_NAME = '$synonym' and OWNER = '${arco_read_user}'" 
         set res [sqlutil_query $sp_id $sql result_array column_names]
         if { $res == 0 } {
            puts $CHECK_OUTPUT "synonym $synonym does not exist"
            continue
         } elseif { $res < 0 } {
            add_sql_error "arco_clean_oracle_database" "-2" "Error: Can not query synonym $synonym" 
            set result -1
            close_spawn_process $id;
            return -1
         }
         
         set sql "DROP SYNONYM ${arco_read_user}.${synonym}"
         puts $CHECK_OUTPUT "drop synonym ${arco_read_user}.${synonym}"
         set res [sqlutil_exec $sp_id $sql]
         if { $res != 0 } {
            add_sql_error "arco_clean_oracle_database" "-2" "Error: Can not drop synonym $synonym"
            close_spawn_process $id;
            return -1
         }
      }
   }
   
   # now connect to the test database
   if { [ sqlutil_connect $sp_id 0 ] != 0 } {
      add_sql_error "arco_clean_oracle_database" "-2" "Can not connect to database [get_database_name 0]"
      close_spawn_process $id;
      return -2
   }
   
   if { $drop } {
      # drop views and synonyms
      foreach view $ARCO_VIEWS {
         set view [string toupper $view]
         set sql "select VIEW_NAME from user_views where VIEW_NAME = '$view'"
         set res [sqlutil_query $sp_id $sql result_array column_names]
         if { $res == 0 } {
            puts $CHECK_OUTPUT "view $view does not exist"
            continue
         } elseif { $res < 0 } {
            add_sql_error "arco_clean_oracle_database" "-2" "Error: Can not query view $view" 
            set result -1
            break;
         }
         
         set sql "DROP VIEW $view"
         puts $CHECK_OUTPUT "drop view ${view}"
         set res [sqlutil_exec $sp_id $sql]
         if { $res != 0 } {
            add_sql_error "arco_clean_oracle_database" "-2" "Error: Can not query view $view"
            set result -1
            break;
         }
      }
      
   }
   
   if { $result == 0 } {
      foreach table $ARCO_TABLES {
         set table [string toupper $table]
         set sql "select table_name from user_tables where table_name = '$table'"
         array set result_array {}
         set column_names {}
         set res [sqlutil_query $sp_id $sql result_array column_names]
         if { $res == 0 } {
            puts $CHECK_OUTPUT "table $table does not exist"
            continue
         } elseif { $res < 0 } {
            add_sql_error "arco_clean_oracle_database" "-2" "Error: Can not query table $table"
            set result -1
            break;
         }
         
         if { $drop } {
            set sql "DROP TABLE $table"
            puts $CHECK_OUTPUT "drop table ${table}"
            set res [sqlutil_exec $sp_id $sql]
            if { $res != 0 } {
               add_sql_error "arco_clean_oracle_database" "-2" "Error: Can not drop table $table"
               set result -1
               break;
            }
         } else {
            if { [string compare [string tolower $table] "sge_version"] != 0 } {
               set sql "DELETE from $table"
               set res [sqlutil_exec $sp_id $sql]
               if { $res != 0 } {
                  add_sql_error "arco_clean_oracle_database" "-2" "Error: Can not delete table $table"
                  set result -1
                  break;
               }
            }
         }
         set sql "COMMIT"
         set res [sqlutil_exec $sp_id $sql]
         if { $res != 0 } {
            add_sql_error "arco_clean_postgres_database" "-2" "Error: Commit failed"
            set result -1
            break;
         }
      }
   }
   close_spawn_process $id;
   return $result
}


proc arco_clean_postgres_database { { drop 0 } } {
   global CHECK_OUTPUT ARCO_TABLES ARCO_VIEWS
   
   set id [sqlutil_create]
   if { $id == "-1" } {
      add_sql_error "arco_clean_postgres_database" "-2" "Can not create sqlutil"
      return -1
   }   
   set sp_id [ lindex $id 1 ]
   
   
   # first of all connect to the admin db and check wether the database exists
   if { [ sqlutil_connect $sp_id 1 ] != 0 } {
      add_sql_error "arco_clean_postgres_database" "-2" "Can not connect to admin database"
      close_spawn_process $id;
      return -2
   }
   
   # Ensure that the test database is available
   set db_name [get_database_name]
   set sql "select datname from pg_database where datname = '$db_name'"
   array set result_array {}
   set column_names {}
   set res [sqlutil_query $sp_id $sql result_array column_names]
   if {$res <= 0} {
      puts $CHECK_OUTPUT "database $db_name does not exist => nothing to clean"
      close_spawn_process $id;
      return 0
   }

   # now connect to the test database
   if { [ sqlutil_connect $sp_id 0 ] != 0 } {
      add_sql_error "arco_clean_postgres_database" "-2" "Can not connect to database $db_name"
      close_spawn_process $id;
      return -2
   }
   
   set result 0
   
   if { $drop } {
      # drop views
      foreach view $ARCO_VIEWS {
         set view [string tolower $view]
         
         set sql "select viewname from pg_views where viewname = '$view'";
         set res [sqlutil_query $sp_id $sql result_array column_names]
         if { $res == 0 } {
            puts $CHECK_OUTPUT "view $view does not exist"
            continue
         } elseif { $res < 0 } {
            add_sql_error "arco_clean_postgres_database" "-2" "Error: Can not query view $view"
            close_spawn_process $id;
            return -1
         }
         
         set sql "DROP VIEW $view"
         puts $CHECK_OUTPUT "drop view $view"
         set res [sqlutil_exec $sp_id $sql]
         if { $res != 0 } {
            add_sql_error "arco_clean_postgres_database" "-2" "Error: Can not drop view $VIEW"
            close_spawn_process $id;
            return -1
         }
      }
   }   
   foreach table $ARCO_TABLES {
      set table [string tolower $table]
      set sql "select tablename, schemaname, tableowner from pg_tables where tablename = '$table'"
      array set result_array {}
      set column_names {}
      set res [sqlutil_query $sp_id $sql result_array column_names]
      if { $res == 0 } {
         puts $CHECK_OUTPUT "table $table does not exist"
         continue
      } elseif { $res < 0 } {
         add_sql_error "arco_clean_postgres_database" "-2" "Error: Can not query table $table"
         close_spawn_process $id
         return -1
      }
      
      if { $drop } {
         set sql "DROP TABLE $table CASCADE"
         puts $CHECK_OUTPUT "drop table $table"
         set res [sqlutil_exec $sp_id $sql]
         if { $res != 0 } {
            add_sql_error "arco_clean_postgres_database" "-2" "Error: Can not drop table $table"
            set result -1
            break;
         }
      } else {
         if { [string compare [string tolower $table] "sge_version"] != 0 } {
            set sql "DELETE from $table"
            set res [sqlutil_exec $sp_id $sql]
            if { $res != 0 } {
               add_sql_error "arco_clean_postgres_database" "-2" "Error: Can not delete table $table"
               set result -1
               break;
            } 
         } 
      }
      set sql "COMMIT"
      set res [sqlutil_exec $sp_id $sql]
      if { $res != 0 } {
         add_sql_error "arco_clean_postgres_database" "-2" "Error: Commit failed"
         set result -1
         break;
      }
   }
   
   close_spawn_process $id;
   return $result
}

proc arco_clean_mysql_database { { drop 0 } } {

global CHECK_OUTPUT ARCO_TABLES ARCO_VIEWS
   
   set id [sqlutil_create]
   if { $id == "-1" } {
      add_sql_error "arco_clean_mysql_database" "-2" "Can not create sqlutil"
      return -1
   }   
   set sp_id [ lindex $id 1 ]
   
   
   # first of all connect to the admin db and check wether the database exists
   if { [ sqlutil_connect $sp_id 1 ] != 0 } {
      add_sql_error "arco_clean_mysql_database" "-2" "Can not connect to admin database"
      close_spawn_process $id;
      return -2
   }
   
   # Ensure that the test database is available
   set db_name [get_database_name]
   set sql "select schema_name FROM information_schema.schemata where schema_name = '${db_name}'"
   array set result_array {}
   set column_names {}
   set res [sqlutil_query $sp_id $sql result_array column_names]
   if {$res <= 0} {
      puts $CHECK_OUTPUT "database $db_name does not exist => nothing to clean"
      close_spawn_process $id;
      return 0
   }

   # now connect to the test database
   if { [ sqlutil_connect $sp_id 0 ] != 0 } {
      add_sql_error "arco_clean_mysql_database" "-2" "Can not connect to database $db_name"
      close_spawn_process $id;
      return -2
   }
   
   set result 0
   
   if { $drop } {
      # drop views
      foreach view $ARCO_VIEWS {
         set view [string tolower $view]
         set sql "select table_name from information_schema.views where table_name = '$view' and table_schema = '${db_name}'";
         set res [sqlutil_query $sp_id $sql result_array column_names]
         if { $res == 0 } {
            puts $CHECK_OUTPUT "view $view does not exist"
            continue
         } elseif { $res < 0 } {
            add_sql_error "arco_clean_mysql_database" "-2" "Error: Can not query view $view"
            close_spawn_process $id;
            return -1
         }
         
         set sql "DROP VIEW $view"
         puts $CHECK_OUTPUT "drop view $view"
         set res [sqlutil_exec $sp_id $sql]
         if { $res != 0 } {
            add_sql_error "arco_clean_mysql_database" "-2" "Error: Can not drop view $VIEW"
            close_spawn_process $id;
            return -1
         }
      }
   }   
   foreach table $ARCO_TABLES {
      set table [string tolower $table]
      set sql "select table_name, table_schema from information_schema.tables where table_name = '$table' and table_schema = '${db_name}'"
      array set result_array {}
      set column_names {}
      set res [sqlutil_query $sp_id $sql result_array column_names]
      if { $res == 0 } {
         puts $CHECK_OUTPUT "table $table does not exist"
         continue
      } elseif { $res < 0 } {
         add_sql_error "arco_clean_mysql_database" "-2" "Error: Can not query table $table"
         close_spawn_process $id
         return -1
      }
      
      if { $drop } {
         set sql "DROP TABLE $table CASCADE"
         puts $CHECK_OUTPUT "drop table $table"
         set res [sqlutil_exec $sp_id $sql]
         if { $res != 0 } {
            add_sql_error "arco_clean_mysql_database" "-2" "Error: Can not drop table $table"
            set result -1
            break;
         }
      } else {
         if { [string compare [string tolower $table] "sge_version"] != 0 } {
            set sql "DELETE from $table"
            set res [sqlutil_exec $sp_id $sql]
            if { $res != 0 } {
               add_sql_error "arco_clean_mysql_database" "-2" "Error: Can not delete table $table"
               set result -1
               break;
            }
         }
      }
      set sql "COMMIT"
      set res [sqlutil_exec $sp_id $sql]
      if { $res != 0 } {
         add_sql_error "arco_clean_mysql_database" "-2" "Error: Commit failed"
         set result -1
         break;
      }
   }
   
   close_spawn_process $id;
   return $result

}

#****** checktree/get_java_web_console_status() **************************************************
#  NAME
#    get_java_web_console_status() -- get the status of the java web console
#
#  SYNOPSIS
#    get_java_web_console_status { { swc_host "" } } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#    swc_host --  the host where the java web console is installed. If this
#                 is an empty string the value from arco_config(swc_host) is taken
# 
#  RESULT
#     0     --  Java Web Console is not running
#     1     --  Java Web Console is running
#     else  --  The Java Web Console is not installed on this host, or it is
#               not accessable by the CHECK_USER
#
#  EXAMPLE
#
#   set res [get_java_web_console_status]
#   if { $res == 0 } {
#      puts "Java Web Console is not running"
#   } else if { $res == 1 } {
#      puts "Java Web Console is running
#   } else {
#      puts "Can not determine status of the Java Web Console"
#   }
#
#*******************************************************************************
proc get_java_web_console_status { { swc_host "" } } {
   global arco_config CHECK_OUTPUT CHECK_USER stored_passwd
   
   if { $swc_host == "" } {
      set swc_host $arco_config(swc_host)
   }

   if { [info exists stored_passwd(root)] } {
      if { [string compare $stored_passwd(root) ""] == 0 } {
         set_root_passwd
      }
   } else {
      set_root_passwd
   }

   set output [start_remote_prog $swc_host root  "/usr/sbin/smcwebserver" "status" ]
   
   if { $prg_exit_state != 0 } {

    #  if {[string compare "You must be the system's root user to manage the server." "$output"] == 0 } {
    #     return 0
    #  }
       puts $CHECK_OUTPUT "------------------------------------------------------------------"
       puts $CHECK_OUTPUT "Command '/usr/sbin/smcwebserver status' on host $swc_host failed"
       puts $CHECK_OUTPUT "------------------------------------------------------------------"
       puts $CHECK_OUTPUT $output"
       puts $CHECK_OUTPUT "------------------------------------------------------------------"
       add_proc_error "get_java_web_console_status" -1 "Can not get status Java Web Console on host $swc_host"
       return -1
   }
   
   if { [string first "is not running" $output] > 0 } {
      return 0
   } else if { [string first "is running" $output] > 0 } {
      return 1
   } else {
      puts $CHECK_OUTPUT "Unexpected output of command '/usr/sbin/smcwebserver status' on host $swc_host:"
      puts $CHECK_OUTPUT $output
      return -1
   }
}

#****** checktree/get_java_web_console_version() **************************************************
#  NAME
#    get_java_web_console_version() -- get the version of the java web console
#
#  SYNOPSIS
#    get_java_web_console_version { version_array { swc_host "" } } 
#
#  FUNCTION
#     get the version of the java web console
#     if the parameter swc_host is "", the swc_host is taken from the globa
#     variable arco_config(swc_host)
#
#  INPUTS
#    version_array -- The array with the major minor and mirco version is stored
#    swc_host      -- name of the host where the java web console is installed
#
#  RESULT
#     0     --   The version has been stored in version_array
#     else  --   Can not determine the version of the java webconsole on the host
#
#  EXAMPLE
#
#     array set version_array {}
#     if { [ get_java_web_console_version ] != 0 } {
#        puts "Can not determin the version of the java web console"
#     } else {
#        puts "Found version ${version_array(major)}. ${version_array(minor)}.${version_array(micro)}"
#     }
#
#*******************************************************************************
proc get_java_web_console_version { version_array { swc_host "" } } {
   global arco_config CHECK_OUTPUT CHECK_USER stored_passwd
   upvar $version_array va
   
   if { $swc_host == "" } {
      set swc_host $arco_config(swc_host)
   }

   if { [info exists stored_passwd(root)] } {
      if { [string compare $stored_passwd(root) ""] == 0 } {
         set_root_passwd
      }
   } else {
      set_root_passwd
   }

   set output [start_remote_prog $swc_host root  "/usr/sbin/smcwebserver" "-V"]

   if { $prg_exit_state != 0 } {
      puts $CHECK_OUTPUT "------------------------------------------------------------------"
      puts $CHECK_OUTPUT "'/usr/sbin/smcwebserver -V' on host $swc_host failed"
      puts $CHECK_OUTPUT "------------------------------------------------------------------"
      puts $CHECK_OUTPUT $output"
      puts $CHECK_OUTPUT "------------------------------------------------------------------"
      add_proc_error "get_java_web_console_version" -1 "Can not get the version of Java Web Console on host $swc_host"
      return -1
   }
   
   set list [split $output " "]
   if { [llength $list] != 2 || [lindex $list 0] != "Version" } {
       add_proc_error "get_java_web_console_version" -1 "Got invalid version string $output from '/usr/sbin/smcwebserver -V' on host $swc_host"
       return -1
   }
   set output [lindex $list 1]
   set list [split $output "."]
   
   switch -- [llength $list] {
      2 {
        set va(major) [lindex $list 0]
        set va(minor) [lindex $list 1]
        set va(micro) 0
        return 0
      }
      3 {
        set va(major) [lindex $list 0]
        set va(minor) [lindex $list 1]
        set va(micro) [lindex $list 2]
        return 0
      }
      default {
         add_proc_error "get_java_web_console_version" -1 "Got invalid version string $output from '/usr/sbin/smcwebserver -V' on host $swc_host"
         return -1
      }
   }
}

