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
   global ts_config ts_host_config

   # remember already resolved compile archs
   set compile_archs {}

   # check each host in host_list
   foreach host $host_list {
      if {![host_conf_is_supported_host $host]} {
         add_proc_error "compile_check_compile_hosts" -1 "host $host is not contained in testsuite host configuration or not supported host!"
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
#
#  RESULT
#     list of compile hosts
#     in case of errors, an empty list is returned
#
#  SEE ALSO
#     compile/compile_search_compile_host()
#*******************************************************************************
proc compile_host_list {} {
   global ts_config ts_host_config
   global CHECK_OUTPUT
  
   # build host list according to cluster requirements
   set host_list [concat $ts_config(master_host) $ts_config(execd_hosts) \
                         $ts_config(shadowd_hosts) $ts_config(submit_only_hosts) \
                         $ts_config(bdb_server) \
                         [checktree_get_required_hosts]]

   # For SGE 6.0 we build the drmaa.jar on the java build host.
   # Beginning with SGE 6.5 we build java code on all platforms.
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
         add_proc_error "compile_host_list" -1 "Cannot determine the architecture of host $host"
         return ""
      }
      if {![info exists compile_host($arch)]} {
         set c_host [compile_search_compile_host $arch]
         if {$c_host == "none"} {
            add_proc_error "compile_host_list" -1 "Cannot determine a compile host for architecture $arch" 
            return ""
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
         add_proc_error "compile_host_list" -1 "the java compile host ($jc_host) has architecture $jc_arch\nbut compile host for architecture $jc_arch is $compile_host($jc_arch).\nJava and C compile must be done on the same host"
         return ""
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
   global ts_config CHECK_OUTPUT

   set options $ts_config(aimk_compile_options)

   if {$options == "none"} {
      set options ""
   }

   if {$options != ""} {
      puts $CHECK_OUTPUT "compile options are: \"$options\""
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
   global CHECK_OUTPUT

   foreach host $ts_host_config(hostlist) {
      if {[host_conf_get_arch $host] == $arch && \
          [host_conf_is_compile_host $host]} {
         return $host
      }
   }

   # no compile host found for this arch
   puts $CHECK_OUTPUT "no compile host found for architecture $arch"
   return "none"
}

#
#                                                             max. column:     |
#
#****** check/compile_source() ******
#  NAME
#     compile_source() -- ??? 
#
#  SYNOPSIS
#     compile_source { } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
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
#*******************************
#
proc compile_source { { do_only_install 0 } { do_only_hooks 0} } {
   global ts_config ts_host_config
   global CHECK_SOURCE_DIR CHECK_OUTPUT CHECK_SOURCE_HOSTNAME
   global CHECK_SCRIPT_FILE_DIR CHECK_PRODUCT_TYPE CHECK_PRODUCT_ROOT
   global CHECK_HTML_DIRECTORY
   global CHECK_DEFAULTS_FILE CHECK_SOURCE_CVS_RELEASE do_not_update check_name
   global CHECK_DIST_INSTALL_OPTIONS CHECK_JOB_OUTPUT_DIR
   global CHECK_CORE_EXECD CHECK_PROTOCOL_DIR CHECK_USER CHECK_HOST check_do_clean_compile

   # settings for mail
   set check_name "compile_source"
   set CHECK_CUR_PROC_NAME "compile_source"
   if { $do_only_hooks == 0 } {
      set NFS_sleep_time 20
   } else {
      set NFS_sleep_time 0
   }

   array set report {}
   report_create "Compiling source" report
   
   report_write_html report
   
   set error_count 0
   set cvs_change_log ""

   # if we configured to install precompiled packages - stop
   if { $ts_config(package_directory) != "none" && 
        ($ts_config(package_type) == "tar" || $ts_config(package_type) == "zip") } {
           
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
   if { ( [ string compare $CHECK_SOURCE_DIR "unknown" ] == 0 ) || ( [ string compare $CHECK_SOURCE_DIR "" ] == 0 ) } {
      report_add_message report "source directory unknown - check defaults file"
      report_finish report -1 
      return -1
   }

   # check compile host
   if { ( [ string compare $CHECK_SOURCE_HOSTNAME "unknown" ] == 0 ) || ( [ string compare $CHECK_SOURCE_HOSTNAME "" ] == 0  ) } {          
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

   # figure out the compile archs
   set compile_arch_list ""
   foreach chost $compile_hosts {
      puts $CHECK_OUTPUT "\n-> checking architecture for host $chost ..."
      set output [start_remote_prog $chost $CHECK_USER "./aimk" "-no-mk" prg_exit_state 60 0 $CHECK_SOURCE_DIR "" 1 0]
      puts $CHECK_OUTPUT "return state: $prg_exit_state"
      if { $prg_exit_state != 0 } {
         report_add_message report "error starting \"aimk -no-mk\" on host $chost"
         report_finish report -1
         return -1
      }
      puts $CHECK_OUTPUT "host $chost will build [string trim $output] binaries"
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

   # shutdown possibly running system
   shutdown_core_system $do_only_hooks

   # for building java code, we need a build_testsuite.properties file
   # create it before update, clean, depend
   compile_create_java_properties $compile_hosts

   set compile_depend_done "false"
   # update sources
   if {$do_only_install != 1} {
      set res [update_source report]      
      if {$res == 1} {
         # make dependencies before compile clean
         if {$do_only_hooks == 0} {
            if {[compile_depend $compile_hosts report] != 0} {
               incr error_count
            } else {
               set compile_depend_done "true"
            }
         } else {
            puts $CHECK_OUTPUT "Skip aimk compile, I am on do_only_hooks mode"
         }

         # after an update, do an aimk clean
         if {$do_only_hooks == 0} {
            compile_with_aimk $compile_hosts report "compile_clean" "clean"
         } else {
            puts $CHECK_OUTPUT "Skip aimk compile, I am on do_only_hooks mode"
         }
         # execute all registered compile_clean hooks of the checktree
         set res [exec_compile_clean_hooks $compile_hosts report]
         if {$res < 0} {
            report_add_message report "exec_compile_clean_hooks returned fatal error"
         } elseif { $res > 0 } {
            report_add_message report "$res compile_clean hooks failed\n"
         } else {
            report_add_message report "All compile_clean hooks successfully executed\n"
         }
      
         # give NFS some rest after (probably massive) deletes
         sleep $NFS_sleep_time

         # after an update, delete macro messages file to have it updated
         set macro_messages_file [get_macro_messages_file_name]
         puts $CHECK_OUTPUT "deleting macro messages file after update!"
         puts $CHECK_OUTPUT "file: $macro_messages_file"
         if {[file isfile $macro_messages_file]} {
            file delete $macro_messages_file
         }
         update_macro_messages_list
      } elseif {$res < 0} {
         incr error_count
      }
   }

   if {$error_count == 0 && $check_do_clean_compile == 1} {
      if {$do_only_hooks == 0} {
         compile_with_aimk $compile_hosts report "compile_clean" "clean"
      } else {
         puts $CHECK_OUTPUT "Skip aimk compile, I am on do_only_hooks mode"
      }
      # execute all registered compile_hooks of the checktree
      set res [exec_compile_clean_hooks $compile_hosts report]
      if {$res < 0} {
         report_add_message report "exec_compile_clean_hooks returned fatal error"
      } elseif {$res > 0} {
         report_add_message report "$res compile_clean hooks failed\n"
      } else {
         report_add_message report "All compile_clean hooks successfully executed\n"
      }

      # give NFS some rest after (probably massive) deletes
      sleep $NFS_sleep_time
   }

   if {$error_count > 0} {
      puts $CHECK_OUTPUT "Skip compile due to previous errors\n"
   } elseif {$do_only_install != 1} {
      if {$do_only_hooks == 0} {
         if { $compile_depend_done == "false" } {
            if {[compile_depend $compile_hosts report] != 0} {
               incr error_count
            } 
         } else {
            puts $CHECK_OUTPUT "Skip second depend, already done!"
         }
      } else {
         puts $CHECK_OUTPUT "Skip aimk compile, I am on do_only_hooks mode"
      }
      if {$error_count == 0} {
         # depend was successfull - sleep a bit so let nfs settle down
         sleep $NFS_sleep_time

         # start build process
         if {$do_only_hooks == 0} {
            if {[compile_with_aimk $compile_hosts report "compile"] != 0} {
               incr error_count
            }
         } else {
            puts $CHECK_OUTPUT "Skip aimk compile, I am on do_only_hooks mode"
         }
         if {$error_count == 0} {
            # new all registered compile_hooks of the checktree
            set res [exec_compile_hooks $compile_hosts report]
            if { $res < 0 } {
               puts $CHECK_OUTPUT "exec_compile_hooks returned fatal error\n"
               incr error_count
            } elseif { $res > 0 } {
               puts $CHECK_OUTPUT "$res compile hooks failed\n"
               incr error_count
            } else {
               puts $CHECK_OUTPUT "All compile hooks successfully executed\n"
            }
         }
      }
   } else {
      puts $CHECK_OUTPUT "Skip compile, I am on do_install mode\n"
   }

   # delete the build_testsuite.properties
   compile_delete_java_properties

   # install to $CHECK_PRODUCT_ROOT
   if {$error_count == 0} {
      report_add_message report "Installing binaries ...."
      report_write_html report
     
      # We need to evaluate the architectures to install.
      # We might have cached architecture strings from an old
      # $SGE_ROOT/util/arch. Clear the cache and resolve 
      # architecture names using dist/util/arch script.
      resolve_arch_clear_cache
      set arch_list {}
      set compiled_mail_architectures ""
      puts -nonewline $CHECK_OUTPUT "\narchitectures: "
      foreach elem $compile_hosts {
         set output [resolve_arch $elem 1]
         lappend arch_list $output 
         puts -nonewline $CHECK_OUTPUT "$output "
         append compiled_mail_architectures "\n$elem ($output)"
      }
      puts ""
      
      if { $do_only_hooks == 0 } {
         if { [ install_binaries $do_only_install $arch_list report] != 0 } {
            report_add_message report "install_binaries failed\n"
            incr error_count
         } 
      } else {
         puts $CHECK_OUTPUT "Skip aimk compile, I am on do_only_hooks mode"
      }
      if { $error_count == 0 } {
         # new all registered compile_hooks of the checktree
         set res [exec_install_binaries_hooks $arch_list report]
         if { $res < 0 } {
            report_add_message report "exec_install_binaries_hooks returned fatal error\n"
            incr error_count
         } elseif { $res > 0 } {
            report_add_message report "$res install_binaries hooks failed\n"
            incr error_count
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
   foreach elem $CHECK_CORE_EXECD {
      set host_arch [ resolve_arch $elem ]
      report_add_message report "$elem ($host_arch)"
   }
   if { [string compare $cvs_change_log "" ] != 0 } {
      report_clear_messages report
      report_add_message report "$mail_body \n\n Update output:\n$cvs_change_log\n\n"
   }
   
   report_finish report 0

   # try to resolve hostnames in settings file
   set catch_return [ catch { eval exec "cp ${CHECK_DEFAULTS_FILE} ${CHECK_DEFAULTS_FILE}.[timestamp]" } ]
   if { $catch_return != 0 } { 
        puts "could not copy defaults file"
        return -1
   }

   # if required, build distribution
   build_distribution $arch_list
   
   return 0
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
   global ts_config CHECK_OUTPUT CHECK_USER
   global CHECK_SCRIPT_FILE_DIR CHECK_SOURCE_DIR
   global CHECK_HTML_DIRECTORY CHECK_PROTOCOL_DIR
   global do_only_install
   
   upvar $a_report report

   set my_compile_options [get_compile_options_string]
   if { [string length $aimk_options] > 0 } {
      append my_compile_options " $aimk_options"
   }
   
   set num 0
   array set host_array {}
   
   set cvs_tag "maintrunk"
   if {[file isfile "${CHECK_SOURCE_DIR}/CVS/Tag"]} {
      set cvs_tag "no_tag_dir" 
      set tag_state [catch {eval exec "cat ${CHECK_SOURCE_DIR}/CVS/Tag"} cvs_tag]
   }

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
      puts $CHECK_OUTPUT "-> starting $task_name on host $host ..."

      set prog "$ts_config(testsuite_root_dir)/$CHECK_SCRIPT_FILE_DIR/remotecompile.sh"
      set par1 "$CHECK_SOURCE_DIR"
      set par2 "-DDAILY_BUILD_NUMBER=$build_number $my_compile_options"

      # For SGE 6.0, we want to build the drmaa.jar.
      # We do so by using the -java aimk option on the java build host
      if {$ts_config(gridengine_version) == 60 && $host == $java_compile_host} {
         set par2 "-java $par2"
      }
      
      puts $CHECK_OUTPUT "$prog $par1 '$par2'"
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
  
   puts $CHECK_OUTPUT "now waiting for end of compile ..." 
   set status_updated 1
   set status_time 0
   set timeout 900
   set done_count 0
   log_user 0

   set org_spawn_list $spawn_list
   
   while {[llength $spawn_list] > 0} {
      if {[info exists spawn_id]} {
         unset spawn_id
      }
      
      set now [timestamp]
      if {$status_updated && $status_time < $now} {
         set status_time $now
         set status_updated 0

         # output compile status
         set status_output [print_xy_array $status_cols $status_rows status_array status_max_column_len status_max_index_len]
         clear_screen
         puts $CHECK_OUTPUT "================================================================================"
         puts $CHECK_OUTPUT "open compile connections (aimk $my_compile_options):\n"
         puts $CHECK_OUTPUT $status_output
         puts $CHECK_OUTPUT "================================================================================"
      }

      expect {
         -i $spawn_list full_buffer {
         }
         -i $spawn_list timeout {
            set spawn_id $expect_out(spawn_id)
            set host $host_array($spawn_id,host)
            set line $expect_out(0,string)
            
            report_task_add_message report $host_array($spawn_id,task_nr) "got timeout for host \"$host\""
            set host_array($spawn_id,bad_compile) 1
            
            close_spawn_process $host_array($spawn_id,open_spawn)
            set host_array($spawn_id,open_spawn) "--"
            set index [lsearch -exact $spawn_list $spawn_id]
            set spawn_list [lreplace $spawn_list $index $index]

            set status_array(file,$host)   "-"
            set status_array(status,$host) "timeout"
            set status_updated 1
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
         -i $spawn_list "remotecompile * aimk compile error" {
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
         -i $spawn_list "remotecompile * aimk no errors" {
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
         -i $spawn_list "*\n" {
            set spawn_id $expect_out(spawn_id)
            set host $host_array($spawn_id,host)
            set line [split [string trim $expect_out(0,string)]]

            report_task_add_message report $host_array($spawn_id,task_nr) $line

            # look for output in the form "<compiler> .... -o target ..."
            #                          or "<compiler> .... -c ...."
            if {[llength $line] > 0} {
               set command [lindex $line 0]
               # puts $CHECK_OUTPUT "line: $line"
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
                     puts $CHECK_OUTPUT $line
                     if {[lsearch -exact $line "jar.wait:"] >= 0} {
                        set status_array(file,$host) "java"
                        set status_array(status,$host) "waiting"
                        set status_updated 1
                     } else {
                        set status_array(file,$host) "java"
                        set status_array(status,$host) "running"
                        set status_updated 1
                     }
                  }
                  default {
                     #set status_array(file,$host)   "(?)"
                     #set status_updated 1
                     #   puts $CHECK_OUTPUT "---> unknown <--- $line"
                  }
               }
            }
         }
      }
   }
   log_user 1
   
   set compile_error 0
   foreach spawn_id $org_spawn_list {
      if {$host_array($spawn_id,bad_compile) != 0} {
         puts $CHECK_OUTPUT "\n=============\ncompile error on host $host_array($spawn_id,host):\n=============\n"
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
#     compile_create_java_properties() -- create java properites file for 65 builds
#
#  SYNOPSIS
#     compile_create_java_properties { compile_hosts } 
#
#  FUNCTION
#     Create and check availablity of the properties file on the specified compile
#     hosts.
#     This is only needed with SGE >= 6.5 (where we build jgdi).
#
#  INPUTS
#     compile_hosts - list of compile hosts
#
#*******************************************************************************
proc compile_create_java_properties { compile_hosts } {
   global ts_config CHECK_OUTPUT CHECK_USER

   if {$ts_config(gridengine_version) >= 65} {
      set properties_file "$ts_config(source_dir)/build_testsuite.properties"
      puts $CHECK_OUTPUT "creating $properties_file"
      set f [open $properties_file "w"]
      puts $f "java.buildhost=[host_conf_get_java_compile_host]"
      close $f
 
      foreach host $compile_hosts {
         puts $CHECK_OUTPUT "waiting for $properties_file on host $host ..."
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
#     This is only needed with SGE >= 6.5 (where we build jgdi).
#
#  INPUTS
#
#*******************************************************************************
proc compile_delete_java_properties {} {
   global ts_config CHECK_OUTPUT

   if {$ts_config(gridengine_version) >= 65} {
      set properties_file "$ts_config(source_dir)/build_testsuite.properties"
      if {[file isfile $properties_file]} {
         puts $CHECK_OUTPUT "deleting $properties_file"
         file delete $properties_file
      }
   }
}
