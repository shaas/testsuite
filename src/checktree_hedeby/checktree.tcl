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

global ts_checktree
global hedeby_config
global hedeby_enhanced_config
global CHECK_OUTPUT
global hedeby_checktree_nr
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
set ts_checktree($hedeby_checktree_nr,setup_hooks_0_filename)     [ get_additional_config_file_path "hedeby" ]
set ts_checktree($hedeby_checktree_nr,setup_hooks_0_version)      "1.0"

set ts_checktree($hedeby_checktree_nr,checktree_clean_hooks_0)  "hedeby_checktree_clean"            
set ts_checktree($hedeby_checktree_nr,compile_hooks_0)          "hedeby_compile"                    
set ts_checktree($hedeby_checktree_nr,compile_clean_hooks_0)    "hedeby_compile_clean"              
set ts_checktree($hedeby_checktree_nr,install_binary_hooks_0)   "hedeby_install_binaries"          

set ts_checktree($hedeby_checktree_nr,required_hosts_hook)      "hedeby_get_required_hosts"        
set ts_checktree($hedeby_checktree_nr,passwd_hook)              "hedeby_get_required_passwords"     

set ts_checktree($hedeby_checktree_nr,startup_hooks_0)          "hedeby_startup"                   
set ts_checktree($hedeby_checktree_nr,shutdown_hooks_0)         "hedeby_shutdown"          



##############################################################
# Here we have all basic system installation specific
# procedures
##############################################################
proc hedeby_startup { } {
   return [startup_hedeby]
}

proc hedeby_shutdown { }  {
   return [shutdown_hedeby]
}

# This should reset the hedeby system (testsuite install re_init)
proc hedeby_checktree_clean {} {
   return [reset_hedeby]
}

proc hedeby_install_binaries { arch_list a_report } {
   global CHECK_OUTPUT 
   upvar $a_report report

   set java_build_host [host_conf_get_java_compile_host]
   puts $CHECK_OUTPUT "java build host is \"$java_build_host\""

   set ret [hedeby_build $java_build_host "distinst" report]
   return $ret
}

proc check_private_propterties_file { build_host } {
   global hedeby_config CHECK_OUTPUT CHECK_USER
   global ts_config
   set return_value 0

   puts $CHECK_OUTPUT "hedeby source dir: $hedeby_config(hedeby_source_dir)"
   puts $CHECK_OUTPUT "hedeby dist dir:   $hedeby_config(hedeby_product_root)"
   puts $CHECK_OUTPUT "used SGE_ROOT dir: $ts_config(product_root)"

   set property_file "build_private.properties"
   set property_path $hedeby_config(hedeby_source_dir)/$property_file
   if { [is_remote_file $build_host $CHECK_USER $property_path] == 0 } {
      puts $CHECK_OUTPUT "no $property_file file found!"
      puts $CHECK_OUTPUT "creating default property_file ..."
      set date [clock format [clock seconds] -format "%d. %b %Y - %H:%M:%S"]
      set data(0) 6
      set data(1) "# automatic generated build_private.properties file from"
      set data(2) "# testsuite. ($date)"
      set data(3) "sge.root=$ts_config(product_root)" 
      set data(4) "distinst.dir=$hedeby_config(hedeby_product_root)"
      set data(5) "#nfs.server=<enter name of nfs server host>"
      set data(6) "#remote.starter=rsh"
      save_file $property_path data
      wait_for_remote_file $build_host $CHECK_USER $property_path
   } else {
      puts $CHECK_OUTPUT "found $property_file file!"
      # check content
      get_file_content $build_host $CHECK_USER $property_path priv_prop 
      set nr_of_lines $priv_prop(0)
      set found_sge_root     ""
      set found_distinst_dir ""
      for { set i 1 } { $i <= $nr_of_lines } { incr i 1 } {
         # sge.root and distinst.dir have to start in the first column !!!
         if { [string match "sge.root=*" $priv_prop($i) ] } {
            set found_sge_root [get_string_value_between "sge.root=" -1 $priv_prop($i)]
            set found_sge_root [string trim $found_sge_root]
         }
         if { [string match "distinst.dir=*" $priv_prop($i) ] } {
            set found_distinst_dir [get_string_value_between "distinst.dir=" -1 $priv_prop($i)]
            set found_distinst_dir [string trim $found_distinst_dir]
         }
      }
      # need sge.root=$ts_config(product_root)
      # need distinst.dir=$hedeby_config(hedeby_product_root)
      puts $CHECK_OUTPUT "sge.root=$found_sge_root"
      puts $CHECK_OUTPUT "distinst.dir=$found_distinst_dir"
 
      if { $found_sge_root != $ts_config(product_root) } {
         add_proc_error "check_private_propterties_file" -1 "$property_path does not contain sge.root=$ts_config(product_root)"
         set return_value -1
      }
      if { $found_distinst_dir != $hedeby_config(hedeby_product_root) } {
         add_proc_error "check_private_propterties_file" -1 "$property_path does not contain distinst.dir=$hedeby_config(hedeby_product_root)"
         set return_value -1
      }
   }
   return $return_value
}


