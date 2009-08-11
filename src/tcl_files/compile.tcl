#!/vol2/TCL_TK/glinux/bin/expect
# expect script 
# test SGE/SGEEE System
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

#****** compile/compile_check_compile_hosts() **********************************
#  NAME
#     compile_check_compile_hosts() -- check for suited compile host
#
#  SYNOPSIS
#     compile_check_compile_hosts { host_list } 
#
#  FUNCTION
#     Goes through the given host list and for every host checks,
#     if a compile host for the architecture of the host is defined
#     in the testsuite host configuration.
#
#  INPUTS
#     host_list - list of hosts to check
#
#  RESULT
#     0 - OK, compile hosts for all given hosts exist
#    -1 - at least for one host, no compile host is configured
#*******************************************************************************
proc compile_check_compile_hosts {host_list} {
   global ts_host_config ts_config


   # remember already resolved compile archs
   set compile_archs {}

   # check each host in host_list
   foreach host $host_list {
      if {![host_conf_is_supported_host $host]} {
         ts_log_severe "host $host is not contained in testsuite host configuration or not supported host!"
      } else {
         # host's architecture
         set arch [host_conf_get_arch $host]

         # do we already have a compile host for this arch?
         # if not, search it.
         if {[lsearch $compile_archs $arch] < 0} {
            if {[compile_search_compile_host $arch] != "none"} {
               lappend compile_archs $arch
            } else {
               return -1
            }
         }
      }
   }

   return 0
}


#****** compile/compile_host_list() ********************************************
#  NAME
#     compile_host_list() -- build compile host list
#
#  SYNOPSIS
#     compile_host_list { } 
#
#  FUNCTION
#     Builds a list of compile host for all the architectures that are 
#     required to install the configured test cluster.
#
#     Takes into account the
#     - master host
#     - execd hosts
#     - shadowd hosts
#     - submit only hosts
#     - berkeley db rpc server host
#     - additional config configurations
#
#  RESULT
#     list of compile hosts
#     in case of errors, an empty list is returned
#
#  SEE ALSO
#     compile/compile_search_compile_host()
#*******************************************************************************
proc compile_host_list {} {
   global ts_host_config
   global ts_config
  
   set submit_hosts {}
   if { $ts_config(submit_only_hosts) != "none" } {
      set submit_hosts $ts_config(submit_only_hosts)
   }
   
   # build host list according to cluster requirements
   set host_list [concat $ts_config(master_host) $ts_config(execd_hosts) \
                         $ts_config(shadowd_hosts) $submit_hosts \
                         $ts_config(bdb_server) \
                         [checktree_get_required_hosts]]

   # for additional configurations, we might have different architectures
   if {$ts_config(additional_config) != "none"} {
      foreach filename $ts_config(additional_config) {
         set cl_type [get_additional_cluster_type $filename add_config]

         if { $cl_type == "" } {
            continue
         }

         # check whether it is cell cluster or independed cluster
         if { $cl_type == "cell" } {
            ts_log_fine "adding hosts from additional cluster configuration file"
            ts_log_fine "$filename"
            ts_log_fine "to compile host list. This cluster will be installed as GE Cell!"
            foreach param "master_host execd_hosts shadowd_hosts submit_only_hosts bdb_server" {
               if { $add_config($param) != "none" } {
                  append host_list " $add_config($param)"
                  ts_log_fine "appending $param host \"$add_config($param)\""
               }
            }
         }
      }
   }

   # For SGE 6.0 we build the drmaa.jar on the java build host.
   # Beginning with SGE 6.1 we build java code on all platforms.
   # Add the java build host to the host list.
   if {$ts_config(gridengine_version) >= 60} {
      lappend host_list [host_conf_get_java_compile_host]
   }

   # remove duplicates from host_list
   set host_list [compile_unify_host_list $host_list]

   # find the compile hosts by architecture
   foreach host $host_list {
      set arch [host_conf_get_arch $host]
      if {$arch == ""} {
         ts_log_severe "Cannot determine the architecture of host $host"
         return {}
      }
      if {![info exists compile_host($arch)]} {
         set c_host [compile_search_compile_host $arch]
         if {$c_host == "none"} {
            ts_log_severe "Cannot determine a compile host for architecture $arch" 
            return {}
         } else {
            set compile_host($arch) $c_host
            lappend compile_host(list) $c_host
         }
      }
   }

   # The java compile host may not duplicate the build host for it's architecture, 
   # it must be also a c build host,
   # so it must be contained in the build host list.
   if {$ts_config(gridengine_version) >= 60} {
      set jc_host [host_conf_get_java_compile_host]
      set jc_arch [host_conf_get_arch $jc_host]

      if {$compile_host($jc_arch) != $jc_host} {
         ts_log_severe "the java compile host ($jc_host) has architecture $jc_arch\nbut compile host for architecture $jc_arch is $compile_host($jc_arch).\nJava and C compile must be done on the same host"
         return {}
      }
   }

   return [lsort -dictionary $compile_host(list)]
}


#****** compile/get_compile_options_string() ***********************************
#  NAME
#     get_compile_options_string() -- return current compile option string
#
#  SYNOPSIS
#     get_compile_options_string { } 
#
#  FUNCTION
#     This function returns a string containing the current set aimk compile
#     options
#
#  RESULT
#     string containing compile options
#*******************************************************************************
proc get_compile_options_string { } {
   global ts_config

   set options $ts_config(aimk_compile_options)

   if {$options == "none"} {
      set options ""
   }

   if {$options != ""} {
      ts_log_fine "compile options are: \"$options\""
   }

   return $options
}

