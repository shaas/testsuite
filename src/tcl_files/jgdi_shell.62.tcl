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

proc jgdi_shell_setup { {host ""} } {
   global CHECK_USER ts_config jgdi_config
   array unset jgdi_config

   if { [string compare $host ""] == 0 } {
      set host [host_conf_get_suited_hosts]
   }
   
   return [setup_jgdi_config_for_host $host]
}

proc setup_jgdi_config_for_host { host } {
   global CHECK_USER ts_config jgdi_config
  
   # Host needs to be submit/admin host
   set jgdi_config(target_host) $host
   set jgdi_config(java15) [get_java_home_for_host $jgdi_config(target_host) "1.5" 0]
   set jgdi_config(java16) [get_java_home_for_host $jgdi_config(target_host) "1.6" 0]
   foreach java "java15 java16" {
      if { [string length $jgdi_config($java)] > 0 } {
         lappend jgdi_config(available_java_list) $java
      }
   }
   if { [llength $jgdi_config(available_java_list)] == 0 } {
      ts_log_severe "No java available on host $jgdi_config(target_host)!!!"
      return -1
   }
   set arch [resolve_arch $jgdi_config(target_host)]
   # aja: TODO: check if jgdi native library is available on $host
   set jgdi_config(classpath) "-cp $ts_config(product_root)/lib/jgdi.jar"
   set jgdi_config(connect_cmd) "bootstrap://$ts_config(product_root)@$ts_config(cell):$ts_config(commd_port)"
   set jgdi_config(logging_config_file) [get_tmp_file_name $jgdi_config(target_host) "jgdi" "properties"]
   jgdi_create_logging_config_file $jgdi_config(target_host) $jgdi_config(logging_config_file)
   set jgdi_config(flags) "-Djava.library.path=$ts_config(product_root)/lib/$arch -Djava.util.logging.config.file=$jgdi_config(logging_config_file)"
   
   #TODO: Check if 64 at the end safe?
   if { [string match "*64" $arch] == 1 } {
      append jgdi_config(flags) " -d64"
   }
   return 0
}

proc jgdi_shell_cleanup { } {
   global jgdi_config
   array unset jgdi_config
}

proc jgdi_junit_setup { JAVA_TEST_VERSION } {
   global ts_config ts_host_config
   global jgdi_config

   if {$ts_config(source_dir) == "none"} {
      ts_log_config "source directory is set to \"none\" - cannot setup junit jgdi"
      return 99
   }

   #TODO: improve so the junit tests can be run in parallel on different architectures
   set jgdi_config(target_host) [host_conf_get_java_compile_host]
   set jgdi_config(ant) $ts_host_config($jgdi_config(target_host),ant)
   set jgdi_config(java_test_version) $JAVA_TEST_VERSION
   
   set jgdi_config(cluster_config_file) [get_tmp_file_name]
   jgdi_create_cluster_config_file $jgdi_config(target_host) $jgdi_config(cluster_config_file)
   
   #set ant_options " -Duse.classpath.from.sge.root=true"
   set ant_options "-Dsge.root=$ts_config(product_root)"
   append ant_options " -Dsge.srcdir=$ts_config(source_dir)"
   append ant_options " -Djava.test.version=$JAVA_TEST_VERSION"
   append ant_options " -Djunit.formatter=plain"
   append ant_options " -Dcluster.config.file.location=$jgdi_config(cluster_config_file)"
   append ant_options " -f $ts_config(source_dir)/libs/jgdi/build.xml"

   set jgdi_config(ant_options) $ant_options
}

proc run_jgdi_command { command java_home } {
   global CHECK_USER jgdi_config
   run_jgdi_command_as_user $jgdi_config(target_host) $command $java_home $CHECK_USER
}

proc run_jgdi_command_as_user { on_host command java_home user {exit_var prg_exit_state}} {
   global jgdi_config
   upvar $exit_var exit_state

   set env(JAVA_HOME) $java_home
   set env_var env
   set java $env(JAVA_HOME)/bin/java

   #TODO LP: Should we throw out the error output (logging)?
   ts_log_fine "$user@$jgdi_config(target_host)# $java $jgdi_config(classpath) $jgdi_config(flags)  com/sun/grid/jgdi/util/JGDIShell -c $jgdi_config(connect_cmd) $command"
   set result [start_remote_prog $on_host $user  \
        "$java" "$jgdi_config(classpath) $jgdi_config(flags) \
        com/sun/grid/jgdi/util/JGDIShell -c $jgdi_config(connect_cmd) $command"\
        exit_state 600 0 "" $env_var]
   return $result
}