##############################################################
# Here we have all the compile procedures
##############################################################
proc hedeby_compile { compile_hosts a_report } {
   global CHECK_OUTPUT
   upvar $a_report report 

   
   set java_build_host [host_conf_get_java_compile_host]
   puts $CHECK_OUTPUT "java build host is \"$java_build_host\""

   # java build host specific things (generate classes, etc.)
   puts $CHECK_OUTPUT "starting pre build on \"$java_build_host\" ..."
   set ret [hedeby_build $java_build_host "dist" report]
   if { $ret != 0 } {
      add_proc_error "hedeby_compile" -1 "Java compile run failed on host \"$java_build_host\" (return code $ret)"
      return -1
   } else {
      puts $CHECK_OUTPUT "done."
   }
   
   # here we do the native build things (all hosts without java build host) ...
   foreach build_host $compile_hosts {
      if { $build_host != $java_build_host } {
         puts $CHECK_OUTPUT "starting build on \"$build_host\" ..."
         set ret [hedeby_build $build_host "native.build" report]
         if { $ret != 0 } {
            add_proc_error "hedeby_compile" -1 "Native build on $build_host failed"
            return -1
         } else {
            puts $CHECK_OUTPUT "done."
         }
      }
   }

   # here we do create the dist on the java build host
   puts $CHECK_OUTPUT "making dist build on \"$build_host\" ..."
   set ret [hedeby_build $java_build_host "tar" report]
   if { $ret != 0 } {
      add_proc_error "hedeby_compile" -1 "Java compile run failed (return code $ret)"
      return -1
   } else {
      puts $CHECK_OUTPUT "done."
   }
   return 0
}


# clean is done on java build host - assuming that all
# code is cleaned (also native code)
proc hedeby_compile_clean { compile_hosts a_report } {
   global CHECK_OUTPUT 
   upvar $a_report report

   set java_build_host [host_conf_get_java_compile_host]
   puts $CHECK_OUTPUT "java build host is \"$java_build_host\""

   set ret [hedeby_build $java_build_host "clean" report]
   puts $CHECK_OUTPUT "compile clean for hedeby done. Result: \"$ret\"" 
   return $ret
}