#****** compile/compile_unify_host_list() **************************************
#  NAME
#     compile_unify_host_list() -- remove duplicates and "none" from list
#
#  SYNOPSIS
#     compile_unify_host_list { host_list } 
#
#  FUNCTION
#     Takes a hostlist and removes all duplicate entries as well as 
#     "none" entries from it.
#     The resulting list is sorted.
#
#  INPUTS
#     host_list - list containing duplicates
#
#  RESULT
#     unified and sorted list
#*******************************************************************************
proc compile_unify_host_list {host_list} {
   set new_host_list {}

   # go over input host list
   foreach host $host_list {
      # filter out "none" entries (coming from empty lists)
      if {$host != "none"} {
         # if we don't have this host in output list, append it
         if {[lsearch $new_host_list $host] < 0} {
            lappend new_host_list $host
         }
      }
   }

   # return sorted list
   return [lsort -dictionary $new_host_list]
}

#****** compile/compile_search_compile_host() **********************************
#  NAME
#     compile_search_compile_host() -- search compile host by architecture
#
#  SYNOPSIS
#     compile_search_compile_host { arch } 
#
#  FUNCTION
#     Search the testsuite host configuration for a compile host for a 
#     certain architecture.
#
#  INPUTS
#     arch - required architecture
#
#  RESULT
#     name of the compile host
#     "none", if no compile host for the given architecture is defined
#*******************************************************************************
proc compile_search_compile_host {arch} {
   global ts_host_config
   
   # special case for HP11-64: it is now compile host for HP11
   if { $arch == "hp11"} {
      set arch "hp11-64"
   }

   foreach host $ts_host_config(hostlist) {
      if {[host_conf_get_arch $host] == $arch && [host_conf_is_compile_host $host]} {
         return $host
      }
   }

   # no compile host found for this arch
   ts_log_warning "no compile host found for architecture $arch"
   return "none"
}


proc compile_rebuild_arch_cache { compile_hosts {al "arch_list"} } {
   upvar $al arch_list
   if { [info exists arch_list] } {
      unset arch_list
   }
   resolve_arch_clear_cache
   set arch_list {}
   set compiled_mail_architectures ""
   foreach elem $compile_hosts {
      set output [resolve_arch $elem 1]
      lappend arch_list $output 
      append compiled_mail_architectures "\n$elem ($output)"
   }
   ts_log_fine "architectures: $arch_list"
   return $compiled_mail_architectures
}

#****** compile/compile_depend() **************************************************
#  NAME
#    compile_depend() -- ???
#
#  SYNOPSIS
#    compile_depend { } 
#
#  FUNCTION
#     Executes scripts/zero-depend, aimk --only-depend and aimk depend
#     on a preferred compile host
#
#  INPUTS
#    compile_hosts -- list of compile hosts
#    a_html_body   -- html body buffer for reporting
#
#  RESULT
#     0  -  on success
#     -1 -  on failure
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc compile_depend { compile_hosts a_report do_clean } {
   global ts_host_config ts_config
   global CHECK_USER
   
   upvar $a_report report
 
   ts_log_fine "building dependencies ..."
 
   # we prefer building the dependencies on a sol-sparc64 host
   # to avoid automounter issues like having a heading /tmp_mnt in paths
   set depend_host_name [lindex $compile_hosts 0] 
   foreach help_host $compile_hosts {
      set help_arch [host_conf_get_arch $help_host]
      if { [ string compare $help_arch "solaris64"] == 0 || 
           [ string compare $help_arch "sol-sparc64"] == 0 } {
         ts_log_fine "using host $help_host to create dependencies"
         set depend_host_name $help_host
      }
   }

   set task_nr [report_create_task report "zerodepend" $depend_host_name]

   if {$ts_config(source_dir) == "none"} {
      report_task_add_message report $task_nr "source directory is set to \"none\" - cannot depend"
      report_finish_task report $task_nr -1
      return -1
   }
   
   # clean dependency files (zerodepend)
   
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "-> starting scripts/zerodepend on host $depend_host_name ..."
   set output [start_remote_prog $depend_host_name $CHECK_USER "scripts/zerodepend" "" prg_exit_state 60 0 $ts_config(source_dir) "" 1 0]
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "return state: $prg_exit_state"
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "output:\n$output"
   report_task_add_message report $task_nr "------------------------------------------"
   
   report_finish_task report $task_nr $prg_exit_state
   if { $prg_exit_state != 0 } {
      report_add_message report "------------------------------------------"
      report_add_message report "Error: scripts/zerodepend (exit code $prg_exit_state)"
      report_add_message report "------------------------------------------"
      return -1
   }
   

   if { $do_clean } {
      set task_nr [report_create_task report "only_depend_clean" $depend_host_name]
      # clean the depencency building program
      set my_compile_options [get_compile_options_string]
      report_task_add_message report $task_nr "-> starting aimk -only-depend clean on host $depend_host_name ..."

      set output [start_remote_prog $depend_host_name $CHECK_USER "./aimk" "-only-depend clean" prg_exit_state 60 0 $ts_config(source_dir) "" 1 0 ]
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "return state: $prg_exit_state"
      report_task_add_message report $task_nr "------------------------------------------"
      report_task_add_message report $task_nr "output:\n$output"
      report_task_add_message report $task_nr "------------------------------------------"
      report_finish_task report $task_nr $prg_exit_state
      if { $prg_exit_state != 0 } {
         report_add_message report "------------------------------------------"
         report_add_message report "Error: aimk -only-depend clean failed (exit code $prg_exit_state)"
         report_add_message report "------------------------------------------"
         return -1
      }
   }


   set task_nr [report_create_task report "only_depend" $depend_host_name]
   # build the depencency building program
   set my_compile_options [get_compile_options_string]
   report_task_add_message report $task_nr "-> starting aimk -only-depend on host $depend_host_name ..."

   set output [start_remote_prog $depend_host_name $CHECK_USER "./aimk" "-only-depend" prg_exit_state 60 0 $ts_config(source_dir) "" 1 0 ]
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "return state: $prg_exit_state"
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "output:\n$output"
   report_task_add_message report $task_nr "------------------------------------------"
   report_finish_task report $task_nr $prg_exit_state
   if { $prg_exit_state != 0 } {
      report_add_message report "------------------------------------------"
      report_add_message report "Error: aimk -only-depend failed (exit code $prg_exit_state)"
      report_add_message report "------------------------------------------"
      return -1
   }

   # build the dependencies
   set task_nr [report_create_task report "depend" $depend_host_name]
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "-> starting aimk $my_compile_options depend on host $depend_host_name ..."
   set output [start_remote_prog $depend_host_name $CHECK_USER "./aimk" "$my_compile_options depend" prg_exit_state 60 0 $ts_config(source_dir) "" 1 0]
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "return state: $prg_exit_state"
   report_task_add_message report $task_nr "------------------------------------------"
   report_task_add_message report $task_nr "output:\n$output"
   report_task_add_message report $task_nr "------------------------------------------"

   report_finish_task report $task_nr $prg_exit_state
   if { $prg_exit_state != 0 } {
      report_add_message report "------------------------------------------"
      report_add_message report "Error: aimk depend failed (exit code $prg_exit_state)"
      report_add_message report "------------------------------------------"
      return -1
   }

   return 0
}

