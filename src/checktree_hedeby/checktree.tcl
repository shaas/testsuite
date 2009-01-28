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
set ts_checktree($hedeby_checktree_nr,setup_hooks_0_version)      "1.3"

set ts_checktree($hedeby_checktree_nr,checktree_clean_hooks_0)  "hedeby_checktree_clean"            
set ts_checktree($hedeby_checktree_nr,compile_hooks_0)          "hedeby_compile"                    
set ts_checktree($hedeby_checktree_nr,compile_clean_hooks_0)    "hedeby_compile_clean"              
set ts_checktree($hedeby_checktree_nr,install_binary_hooks_0)   "hedeby_install_binaries"          

set ts_checktree($hedeby_checktree_nr,required_hosts_hook)      "hedeby_get_required_hosts"        
set ts_checktree($hedeby_checktree_nr,required_ports_hook)      "hedeby_get_required_ports"
set ts_checktree($hedeby_checktree_nr,passwd_hook)              "hedeby_get_required_passwords"     

set ts_checktree($hedeby_checktree_nr,startup_hooks_0)          "hedeby_startup"                   
set ts_checktree($hedeby_checktree_nr,shutdown_hooks_0)         "hedeby_shutdown"          
set ts_checktree($hedeby_checktree_nr,start_runlevel_hooks_0)   "hedeby_test_run_level_check"



##############################################################
# Here we have all basic system installation specific
# procedures
##############################################################
#****** checktree_hedeby/hedeby_startup() *********************************************
#  NAME
#     hedeby_startup() -- startup hook for hedeby
#
#  SYNOPSIS
#     hedeby_startup { } 
#
#  FUNCTION
#     This hook is used to startup the hedeby system from testsuite framework
#
#  INPUTS
#
#  RESULT
#     0 - on success
#     1 - on error
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#     util/startup_hedeby()
#*******************************************************************************
proc hedeby_startup { } {
   return [startup_hedeby]
}

#****** checktree_hedeby/hedeby_shutdown() ********************************************
#  NAME
#     hedeby_shutdown() -- shutdown hook for hedeby
#
#  SYNOPSIS
#     hedeby_shutdown { } 
#
#  FUNCTION
#     This hook is used to shutdown the hedeby system from testsuite framework
#
#  INPUTS
#
#  RESULT
#     0 - on success
#     1 - on error
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#     util/shutdown_hedeby()
#*******************************************************************************
proc hedeby_shutdown { }  {
   return [shutdown_hedeby 1]
}
#****** checktree/hedeby_test_run_level_check() ********************************
#  NAME
#     hedeby_test_run_level_check() -- start runlevel check hooks for hedeby
#
#  SYNOPSIS
#     hedeby_test_run_level_check { is_starting was_error } 
#
#  FUNCTION
#     This procedure is the callback for the runlevel start hook of TS.
#     It checks if all resources and services are available. It will not do
#     any checking if the current test name is "hedeby_install" since this
#     check needs a running hedeby system.
#     
#     This procedure will also create log files in the hedeby distinst dir when
#     a test failes.
#
#  INPUTS
#     is_starting - if != 0 the test is starting, otherwise test is already run
#                   and it is cleanup check
#     was_error - if not 0 the test generated an error (set by TS framework)
#     
#
#  RESULT
#     0 on success, 1 on error
#*******************************************************************************
proc hedeby_test_run_level_check { is_starting was_error } {
   global env check_name hedeby_config
   upvar #0 hedeby_test_run_start_time_ctx this

   if {$check_name == "hedeby_install"} {
      ts_log_fine "skip hedeby_install runlevel checking"
      return 0
   }

   ts_log_fine "performing run level check ..."

   if {$is_starting != 0} {
      # save test start time (consider possible time difference between hosts)
      set this(start_time) [expr [timestamp] - 61]
   } else {
      # This code is called after a test has finished
      if {![info exists this(start_time)]} {
         set    msg "Hit severe bug in testsuite framework!!!!\n"
         append msg "=========================================\n"
         append msg "\n"
         append msg "It seems that the hedeby_test_run_level_check has not\n"
         append msg "been called before executing test '$check_name', because\n"
         append msg "the start_time is not set in the global variable 'hedeby_test_run_start_time_ctx'"
         ts_log_severe msg
         return 1
      }
      # set test end time (consider possible time difference between hosts)
      set end_time [expr [timestamp] + 61]
      if {$was_error != 0} {
         ts_log_fine "--> test \"$check_name\" failed with error: $was_error"
         set time_start_string [clock format $this(start_time) -format "%Y-%m-%d %H:%M:%S"]
         set time_end_string [clock format $end_time -format "%Y-%m-%d %H:%M:%S"]

         ts_log_fine "--> creating merged hedeby log file for time range \"$time_start_string\" - \"$time_end_string\"" 
         if {[info exists env(TS_SKIP_COLLECT_LOG)] && $env(TS_SKIP_COLLECT_LOG) == 1} {
            set    msg "Skipped collection of log files for failed test '$check_name'.\n"
            append msg "  Set environment variable TS_SKIP_COLLECT_LOG to zero (or delete it) to enable collection of log file information."
            ts_log_info $msg
         } else {
            set path [get_all_log_files "root" "$hedeby_config(hedeby_product_root)/TS_LOG_FILES/" "" $this(start_time) $end_time]
            ts_log_info "tared logging files of test \"$check_name\" stored in archive:\n$path\n"
         }
      }
      # Check that the test did cleanup all jobs from all clusters
      ts_log_fine "Check that the test removed all jobs from all clusters" 
      set ccnr [get_current_cluster_config_nr]

      get_hedeby_default_services service_names

      foreach service $service_names(services) {
           set_current_cluster_config_nr $service_names(ts_cluster_nr,$service)
           if {[get_job_count] != 0} {
              get_current_cluster_config_array config
              set msg "Test '$check_name' did not cleanup submitted jobs in cluster '$config(cluster_name)'\n"
              append msg "\n"
              append msg [start_sge_bin "qstat" "-f"]
              append msg "\n"
              ts_log_severe $msg
           } 
      }
      set_current_cluster_config_nr $ccnr 
   }


   ts_log_fine "checking services ..."
   # check correct startup of services
   set ret_val [hedeby_check_default_services]
   if { $ret_val != 0} {
      return 1
   }

   # check correct startup of resources
   ts_log_fine "checking resources ..."
   set ret_val [hedeby_check_default_resources]
   if { $ret_val != 0} {
      return 1
   }
 
   return 0
}