proc hedeby_build { build_host target a_report { ant_options "" } { hedeby_build_timeout 300 } } {
   global CHECK_OUTPUT CHECK_USER
   global CHECK_HTML_DIRECTORY CHECK_PROTOCOL_DIR
   global ts_host_config hedeby_config
   global ts_config
   upvar $a_report report

   if { [check_private_propterties_file $build_host] != 0 } {
      return -1
   }
   puts $CHECK_OUTPUT "starting $build_host:ant $target $ant_options in dir $hedeby_config(hedeby_source_dir)"
   
   set task_nr [report_create_task report "hedeby_build_$target" $build_host]
   
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "-> starting hedeby ant $target on host $build_host ..."
   
   set env(JAVA_HOME) [get_java_home_for_host $build_host "1.5"]
   
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

   set open_spawn [ open_remote_spawn_process $build_host $CHECK_USER "ant" "$target" 0 "$hedeby_config(hedeby_source_dir)" env]
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








##############################################################
# Here we start with configuration for hedeby
##############################################################
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

proc config_hedeby_product_root { only_check name config_array } {
   global CHECK_OUTPUT fast_setup
   upvar $config_array config
   
   set help_text { "Please enter the path where the testsuite should install Hedeby,"
                   "or press >RETURN< to use the default value." 
                   "WARNING: The compile option will remove the content of this directory" 
                   "and store it to \"testsuite_trash\" directory!!!" }
 
   set value [config_generic $only_check $name config $help_text "directory" ]
   if {!$fast_setup} {
      # to be able to find processes with ps command, don't allow to long
      # directory path:
      set add_path "/bin/sol-sparc64/abcdef"
      set path_length [ string length $add_path ]
      if { [string length "$value/$add_path"] > 60 } {
           puts $CHECK_OUTPUT "path for hedeby dist directory is too long (must be <= [expr ( 60 - $path_length )] chars)"
           puts $CHECK_OUTPUT "The testsuite tries to find processes via ps output most ps output is truncated"
           puts $CHECK_OUTPUT "for longer lines."
           return -1
      }
   }
   return $value
}


proc config_hedeby_source_dir { only_check name config_array } {
   global CHECK_OUTPUT
   upvar $config_array config
   
   set help_text { "Please enter the path to Hedeby source directory, or press >RETURN<"
                   "to use the default value." }
 
   return [config_generic $only_check $name config $help_text "directory" ]
}

proc config_hedeby_master_host { only_check name config_array } {
   global CHECK_OUTPUT ts_host_config fast_setup
   global ts_config
   upvar $config_array config

   set help_text { "Please select the host where the testsuite should install"
                   "the hedeby master host components. The testsuite will"
                   "install the config center, config service, CA component"
                   "and the resource provider on this host."
                   "NOTE: The testsuite is checking that the hedeby master"
                   "      components are not installed on a grid engine"
                   "      qmaster host to enhance test quality!" }
   set value [config_generic $only_check $name config $help_text "host"]
   if {!$fast_setup} {
      # now check that the selected host is not a qmaster in any cluster setup
      set master_list [get_all_qmaster_hosts]
      foreach master $master_list {
         if { $value == $master } {
            puts $CHECK_OUTPUT "host \"$value\" is a master host"
            return -1
         }
      }
   }
   return $value
}
proc config_hedeby_cs_port { only_check name config_array } {
   global CHECK_OUTPUT ts_host_config fast_setup CHECK_USER
   global ts_config
   upvar $config_array config
  
   set help_text { "Please enter the port number value the testsuite should use"
                   "for the Configuraiton Service."
                   "or press >RETURN< to use the default value." }
   set value [config_generic $only_check $name config $help_text "port"]
   if {!$fast_setup} {
      # now check that the port is not equal to hedeby_user_jvm_port
      if { $value != 0 } {
         if { $value == $config(hedeby_user_jvm_port) } {
            puts $CHECK_OUTPUT "root JVM port must be different to $CHECK_USER JVM port!"
            return -1
         }
      }
      # now check that the testsuite isn't already using the port
      set qmaster_port $ts_config(commd_port)
      set execd_port $qmaster_port
      incr execd_port 1
      if { $value == $ts_config(reserved_port) ||
           $value == $qmaster_port ||
           $value == $execd_port } {
         puts $CHECK_OUTPUT "The port \"$value\" is already used in testsuite config!"
         puts $CHECK_OUTPUT "Please select another port!"
         return -1
      }
      # now check that the selected port is not used for the GE clusters
      if {$ts_config(additional_config) != "none"} {
         foreach filename $ts_config(additional_config) {
            get_additional_config $filename add_config
            set qmaster_port $add_config(commd_port)
            set execd_port $qmaster_port
            incr execd_port 1
            if { $value != $add_config(reserved_port) &&
                 $value != $qmaster_port &&
                 $value != $execd_port } {
               continue
            } else {
               puts $CHECK_OUTPUT "The port \"$value\" is already used for addtional testsuite"
               puts $CHECK_OUTPUT "config file \"$filename\"! Please select another port!"
               return -1
            }
         }
      }
   }
   return $value
}

proc config_hedeby_user_jvm_port { only_check name config_array } {
   global CHECK_OUTPUT ts_host_config fast_setup CHECK_USER
   global ts_config
   upvar $config_array config

   set help_text { "Please enter the port number value the testsuite should use"
                   "for components which are started in the $CHECK_USER JVM."
                   "or press >RETURN< to use the default value." }
   set value [config_generic $only_check $name config $help_text "port"]
   if {!$fast_setup} {
      # now check that the port is not equal to hedeby_user_jvm_port
      if { $value != 0 } {
         if { $value == $config(hedeby_cs_port) } {
            puts $CHECK_OUTPUT "root JVM port must be different to $CHECK_USER JVM port!"
            return -1
         }
      }

      # now check that the testsuite isn't already using the port
      set qmaster_port $ts_config(commd_port)
      set execd_port $qmaster_port
      incr execd_port 1
      if { $value == $ts_config(reserved_port) ||
           $value == $qmaster_port ||
           $value == $execd_port } {
         puts $CHECK_OUTPUT "The port \"$value\" is already used in testsuite config!"
         puts $CHECK_OUTPUT "Please select another port!"
         return -1
      }

      # now check that the selected port is not used for the GE clusters
      if {$ts_config(additional_config) != "none"} {
         foreach filename $ts_config(additional_config) {
            get_additional_config $filename add_config
            set qmaster_port $add_config(commd_port)
            set execd_port $qmaster_port
            incr execd_port 1
            if { $value != $add_config(reserved_port) &&
                 $value != $qmaster_port &&
                 $value != $execd_port } {
               continue
            } else {
               puts $CHECK_OUTPUT "The port \"$value\" is already used for addtional testsuite"
               puts $CHECK_OUTPUT "config file \"$filename\"! Please select another port!"
               return -1
            }
         }
      }
   }
   return $value
}





proc config_hedeby_host_resources { only_check name config_array } {
   global CHECK_OUTPUT ts_host_config fast_setup
   global ts_config
   upvar $config_array config

   set help_text { "Please select the host which should be used as free"
                   "assignable host resources. On host resources the testsuite"
                   "will install the remote CA and and Executor component."
                   "NOTE: The testsuite is checking that no free assignable"
                   "      resource is specified as execd host in any gridengine"
                   "      cluster. These resources are statically assigned to their"
                   "      service." }
   set value [config_generic $only_check $name config $help_text "hosts"]
   if {!$fast_setup} {
      # now check that the selected host is not a qmaster in any cluster setup
      set execd_list [get_all_execd_hosts]
      foreach execd $execd_list {
         foreach hostResource $value {
            if { $hostResource == $execd } {
               puts $CHECK_OUTPUT "host \"$hostResource\" is a execd host"
               return -1
            }
         }
      }
      # we need at least 2 host resources
      if { [llength $value] < 2 } {
         puts $CHECK_OUTPUT "need at least 2 free assignable host resources"
         return -1
      }
   }
   return $value
}



proc config_hedeby_source_cvs_release { only_check name config_array } {
   global CHECK_OUTPUT fast_setup CHECK_USER ts_config

   upvar $config_array config

   # we need source dir to check the value
   if {![file isdirectory $config(hedeby_source_dir)]} {
      puts $CHECK_OUTPUT "source directory $config(hedeby_source_dir) doesn't exist"
      return -1
   }

   # if the default value is set to "" (setup of config) find out default 
   # by reading the testsuite CVS/Tag file ...
   if { $config($name,default) == "" } {
      set result [start_remote_prog $ts_config(source_cvs_hostname) $CHECK_USER "cat" "$config(hedeby_source_dir)/CVS/Tag" prg_exit_state 60 0 "" "" 1 0]
      set result [string trim $result]
      if {$prg_exit_state == 0} {
         if {[string first "T" $result] == 0 || [string first "N" $result] == 0  } {
            set config($name,default) [string range $result 1 end]
         }
      } else {
         # there might be no tag file, setting default to "maintrunk"
         set config($name,default) "maintrunk" 
      }
   }

   set help_text { "Please enter cvs release tag of Hedeby source." 
                   "\"maintrunk\" specifies no tag or press "
                   ">RETURN< to use the default value." }
 
   set value [config_generic $only_check $name config $help_text "string" ]
   if {!$fast_setup} {
      set result [start_remote_prog $ts_config(source_cvs_hostname) $CHECK_USER "cat" "$config(hedeby_source_dir)/CVS/Tag" prg_exit_state 60 0 "" "" 1 0]
      set result [string trim $result]
      if {$prg_exit_state == 0} {
         if {[string compare $result "T$value"] != 0 && [string compare $result "N$value"] != 0} {
            puts $CHECK_OUTPUT "CVS/Tag entry doesn't match cvs release tag \"$value\" in directory $config(hedeby_source_dir)/CVS/Tag"
            return -1
         }
      }
      if { $only_check == 0 } {
         puts $CHECK_OUTPUT "INFO: Testsuite internal hedeby version id: \"[hedeby_get_version $value]\""
      }
   }
   return $value
}


#proc hedeby_config_dist { only_check name config_array } {
#   
#   upvar $config_array config
#   
#   set help_text {  "Please enter the directory GRM dist directory >RETURN<" }
#                    
#   return [ config_generic $only_check $name config $help_text ]
#}

proc hedeby_get_version { { cvstagname "" } } {
   global hedeby_config CHECK_OUTPUT

   set version "unsupported"

   if { [info exists hedeby_config(hedeby_source_cvs_release)] } {
      if { $cvstagname == "" } {
         set tag_name $config(hedeby_source_cvs_release) 
      } else {
         set tag_name $cvstagname
      }
      switch -- $tag_name {
         "V01_TAG" {
            set version "0.1"
         }
         "V02_TAG" {
            set version "0.2"
         }
         "maintrunk" {
            set version "0.9"
         }
      }
   } else {
      add_proc_error "hedeby_get_version" -1 "configuration not available"
   }
   return $version
}


proc hedeby_init_config { config_array } {
   global hedeby_config hedeby_checktree_nr ts_checktree
   global CHECK_CURRENT_WORKING_DIR
   
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

   set parameter "hedeby_source_cvs_release"
   set config($parameter)            ""
   set config($parameter,desc)       "Used Hedeby cvs release tag"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "stop"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "hedeby_product_root"
   set config($parameter)            ""
   set config($parameter,desc)       "Hedeby distribution directory"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "hedeby_master_host"
   set config($parameter)            ""
   set config($parameter,desc)       "Hedeby master host"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "hedeby_host_resources"
   set config($parameter)            ""
   set config($parameter,desc)       "Hedeby assignable host resource list"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "hedeby_cs_port"
   set config($parameter)            ""
   set config($parameter,desc)       "Java JMX Port used for Configuraiton Service (CS)"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "hedeby_user_jvm_port"
   set config($parameter)            ""
   set config($parameter,desc)       "Java JMX Port used for user JVMs"
   set config($parameter,default)    ""
   set config($parameter,setup_func) "config_$parameter"
   set config($parameter,onchange)   "install"
   set config($parameter,pos)        $ts_pos
   incr ts_pos 1

}


proc hedeby_verify_config { config_array only_check parameter_error_list } {
   global ts_checktree hedeby_checktree_nr CHECK_OUTPUT hedeby_enhanced_config
   global CHECK_DEFAULTS_FILE
   global ts_config
   upvar $config_array config
   upvar $parameter_error_list param_error_list
   
   set retval [verify_config2 config $only_check param_error_list $ts_checktree($hedeby_checktree_nr,setup_hooks_0_version)]
   puts $CHECK_OUTPUT "   hedeby configuration verify result: $retval"
   if { $retval == 0 } {
      puts $CHECK_OUTPUT "      hedeby configuration seems to be ok, creating enhanced config array ..."
      if { [info exists hedeby_enhanced_config] } {
         puts -nonewline $CHECK_OUTPUT "      cleaning up hedeby_enhanced_config array -> "
         unset hedeby_enhanced_config
         puts $CHECK_OUTPUT "ok"
      }
      if { $ts_config(additional_config) == "none" } {
         puts $CHECK_OUTPUT "There is no additional_config specified! Please check testsuite configuration!"
         return -1
      }
      set hedeby_enhanced_config(cluster_count) 1
      set hedeby_enhanced_config(cluster,file,0) "$CHECK_DEFAULTS_FILE"
      set hedeby_enhanced_config(cluster,type,0) "cell"
      set act_cluster 1
      set cell_cluster 1
      set independent_cluster 0
      foreach filename $ts_config(additional_config) {
         set type [get_additional_cluster_type $filename add_config]
         set hedeby_enhanced_config(cluster,file,$act_cluster) $filename
         set hedeby_enhanced_config(cluster,type,$act_cluster) $type
         switch -- $type {
            "cell" {
               incr cell_cluster 1
            }
            "independent" {
               incr independent_cluster 1
            }
            default {
               puts $CHECK_OUTPUT "Error reading additional config file: \"$filename\""
               return -1
            }
         }
         incr hedeby_enhanced_config(cluster_count) 1
         incr act_cluster 1
      }

      if { $cell_cluster <= 1 } {
         puts $CHECK_OUTPUT "Need at least one additional cell GE cluster! Please check testsuite configuration!"
         return -1
      }

      if { $independent_cluster <= 0 } {
         puts $CHECK_OUTPUT "Need at least one additional independent GE cluster! Please check testsuite configuration!"
         return -1
      }

      puts $CHECK_OUTPUT "      hedeby_enhanced_config:"
      set names [array names hedeby_enhanced_config]
      foreach name $names {
         if { [string match "cluster,*" $name] == 0 } {
            puts $CHECK_OUTPUT "         $name: $hedeby_enhanced_config($name)"
         }
      }
      for {set i 0} {$i < $hedeby_enhanced_config(cluster_count) } { incr i 1} {
         puts $CHECK_OUTPUT "         cluster $i:"
         puts $CHECK_OUTPUT "            config: $hedeby_enhanced_config(cluster,file,$i)"
         puts $CHECK_OUTPUT "            type:   $hedeby_enhanced_config(cluster,type,$i)"
      } 
   }

   # TODO: now check all local spool directories to have the same path
   # TODO: this can be removed if hedeby supports host specific
   # TODO: spool directories in the user preferences installation
   if { [get_hedeby_pref_type] == "user" } {
      set main_spool_dir ""
      set error_text ""
      foreach host [hedeby_get_all_hosts] {
         set spool_dir [get_hedeby_local_spool_dir $host]
         puts $CHECK_OUTPUT "local spooldir for host \"$host\": $spool_dir"
         if { $main_spool_dir == ""} {
            set main_spool_dir $spool_dir
         } else {
            if { $spool_dir != $main_spool_dir } {
               append error_text "local spool directory on host \"$host\" is not set to\n"
               append error_text "\"$main_spool_dir\".\n"
               append error_text "The local spool dir on host \"$host\" is set to\n"
               append error_text "\"$spool_dir\".\n\n"
            }
         }
      }

      if { $error_text != "" } {
         append error_text "==> Hedeby currently does require to have the same local spool dir for user preferences mode!\n\n"
         add_proc_error "hedeby_get_required_hosts" -3 $error_text
      }
   }

   return $retval
}

proc hedeby_get_all_hosts {} {
   global hedeby_config CHECK_OUTPUT
   global hedeby_enhanced_config
   set res {}
   # required hosts for hedeby
   lappend res $hedeby_config(hedeby_master_host)
   # all master hosts
   foreach host [get_all_qmaster_hosts] {
      lappend res $host
   }
   # all execd hosts
   foreach host [get_all_execd_hosts] {
      lappend res $host
   }
   # host resources (all additional checktree configs must have 
   # these hosts in their additional compile host list, since
   # they are exchanged between the clusters)
   foreach host $hedeby_config(hedeby_host_resources) {
      lappend res $host
   }

    # make host entries unique
   set result {}
   foreach host $res {
      if {[lsearch -exact $result $host] < 0} {
         lappend result $host
      }
   }

   return $result
}

proc hedeby_get_required_hosts {} {
   global hedeby_config CHECK_OUTPUT
   global hedeby_enhanced_config
   set enhanced_res {}

   set res [hedeby_get_all_hosts]
   
   # host resources (all additional checktree configs must have 
   # these hosts in their additional compile host list, since
   # they are exchanged between the clusters)
   foreach host $hedeby_config(hedeby_host_resources) {
      lappend enhanced_res $host
   }

   # check that each cluster has the architecture compiled
   # for the host resources ...
   set required_additional_archs {}
   foreach host $enhanced_res {
      set host_arch [resolve_arch $host]
      lappend required_additional_archs $host_arch
   }

   for {set i 1} {$i < $hedeby_enhanced_config(cluster_count) } { incr i 1} {
      if { $hedeby_enhanced_config(cluster,type,$i) == "independent" } {
         puts $CHECK_OUTPUT "testing compile host for independent cluster config $hedeby_enhanced_config(cluster,file,$i) ..."
         get_additional_config $hedeby_enhanced_config(cluster,file,$i) add_config
         operate_add_cluster $hedeby_enhanced_config(cluster,file,$i) "execute_func" 120 {compile_host_list} hosts_list
         puts $CHECK_OUTPUT "testsuite rpc call returned: \"$hosts_list\""
         
         set remote_archs {}
         foreach host $hosts_list {
            set arch [resolve_arch $host]
            lappend remote_archs $arch
         }
         foreach forced_arch $add_config(add_compile_archs) {
            lappend remote_archs $forced_arch
         }
         foreach required_arch $required_additional_archs {
            if { [lsearch -exact $remote_archs $required_arch] < 0 } {
               add_proc_error "hedeby_get_required_hosts" -1 "cluster configuration file \"$hedeby_enhanced_config(cluster,file,$i)\" must have additional compile archs for compile arch $required_arch"
               return -1
            }
         }

      }
   }   
   puts $CHECK_OUTPUT "Required hosts for hedeby: $res"
   return $res
}

proc hedeby_get_required_passwords {} {
   global hedeby_config CHECK_OUTPUT
   puts $CHECK_OUTPUT "only standard testsuite users needed by hedeby"
   return 0
}