#****** compile/wait_for_NFS_after_compile_clean() *****************************
#  NAME
#     wait_for_NFS_after_compile_clean() -- check compile arch dir after clean
#
#  SYNOPSIS
#     wait_for_NFS_after_compile_clean { host_list a_report } 
#
#  FUNCTION
#     This function checks if the compile arch directory is empty after a 
#     aimk clean. It also checks that the arch is empty on all used specified 
#     hosts.
#
#  INPUTS
#     host_list - list of compile hosts
#     a_report  - a report array
#
#  RESULT
#     1 on success, 0 on error
#*******************************************************************************
proc wait_for_NFS_after_compile_clean { host_list a_report } {
   global CHECK_USER
   upvar $a_report report
   get_current_cluster_config_array ts_config

   if {$ts_config(source_dir) == "none"} {
      ts_log_config "source directory is set to \"none\" - cannot check build dirs"
      return 0
   }

   ts_log_fine "verify compile_clean call ($host_list)..."

   set result 1
   foreach host $host_list {
      set task_nr [report_create_task report "verify compile clean" $host]
      set build_dir_name [resolve_build_arch $host]
      set wait_path  "$ts_config(source_dir)/$build_dir_name"
 
      ts_log_fine "wait path: $ts_config(source_dir)/$build_dir_name"
      set my_timeout [timestamp]
      incr my_timeout 10
      set was_error 1
      while { [timestamp] < $my_timeout } {
         analyze_directory_structure $host $CHECK_USER $wait_path "" files ""
         report_task_add_message report $task_nr "waiting for empty directory: $wait_path"
         if {[llength $files] == 0} {
            set was_error 0
            report_task_add_message report $task_nr "directory $wait_path contains no files! Good!"
            break
         }
         after 1000
         ts_log_washing_machine
      }
      if {$was_error == 1} {
         set error_text "Timout while waiting for build dir \"$wait_path\" containing no files.\n"
         foreach filen $files {
            append error_text "   found file: $filen\n"
         }
         ts_log_severe $error_text
         set result 0
         report_task_add_message report $task_nr $error_text
      }
      report_finish_task report $task_nr $was_error
   }
   return $result
}