# This should reset the hedeby system (testsuite install re_init)
#****** checktree_hedeby/hedeby_checktree_clean() *************************************
#  NAME
#     hedeby_checktree_clean() -- checktree_clean_hook for hedeby
#
#  SYNOPSIS
#     hedeby_checktree_clean { } 
#
#  FUNCTION
#     This hook is used to reset the hedeby system configurations and is used from
#     the testsuite framework.
#
#     Mainly useful to setup a clean configuration without shutting down the hedeby
#     system.
#
#     Used to bypass complete installation when testsuite parameter "re_init" is used.
#
#  INPUTS
#
#  RESULT
#     0 - on success
#     1 - on error
#
#  NOTES
#     Currently the called procedure is not implemented
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#     util/reset_hedeby()
#*******************************************************************************
proc hedeby_checktree_clean {} {
   return [reset_hedeby]
}

#****** checktree_hedeby/hedeby_install_binaries() ************************************
#  NAME
#     hedeby_install_binaries() -- install binary hook for hedeby
#
#  SYNOPSIS
#     hedeby_install_binaries { arch_list a_report } 
#
#  FUNCTION
#     This procedure is used by the testsuite framework to install the
#     hedeby distribution after compilation of the code.
#
#     The parameters contain information about where to write errors or info
#     messages (report array) and which architectures should be installed.
#
#     The procidure will call the hedeby procedure hedeby_build() which
#     calls the ant target "distinst" on the testsuite java compile host.
#
#  INPUTS
#     arch_list - list of architectures which should be installed. This
#                 parameter is currently not used. (all compiled architectures
#                 are installed)
#     a_report  - name of a report array where messages and infos should be
#                 printed (see report_XXXXXX procedures)
#
#  RESULT
#     0 - on success
#    -1 - on error
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#     checktree_hedeby/hedeby_build()
#*******************************************************************************
proc hedeby_install_binaries { arch_list a_report } {
   global CHECK_OUTPUT 
   global CHECK_USER
   global hedeby_config
   global ts_config
   upvar $a_report report

   # fix for hedeby testsuite issue #76 (Part 1/2)
   # first delete distribution directory
   set task_nr [report_create_task report "hedeby_delete_dist" $hedeby_config(hedeby_master_host)]
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "deleting dist directory: $hedeby_config(hedeby_product_root)"

   set del_ret_val [remote_delete_directory $hedeby_config(hedeby_master_host) $hedeby_config(hedeby_product_root)]
   if { $del_ret_val != 0 } {
      report_task_add_message report $task_nr "remote_delete_directory returned: $del_ret_val"
      report_task_add_message report $task_nr "------------------------------------------"
      report_finish_task report $task_nr 0
      return -1
   }
   report_task_add_message report $task_nr "------------------------------------------"
   report_finish_task report $task_nr 0

   set java_build_host [host_conf_get_java_compile_host]
   puts $CHECK_OUTPUT "java build host is \"$java_build_host\""

   wait_for_remote_dir $java_build_host $CHECK_USER $hedeby_config(hedeby_product_root) 70 1 1
   remote_file_mkdir $hedeby_config(hedeby_master_host) $hedeby_config(hedeby_product_root)
   wait_for_remote_dir $java_build_host $CHECK_USER $hedeby_config(hedeby_product_root) 70  

   set ret [hedeby_build $java_build_host "distinst" report]

   # fix for hedeby testsuite issue #76 (Part 2/2)
   set sdm_adm_path [get_hedeby_binary_path "sdmadm" $CHECK_USER $hedeby_config(hedeby_master_host)]
   wait_for_remote_file $hedeby_config(hedeby_master_host) $CHECK_USER $sdm_adm_path
   if { ![is_remote_file $hedeby_config(hedeby_master_host) $CHECK_USER $sdm_adm_path 1]} {
      add_proc_error "hedeby_install_binaries" -1 "The ant target \"distinst\" did not install hedeby distribution!"
      set task_nr [report_create_task report "hedeby_check_dist" $hedeby_config(hedeby_master_host)]
      report_task_add_message report $task_nr "File \"$sdm_adm_path\" not installed after installing the distribution"
      report_finish_task report $task_nr 1
      return -1
   }
   return $ret
}


#****** checktree_hedeby/create_testsuite_properties_file() *****************************
#  NAME
#     create_testsuite_properties_file() -- check private properties file
#
#  SYNOPSIS
#     create_testsuite_properties_file { build_host } 
#
#  FUNCTION
#     This procedure is used in the hedeby_build() procedure to verify
#     the settings in the "build_private.properties" which is stored in the
#     hedeby source directory. It contains information about SGE_ROOT
#     directory and the used Distribution directory. These informations
#     are used for the ant build targets.
#
#     If the "build_private.properties" file is not existing the testsuite
#     will automatically create it.
#
#  INPUTS
#     build_host - the build host is needed to verfiy that the file also
#                  is available on the specified host which should be set
#                  to the java build host.
#
#  RESULT
#     -1 - on error
#      0 - on success
#
#  SEE ALSO
#     checktree_hedeby/hedeby_build()
#*******************************************************************************
proc create_testsuite_properties_file { property_path build_host } {
   global hedeby_config CHECK_OUTPUT CHECK_USER
   global ts_config
   set return_value 0

   puts $CHECK_OUTPUT "hedeby source dir: $hedeby_config(hedeby_source_dir)"
   puts $CHECK_OUTPUT "hedeby dist dir:   $hedeby_config(hedeby_product_root)"
   puts $CHECK_OUTPUT "used SGE_ROOT dir: $ts_config(product_root)"

   puts $CHECK_OUTPUT "creating testsuite property_file ..."
   set date [clock format [clock seconds] -format "%d. %b %Y - %H:%M:%S"]
   set data(0) 7
   set data(1) "# automatic generated build_testsuite.properties file from"
   set data(2) "# testsuite. ($date)"
   set data(3) "sge.root=$ts_config(product_root)" 
   set data(4) "distinst.dir=$hedeby_config(hedeby_product_root)"
   set data(5) "suppress.arch.check=true"
   set data(6) "#nfs.server=<enter name of nfs server host>"
   set data(7) "#remote.starter=rsh"
   save_file $property_path data
   wait_for_remote_file $build_host $CHECK_USER $property_path

   return $return_value
}