#****** jgdi_create_cluster_config_file() **************************************
#  NAME
#    jgdi_create_cluster_config_file() -- creates cluster config file on 
#                                         specified host to be used by JGDI
#
#  SYNOPSIS
#    jgdi_create_cluster_config_file { host filename } 
#
#  FUNCTION
#    Creates cluster config file on specified host to be used by JGDI
#
#  INPUTS
#    host      -- host where the file will be created
#    filename  -- filename
#
#  RESULT
#     0    -- successful
#     else -- failure
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc jgdi_create_cluster_config_file { host filename } { 
   global CHECK_USER
   global ts_config

   set is_csp_used "false"
   if { $ts_config(product_feature) == "csp" } {
      set is_csp_used "true"
   }

   set cluster_config "\"cluster\[0].sge_root=$ts_config(product_root)"
   append cluster_config "\ncluster\[0].sge_cell=$ts_config(cell)"
   append cluster_config "\ncluster\[0].qmaster_port=$ts_config(commd_port)"
   append cluster_config "\ncluster\[0].execd_port=[expr $ts_config(commd_port) + 1]"
   append cluster_config "\ncluster\[0].csp=$is_csp_used"
   append cluster_config "\ncluster\[0].username=$CHECK_USER"
   append cluster_config "\ncluster\[0].jass_login_context=jgdi"
   append cluster_config "\ncluster\[0].keystore_password=changeit"
   append cluster_config "\ncluster\[0].privatekey_password=changeit\""

   jgdi_create_config_file $host $cluster_config $filename
}

#****** jgdi_create_logging_config_file() **************************************
#  NAME
#    jgdi_create_logging_config_file() -- creates logging config file on 
#                                         specified host to be used by JGDI
#
#  SYNOPSIS
#    jgdi_create_logging_config_file { host filename } 
#
#  FUNCTION
#    Creates logging config file on specified host to be used by JGDI
#
#  INPUTS
#    host      -- host where the file will be created
#    filename  -- filename
#
#  RESULT
#     0    -- successful
#     else -- failure
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc jgdi_create_logging_config_file { host filename } { 
   jgdi_create_config_file $host \
"handlers=java.util.logging.ConsoleHandler\n\
.level = WARNING\n\
java.util.logging.ConsoleHandler.level = INFO\n\
java.util.logging.ConsoleHandler.formatter = com.sun.grid.jgdi.util.SGEFormatter\n\
com.sun.grid.jgdi.util.SGEFormatter.columns = level_long message" $filename
}

#****** jgdi_create_config_file() **************************************
#  NAME
#    jgdi_create_config_file() -- creates config file on specified host 
#
#  SYNOPSIS
#    jgdi_create_config_file { host filename } 
#
#  FUNCTION
#    Creates config file on specified host to be used by JGDI
#
#  INPUTS
#    host      -- host where the file will be created
#    filename  -- filename
#
#  RESULT
#     0    -- successful
#     else -- failure
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc jgdi_create_config_file { host content filename } { 
   global CHECK_USER
   global ts_config

   set fd [open $filename w+ 0777]
   foreach line [split $content "\n"] {
      puts $fd [string trim $line]
   }
   close $fd

   wait_for_remote_file $host $CHECK_USER $filename
}