#****** compile/compile_source() ***********************************************
#  NAME
#     compile_source() -- compile source code
#
#  SYNOPSIS
#     compile_source { { do_only_hooks 0} } 
#
#  FUNCTION
#     compile all source code
#
#  INPUTS
#     { do_only_hooks 0} - if set, only compile and distinst hooks
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc compile_source { { do_only_hooks 0} } {
   global ts_host_config ts_config
   global CHECK_PRODUCT_TYPE
   global CHECK_HTML_DIRECTORY
   global CHECK_DEFAULTS_FILE do_not_update check_name
   global CHECK_JOB_OUTPUT_DIR
   global CHECK_PROTOCOL_DIR CHECK_USER check_do_clean_compile

   # settings for mail
   set check_name "compile_source"
   set CHECK_CUR_PROC_NAME $check_name
   array set report {}
   report_create "Compiling source" report
   report_write_html report

   if {$ts_config(source_dir) == "none"} {
      report_add_message report "source directory is set to \"none\" - cannot compile"
      report_finish report -1
      return -1
   }


   set error_count 0
   set cvs_change_log ""

   # for additional configurations, we might want to start remote operation, if hedeby is set up
   # (for independed clusters)
   if { $do_only_hooks == 0 } {
      if {$ts_config(additional_config) != "none"} {
         foreach filename $ts_config(additional_config) {
            set cl_type [get_additional_cluster_type $filename add_config]
            if { $cl_type == "" } {
               continue
            }
            if { $cl_type == "independent" } {
               ts_log_fine "Found $cl_type additional cluster, starting remote compile ..."
               set task_nr [report_create_task report "build_additional_${cl_type}_cluster" $add_config(master_host) "$add_config(master_host)/index.html"]
               report_task_add_message report $task_nr "------------------------------------------"
               report_task_add_message report $task_nr "-> starting remote build of additional configuration $filename ..."
               report_task_add_message report $task_nr "-> see report in $CHECK_HTML_DIRECTORY/$add_config(master_host)/index.html"
               set error [operate_add_cluster $filename "compile" 3600]
               report_finish_task report $task_nr $error
               if { $error != 0 } {
                  incr error_count 1
               }
            }
         }
         if { $error_count != 0 } {
            report_add_message report "skip compilation because of errors!\n"
            report_finish report -1
            return -1
         }
      }
   }

   
   # if we configured to install precompiled packages - stop
   if { $ts_config(package_directory) != "none" && 
       ($ts_config(package_type)      == "tar" || $ts_config(package_type) == "zip") } {
      report_add_message report "will not compile but use precompiled packages\n"
      report_add_message report "set package_directory to \"none\" or set package_type to \"create_tar\"\n"
      report_add_message report "if compilation (and package creation) should be done"
      report_finish report -1
      return -1
   }

   # compile hosts required for master, exec, shadow, submit_only, bdb_server hosts
   set compile_hosts [compile_host_list]

   # add compile hosts for additional compile archs
   if {$ts_config(add_compile_archs) != "none"} {
      foreach arch $ts_config(add_compile_archs) {
         lappend compile_hosts [compile_search_compile_host $arch]
      }
   }

   # eliminate duplicates
   set compile_hosts [compile_unify_host_list $compile_hosts]

   # check source directory
   if { ( [ string compare $ts_config(source_dir) "unknown" ] == 0 ) || ( [ string compare $ts_config(source_dir) "" ] == 0 ) } {
      report_add_message report "source directory unknown - check defaults file"
      report_finish report -1 
      return -1
   }

   # check compile host
   if { ( [ string compare $ts_config(source_cvs_hostname) "unknown" ] == 0 ) || ( [ string compare $ts_config(source_cvs_hostname) "" ] == 0  ) } {          
      report_add_message report "host for cvs checkout unknown - check defaults file"
      report_finish report -1
      return -1
   }

   # check compile hosts
   if { ( [ string compare $compile_hosts "unknown" ] == 0 ) || ([ string compare $compile_hosts "" ] == 0) } {
      report_add_message report "host list to compile for unknown - check defaults file"
      report_finish report -1
      return -1
   }

   # do we have a unknown host ?
   if {[string match "*unknown*" $compile_hosts]} {
      report_add_message report "compile host list contains unknown host: $compile_hosts"
      report_finish report -1
   }

   # If we still have no compile hosts - report error
   if {[llength $compile_hosts] == 0} {
      report_add_message report "host list to compile has zero length"
      report_finish report -1
      return -1
   }

   # figure out the compile archs
   set compile_arch_list {}
   foreach chost $compile_hosts {
      ts_log_fine "\n-> checking architecture for host $chost ..."
      set output [resolve_build_arch $chost]
      if { $output == "" } {
         report_add_message report "error resolving build architecture for host $chost"
         report_finish report -1
         return -1
      }
      lappend compile_arch_list $output
   }

   # check if compile hosts are unique per arch
   foreach elem $compile_arch_list {
     set found 0
     set hostarch ""
     foreach host $compile_arch_list {
        if { [ string compare $host $elem ] == 0 }  {
           incr found 1
           set hostarch $host
        }
     }
     if { $found != 1 } {
        report_add_message report "two compile hosts have the same architecture -> error"
        report_finish report -1
        return -1
     }
   }

   # create protocol directory
   if {[file isdirectory "$CHECK_PROTOCOL_DIR"] != 1} {
      set catch_return [ catch {  file mkdir "$CHECK_PROTOCOL_DIR" } ]
      if { $catch_return != 0 } {
        report_add_message report "could not create directory \"$CHECK_PROTOCOL_DIR\""
        report_finish report -1
        return -1
      } 
   }

   # shutdown possibly running system (and additional config clusters)
   shutdown_core_system $do_only_hooks 1

   # for building java code, we need a build_testsuite.properties file
   # create it before update, clean, depend
   compile_create_java_properties $compile_hosts

   set compile_depend_done "false"

   # update sources
   set res [update_source report $do_only_hooks]      

   set aimk_clean_done 0

   if { $check_do_clean_compile } {
      set do_aimk_depend_clean 1
   } else {
      set do_aimk_depend_clean 0
   }
   if {$res == 1 || $check_do_clean_compile } {
      # make dependencies before compile clean
      if {$do_only_hooks == 0} {
         if {[compile_depend $compile_hosts report 1] != 0} {
            incr error_count 1
         } else {
            set compile_depend_done "true"
            set do_aimk_depend_clean 0
         }
      } else {
         ts_log_fine "Skip aimk compile, I am on do_only_hooks mode"
      }

      # after an update, do an aimk clean
      if {$do_only_hooks == 0} {
         # TODO: remove pre building on java host if ant build procedure
         #       supports parallel build correctly
         set tmp_java_compile_host [host_conf_get_java_compile_host]
         set exclude_host ""
         if { [lsearch $compile_hosts $tmp_java_compile_host] >= 0 } {
            if {[compile_with_aimk $tmp_java_compile_host report "compile_clean_java_build_host" "clean"] != 0} {
                  incr error_count 1
            } else {
               if {![wait_for_NFS_after_compile_clean $tmp_java_compile_host report]} {
                  incr error_count 1
               } else {
                  set exclude_host $tmp_java_compile_host
               }
            }
         }
       
         set tmp_clean_list {}
         foreach chost $compile_hosts {
            if {$chost != $exclude_host} {
               lappend tmp_clean_list $chost
            }
         }

         if {[compile_with_aimk $tmp_clean_list report "compile_clean" "clean"] != 0} {
            incr error_count 1
         }

         if {$error_count == 0} {
            set aimk_clean_done 1
            if {![wait_for_NFS_after_compile_clean $compile_hosts report]} {
               incr error_count 1
            }
         }
      } else {
         ts_log_fine "Skip aimk compile, I am on do_only_hooks mode"
      }

      # execute all registered compile_clean hooks of the checktree
      set res [exec_compile_clean_hooks $compile_hosts report]
      if {$res < 0} {
         report_add_message report "exec_compile_clean_hooks returned fatal error"
         incr error_count 1
      } elseif { $res > 0 } {
         report_add_message report "$res compile_clean hooks failed\n"
         incr error_count 1
      } else {
         report_add_message report "All compile_clean hooks successfully executed\n"
      }
   

      # after an update, delete macro messages file to have it updated
      set macro_messages_file [get_macro_messages_file_name]
      # only clean macro file if GE sources were updated!
      if {[file isfile $macro_messages_file] && $do_only_hooks == 0} {
         ts_log_fine "deleting macro messages file after update!"
         ts_log_fine "file: $macro_messages_file"
         file delete $macro_messages_file
      }
      update_macro_messages_list
   } elseif {$res < 0} {
      incr error_count 1
   }

   # do clean (if not already done)
   if {$error_count == 0 && $check_do_clean_compile == 1 && $aimk_clean_done == 0} {
      if {$do_only_hooks == 0} {
         # TODO: remove pre building on java host if ant build procedure
         #       supports parallel build correctly
         set tmp_java_compile_host [host_conf_get_java_compile_host]
         set exclude_host ""
         if { [lsearch $compile_hosts $tmp_java_compile_host] >= 0 } {
            if {[compile_with_aimk $tmp_java_compile_host report "compile_clean_java_build_host" "clean"] != 0} {
               incr error_count 1
            } else {
               if {![wait_for_NFS_after_compile_clean $tmp_java_compile_host report]} {
                  incr error_count 1
               } else {
                  set exclude_host $tmp_java_compile_host
               }
            }
         }

         set tmp_clean_list {}
         foreach chost $compile_hosts {
            if {$chost != $exclude_host} {
               lappend tmp_clean_list $chost
            }
         }

         if {[compile_with_aimk $tmp_clean_list report "compile_clean" "clean"] != 0} {
            incr error_count 1
         }

         if {$error_count == 0} {
            set aimk_clean_done 1
            if {![wait_for_NFS_after_compile_clean $compile_hosts report]} {
               incr error_count 1
            }
         }
      } else {
         ts_log_fine "Skip aimk compile, I am on do_only_hooks mode"
      }
      # execute all registered compile_hooks of the checktree
      set res [exec_compile_clean_hooks $compile_hosts report]
      if {$res < 0} {
         report_add_message report "exec_compile_clean_hooks returned fatal error"
         incr error_count 1
      } elseif {$res > 0} {
         report_add_message report "$res compile_clean hooks failed\n"
         incr error_count 1
      } else {
         report_add_message report "All compile_clean hooks successfully executed\n"
      }

   }

   if {$error_count > 0} {
      ts_log_fine "Skip compile due to previous errors\n"
   } else {
      if {$do_only_hooks == 0} {
         if { $compile_depend_done == "false" } {
            if {[compile_depend $compile_hosts report $do_aimk_depend_clean] != 0} {
               incr error_count 1
            } 
         } else {
            ts_log_fine "Skip second depend, already done!"
         }
      } else {
         ts_log_fine "Skip aimk compile, I am on do_only_hooks mode"
      }
      if {$error_count == 0} {
         # start build process
         if {$do_only_hooks == 0} {
            # TODO: remove pre building on java host if ant build procedure
            #       supports parallel build correctly
            set tmp_java_compile_host [host_conf_get_java_compile_host]
            if { [lsearch $compile_hosts $tmp_java_compile_host] >= 0 } {
               if {[compile_with_aimk $tmp_java_compile_host report "compile_java_build_host"] != 0} {
                  incr error_count 1
               }
            }
            if {[compile_with_aimk $compile_hosts report "compile"] != 0} {
               incr error_count 1
            }
            if { $error_count == 0 } {
               # we have to install the GE system here because other compile
               # hooks might need it
               report_add_message report "Installing GE binaries ...."
               report_write_html report
               # We need to evaluate the architectures to install.
               # We might have cached architecture strings from an old
               # $SGE_ROOT/util/arch. Clear the cache and resolve 
               # architecture names using dist/util/arch script.
               set compiled_mail_architectures [compile_rebuild_arch_cache $compile_hosts arch_list]
               
               # DG: if arch_list contains hp11-64 then we have 
               # an additional 32 bit architecture compiled on this host  
               # which  we have to install 
               set arch_list [add_32_bit_architecture_for_HP_64 $arch_list]               
 
               if { [ install_binaries $arch_list report] != 0 } {
                  report_add_message report "install_binaries failed\n"
                  incr error_count 1
               } 
            }
         } else {
            ts_log_fine "Skip aimk compile, I am on do_only_hooks mode"
         }
         report_write_html report
         if {$error_count == 0} {
            # new all registered compile_hooks of the checktree
            set res [exec_compile_hooks $compile_hosts report]
            if { $res < 0 } {
               ts_log_fine "exec_compile_hooks returned fatal error\n"
               incr error_count 1
            } elseif { $res > 0 } {
               ts_log_fine "$res compile hooks failed\n"
               incr error_count 1
            } else {
               ts_log_fine "All compile hooks successfully executed\n"
            }
         }
      }
   }

   # delete the build_testsuite.properties
   compile_delete_java_properties

   # install
   if {$error_count == 0} {
      if { $error_count == 0 } {
         # We need to evaluate the architectures to install.
         # We might have cached architecture strings from an old
         # $SGE_ROOT/util/arch. Clear the cache and resolve 
         # architecture names using dist/util/arch script.
         set compiled_mail_architectures [compile_rebuild_arch_cache $compile_hosts arch_list]

         # HP 64 compiles 32 bit binaries: so add 32 bit architecture if not inside
         set arch_list [add_32_bit_architecture_for_HP_64 $arch_list]              
 
         # new all registered compile_hooks of the checktree
         set res [exec_install_binaries_hooks $arch_list report]
         if { $res < 0 } {
            report_add_message report "exec_install_binaries_hooks returned fatal error\n"
            incr error_count 1
         } elseif { $res > 0 } {
            report_add_message report "$res install_binaries hooks failed\n"
            incr error_count 1
         } else {
            report_add_message report "All install_binaries hooks successfully executed\n"
         }
      }
   } else {
      report_add_message report "Skip installation due to previous error\n"
   }

   if { $error_count > 0 } {
      report_add_message report "Error occured during compilation or pre-installation of binaries"
      report_finish report -1 
      return -1
   }
   
   report_add_message report "Successfully compiled and pre-installed following architectures:"
   report_add_message report "${compiled_mail_architectures}\n"
   
   report_add_message report "init_core_system check will install the $CHECK_PRODUCT_TYPE execd at:"
   foreach elem $ts_config(execd_hosts) {
      set host_arch [ resolve_arch $elem ]
      report_add_message report "$elem ($host_arch)"
   }
   if { [string compare $cvs_change_log "" ] != 0 } {
      report_clear_messages report
      report_add_message report "$mail_body \n\n Update output:\n$cvs_change_log\n\n"
   }
   
   report_finish report 0

   # if required, build distribution

   # HP 64 compiles 32 bit binaries: so add 32 bit architecture if not inside
   set arch_list [add_32_bit_architecture_for_HP_64 $arch_list]             

   build_distribution $arch_list
   
   return 0
}