#****** checktree_hedeby/hedeby_compile() *********************************************
#  NAME
#     hedeby_compile() -- compile hook for testsuite
#
#  SYNOPSIS
#     hedeby_compile { compile_hosts a_report } 
#
#  FUNCTION
#     This procedure is the implemented compile hook to get the hedeby
#     sources compiled. Testsuite is calling all compile hooks when 
#     compile_source is started.
#
#     First the ant target "dist" is called on the testsuite java
#     compile host.
#
#     After that for each compile host the ant target "native.build"
#     is remotely executed.
#
#     Then the ant target "tar" is started on the java build host
#     to create the distribution.
#
#     After successfull compiling all *.properties files in the
#     hedeby source directory are parsed to fill up the testsuite
#     internal bundle_cache which contains all L10N bundle ids and their
#     strings to be used by the bundle procedures.
#
#  INPUTS
#     compile_hosts - all hosts for which the sources should be build
#     a_report      - name of a report variable where reports should be
#                     written in
#
#  RESULT
#     0 - on success
#    -1 - on error
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/create_testsuite_properties_file()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#     util/parse_bundle_properties_files()
#*******************************************************************************
proc hedeby_compile { compile_hosts a_report } {
   global CHECK_OUTPUT
   global hedeby_config
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

   set hosts(lx26_amd64) 1
   set hosts(lx26_x86) 1
   #here we need to check if lx24 and lx26 are for given platform lx26 should not be compiled
   foreach build_host $compile_hosts {
	   if { "[host_conf_get_arch $build_host]" == "lx24-amd64" } {
              set hosts(lx26_amd64) 0
	   }
	   if { "[host_conf_get_arch $build_host]" == "lx24-x86" } {
              set hosts(lx26_x86) 0
	   }
	      
   }
   # here we do the native build things (all hosts without java build host) ...
   foreach build_host $compile_hosts {
      if { $build_host != $java_build_host } {
	 if { "[host_conf_get_arch $build_host]" == "lx26-amd64" && $hosts(lx26_amd64) == 0 } {
	    puts $CHECK_OUTPUT "Skipping build on \"$build_host\" ..."
	       } elseif { "[host_conf_get_arch $build_host]" == "lx26-x86" && $hosts(lx26_x86) == 0 } {
		   puts $CHECK_OUTPUT "Skipping build on \"$build_host\" ..."
	       } else {
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

   # here we parse our properties files
   parse_bundle_properties_files $hedeby_config(hedeby_source_dir)
   return 0
}


#****** checktree_hedeby/hedeby_compile_clean() ***************************************
#  NAME
#     hedeby_compile_clean() -- compile clean hook for hedeby
#
#  SYNOPSIS
#     hedeby_compile_clean { compile_hosts a_report } 
#
#  FUNCTION
#     This hook is used by testsuite framework to cleanup the hedeby build.
#
#  INPUTS
#     compile_hosts - hosts for which the build should be cleaned. Currently
#                     not used (hedeby clean target currently cleans all).
#     a_report      - name of a report variable where reports should be
#                     written in (see report_XXXXXX procedures)
#
#  RESULT
#     0 - on success
#    -1 - on error
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#     checktree_hedeby/create_testsuite_properties_file()
#*******************************************************************************
proc hedeby_compile_clean { compile_hosts a_report } {
   global CHECK_OUTPUT 
   upvar $a_report report

   set java_build_host [host_conf_get_java_compile_host]
   puts $CHECK_OUTPUT "java build host is \"$java_build_host\""

   set ret [hedeby_build $java_build_host "clean" report]
   puts $CHECK_OUTPUT "compile clean for hedeby done. Result: \"$ret\"" 
   return $ret
}



#****** checktree_hedeby/hedeby_build() ***********************************************
#  NAME
#     hedeby_build() -- helper procedure to call ant build targets
#
#  SYNOPSIS
#     hedeby_build { build_host target a_report { ant_options "" } 
#     { hedeby_build_timeout 300 } } 
#
#  FUNCTION
#     This procedure is used to start an ant target on the specified build
#     host and create reports for it.
#
#  INPUTS
#     build_host                   - the host where the ant target should be
#                                    started
#     target                       - the name of the ant target
#     a_report  - name of a report array where messages and infos should be
#                 printed (see report_XXXXXX procedures)
#     { ant_options "" }           - optional ant options (default "")
#     { hedeby_build_timeout 300 } - build timeout value (default 300 sec)
#     { hedeby_source "" }         - choose the directory with sources which should be built
#                                    by default the $hedeby_config(hedeby_source_dir) value is taken
#
#  RESULT
#     0 - on success
#    -1 - on error
#
#  SEE ALSO
#     checktree_hedeby/hedeby_compile()
#*******************************************************************************
proc hedeby_build { build_host target a_report { ant_options "" } { hedeby_build_timeout 300 } { hedeby_source "" } } {
   global CHECK_OUTPUT CHECK_USER
   global CHECK_HTML_DIRECTORY CHECK_PROTOCOL_DIR
   global ts_host_config hedeby_config
   global ts_config
   upvar $a_report report

   set property_file "build_testsuite.properties"
   if { "$hedeby_source" == "" } {
      set hedeby_source $hedeby_config(hedeby_source_dir)
    }
   set property_path $hedeby_source/$property_file

   if { [create_testsuite_properties_file $property_path $build_host] != 0 } {
      return -1
   }
   puts $CHECK_OUTPUT "starting $build_host:ant $target $ant_options in dir $hedeby_source"
   
   set task_nr [report_create_task report "hedeby_build_$target" $build_host]
   
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "-> starting hedeby ant $target on host $build_host ..."
  
   set env(JAVA_HOME) [get_java_home_for_host $build_host $hedeby_config(hedeby_java_version)]
   
   if { $env(JAVA_HOME) == "" } {
      report_task_add_message report $task_nr "Error: hededy build requires java $hedeby_config(hedeby_java_version). It is not available on host $build_host"
      report_finish_task report $task_nr -1
      return -1
   }
   
   set env(ARCH)      [resolve_arch $build_host]
   
   # Due to some limitation in ant junit.jar must be available in the
   # classpath before starting ant
   set junit_classpath ""
   
   # Iterate over all build property files. The order is important
   foreach prop_file { build_testsuite.properties build_private.properties build.properties } { 
      set output [start_remote_prog $build_host $CHECK_USER \
                      "grep" "'libs.junit.classpath=' $hedeby_source/$prop_file"]
      if {$prg_exit_state == 0} {
         foreach line [split $output "\r\n"] {
            # this following regular expression matches against all lines containing
            # libs.junit.classpath
            # lines starting with a '#' are omitted. Whitespaces around  '=', at the beginning and
            # at the end of the line are allowed.
            # The regexp contains a caputure for the value of the property. It is returned in the
            # variable path
            if {[regexp "^\\s*libs.junit.classpath\\s*=\\s*(\\S+)\\s*\$" $line res path] == 1} {
               ts_log_finer "found junit classpath in $prop_file ($path)"
               set junit_classpath $path
            }
         }
         if { $junit_classpath != "" } {
            break
         }
      }
   }
   
   if { $junit_classpath != "" } {
      set env(CLASSPATH) "$junit_classpath"
   }

   report_task_add_message report $task_nr "using JAVA_HOME = $env(JAVA_HOME)"
   report_task_add_message report $task_nr "using ARCH = $env(ARCH)"

   if { [string length ant_options] > 0 } {
      set env(ANT_OPTS) "$ant_options"
      report_task_add_message report $task_nr "using ANT_OPTS = $env(ANT_OPTS)"
   }

   set open_spawn [ open_remote_spawn_process $build_host $CHECK_USER "ant" "$target" 0 "$hedeby_source" env]
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
         report_task_add_message report $task_nr "cd $hedeby_source; ./build.sh $target"
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

   delete_remote_file $build_host $CHECK_USER $property_path

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
#****** checktree_hedeby/hedeby_save_configuration() **********************************
#  NAME
#     hedeby_save_configuration() -- hook for saving hedeby configuration
#
#  SYNOPSIS
#     hedeby_save_configuration { filename } 
#
#  FUNCTION
#     This testsuite hook is used to save the hedeby configuration in the testsuite
#     framework (menu 26) after the hedeby configuration settings was done. 
#
#  INPUTS
#     filename - filename of configuration
#
#  RESULT
#     0 - on success
#    -1 - on error
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#*******************************************************************************
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

#****** checktree_hedeby/config_hedeby_product_root() *********************************
#  NAME
#     config_hedeby_product_root() -- configure procedure for "hedeby_product_root"
#
#  SYNOPSIS
#     config_hedeby_product_root { only_check name config_array } 
#
#  FUNCTION
#     Used by testsuite configuration framework to setup the 
#     hedeby_config(hedeby_product_root) parameter
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  SEE ALSO
#     config/config_generic()
#     checktree_hedeby/config_hedeby_product_root()
#     checktree_hedeby/config_hedeby_source_dir()
#     checktree_hedeby/config_hedeby_master_host()
#     checktree_hedeby/config_hedeby_cs_port()
#     checktree_hedeby/config_hedeby_user_jvm_port()
#     checktree_hedeby/config_hedeby_host_resources()
#     checktree_hedeby/config_hedeby_source_cvs_release()
#*******************************************************************************
proc config_hedeby_product_root { only_check name config_array } {
   global fast_setup
   upvar $config_array config
   
   set help_text { "Enter the path where the testsuite should install Hedeby,"
                   "or press >RETURN< to use the default value." 
                   "WARNING: The compile option will remove the content of this directory" 
                   "or store it to \"testsuite_trash\" directory with testsuite_trash commandline option!!!" }
 
   set value [config_generic $only_check $name config $help_text "directory" 0]

   if {$value == -1 } { return -1 }

   if {!$fast_setup} {
      # to be able to find processes with ps command, don't allow to long
      # directory path:
      set add_path "/bin/sol-sparc64/abcdef"
      set path_length [ string length $add_path ]
      if { [string length "$value/$add_path"] > 60 } {
           puts "path for hedeby dist directory is too long (must be <= [expr ( 60 - $path_length )] chars)"
           puts "The testsuite tries to find processes via ps output most ps output is truncated"
           puts "for longer lines."
           return -1
      }
   }
   return $value
}

#****** checktree_hedeby/config_hedeby_source_dir() *********************************
#  NAME
#     config_hedeby_source_dir() -- configure procedure for "hedeby_source_dir"
#
#  SYNOPSIS
#     config_hedeby_source_dir { only_check name config_array } 
#
#  FUNCTION
#     Used by testsuite configuration framework to setup the 
#     hedeby_config(hedeby_source_dir) parameter
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  SEE ALSO
#     config/config_generic()
#     checktree_hedeby/config_hedeby_product_root()
#     checktree_hedeby/config_hedeby_source_dir()
#     checktree_hedeby/config_hedeby_master_host()
#     checktree_hedeby/config_hedeby_cs_port()
#     checktree_hedeby/config_hedeby_user_jvm_port()
#     checktree_hedeby/config_hedeby_host_resources()
#     checktree_hedeby/config_hedeby_source_cvs_release()
#*******************************************************************************
proc config_hedeby_source_dir { only_check name config_array } {

   upvar $config_array config

   set help_text { "Enter the full path to Hedeby source directory." }

   return [config_generic $only_check $name config $help_text "directory" 0]   
}

#****** checktree_hedeby/config_hedeby_master_host() **********************************
#  NAME
#     config_hedeby_master_host() -- configure procedure for "hedeby_master_host"
#
#  SYNOPSIS
#     config_hedeby_master_host { only_check name config_array } 
#
#  FUNCTION
#     Used by testsuite configuration framework to setup the 
#     hedeby_config(hedeby_master_host) parameter
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  SEE ALSO
#     config/config_generic()
#     checktree_hedeby/config_hedeby_product_root()
#     checktree_hedeby/config_hedeby_source_dir()
#     checktree_hedeby/config_hedeby_master_host()
#     checktree_hedeby/config_hedeby_cs_port()
#     checktree_hedeby/config_hedeby_user_jvm_port()
#     checktree_hedeby/config_hedeby_host_resources()
#     checktree_hedeby/config_hedeby_source_cvs_release()
#*******************************************************************************
proc config_hedeby_master_host { only_check name config_array } {
   global ts_host_config

   upvar $config_array config

   set help_text { "Select the host where the testsuite should install"
                   "the hedeby master host components. The testsuite will"
                   "install the config center, config service, CA component"
                   "and the resource provider on this host."
                   "NOTE: The testsuite is checking that the hedeby master"
                   "      components are not installed on a grid engine"
                   "      qmaster host to enhance test quality!" }

   array set params {}
   set params(exclude_list) [get_all_qmaster_hosts]
   set params(verify) "compile"

   return [config_generic $only_check $name config $help_text "host" 0 1 "" params ]
}

#****** checktree_hedeby/config_hedeby_cs_port() *********************************
#  NAME
#     config_hedeby_cs_port() -- configure procedure for "hedeby_cs_port"
#
#  SYNOPSIS
#     config_hedeby_cs_port { only_check name config_array } 
#
#  FUNCTION
#     Used by testsuite configuration framework to setup the 
#     hedeby_config(hedeby_cs_port) parameter
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  SEE ALSO
#     config/config_generic()
#     checktree_hedeby/config_hedeby_product_root()
#     checktree_hedeby/config_hedeby_source_dir()
#     checktree_hedeby/config_hedeby_master_host()
#     checktree_hedeby/config_hedeby_cs_port()
#     checktree_hedeby/config_hedeby_user_jvm_port()
#     checktree_hedeby/config_hedeby_host_resources()
#     checktree_hedeby/config_hedeby_source_cvs_release()
#*******************************************************************************
proc config_hedeby_cs_port { only_check name config_array } {

   upvar $config_array config

   set help_text { "Enter the port number value the testsuite should use"
                   "for the Configuraiton Service." }

   array set params {}

   set exclude [get_all_reserved_ports]
   lappend exclude $config(hedeby_user_jvm_port)
   set params(exclude_list) $exclude

   return [config_generic $only_check $name config $help_text "port" 0 1 "" params]
}

#****** checktree_hedeby/config_hedeby_user_jvm_port() *********************************
#  NAME
#     config_hedeby_user_jvm_port() -- configure procedure for "hedeby_user_jvm_port"
#
#  SYNOPSIS
#     config_hedeby_user_jvm_port { only_check name config_array } 
#
#  FUNCTION
#     Used by testsuite configuration framework to setup the 
#     hedeby_config(hedeby_user_jvm_port) parameter
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  SEE ALSO
#     config/config_generic()
#     checktree_hedeby/config_hedeby_product_root()
#     checktree_hedeby/config_hedeby_source_dir()
#     checktree_hedeby/config_hedeby_master_host()
#     checktree_hedeby/config_hedeby_cs_port()
#     checktree_hedeby/config_hedeby_user_jvm_port()
#     checktree_hedeby/config_hedeby_host_resources()
#     checktree_hedeby/config_hedeby_source_cvs_release()
#*******************************************************************************
proc config_hedeby_user_jvm_port { only_check name config_array } {

   upvar $config_array config

   set help_text { "Enter the port number value the testsuite should use"
                   "for components which are started in the $CHECK_USER JVM."
                   "or press >RETURN< to use the default value." }

   array set params {}
   set exclude [get_all_reserved_ports]
   lappend exclude $config(hedeby_cs_port)
   set params(exclude_list) $exclude

   return [config_generic $only_check $name config $help_text "port" 1 1 "" params]

}

#****** checktree_hedeby/config_hedeby_host_resources() *********************************
#  NAME
#     config_hedeby_host_resources() -- configure procedure for "hedeby_host_resources"
#
#  SYNOPSIS
#     config_hedeby_host_resources { only_check name config_array } 
#
#  FUNCTION
#     Used by testsuite configuration framework to setup the 
#     hedeby_config(hedeby_host_resources) parameter
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  SEE ALSO
#     config/config_generic()
#     checktree_hedeby/config_hedeby_product_root()
#     checktree_hedeby/config_hedeby_source_dir()
#     checktree_hedeby/config_hedeby_master_host()
#     checktree_hedeby/config_hedeby_cs_port()
#     checktree_hedeby/config_hedeby_user_jvm_port()
#     checktree_hedeby/config_hedeby_host_resources()
#     checktree_hedeby/config_hedeby_source_cvs_release()
#*******************************************************************************
proc config_hedeby_host_resources { only_check name config_array } {
   global ts_host_config

   upvar $config_array config

   set help_text { "Select the host which should be used as free assignable"
                   "host resources. On host resources the testsuite will install"
                   "the remote CA and and Executor component."
                   "NOTE: The testsuite is checking that no free assignable"
                   "      resource is specified as execd host in any gridengine"
                   "      cluster. These resources are statically assigned to their"
                   "      service." }

   array set params {}
   set params(exclude_list) [get_all_execd_nodes]
   set params(verify) "compile"

   return [config_generic $only_check $name config $help_text "host" 0 "2+" "" params]
}

#****** checktree_hedeby/config_security_disable() ************************************
#  NAME
#     config_security_disable() -- configure procedure for "security_disable"
#
#  SYNOPSIS
#     config_security_disable { only_check name config_array } 
#
#  FUNCTION
#     Used by testsuite configuration framework to setup the 
#     hedeby_config(security_disable) parameter
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  SEE ALSO
#     config/config_generic()
#     checktree_hedeby/config_hedeby_product_root()
#     checktree_hedeby/config_hedeby_source_dir()
#     checktree_hedeby/config_hedeby_master_host()
#     checktree_hedeby/config_hedeby_cs_port()
#     checktree_hedeby/config_hedeby_user_jvm_port()
#     checktree_hedeby/config_hedeby_host_resources()
#     checktree_hedeby/config_hedeby_source_cvs_release()
#     checktree_hedeby/config_security_disable()
#*******************************************************************************
proc config_security_disable { only_check name config_array } {
   global fast_setup

   upvar $config_array config

   array set security_disable {
      "true"  "Install hedeby without security"
      "false" "Install hedeby in secure mode (default)"
   }
   set value [config_generic $only_check $name config "" "choice" 0 1 security_disable]

   if {!$fast_setup} {
      if { $value == "true" } {
         ts_log_warning "Testsuite will install hedeby NOT in security mode!!!"  
      }
   }
   return $value
}

#****** checktree_hedeby/config_preferences_mode() ************************************
#  NAME
#     config_preferences_mode() -- configure procedure for "preferences_mode"
#
#  SYNOPSIS
#     config_preferences_mode { only_check name config_array } 
#
#  FUNCTION
#     Used by testsuite configuration framework to setup the 
#     hedeby_config(preferences_mode) parameter
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  SEE ALSO
#     config/config_generic()
#     checktree_hedeby/config_hedeby_product_root()
#     checktree_hedeby/config_hedeby_source_dir()
#     checktree_hedeby/config_hedeby_master_host()
#     checktree_hedeby/config_hedeby_cs_port()
#     checktree_hedeby/config_hedeby_user_jvm_port()
#     checktree_hedeby/config_hedeby_host_resources()
#     checktree_hedeby/config_hedeby_source_cvs_release()
#*******************************************************************************
proc config_preferences_mode { only_check name config_array } {
   global fast_setup

   upvar $config_array config

   set help_text { "Choose the preferences which should hedeby use to store"
                   "bootstrap information." }
   array set modes {
      "system" "system preferences (root access required)"
      "user" "user preferences"
   }
   set value [config_generic $only_check $name config $help_text "choice" 0 1 modes]

   if { !$fast_setup && [string compare $value "user"] == 0 } {
      ts_log_warning "Testsuite will use \"user\" preferences for storing"
   }

   return $value
}

#****** checktree_hedeby/config_hedeby_source_cvs_release() *********************************
#  NAME
#     config_hedeby_source_cvs_release() -- configure procedure for "hedeby_source_cvs_release"
#
#  SYNOPSIS
#     config_hedeby_source_cvs_release { only_check name config_array } 
#
#  FUNCTION
#     Used by testsuite configuration framework to setup the 
#     hedeby_config(hedeby_source_cvs_release) parameter
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  SEE ALSO
#     config/config_generic()
#     checktree_hedeby/config_hedeby_product_root()
#     checktree_hedeby/config_hedeby_source_dir()
#     checktree_hedeby/config_hedeby_master_host()
#     checktree_hedeby/config_hedeby_cs_port()
#     checktree_hedeby/config_hedeby_user_jvm_port()
#     checktree_hedeby/config_hedeby_host_resources()
#     checktree_hedeby/config_hedeby_source_cvs_release()
#*******************************************************************************
proc config_hedeby_source_cvs_release { only_check name config_array } {
   global fast_setup CHECK_USER ts_config

   upvar $config_array config

   array set tags {}

   if {[file isdirectory $config(hedeby_source_dir)]} {
      set cvs_tag [start_remote_prog $ts_config(source_cvs_hostname) $CHECK_USER "cat" "$config(hedeby_source_dir)/CVS/Tag" prg_exit_state 60 0 "" "" 1 0]
      set cvs_tag [string trim $cvs_tag]
      set tag "maintrunk"
      if {$prg_exit_state == 0} {
         if {[string first "T" $cvs_tag] == 0} {
            set tag [string range $cvs_tag 1 end]
         }
      }
      set config($name,default) $tag
      set tags($tag) ""
   }

   set help_text { "Enter cvs release tag of Hedeby source, or press >RETURN<"
                   "to use the default value."
                   "\"maintrunk\" specifies no tag or press " }
 
   set value [config_generic $only_check $name config $help_text "choice" 0 1 tags ]

   if { $only_check == 0 } {
      puts "INFO: Testsuite internal hedeby version id: \"[hedeby_get_version $value]\""
   }

   if {![file isdirectory $config(hedeby_source_dir)]} {
      puts "source directory $config(hedeby_source_dir) doesn't exist!!!"
   }

   return $value
}

#****** checktree_hedeby/config_hedeby_java_version() *********************************
#  NAME
#     config_hedeby_java_version() -- configure procedure for "hedeby_java_version"
#
#  SYNOPSIS
#     config_hedeby_java_version { only_check name config_array } 
#
#  FUNCTION
#     Used by testsuite configuration framework to setup the 
#     hedeby_config(hedeby_java_version) parameter
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  SEE ALSO
#     config/config_generic()
#*******************************************************************************
proc config_hedeby_java_version { only_check name config_array } {

   upvar $config_array config

   array set versions {
      "1.5" "Java SE 5"
      "1.6" "Java SE 6"
   }
   return [config_generic $only_check $name config "" "choice" 0 1 versions]
}

#****** checktree_hedeby/hedeby_get_version() *****************************************
#  NAME
#     hedeby_get_version() -- returns the testsuite internal version id of build
#
#  SYNOPSIS
#     hedeby_get_version { { cvstagname "" } } 
#
#  FUNCTION
#     Returns the internal testsuite version number of the hedeby source code. This
#     might be used to create version depended tests.
#
#  INPUTS
#     { cvstagname "" } - if not set to "" the version number for this cvs tag
#                         is returned
#
#  RESULT
#     string containing the internal testsuite version
#
#*******************************************************************************
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


#****** checktree_hedeby/hedeby_init_config() *****************************************
#  NAME
#     hedeby_init_config() -- init configuration hook for hedeby
#
#  SYNOPSIS
#     hedeby_init_config { config_array } 
#
#  FUNCTION
#     This hook is used to create a hedeby configuration array for the hedeby system.
#     All hedeby configuration parameters from hedeby_config have to be defined here.
#
#  INPUTS
#     config_array - the array where the configuration values should be stored
#
#  RESULT
#     none
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#*******************************************************************************
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


#****** checktree_hedeby/hedeby_verify_config() ***************************************
#  NAME
#     hedeby_verify_config() -- verify function hook for testsuite integration
#
#  SYNOPSIS
#     hedeby_verify_config { config_array only_check parameter_error_list } 
#
#  FUNCTION
#     This procedure is called from the testsuite framework to verify the hedeby
#     testsuite configuration.
# 
#     After verifying the hedeby_config the bundle_cache is re-created by reading
#     the bundle_cache file from the results directory. The bundle cache file
#     is re-created and spooled to disk every time the hedeby sources are builded.
#
#  INPUTS
#     config_array         - tcl array containing the hedeby configuration to be
#                            verified
#     only_check           - if only_check is not 0 no modifications are possible
#     parameter_error_list - used to identify errors and contains verify errors
#                            after the verification
#
#  RESULT
#     0 - on success
#    -1 - on error
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#     util/read_bundle_properties_cache()
#     checktree_hedeby/hedeby_compile()
#*******************************************************************************
proc hedeby_verify_config { config_array only_check parameter_error_list } {
   global ts_checktree hedeby_checktree_nr CHECK_OUTPUT hedeby_enhanced_config
   global CHECK_DEFAULTS_FILE
   global ts_config
   global hedeby_required_host_cache

   upvar $config_array config
   upvar $parameter_error_list param_error_list

   hedeby_config_upgrade_1_1 config
   hedeby_config_upgrade_1_2 config
   hedeby_config_upgrade_1_3 config

   # unset required host cache when verify config is called
   if {[info exists hedeby_required_host_cache]} {
      unset hedeby_required_host_cache
   }


   
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

      # TODO: This might be removed if GE installation creates keystores for default installation (1/2)
      if { $ts_config(jmx_ssl) != "true" } {
         puts $CHECK_OUTPUT "Need enabled jmx_ssl option for GE installation!"
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

   set error_text ""
   # now check for hedeby resource hosts to be in compile host list of addition clusters
   set master_host_list {}
   set execd_host_list {}
   set compile_archs_from_additional_cell {}
   set config_nr 1
   foreach filename $ts_config(additional_config) {
      set cl_type [get_additional_cluster_type $filename add_config]
      # check 1:
      # ========
      # master hosts must be uniq, we don't allow running more than one qmaster on a host ...
      set cur_master_host $add_config(master_host)
      if {[lsearch -exact $master_host_list $cur_master_host] >= 0} {
         append error_text "qmaster host \"$cur_master_host\" already defined for different cluster!\n => cur. config: $filename\n"
      }
      lappend master_host_list $cur_master_host
      set arch [resolve_arch $cur_master_host]
      ts_log_fine "master of config#$config_nr: \"$cur_master_host\" (arch=\"$arch\")"
      if {$cl_type == "cell"} {
         #archs from cell clusters are availabe for this cluster!
         lappend compile_archs_from_additional_cell $arch
      }

      
      # check 2:
      # ========
      # we also don't allow more than 1 execd on a host ...
      foreach execd $add_config(execd_hosts) {
         if {[lsearch -exact $execd_host_list $execd] >= 0} {
            append error_text "execd host \"$execd\" already defined for different cluster!\n => cur. config: $filename\n"
         }
         lappend execd_host_list $execd
         set arch [resolve_arch $execd]
         ts_log_fine "execd of config#$config_nr: \"$execd\" (arch=\"$arch\")"
         if {$cl_type == "cell"} {
            #archs from cell clusters are availabe for this cluster!
            lappend compile_archs_from_additional_cell $arch
         }
      }
      # check 3:
      # ========
      # check that add_config(jmx_ssl) is enabled (true)
      # TODO: This might be removed if GE installation creates keystores for default installation (2/2)
      if { $add_config(jmx_ssl) != "true" } {
         append error_text "jmx_ssl must be set to \"true\"!\n => cur. config: $filename\n"
      }
      incr config_nr 1
   }

   ts_log_fine "masters: $master_host_list"
   ts_log_fine "execds: $execd_host_list"

   
   # all hedeby resource archs must be compiled
   set expect_resource_archs {}
   foreach h_host $config(hedeby_host_resources) {
      set arch [resolve_arch $h_host]
      lappend expect_resource_archs $arch
      ts_log_fine "arch for hedeby resource \"$h_host\": \"$arch\""
   }
   # all execd archs must be compiled
   foreach h_host $execd_host_list {
      # but not the master hosts
      if {[lsearch -exact $master_host_list $h_host] >= 0} {
         ts_log_fine "skip master host \"$h_host\" arch \"[resolve_arch $h_host]\""
         continue
      } else {
         ts_log_fine "add expected host \"$h_host\" arch \"[resolve_arch $h_host]\""
         lappend  expect_resource_archs [resolve_arch $h_host]
      }
   }

   ts_log_fine "expected resource architectures for all clusters: $expect_resource_archs"

   # check that all archs are also compiled for this config (1/5)
   set this_cluster_hosts {}
   foreach param "master_host execd_hosts shadowd_hosts submit_only_hosts bdb_server" {
      if { $ts_config($param) != "none" } {
         append this_cluster_hosts " $ts_config($param)"
      }
   }
   # resolve all archs for this config (2/5)
   set this_compile_arch_list {}
   foreach host $this_cluster_hosts {
      set arch [resolve_arch $host]
      if { [lsearch -exact $this_compile_arch_list $arch] < 0 } {
         lappend this_compile_arch_list $arch
      }
   }
   # add forced this compile archs (3/5)
   foreach compile_arch $ts_config(add_compile_archs) {
      if { $compile_arch != "none" } {
         if { [lsearch -exact $this_compile_arch_list $compile_arch] < 0 } {
            lappend this_compile_arch_list $compile_arch 
         }
      }
   }
   # add archs from 
   foreach arch $compile_archs_from_additional_cell {
      lappend this_compile_arch_list $arch
   }

   # finally check that all archs are available for this cluster (5/5)
   set missing_archs {}
   foreach harch $expect_resource_archs {
      if { [lsearch -exact $this_compile_arch_list $harch] < 0 } {
         lappend missing_archs $harch
      }
   }
   # we have missing architectures, report error
   if { [llength $missing_archs] > 0 } {
      append error_text "This cluster configuration has missing compile architectures which are defined in additional clusters!\n"
      append error_text "Missing compile architecutes are \"$missing_archs\"\n"
   }
   
   foreach filename $ts_config(additional_config) {
      set cl_type [get_additional_cluster_type $filename add_config]
      
      # checks for independent configuration (with different SGE_ROOT) ...
      # ==================================================================
      if { $cl_type == "independent" } {

         # check 1:
         # ========
         # get all required and used hosts ...
         set independent_used_hosts {}
         ts_log_finer "checking that remote cluster config $filename has all hedeby resource architectures ..."
         foreach param "master_host execd_hosts shadowd_hosts submit_only_hosts bdb_server" {
            if { $add_config($param) != "none" } {
               append independent_used_hosts " $add_config($param)"
            }
         }
         ts_log_finer "following hosts are used: $independent_used_hosts"

         # now we have the hosts, here we get the architectures ...
         set independent_compile_arch_list {}
         foreach host $independent_used_hosts {
            set iarch [resolve_arch $host]
            if { [lsearch -exact $independent_compile_arch_list $iarch] < 0 } {
               lappend independent_compile_arch_list $iarch
            }
         }
           
         # now we add the required compile architectures for this independet cluster ...
         foreach compile_arch $add_config(add_compile_archs) {
            if { $compile_arch != "none" } {
               if { [lsearch -exact $independent_compile_arch_list $compile_arch] < 0 } {
                  ts_log_fine "adding forced compile arch \"$compile_arch\" to list"
                  lappend independent_compile_arch_list $compile_arch 
               }
            }
         }
         # here we have all the archs that are compiled for the independent cluster!
         ts_log_finer "following architectures are compiled: $independent_compile_arch_list"

         # now we check if all hedeby_host_resources are compiled for this cluster ...
         set missing_archs {}
         foreach harch $expect_resource_archs {
            if { [lsearch -exact $independent_compile_arch_list $harch] < 0 } {
               lappend missing_archs $harch
            }
         }

         # we have missing architectures, report error
         if { [llength $missing_archs] > 0 } {
            append error_text "additional cluster configuration \"$filename\"\n"
            append error_text "has missing compile architecutes: \"$missing_archs\"\n"
         }
      }
   }

   # here we have a complete list of execds check that no arch is missing in all clusters



   if { $error_text != "" } {
      set full_error_text "==> Hedeby does require to have following resource architectures compiled:\n$expect_resource_archs\n"
      append full_error_text $error_text
      ts_log_config $full_error_text
      return -1
   }


   # further global checks
   # =====================


   # now check that every host has a local spool directory
   foreach host [hedeby_get_all_hosts] {
      set spool_dir [get_local_spool_dir $host "" 0]
      puts $CHECK_OUTPUT "local testsuite spooldir for host \"$host\": \"$spool_dir\""
      if { $spool_dir == "" } {
         puts $CHECK_OUTPUT "local spool directory on host \"$host\" is not set!\n"
         puts $CHECK_OUTPUT "Hedeby requires to have a local spool directory for each host!\n"
         return -1
      }
   }

   read_bundle_properties_cache

   return $retval
}



#****** checktree_hedeby/hedeby_get_all_hosts() ***************************************
#  NAME
#     hedeby_get_all_hosts() -- get all hosts used for hedeby
#
#  SYNOPSIS
#     hedeby_get_all_hosts { } 
#
#  FUNCTION
#     Returns all hosts which are used for the hedeby setup. The returned
#     list contains all qmaster hosts, execd hosts, etc. from the additional
#     cluster configurations, the hedeby managed hosts and hedeby master hosts.
#
#  INPUTS
#
#  RESULT
#     list with uniq host entries 
#
#  SEE ALSO
#     checktree_hedeby/hedeby_get_all_hosts()
#*******************************************************************************
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

#****** checktree_hedeby/hedeby_get_required_hosts() **********************************
#  NAME
#     hedeby_get_required_hosts() -- required hosts hook for hedeby
#
#  SYNOPSIS
#     hedeby_get_required_hosts { } 
#
#  FUNCTION
#     The testsuite framework script is calling this procedure to find out which 
#     hosts are used be hedeby to find out which architectures have to be compiled
#     for the gridengine clusters.
#
#  INPUTS
#
#  RESULT
#     list of required (used) host
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#*******************************************************************************

# this is to delete required host cache if file is re-sourced
global hedeby_required_host_cache
if {[info exists hedeby_required_host_cache]} {
   unset hedeby_required_host_cache
}
proc hedeby_get_required_hosts {} {
   global hedeby_config CHECK_OUTPUT
   global hedeby_enhanced_config
   global hedeby_required_host_cache
   set enhanced_res {}

   if {[info exists hedeby_required_host_cache]} {
      ts_log_fine "returning required hosts from cache!"
      ts_log_fine "required hosts are: $hedeby_required_host_cache"
      return $hedeby_required_host_cache
   }

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
               unset hedeby_required_host_cache
               return -1
            }
         }

      }
   }   
   puts $CHECK_OUTPUT "Required hosts for hedeby: $res"
   set hedeby_required_host_cache $res
   return $res
}

#****** checktree/hedeby_get_required_ports() **********************************
#  NAME
#     hedeby_get_required_ports() -- get configured ports for hedeby
#
#  SYNOPSIS
#     hedeby_get_required_ports { } 
#
#  FUNCTION
#     This procedure returns a list of ports which are used by the current
#     hedeby configuration: CS port, ports for the Jvms. 
#
#  INPUTS
#
#  RESULT
#     TCL list with port numbers
#
#  NOTES
#     The hedeby configuration must be enhanced to support individual ports
#     for executor_vm and rp_vm.
#
#  BUGS
#     Currently only CS Port and the (not used) hedeby_user_jvm_port from the
#     hedeby configuration is returned.
#*******************************************************************************
proc hedeby_get_required_ports {} {
   global hedeby_config
   global CHECK_OUTPUT

   set portlist {}
   lappend portlist $hedeby_config(hedeby_cs_port)
   lappend portlist $hedeby_config(hedeby_user_jvm_port)

   puts $CHECK_OUTPUT "Required ports for hedeby: $portlist"
   return $portlist
}

#****** checktree_hedeby/hedeby_get_required_passwords() ******************************
#  NAME
#     hedeby_get_required_passwords() -- password hook for hedeby
#
#  SYNOPSIS
#     hedeby_get_required_passwords { } 
#
#  FUNCTION
#     Called by testsuite framework to set all passwords (call to set_passwd)
#     for needed hedeby user passwords
#
#  INPUTS
#
#  RESULT
#     0 - on success
#    -1 - on error
#
#  NOTES
#     currently not implemented
#
#  SEE ALSO
#     checktree_hedeby/hedeby_startup()
#     checktree_hedeby/hedeby_shutdown()
#     checktree_hedeby/hedeby_checktree_clean()
#     checktree_hedeby/hedeby_install_binaries()
#     checktree_hedeby/hedeby_compile_clean()
#     checktree_hedeby/hedeby_compile()
#     checktree_hedeby/hedeby_save_configuration()
#     checktree_hedeby/hedeby_init_config()
#     checktree_hedeby/hedeby_get_required_hosts()
#     checktree_hedeby/hedeby_get_required_passwords()
#*******************************************************************************
proc hedeby_get_required_passwords {} {
   global hedeby_config CHECK_OUTPUT
   puts $CHECK_OUTPUT "only standard testsuite users needed by hedeby"
   return 0
}


#****** checktree_hedeby/hedeby_config_upgrade_1_1() **********************************
#  NAME
#     hedeby_config_upgrade_1_1() -- upgrade procedure to version 1.1
#
#  SYNOPSIS
#     hedeby_config_upgrade_1_1 { config_array } 
#
#  FUNCTION
#     This procedure is used to update (if necessary) the hedeby configuration
#     version 1.0 to config version 1.1
#
#  INPUTS
#     config_array - current configuration 
#
#  RESULT
#     none
#*******************************************************************************
proc hedeby_config_upgrade_1_1 { config_array } {
   global CHECK_OUTPUT   

   upvar $config_array config

   if { $config(version) == "1.0" } {
      puts $CHECK_OUTPUT "Upgrade to version 1.1"
      # insert new parameter after hedeby_product_root
      set insert_pos $config(hedeby_product_root,pos)
      incr insert_pos 1
      
      # move positions of following parameters
      set names [array names config "*,pos"]
      foreach name $names {
         if { $config($name) >= $insert_pos } {
            set config($name) [ expr ( $config($name) + 1 ) ]
         }
      }
   
      # new parameter security_enabled
      set parameter "security_disable"
      set config($parameter)            ""
      set config($parameter,desc)       "Security disable parameter"
      set config($parameter,default)    "false"
      set config($parameter,setup_func) "config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos
   
      # now we have a configuration version 1.1
      set config(version) "1.1"
   }
}


#****** checktree_hedeby/hedeby_config_upgrade_1_2() **********************************
#  NAME
#     hedeby_config_upgrade_1_2() -- upgrade procedure to version 1.2
#
#  SYNOPSIS
#     hedeby_config_upgrade_1_2 { config_array } 
#
#  FUNCTION
#     This procedure is used to update (if necessary) the hedeby configuration
#     version 1.1 to config version 1.2
#
#  INPUTS
#     config_array - current configuration 
#
#  RESULT
#     none
#*******************************************************************************
proc hedeby_config_upgrade_1_2 { config_array } {
   global CHECK_OUTPUT   

   upvar $config_array config

   if { $config(version) == "1.1" } {
      puts $CHECK_OUTPUT "Upgrade to version 1.2"
      # insert new parameter after hedeby_product_root
      set insert_pos $config(security_disable,pos)
      incr insert_pos 1
      
      # move positions of following parameters
      set names [array names config "*,pos"]
      foreach name $names {
         if { $config($name) >= $insert_pos } {
            set config($name) [ expr ( $config($name) + 1 ) ]
         }
      }
   
      # new parameter security_enabled
      set parameter "preferences_mode"
      set config($parameter)            ""
      set config($parameter,desc)       "hedeby preferences location"
      set config($parameter,default)    "system"
      set config($parameter,setup_func) "config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos
   
      # now we have a configuration version 1.1
      set config(version) "1.2"
   }
}

#****** checktree_hedeby/hedeby_config_upgrade_1_3() **********************************
#  NAME
#     hedeby_config_upgrade_1_3() -- upgrade procedure to version 1.3
#
#  SYNOPSIS
#     hedeby_config_upgrade_1_3 { config_array } 
#
#  FUNCTION
#     This procedure is used to update (if necessary) the hedeby configuration
#     version 1.2 to config version 1.3
#
#  INPUTS
#     config_array - current configuration 
#
#  RESULT
#     none
#*******************************************************************************
proc hedeby_config_upgrade_1_3 { config_array } {
   global CHECK_OUTPUT   

   upvar $config_array config

   if { $config(version) == "1.2" } {
      puts $CHECK_OUTPUT "Upgrade to version 1.3"
      # insert new parameter after hedeby_product_root
      set insert_pos $config(hedeby_product_root,pos)
      incr insert_pos 1
      
      # move positions of following parameters
      set names [array names config "*,pos"]
      foreach name $names {
         if { $config($name) >= $insert_pos } {
            set config($name) [ expr ( $config($name) + 1 ) ]
         }
      }
   
      # new parameter security_enabled
      set parameter "hedeby_java_version"
      set config($parameter)            ""
      set config($parameter,desc)       "java version used for hedeby"
      set config($parameter,default)    "1.5"
      set config($parameter,setup_func) "config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos
   
      # now we have a configuration version 1.3
      set config(version) "1.3"
   }
}