#****** compare_jgdi() *********************************************************
#  NAME
#    compare_jgdi() -- compare commands output with JGDI shell implementation
#
#  SYNOPSIS
#    compare_jgdi { commands a_report } 
#
#  FUNCTION
#     compare commands output with JGDI shell implementation
#
#  INPUTS
#    commands       -- list of commands to execute in shell and then in java14, 
#                      java15, java16 if exist on the host
#
#  RESULT
#     0    -- success
#     else -- failure
#
#  EXAMPLE
#
#  NOTES
#
#  BUGS
#
#  SEE ALSO
#*******************************************************************************
proc compare_jgdi { commands } {
   global CHECK_USER CHECK_DEBUG_LEVEL
   global CHECK_HTML_DIRECTORY CHECK_PROTOCOL_DIR CHECK_ACT_LEVEL
   global ts_config ts_host_config jgdi_config do_jgdi_rebuild

   set output ""
   set error 0

   set max_len 0
   foreach cmd $commands {
      set len [string length $cmd]
      if { $max_len < $len } {
         set max_len $len
      }
   }


   #Create header
   set HEADER ""
   for { set i 0 } { $i < $max_len } { incr i 1} {
      append HEADER "="
   }
   set result "$HEADER\n[join $commands "\n"]\n$HEADER\n"
   #Print the header  
   #ts_log_fine $result

   set cmd_list {}
   set env_var ""
   #Get the client output
   foreach command $commands {
      set cmd [lrange [split $command " "] 0 0]
      lappend cmd_list $cmd
      set opts [string range $command [expr [string length $cmd] + 1] end]
      set opt [lrange [split $opts " "] 0 0]
#ts_log_fine "cmd=$cmd opts=\"$opts\" opt=\"$opt\""

      #Init array variables
      if { [array names opt_list $cmd] == "" } {
         set opt_list($cmd) ""
      }
      if { [array names jgdi_config $cmd,passed_opts] == "" } {
         set jgdi_config($cmd,passed_opts) ""
      }
      if { [array names jgdi_config $cmd,failed_opts] == "" } {
         set jgdi_config($cmd,failed_opts) ""
      }
      if { [array names client_output $cmd,$opt] == "" } {
         set client_output($cmd,$opt) ""
      }

      set opt_list($cmd) [lsort -unique [concat $opt_list($cmd) $opt]]

#ts_log_fine "cmd=$cmd opts=$opts optList($cmd)=$opt_list($cmd)"

      #Get the outputs for command + option
      append client_output($cmd,$opt) [start_remote_prog $jgdi_config(target_host) $CHECK_USER \
                                       "$cmd" "$opts" prg_exit_state 600 0 "" $env_var]
      if { $CHECK_DEBUG_LEVEL > 0 } {
         #ts_log_fine "$cmd $opt on client:\n$client_output($cmd,$opt)\n"
         append result "$cmd $opt on client:\n$client_output($cmd,$opt)\n"
      }
   }

   foreach java $jgdi_config(available_java_list) {
      foreach command $commands {
         set cmd [lrange [split $command " "] 0 0]
         set opts [string range $command [expr [string length $cmd] + 1] end]
         set opt [lrange [split $opts " "] 0 0]

         #Init array variables
         if { [array names jgdi_output $java,$cmd,$opt] == "" } {
            set jgdi_output($java,$cmd,$opt) ""
         }

         append jgdi_output($java,$cmd,$opt) [run_jgdi_command "$command" $jgdi_config($java)]
         if { $CHECK_DEBUG_LEVEL > 0 } {
            #ts_log_fine "$cmd $opt on $java:\n$jgdi_output($java,$cmd,$opt)\n"
            append result "$cmd $opt on $java:\n$jgdi_output($java,$cmd,$opt)\n"
         }
      }
   }

   set cmd_list [lsort -unique $cmd_list]
   set res2 [compare_java jgdi_output $cmd_list opt_list]
#ts_log_fine "res2=\"$res2\""
   set res1 [compare_client_vs_java client_output jgdi_output $cmd_list opt_list]
#ts_log_fine "res1=\"$res1\""

   if { [all_ok $res1] == 0 && [all_ok $res2] == 0 } {
      #ts_log_fine "OK\n"
      append result "OK\n"
      return $result
   }
   #ts_log_fine "$res1\n$res2"
   append result "$res1$res2"
   return $result
}

#****** remove_values_from_list() **********************************************
#  NAME
#    remove_values_from_list() -- remove one list values from another if exist
#
#  SYNOPSIS
#    remove_values_from_list { list_to_remove target_list } 
#
#  FUNCTION
#     remove one list values from another if exist
#
#  INPUTS
#    list_to_remove    -- list of values to be removed from target_list
#    target_list       -- list to be modifed
#
#  RETURN
#     modified target_list
#*******************************************************************************
proc remove_values_from_list { list_to_remove target_list } {
   foreach val $list_to_remove {
      set index [lsearch -exact $target_list $val]
      if { $index >= 0 } {
         set target_list [lreplace $target_list $index $index]
      }
   }
   return $target_list
}