#****** check/add_32_bit_architecture_for_HP_64() **************************************************
#  NAME
#    add_32_bit_architecture_for_HP_64() -- adds the hp11 host to the arch list 
#
#  SYNOPSIS
#    add_32_bit_architecture_for_HP_64 { arch_list } 
#
#  FUNCTION
#    HP11-64 hosts are building 32 bit binaries. These binaries must be 
#    installed. Therefore we need to add the HP11 arch into the list. 
#    This function adds the 32 bit HP11 arch to the list if and only if 
#    we have an HP11-64 arch and not an HP11 arch inside. 
#
#  INPUTS
#    arch_list --  list of architectures 
#
#  RESULT
#    modified arch list which contains the HP11 32 bit arch 
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
proc add_32_bit_architecture_for_HP_64 { arch_list } {
   
   set contains_hp11_64 0
   set contains_hp11 0

   # if $arch_list contains hp11-64 add hp11 because we have the 
   # 32 bit binaries too

   foreach arch $arch_list {
      if { $arch == "hp11-64" } {
         set contains_hp11_64 1   
      }
      if { $arch == "hp11" } {
         set contains_hp11 1 
      }
   }

   if { $contains_hp11_64 == 1 && $contains_hp11 == 0 } {
      lappend arch_list "hp11"
   }

  return $arch_list  
}