#****** compare_client_vs_java() ***********************************************
#  NAME
#    compare_client_vs_java() -- compare client and java outputs
#
#  SYNOPSIS
#    compare_client_vs_java { client_output jgdi_output cmd_list opt_list } 
#
#  FUNCTION
#     Compare client and java output
#
#  INPUTS
#    client_output    -- client output form executing commands in compare_jgdi
#    jgdi_output      -- array of java outputs
#    cmd_list         -- list of executed commands
#    opt_list         -- array of executed options for each cmd_list command
#
#  RETURN
#     Formatted comparation. If OK each line ends with "OK" string. Otherwise 
#     returns a differences between client and java execution.
#
#  SEE
#     compare_jgdi
#*******************************************************************************
proc compare_client_vs_java { client_output jgdi_output cmd_list opt_list } {
   global jgdi_config
   upvar $client_output client
   upvar $jgdi_output jgdi
   upvar $opt_list opt

   set tout ""
   set oldest_java [lindex $jgdi_config(available_java_list) 0]

   foreach cmd $cmd_list {
#ts_log_fine "opt=$opt($cmd)"
      foreach option $opt($cmd) {
         set out ""
         #If all java ok, option might pass
         if { $jgdi_config($cmd,$option,java_ok)  == 1 } {
            append out "\"$cmd $option\" client vs java:   "
#ts_log_fine "client $cmd,$option:\n$client($cmd,$option)"
#ts_log_fine "$oldest_java $cmd,$option:\n$jgdi($oldest_java,$cmd,$option)"
            set cout [compare_output $client($cmd,$option) $jgdi($oldest_java,$cmd,$option)]
            append out [get_diff_result $cout]
            set ok [all_ok $out]
#ts_log_fine "$option: ok=$ok, out=\"$out\""
            set option_already_failed [lsearch -exact $jgdi_config($cmd,failed_opts) $option]
            #If OK add to passed opts if not already in failed
            if { $ok == 0 && $option_already_failed == -1 } {
               set out ""
               set jgdi_config($cmd,passed_opts) [lsort -unique [concat $jgdi_config($cmd,passed_opts) $option]]
            #Remove from passed and add to failed
            } else {
               set jgdi_config($cmd,passed_opts) [remove_values_from_list [list $option] $jgdi_config($cmd,passed_opts)]
               set jgdi_config($cmd,failed_opts) [lsort -unique [concat $jgdi_config($cmd,failed_opts) [list $option]]]
            }
         } else {
            #Java already failed - adding as failed test option
            foreach java $jgdi_config(available_java_list) {
               append out "\"$cmd $option\" client vs $java:   "
               set cout [compare_output $client($cmd,$option) $jgdi($java,$cmd,$option)]
               append out [get_diff_result $cout]
            }
            set out [string range $out 0 [expr [string length $out] - 1]]
            #Remove from passed and add to failed
            set jgdi_config($cmd,passed_opts) [remove_values_from_list [list $option] $jgdi_config($cmd,passed_opts)]
            set jgdi_config($cmd,failed_opts) [lsort -unique [concat $jgdi_config($cmd,failed_opts) [list $option]]]
         }
         append tout $out
      }
   }
   #set tout [string range $tout 0 [expr [string length $tout] - 1]]
   return $tout
}

#****** compare_java() *********************************************************
#  NAME
#    compare_java() -- compare client and java outputs
#
#  SYNOPSIS
#    compare_java { jgdi_output cmd_list opt_list } 
#
#  FUNCTION
#     Compare outputs for different java versions
#
#  INPUTS
#    jgdi_output      -- array of java outputs
#    cmd_list         -- list of executed commands
#    opt_list         -- array of executed options for each cmd_list command
#
#  RETURN
#     Formatted comparation. If OK each line ends with "OK" string. Otherwise 
#     returns a differences between execution of different java VM versions.
#
#  SEE
#     compare_jgdi
#*******************************************************************************
proc compare_java { jgdi_output cmd_list opt_list} {
   global jgdi_config
   upvar $jgdi_output jgdi
   upvar $opt_list opt
   set res 0
   set tout ""

   set has15 [lsearch -exact $jgdi_config(available_java_list) "java15"]
   set has16 [lsearch -exact $jgdi_config(available_java_list) "java16"]

   foreach cmd $cmd_list {
      foreach option $opt($cmd) {
         set out ""

         if { $has15 >= 0 && $has16 >= 0 } {
            append out "\"$cmd $option\" java15 vs java16:   "
            set cout [compare_output $jgdi(java15,$cmd,$option) $jgdi(java16,$cmd,$option)]
            append out [get_diff_result $cout]
         }
         #If OK print just 1 line
         if { [all_ok $out] == 0 } {
            append tout "\"$cmd $option\" all java vs java:   OK\n"
            set jgdi_config($cmd,$option,java_ok) 1
         } else {
            append tout $out
            set jgdi_config($cmd,$option,java_ok) 0
         }
      }
   }
   #If OK print just 1 line
   if { [all_ok $tout] == 0 } {
      set tout "all java vs java:   OK\n"
   }
   return $tout
}