#****** check/compile_with_aimk() **************************************************
#  NAME
#    compile_with_aimk() -- compile with aimk
#
#  SYNOPSIS
#    compile_with_aimk { host_list report task_name { aimk_options "" } } 
#
#  FUNCTION
#     Start the aimk parallel on some hosts
#
#  INPUTS
#    host_list --  list of host where aimk should be started
#    a_report    --  the report object
#    task_name --  name of the task in the report object
#    aimk_options -- aimk options
#
#  RESULT
#     ??? 
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
proc compile_with_aimk {host_list a_report task_name { aimk_options "" }} {
   global CHECK_USER define_daily_build_nr
   global CHECK_HTML_DIRECTORY CHECK_PROTOCOL_DIR ts_config

   upvar $a_report report

   if {$ts_config(source_dir) == "none"} {
      report_add_message report "source directory is set to \"none\" - cannot compile"
      return 1
   }


   set my_compile_options [get_compile_options_string]
   if { [string length $aimk_options] > 0 } {
      append my_compile_options " $aimk_options"
   }
   
   set num 0
   array set host_array {}
   
   # we'll pass a build number into aimk to distinguish our binaries
   # from official builds.
   set build_number [get_build_number]

   set table_row 2
   set status_rows {}
   set status_cols {status file}
   set java_compile_host [host_conf_get_java_compile_host]
   foreach host $host_list {
      # we have to make sure that the build number is compiled into 
      # the object code (therefore delete the appropriate object module).
      delete_build_number_object $host $build_number

      # start build jobs
      ts_log_fine "-> starting $task_name on host $host ..."

      set prog "$ts_config(testsuite_root_dir)/scripts/remotecompile.sh"
      set par1 "$ts_config(source_dir)"
      if {$define_daily_build_nr} {
         set par2 "-DDAILY_BUILD_NUMBER=$build_number $my_compile_options"
      } else {
         set par2 "$my_compile_options"
      }

      # For SGE 6.0, we want to build the drmaa.jar.
      # We do so by using the -java aimk option on the java build host
      if {$ts_config(gridengine_version) == 60 && $host == $java_compile_host} {
         set par2 "-java $par2"
      }
   
      ts_log_fine "$prog $par1 '$par2'"
      set open_spawn [open_remote_spawn_process $host $CHECK_USER $prog "$par1 '$par2'" 0 "" "" 0 15 0]
      set spawn_id [lindex $open_spawn 1]

      set host_array($spawn_id,host) $host
      set host_array($spawn_id,task_nr) [report_create_task report $task_name $host]
      set host_array($spawn_id,open_spawn) $open_spawn 
      lappend spawn_list $spawn_id

      # initialize fancy compile output
      lappend status_rows $host
      set status_array(file,$host)     "unknown"
      set status_array(status,$host)   "running"
      incr num 1
   }
  
   ts_log_fine "now waiting for end of compile ..." 
   set status_updated 1
   set status_time 0
   set timeout 3600 ;# need this extreme long timeout because of long jgdi wrapper classes
   # TODO (CR): decrease timeout when jgdi wrapper classes compilation is splitted into smaller c files
   set done_count 0
   log_user 0

   set org_spawn_list $spawn_list
   set do_stop 0
   while {[llength $spawn_list] > 0} {
      expect {
         -i $spawn_list full_buffer {
            # we got full buffer error, stop compileing
            set do_stop 1
         }
         -i $spawn_list timeout {
            # we got timeout, stop compileing
            set do_stop 1
         }
         -i $spawn_list eof {
            set spawn_id $expect_out(spawn_id)
            set host $host_array($spawn_id,host)
            set line $expect_out(0,string)
            
            report_task_add_message report $host_array($spawn_id,task_nr) "got eof for host \"$host\""
            set host_array($spawn_id,bad_compile) 1
            
            close_spawn_process $host_array($spawn_id,open_spawn)
            set host_array($spawn_id,open_spawn) "--"
            set index [lsearch -exact $spawn_list $spawn_id]
            set spawn_list [lreplace $spawn_list $index $index]

            set status_array(file,$host)   "-"
            set status_array(status,$host) "eof"
            set status_updated 1
         }
         -i $spawn_list -- "remotecompile * aimk compile error" {
            set spawn_id $expect_out(spawn_id)
            set host $host_array($spawn_id,host)
            set line $expect_out(0,string)
            
            
            report_task_add_message report $host_array($spawn_id,task_nr) $line
            set host_array($spawn_id,bad_compile) 1
            
            close_spawn_process $host_array($spawn_id,open_spawn)
            set host_array($spawn_id,open_spawn) "--"
            set index [lsearch -exact $spawn_list $spawn_id]
            set spawn_list [lreplace $spawn_list $index $index]

            set status_array(file,$host)   "-"
            set status_array(status,$host) "compile error"
            set status_updated 1
         }
         -i $spawn_list -- "remotecompile * aimk no errors" {
            set spawn_id $expect_out(spawn_id)
            set host $host_array($spawn_id,host)
            set line $expect_out(0,string)

            report_task_add_message report $host_array($spawn_id,task_nr) $line
            set host_array($spawn_id,bad_compile) 0
            
            close_spawn_process $host_array($spawn_id,open_spawn)
            set host_array($spawn_id,open_spawn) "--"
            set index [lsearch -exact $spawn_list $spawn_id]
            set spawn_list [lreplace $spawn_list $index $index]
            

            set status_array(file,$host)   "-"
            set status_array(status,$host) "finished"
            set status_updated 1
         }
         -i $spawn_list -- "*\n" {
            set spawn_id $expect_out(spawn_id)
            set host $host_array($spawn_id,host)
            set line [split [string trim $expect_out(0,string)]]
            set report_line "[clock format [clock seconds] -format "%H:%M:%S"]:$line"
            report_task_add_message report $host_array($spawn_id,task_nr) $report_line

            # look for output in the form "<compiler> .... -o target ..."
            #                          or "<compiler> .... -c ...."
            if {[llength $line] > 0} {
               set command [lindex $line 0]
               # ts_log_finest "line: $line"
               switch -exact -- $command {
                  "cc" -
                  "gcc" -
                  "xlc" -
                  "xlc_r" -
                  "insure" -
                  "cl.exe" {
                     set pos [lsearch -exact $line "-o"]
                     if {$pos > 0 && [llength $line] > [expr $pos + 1]} {
                        set status_array(file,$host) [lindex $line [expr $pos + 1]]
                        set status_array(status,$host) "running"
                        set status_updated 1
                     } else {
                        set pos [lsearch -glob $line "*.c"]
                        if {$pos > 0 && [llength $line] > $pos} {
                           set status_array(file,$host) [file tail [lindex $line $pos]]
                           set status_array(status,$host) "running"
                           set status_updated 1
                        }
                     }
                  }
                  "ar" {
                     if {[llength $line] > 2} {
                        set status_array(file,$host) [lindex $line 2]
                        set status_array(status,$host) "running"
                        set status_updated 1
                     }
                  }
                  "\[java\]" {
                     #ts_log_finest $line
                     if {[lsearch -exact $line "jar.wait:"] >= 0} {
                        set status_array(file,$host) "java (wait for java build host)"
                        set status_array(status,$host) "waiting"
                        set status_updated 1
                     } else {
                        set pos [lsearch -glob $line "*.c"]
                        if {$pos > 0 && [llength $line] > $pos} {
                           set status_array(file,$host) "java ([file tail [lindex $line $pos]])"
                           set status_array(status,$host) "running"
                           set status_updated 1
                        } else {
                           set pos [string last ":" $line]
                           set pos1 [string last "java\]\}" $line]
                           if { $pos > 0 && $pos1 > 0 } {
                              incr pos1 6
                              set my_text [string range $line $pos1 $pos]
                              if { [string length $my_text] > 60 } {
                                 set my_text [string range $my_text 0 59]
                              }
                              set status_array(file,$host) "java ($my_text)"
                              set status_array(status,$host) "running"
                              set status_updated 1
                           } else {
                              set status_array(file,$host) "java (unparsed output)"
                              set status_array(status,$host) "running"
                              set status_updated 1
                           }
                        }
                     }
                  }
                  default {
                     #set status_array(file,$host)   "(?)"
                     #set status_updated 1
                     #   ts_log_finest "---> unknown <--- $line"
                  }
               }
            }
         }
      }
      if { $do_stop == 1 } {
         foreach tmp_spawn_id $spawn_list {
            set host $host_array($tmp_spawn_id,host)
            ts_log_fine "stoping $tmp_spawn_id (host: $host)!"

            set report_line "[clock format [clock seconds] -format "%H:%M:%S"]: got timeout while waiting for output (some host is extremely slow)"
            report_task_add_message report $host_array($tmp_spawn_id,task_nr) $report_line

            set host_array($tmp_spawn_id,bad_compile) 1
            set tmp_open_spawn $host_array($tmp_spawn_id,open_spawn)
            if { $tmp_open_spawn != "--" && $tmp_open_spawn != "" } {
               close_spawn_process $host_array($tmp_spawn_id,open_spawn)
            }
            set host_array($tmp_spawn_id,open_spawn) "--"
            set status_array(file,$host)   "-"
            set status_array(status,$host) "timeout"
         }
         set spawn_list {}
         set status_updated 1
         set status_time 0
      }
      
      set now [timestamp]
      if {$status_updated && $status_time < $now} {
         set status_time $now
         set status_updated 0

         # output compile status
         set status_output [print_xy_array $status_cols $status_rows status_array status_max_column_len status_max_index_len]
         #if {[info exists status_max_column_len]} {
         #   unset status_max_column_len
         #}
         #if {[info exists status_max_index_len]} {
         #   unset status_max_index_len
         #}
         clear_screen
         ts_log_frame INFO "================================================================================"
         ts_log_info "open compile connections (aimk $my_compile_options):\n" 0 "" 1 0 0
         ts_log_info $status_output 0 "" 1 0 0
         ts_log_frame INFO "================================================================================"
      }
   }
   log_user 1
   
   set compile_error 0
   foreach spawn_id $org_spawn_list {
      if {$host_array($spawn_id,bad_compile) != 0} {
         ts_log_fine "\n=============\ncompile error on host $host_array($spawn_id,host):\n=============\n"
         report_finish_task report $host_array($spawn_id,task_nr) 1
         set compile_error 1
      } else {
         report_finish_task report $host_array($spawn_id,task_nr) 0
      }
   }

   return $compile_error
}

#****** check/get_build_number() ***********************************************
#  NAME
#     get_build_number() -- create a build number
#
#  SYNOPSIS
#     get_build_number { } 
#
#  FUNCTION
#     Creates a build number.
#     Currently, we use the date (formatted as yyyymmdd) as build number.
#
#  INPUTS
#
#  RESULT
#     build number
#*******************************************************************************
proc get_build_number {} {
   set build [clock format [clock seconds] -format "%Y%m%d" -gmt 1]
   return $build
}

#****** check/delete_build_number_object() *************************************
#  NAME
#     delete_build_number_object() -- delete object code containing build num
#
#  SYNOPSIS
#     delete_build_number_object { host build } 
#
#  FUNCTION
#     The function deletes the object code file from the build directory
#     which has the build number compiled in.
#
#     Currently this is the file sge_feature.o.
#
#     As we use the date as build number, the file is only deleted - and
#     therefore will be rebuilt with a new build number - when it has been
#     created or modified earlier than today.
#
#  INPUTS
#     host  - the host for whose architecture the object module will be deleted
#     build - the build number
#*******************************************************************************
proc delete_build_number_object {host build} {
   global ts_config

   if {$ts_config(source_dir) == "none"} {
      ts_log_config "source directory is set to \"none\" - cannot delete a build object"
      return 
   }

   set arch [resolve_build_arch $host]
   set filename "$ts_config(source_dir)/$arch/sge_feature.o"

   # only delete the file, if it is older than 00:00 today
   if {[file exists $filename]} {
      set midnight [clock scan $build -gmt 1]
      if {[file mtime $filename] < $midnight} {
         file delete $filename
      }
   }
}