#****** get_diff_result() ******************************************************
#  NAME
#    get_diff_result() -- formats the differences
#
#  SYNOPSIS
#    get_diff_result { cout } 
#
#  FUNCTION
#     Formats the differences
#
#  INPUTS
#    cout    -- string holding the differences
#
#  RETURN
#     Formatted differences. If OK each line ends with "OK" string. Otherwise 
#     returns a differences between client and java execution.
#*******************************************************************************
proc get_diff_result { cout } {
   set out ""
   if { [string length $cout] > 0 } {
      append out "ERROR\n"
      append out "$cout"
   } else {
      append out "OK"
   }
   return "$out\n"
}

#****** all_ok() ******************************************************
#  NAME
#    all_ok() -- Checks if all lines end with OK (no differences)
#
#  SYNOPSIS
#    all_ok { out } 
#
#  FUNCTION
#     Checks if all lines end with OK (no differences)
#
#  INPUTS
#    out    -- string holding the formatted differences
#
#  RETURN
#     0     - no differences (OK)
#    -1     - differences exist (ERROR)
#*******************************************************************************
proc all_ok { out } {
   set lines [split $out "\n"]
   foreach line $lines {
      #Match only lines with length >1 (skiping empty lines)
      if { [string length $line] > 1 } {
         #If not found return error
         if { [string match "*:   OK" $line] == 0 } {
            return -1
         }
      }
   }
   return 0
}

#****** compare_output() *******************************************************
#  NAME
#    compare_output() -- Compares outputs a and b
#
#  SYNOPSIS
#    compare_output { a b } 
#
#  FUNCTION
#     Compares outputs a and b. Adds the length of each line to the end.
#
#  INPUTS
#    a    -- string a to compare
#    b    -- string b to compare
#
#  RETURN
#     String with differences that were found
#
#  SEE
#     get_diff_result
#     all_ok
#     compare_client_vs_java
#     compare_java
#     compare_jgdi
#*******************************************************************************
proc compare_output { a b } {
   set ar [split $a "\n"]
   set br [split $b "\n"]
   
   set i 0
   while { $i < [llength $ar] } {
      set end_loop 0
      set j 0
      set line_a [lindex $ar $i]
      while { $j < [llength $br] && $end_loop != 1 } {
         set line_b [lindex $br $j]
         #We don't care also about number of spaces
         if { [match_lines_without_spaces $line_a $line_b] == 0 } {
            set ar [lreplace $ar $i $i]
            set i [expr $i - 1]
            set br [lreplace $br $j $j]
            set j [expr $j - 1]
            set end_loop 1
         }
         set j [expr $j + 1]
      }
      set i [expr $i + 1]
   }
   #Show what was left
   set out ""
   foreach line $ar {
      if { [string length $line] > 0 } {
        append out "[string length $line]:   $line\n"
        #append out "123 $line abc\n"
      }
   }
   if { [llength $ar] > 0 || [llength $br] > 0 } {
      append out "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n"
      set res -1
   } else {
      set res 0
   }
   foreach line $br {
      append out "[string length $line]:   $line\n"
   }
   return $out
}

#****** match_lines_without_spaces() **************************************
#  NAME
#    match_lines_without_spaces() -- Shows statistics for the tested command
#
#  SYNOPSIS
#    match_lines_without_spaces { a b }
#
#  INPUTS
#    a    -- string a to compare
#    b    -- string b to compare
#
#  FUNCTION
#     Tries to match the lines without spaces
#
#  RETURN
#     0         -- MATCH
#     otherwise -- DO NOT MATCH
#*******************************************************************************
proc match_lines_without_spaces { a b } {
   set al [split $a " "]
   set bl [split $b " "]
   set ca {}
   set cb {}
   foreach elem $al {
      if { [string length $elem] > 0 } {
         lappend ca $elem
      }
   }
   foreach elem $bl {
      if { [string length $elem] > 0 } {
         lappend cb $elem
      }
   }
   if { [llength $ca] != [llength $cb] } {
      return -1
   }
   for { set i 0 } { $i < [llength $ca] } { incr i 1 } {
      set elema [lindex $ca $i]
      set elemb [lindex $cb $i]
      if { [string compare $elema $elemb] != 0 } {
         return -1
      }
   }
   return 0
}