#****** compile/compile_create_java_properties() *******************************
#  NAME
#     compile_create_java_properties() -- create java properites file for 61 builds
#
#  SYNOPSIS
#     compile_create_java_properties { compile_hosts } 
#
#  FUNCTION
#     Create and check availablity of the properties file on the specified compile
#     hosts.
#     This is only needed with SGE >= 6.1 (where we build jgdi).
#
#  INPUTS
#     compile_hosts - list of compile hosts
#
#*******************************************************************************
proc compile_create_java_properties { compile_hosts } {
   global CHECK_USER ts_config

   if {$ts_config(source_dir) == "none"} {
      ts_log_config "source directory is set to \"none\" - cannot create properties"
      return 
   }

   if {$ts_config(gridengine_version) >= 61} {
      set properties_file "$ts_config(source_dir)/build_testsuite.properties"
      ts_log_fine "deleting $properties_file"
      foreach host $compile_hosts {
         delete_remote_file $host $CHECK_USER $properties_file
      }

      # store long resolved host name in properties file ...
      ts_log_fine "creating $properties_file"
      set f [open $properties_file "w"]
      puts $f "java.buildhost=[host_conf_get_java_compile_host 1 1]"
      close $f
 
      foreach host $compile_hosts {
         ts_log_fine "waiting for $properties_file on host $host ..."
         wait_for_remote_file $host $CHECK_USER $properties_file
      }
   }
}

#****** compile/compile_delete_java_properties() *******************************
#  NAME
#     compile_delete_java_properties() -- delete testsuite properties file
#
#  SYNOPSIS
#     compile_delete_java_properties { } 
#
#  FUNCTION
#     Delete the generated testsuite properties file.
#     This is only needed with SGE >= 6.1 (where we build jgdi).
#
#  INPUTS
#
#*******************************************************************************
proc compile_delete_java_properties {} {
   global ts_config

   if {$ts_config(source_dir) == "none"} {
      ts_log_config "source directory is set to \"none\" - cannot create properties"
      return 
   }

   if {$ts_config(gridengine_version) >= 61} {
      set properties_file "$ts_config(source_dir)/build_testsuite.properties"
      if {[file isfile $properties_file]} {
         ts_log_fine "deleting $properties_file"
         file delete $properties_file
      }
   }
}
