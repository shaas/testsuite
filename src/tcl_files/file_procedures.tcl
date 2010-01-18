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

global file_procedure_logfile_wait_sp_id
global last_file_extention
#                                                             max. column:     |
#****** file_procedures/test_file() ******
# 
#  NAME
#     test_file -- test procedure 
#
#  SYNOPSIS
#     test_file { me two } 
#
#  FUNCTION
#     this function is just for test the correct function call 
#
#  INPUTS
#     me  - first output parameter 
#     two - second output parameter 
#
#  RESULT
#     output to stdout: 
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
proc test_file { me two} {
  ts_log_fine "printing \"$me\" \"$two\". host is [exec hostname]" 
  return "test ok"
}

#                                                             max. column:     |
#****** file_procedures/get_dir_names() ******
# 
#  NAME
#     get_dir_names -- return all subdirectory names 
#
#  SYNOPSIS
#     get_dir_names { path } 
#
#  FUNCTION
#     read in directory and return a list of subdirectory names 
#
#  INPUTS
#     path - path to read in 
#
#  RESULT
#     list of subdirectory names 
#
#  EXAMPLE
#     set dirs [ get_dir_names /tmp ] 
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     file_procedures/get_file_names
#*******************************
proc get_dir_names {path} {
  catch {glob "$path/*"} r1
  set r2 ""
  foreach filename $r1 {
     if {[file isdirectory $filename] == 1 && [string compare [file tail $filename] "CVS"] != 0} {
        lappend r2 [file tail $filename]
     }
  }
  return $r2
}

#****** file_procedures/get_tmp_directory_name() *******************************
#  NAME
#     get_tmp_directory_name() -- returns temporary directory path
#
#  SYNOPSIS
#     get_tmp_directory_name { { hostname "" } { type "default" } 
#     { dir_ext "tmp" } } { not_in_results 0 }
#
#  FUNCTION
#     Generates a temporary usable directory name (full path). The parameters
#     are used to define substrings of the directory name. The path
#     is located in the testsuite main results directory or in "tmp" if the
#     testsuite results directory is not accessable.
#
#  INPUTS
#     { hostname "" }      - a hostname substring
#     { type "default" }   - a type substring
#     { dir_ext "tmp" }    - a extension substring
#     { not_in_results 0 } - if not 0: generate path in /tmp
#
#  RESULT
#     full path string of a directory
#
#  SEE ALSO
#     file_procedures/get_tmp_file_name()
#*******************************************************************************
proc get_tmp_directory_name {{hostname ""} {type "default"} {dir_ext "tmp"} {not_in_results 0}} {
   global CHECK_MAIN_RESULTS_DIR CHECK_USER last_file_extention

   if {$hostname == ""} {
      set local_host [gethostname]
      set hostname $local_host
   }

   if {![info exists last_file_extention]} {
      set last_file_extention 0
      ts_log_finest "set last file extention to initial value=$last_file_extention"
   } else {
      incr last_file_extention 1
   }

   set timestamp_sub_index $last_file_extention
   if {$not_in_results == 0} {
      while {1} {
         set timestamp_appendix "[clock seconds]_$timestamp_sub_index"
         if {![file isdirectory $CHECK_MAIN_RESULTS_DIR ]} {
           set file_name "/tmp/${CHECK_USER}_${hostname}_${type}_${timestamp_appendix}_${dir_ext}"
           set is_host_local_dir 1
         } else {
           set file_name "$CHECK_MAIN_RESULTS_DIR/${CHECK_USER}_${hostname}_${type}_${timestamp_appendix}_${dir_ext}"
           set is_host_local_dir 0
         }
         # break loop when file is not existing (when timestamp has increased)
         if {![file isdirectory $file_name]} {
            break
         } else {
            incr timestamp_sub_index 1
         }
      } 
   } else {
      set is_host_local_dir 1
      while {1} {
         set timestamp_appendix "[clock seconds]_$timestamp_sub_index"
         set file_name "/tmp/${CHECK_USER}_${hostname}_${type}_${timestamp_appendix}_${dir_ext}"
         # break loop when file is not existing (when timestamp has increased)
         if {[remote_file_isdirectory $hostname $file_name]} {
            incr timestamp_sub_index 1
         } else {
            break
         }
      }
   }
 
   if {$is_host_local_dir == 0} {
      delete_file_at_startup $file_name
   } else {
      delete_local_file_at_startup $hostname $file_name
   }
   return $file_name
}


#****** file_procedures/analyze_directory_structure() **************************
#  NAME
#     analyze_directory_structure() -- analyse files dirs and permissions of dir
#
#  SYNOPSIS
#     analyze_directory_structure { host user path dirs files permissions 
#     ignore } 
#
#  FUNCTION
#     This procedure is analysing the specified directory and returns
#     informations in specified arrays and lists.
#
#     It finds recursively all files and directories, including files starting
#     with '.'. Permissions are only returned for files.
#
#  INPUTS
#     host        - host of directory
#     user        - user who should analyze
#     path        - directory path
#     dirs        - name of array where to store directory names
#                   using value "" will result in not starting analyse
#                   script for dirs. This is a performance parameter
#                   when this information is not needed.
#     files       - name of array where to store file names
#     permissions - name of array for permissions of file names
#                   using value "" will result in not starting analyse
#                   script for file permissions. This is a performance
#                   parameter when this information is not needed.
#     {ignore {}} - optional: list directories to ignore
#
#  RESULT
#     undefined
#     specified arrays are updated with information
#     
#             dirs  -> list of all sub directories
#            files  -> list of all files (also from subdirectories)
#      permissions  -> the permission array has the following structure. Only
#                      files are returned, no directories:
#
#                      permissions($FILE,perm)  column 0 from "ls -la" output
#                      permissions($FILE,owner) column 2 from "ls -la" output
#                      permissions($FILE,group) column 3 from "ls -la" output
#                      where $FILE is a entry from files array
#
#*******************************************************************************
proc analyze_directory_structure {host user path dirs files permissions {ignore {}}} {
   global ts_config 

   if {$dirs != ""} {
      upvar $dirs spool_directories
   } else {
      set spool_directories {}
   }
   if {$files != ""} {
      upvar $files spool_files
   } else {
      set spool_files {}
   }

   if {$permissions != ""} {
      upvar $permissions spool_files_permissions
   }

   if {[info exists spool_files_permissions]} {
      unset spool_files_permissions
   }

   ts_log_fine "analyze directory: \"$path\" as user \"$user\" on host \"$host\""
   set script "$ts_config(testsuite_root_dir)/scripts/analyze_dir.sh"

   
   if {$dirs != ""} {
      set tmp [start_remote_prog $host $user $script "$path dirs" prg_exit_state 120 0 "" "" 1 0 0 1 1]
      set tmp2 [split $tmp "\n"]
      set spool_directories {}
      if {$prg_exit_state == 0} {
         foreach line $tmp2 {
            set file [string trim $line] 
            if {$file == ""} {
               continue
            }
            set matched 0
            foreach dir $ignore {
               if {[string match $dir $file]} {
                  ts_log_fine "ignoring path $file"
                  set matched 1
                  break
               }
            }
            if {$matched == 1} {
               continue
            }
            ts_log_finer "adding dir \"$file\""
            lappend spool_directories $file
         }
      } else {
         ts_log_severe "$script $path dirs returned exit status $prg_exit_state:\n$tmp\n"
      }
   }

   set tmp [start_remote_prog $host $user $script "$path files" prg_exit_state 120 0 "" "" 1 0 0 1 1]
   set tmp2 [split $tmp "\n"]
   set spool_files {}
   if {$prg_exit_state == 0} {
      foreach line $tmp2 {
         set file [string trim $line] 
         if {$file == ""} {
            continue
         }
         set matched 0
         foreach dir $ignore {
            if {[string match $dir $file]} {
               ts_log_fine "ignoring path $file"
               set matched 1
               break
            }
         }
         if {$matched == 1} {
            continue
         }
         ts_log_finer "adding file \"$file\""
         lappend spool_files $file
      }
   } else {
      ts_log_severe "$script $path files returned exit status $prg_exit_state:\n$tmp\n"
   }

   if {$permissions != ""} {
      set tmp [start_remote_prog $host $user $script "$path fileperm" prg_exit_state 120 0 "" "" 1 0 0 1 1]
      set tmp2 [split $tmp "\n"]
      if {$prg_exit_state == 0} {
         foreach file $spool_files {
            # find entry in tmp2
            foreach line $tmp2 {
               set length [llength $line]
               incr length -1
               set dir [lindex $line $length]
               if {$dir == $file} {
                  set spool_files_permissions($file,perm)   [lindex $line 0]
                  set spool_files_permissions($file,owner)  [lindex $line 2]
                  set spool_files_permissions($file,group)  [lindex $line 3]
               }
            }
         }
      } else {
         ts_log_severe "$script $path fileperm returned exit status $prg_exit_state:\n$tmp\n"
      }
   }
}


#****** file_procedures/get_tmp_file_name() ************************************
#  NAME
#     get_tmp_file_name() -- generate temporary filename 
#
#  SYNOPSIS
#     get_tmp_file_name { { hostname "" } { type "default" } { file_ext "tmp" } 
#     } { not_in_results 0 }
#
#  FUNCTION
#     Generates a temporary usable file name (full path). The parameters
#     are used to define substrings of the file name. The path
#     is located in the testsuite main results directory or in "tmp" if the
#     testsuite results directory is not accessable.
#
#     The file is automatically erased when:
#
#        a) The testsuite menu() procedure is called
#        b) A new test ( or testlevel) is started
#
#     So if the caller is generating this file, he as not to delete it.
#
#  INPUTS
#     { hostname "" }      - a hostname substring
#     { type "default" }   - a type substring
#     { file_ext "tmp" }   - a extension substring
#     { not_in_results 0 } - if not 0: generate file in /tmp
#
#  RESULT
#    a filename string ( absolute path )
#
#  SEE ALSO
#     file_procedures/get_tmp_directory_name()
#*******************************************************************************
proc get_tmp_file_name {{hostname ""} {type "default"} {file_ext "tmp"} {not_in_results 0}} {
   global CHECK_MAIN_RESULTS_DIR CHECK_USER last_file_extention

   if {$hostname == ""} {
      set local_host [gethostname]
      set hostname $local_host
   }

   if {![info exists last_file_extention]} {
      set last_file_extention 0
      ts_log_finest "set last file extention to initial value=$last_file_extention"
   } else {
      incr last_file_extention
   }
   
   set timestamp_sub_index $last_file_extention
   if {$not_in_results == 0} {
      # local file operations
      while {1} {
         set timestamp_appendix "[clock seconds]_$timestamp_sub_index"
         if {![file isdirectory $CHECK_MAIN_RESULTS_DIR]} {
           set file_name "/tmp/${CHECK_USER}_${hostname}_${type}_$timestamp_appendix.${file_ext}"
           set is_host_local_file 1
         } else {
           set file_name "$CHECK_MAIN_RESULTS_DIR/${CHECK_USER}_${hostname}_${type}_$timestamp_appendix.${file_ext}"
           set is_host_local_file 0
         }
         # break loop when file is not existing (when timestamp has increased)  
         if {[file isfile $file_name]} {
            incr timestamp_sub_index 1
         } else {
            break
         }
      }
   } else {
      # remote file operations
      set is_host_local_file 1
      while {1} {
         set timestamp_appendix "[clock seconds]_$timestamp_sub_index"
         set file_name "/tmp/${CHECK_USER}_${hostname}_${type}_$timestamp_appendix.${file_ext}"
         # break loop when file is not existing (when timestamp has increased)  
         if {[is_remote_file $hostname $CHECK_USER $file_name]} {
            incr timestamp_sub_index 1
         } else {
            break
         }
      }
   }

   if {$is_host_local_file == 0} {
      delete_file_at_startup $file_name
   } else {
      delete_local_file_at_startup $hostname $file_name
   }
 
   return $file_name
}


#****** file_procedures/print_xy_array() ***************************************
#  NAME
#     print_xy_array() -- print out an tcl x-y array
#
#  SYNOPSIS
#     print_xy_array { columns rows data_array } 
#
#  FUNCTION
#     This function can be used to format data like: 
#
#     set columns "sgetest1 sgetest2 root cr114091"
#     set rows "es-ergb01-01 balrog"
#
#                  | sgetest1 | sgetest2 | root | cr114091 
#     -------------+----------+----------+----------+----------
#     es-ergb01-01 |      639 |      639 |  739 |      639 
#     balrog       |     1409 |     1409 | 1659 |     1869 
#
#     The widths of the columns are adjusted according to the widths of the
#     header and data cells.
#
#     By specifying variables for the parametes column_len_var and 
#     index_len_var, column widths can reused in multiple subsequent calls
#     of print_xy_array.
#
#  INPUTS
#     columns              - x value list
#     rows                 - y value list 
#     data_array           - array with data for e.g. $data($col,$row)
#     {empty_cell ""}      - value to print for empty cells 
#                            (no value given in data_array)
#     {column_len_var ""}  - variable to store maximum column length
#     {index_len_var ""}   - variable to store maximum length of 
#                            index (first) column
#
#  EXAMPLE
#     set columns "sgetest1 sgetest2 root cr114091"
#     set rows "es-ergb01-01 balrog"
#     set data(sgetest1,es-ergb01-01) 639
#     ...
#     ...
#     puts [print_xy_array $columns $rows data]
#
#  RESULT
#     string containing the formatted table
#*******************************************************************************
proc print_xy_array {columns rows data_array {empty_cell ""} {column_len_var ""} {index_len_var ""}} {
   upvar $data_array result_array

   # if requested, keep column sizes persistent over multiple calls
   if {$column_len_var != ""} {
      upvar $column_len_var max_column_len
   }
   if {$index_len_var != ""} {
      upvar $index_len_var max_index_len
   }

   # calculate max width of first column (index column)
   if {![info exists max_index_len]} {
      set max_index_len 0
   }
   foreach row $rows {
      set len [string length $row]
      if {$max_index_len < $len} {
         set max_index_len $len
      }
   }

   # calculate max width of data columns
   # store width per column
   foreach col $columns {
      # minimum width is width of column header
      if {![info exists max_column_len($col)]} {
         set max_column_len($col) [string length $col]
      }

      # now look at the data in this column
      foreach row $rows {
         if {[info exists result_array($col,$row)]} { 
            set len [string length $result_array($col,$row)]
            if {$max_column_len($col) < $len} {
               set max_column_len($col) $len
            }
         }
      }
   }

   # initialize output string
   set output_text ""

   # output first line (header)
   append output_text [format "%-${max_index_len}s" ""]
   foreach col $columns {
      append output_text " | "
      set len $max_column_len($col)
      append output_text [format "%-${len}s" $col]
   }
   append output_text "\n"

   # output separating line between header and data 
   # - for index row
   set len [expr $max_index_len + 1]
   for {set i 0} {$i < $len} {incr i} {
      append output_text "-"
   }
  
   # - for data rows
   foreach col $columns {
      append output_text "+"
      set len [expr $max_column_len($col) + 2]
      for {set i 0} {$i < $len} {incr i} {
         append output_text "-"
      }
   }
   append output_text "\n"

   # output data
   foreach row $rows {
      append output_text [format "%-${max_index_len}s" $row]
      foreach col $columns {
         append output_text " | "
         if {[info exists result_array($col,$row)]} {
            set data $result_array($col,$row)
         } else {
            set data $empty_cell
         }
         set len $max_column_len($col)
         append output_text [format "%-${len}s" $data]
      }
      append output_text "\n"
   }

   return $output_text
}


#****** file_procedures/create_gnuplot_xy_gif() ********************************
#  NAME
#     create_gnuplot_xy_gif() -- create xy chart with gnuplot application
#
#  SYNOPSIS
#     create_gnuplot_xy_gif { data_array_name row_array_name } 
#
#  FUNCTION
#     This procedure works only if the gnuplot binary is in the local user path.
#
#  INPUTS
#     data_array_name(output_file) - chart output file (gif format) 
#     data_array_name(xlabel)      - chart label for x axis
#     data_array_name(ylabel)      - chart label for y axis
#     data_array_name(title)       - chart title
#
#     row_array_name(ROW,COUNTER,x) - x value for data ROW, position COUNTER
#     row_array_name(ROW,COUNTER,y) - y value for data ROW, position COUNTER
#     row_array_name(ROW,drawmode)  - drawmode for data ROW 
#                                     (="lines", "linespoints", "points", ...)
#     row_array_name(ROW,title)     - title for data ROW
#     row_array_name(ROW,show)      - show data ROW ( 0=don't show, 1=show row)
#
#  EXAMPLE
#     for { set i 0 } { $i < 300 } { incr i 1 }  {
#        set x [ expr ( $i / 100.00 ) ]
#        set dr1(0,$i,y) [expr ( sin($x) )]
#        set dr1(0,$i,x) $x 
#        set dr1(1,$i,y) [expr ( cos($x) )]
#        set dr1(1,$i,x) $x
#     }
#     set dr1(0,drawmode) "lines"  ;# or linespoints
#     set dr1(0,title) "sin(x)"
#     set dr1(0,show) 1
#     set dr1(1,drawmode) "lines"
#     set dr1(1,title) "cos(x)"
#     set dr1(1,show) 1
#  
#     set test(output_file) [get_tmp_file_name]
#     set test(xlabel) "x"
#     set test(ylabel) "y"
#     set test(title)  "sin(x) and cos(x)"
#     create_gnuplot_xy_gif test dr1
#
#*******************************************************************************
proc create_gnuplot_xy_gif { data_array_name row_array_name } {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   upvar $data_array_name data
   upvar $row_array_name rows

   set use_local_host true
   set local_host [gethostname]
   set gnuplot_bin [get_binary_path $local_host "gnuplot" 0]
   if { $gnuplot_bin == "gnuplot" } {
      # we didn't find gnuplot binaries on a local host, use another host
      foreach host [get_all_hosts] {
         set gnuplot_bin [get_binary_path $host "gnuplot" 0]
         if { $gnuplot_bin != "gnuplot" } {
            set local_host $host
            break
         }
      }
      set use_local_host false
   }

   # generate data files
   set file_name_list ""
   set drawmode_list ""
   set title_list ""

   set datarows 0
   set row_index ""
   while { [info exists rows($datarows,show) ] } {
      lappend row_index $datarows
      incr datarows 1 
   }

   set command_file [get_tmp_file_name]

   foreach row $row_index {
      if { $rows($row,show) == 0 } {
         continue
      }

      set file_name [get_tmp_file_name "" "$row"]
      set file_pointer [open $file_name w]

      set counter 0
      while { [ info exists rows($row,$counter,x)] && [ info exists rows($row,$counter,y)] } {
         set x_val $rows($row,$counter,x)
         set y_val $rows($row,$counter,y)
         puts $file_pointer "$x_val $y_val"
         incr counter 1
      }
      close $file_pointer

      # try to plot only if there were data points in this file
      if { $counter > 0 } {
         lappend file_name_list $file_name
      }

      if { [ info exists rows($row,drawmode) ] } {
         lappend drawmode_list $rows($row,drawmode)
      } else {
         lappend drawmode_list "linespoints"
      }
      if { [ info exists rows($row,title) ] } {
         lappend title_list $rows($row,title)
      } else {
         lappend title_list "row $row"
      }
   }


   # check gnuplot supporting gif terminals:
   set terminal_type "gif"
   set test_file_name [get_tmp_file_name "" "gnuplot_test"]
   set test_file [open $test_file_name w]
   puts $test_file "set terminal gif" 
   flush $test_file
   close $test_file
   if { !$use_local_host } {
      wait_for_remote_file $local_host $CHECK_USER $test_file_name
   }
   set result [start_remote_prog $local_host $CHECK_USER $gnuplot_bin $test_file_name prg_exit_state 60 0 "" "" 1 0 0]
   if { $prg_exit_state != 0 } {
      ts_log_fine "gnuplot does not support gif terminal, using png terminal ..."
      set terminal_type "png"
   }

   set command_file [get_tmp_file_name "" "cmd"]
   set cmd_file [open $command_file w]
   puts $cmd_file "set terminal $terminal_type"
   puts $cmd_file "set output \"$data(output_file)\""
#   puts $cmd_file "set xtics (0,1,2,3,4,5,6,7,8,9,10)"
#   puts $cmd_file "set ytics (0,5,10)"
   puts $cmd_file "set xlabel \"$data(xlabel)\""
   puts $cmd_file "set ylabel \"$data(ylabel)\""
   puts $cmd_file "set title \"$data(title)\""
#   puts $cmd_file "set pointsize 1.5"

   puts -nonewline $cmd_file "plot "
   for { set i 0 } { $i < [llength $file_name_list] } { incr i 1 } {
      set filename [lindex $file_name_list $i]
      set drawmode [lindex $drawmode_list $i]
      set title    [lindex $title_list $i]
      if { $i > 0 } {
         puts -nonewline $cmd_file ", "
      }
      puts -nonewline $cmd_file "'$filename' index 0 title \"$title\" with $drawmode"
   }
   close $cmd_file
   if { !$use_local_host } {
      wait_for_remote_file $local_host $CHECK_USER $command_file
   }
   set result [start_remote_prog $local_host $CHECK_USER $gnuplot_bin $command_file prg_exit_state 60 0 "" "" 1 0 0]
   if { $prg_exit_state == 0 } {
      return $data(output_file)
   } else {
      ts_log_finer $result
      catch { file copy $ts_config(testsuite_root_dir)/images/no_gnuplot.gif $data(output_file) }

      return $data(output_file)
   }
}



#****** file_procedures/tail_directory_name() **********************************
#  NAME
#     tail_directory_name() -- remove unnecessarily directory path content
#
#  SYNOPSIS
#     tail_directory_name { directory } 
#
#  FUNCTION
#     This function will remove all additional "/" signs inside the given
#     directory path.
#
#  INPUTS
#     directory - path to a directory
#
#  RESULT
#     string with clean path
# 
#*******************************************************************************
proc tail_directory_name { directory } {
   set first [file dirname $directory]
   if {[string compare "/" $first] == 0} {
      set first ""
   }
   return "$first/[file tail $directory]"
}


#****** file_procedures/dump_array_data() **************************************
#  NAME
#     dump_array_data() -- dump array data to stdout
#
#  SYNOPSIS
#     dump_array_data { obj_name obj } 
#
#  FUNCTION
#     This procedure dumps all array data to stdout.
#
#  INPUTS
#     obj_name - data object name (used for output)
#     obj      - array name
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc dump_array_data {obj_name obj} {
   upvar $obj data

   set names [array names data]
   set names [lsort $names]
   foreach elem $names {
      puts "$obj_name->$elem=$data($elem)"
   }
}

#****** file_procedures/convert_spool_file_to_html() ***************************
#  NAME
#     convert_spool_file_to_html() -- convert array data in spool file to html 
#
#  SYNOPSIS
#     convert_spool_file_to_html { spoolfile htmlfile { just_return_content 0 }} 
#
#  FUNCTION
#     This procedure generates a html output file from an array spool file.
#     Use the procedure spool_array_to_file() to generate a array spool file.
#
#  INPUTS
#     spoolfile                 - spool file directory path
#     htmlfile                  - output file directory path
#     { just_return_content 0 } - if 1: return just html content
#                               - if 0: create file and return html content
#
#  SEE ALSO
#     file_procedures/generate_html_file()
#     file_procedures/create_html_table()
#     file_procedures/create_html_link()
#     file_procedures/create_html_text()
#*******************************************************************************
proc convert_spool_file_to_html {spoolfile htmlfile {just_return_content 0}} {
   set content ""

   # read in spool file
   read_file $spoolfile file_dat
   
   # get all stored obj_names
   set obj_names [get_all_obj_names file_dat]

   foreach obj $obj_names {
      set obj_start [search_for_obj_start file_dat $obj]
      set obj_end   [search_for_obj_end file_dat $obj]
      for {set i $obj_start} {$i <= $obj_end} {incr i} {
         incr i
         set spec [unpack_data_line $file_dat($i)]
         incr i
         set spec_data [unpack_data_line $file_dat($i)]
         set obj_data($spec) $spec_data
      }
      if {$just_return_content == 0} {
         append content [create_html_text "Object name: $obj"]
      }
      set obj_names [array names obj_data]
      set obj_names [lsort $obj_names]
      set obj_names_count [llength $obj_names]
      set table(COLS) 2
      set table(ROWS) $obj_names_count
      for { set tb 1 } { $tb <= $obj_names_count } { incr tb 1 } {
         set obj_name_index [ expr ( $tb - 1 ) ]
         set obj_name [lindex $obj_names $obj_name_index]
         set table($tb,BGCOLOR) "#3366FF"
         set table($tb,FNCOLOR) "#66FFFF"    
         set table($tb,1) $obj_name
         set table($tb,2) [ format_output "" 75 $obj_data($obj_name)]
      }
      append content [create_html_table table]
      unset table
      
      dump_array_data $obj obj_data
      unset obj_data
   }
   if { $just_return_content == 0 } {
      return [generate_html_file $htmlfile "Object Dump" $content 1]
   } else {
      return $content
   }
}

#****** file_procedures/spool_array_to_file() **********************************
#  NAME
#     spool_array_to_file() -- spool array data to array spool file
#
#  SYNOPSIS
#     spool_array_to_file { filename obj_name array_name } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     filename   - file for data spooling
#     obj_name   - file object name of error
#     array_name - array to spool
#     { write_comment 1 } - if 1: write comment line into file
#     { remove_backup 0 } - if 1: remove saved data (*.old file)
#
#  RESULT
#     number of changed values 
#
#  SEE ALSO
#     file_procedures/read_array_from_file()
#*******************************************************************************
proc spool_array_to_file { filename obj_name array_name { write_comment 1 } {remove_backup 0}} {
   upvar $array_name data

   ts_log_fine "saving object \"$obj_name\" ..."
  
   spool_array_prepare $filename file_dat

   spool_array_add_data $filename $obj_name data $write_comment file_dat

   spool_array_finish $filename file_dat $remove_backup
}


proc spool_array_prepare {filename {data_array spool_array_data}} {
   upvar $data_array data

   # if file_dat exists - remove it
   if {[info exists data]} {
      unset data
   }

   # read in file
   read_file $filename data
}

proc spool_array_add_data {filename obj_name array_name {write_comment 0} {data_array spool_array_data}} {
   upvar $data_array data
   upvar $array_name obj

   # get all stored obj_names
   set obj_names [get_all_obj_names data]

   # if the object is already in data, we have to remove it.
   if {[lsearch -exact $obj_names $obj_name] != -1} {
      # search_for_obj... gives us the position of the object, we need
      # the position of the OBJ_START/OBJ_END line
      set obj_start [expr [search_for_obj_start data $obj_name] - 1]
      set obj_end [expr [search_for_obj_end data $obj_name] + 1]

      # delete the object from data
      for {set i $obj_start} {$i <= $obj_end} {incr i} {
         unset data($i)
      }

      # now we have to move the following objects up
      set last $data(0)
      set new_idx $obj_start
      for {set i [expr $obj_end + 1]} {$i <= $last} {incr i} {
         set data($new_idx) $data($i)
         unset data($i)
         incr new_idx
      }

      # set new data size
      set data(0) [expr $new_idx - 1]
   }


   # now append the object to data
   set act_line [expr $data(0) + 1]
   set data_specs [lsort [array names obj]]
   set data_count [llength $data_specs]
   if { $data_count > 0 } {
      set data($act_line) "OBJ_START:$obj_name:"
      incr act_line 1

      foreach spec $data_specs {
         if { $write_comment == 1 } {
            set data($act_line) "####### $spec #######"
            incr act_line 1
         }
         set data($act_line) [pack_data_line $spec]
         incr act_line 1
         set data($act_line) [pack_data_line $obj($spec)]
         incr act_line 1
      }

      set data($act_line) "OBJ_END:$obj_name:"
      set data(0) $act_line
   }
}

proc spool_array_finish {filename {data_array spool_array_data} {remove_backup 0}} {
   upvar $data_array data

   # write data to a temp file
   save_file $filename.tmp data

   # delete old backup
   if {[file isfile $filename.old]} {
      file delete $filename.old
   }

   # save current as backup
   if {[file isfile $filename]} {
      file rename $filename $filename.old
   }

   # make temp file current version
   if {[file isfile $filename.tmp]} {
      file rename $filename.tmp $filename
      file delete $filename.tmp
   }

   if {[file isfile $filename.old] && $remove_backup} {
      file delete $filename.old
   }

}

#****** file_procedures/save_file() ********************************************
#  NAME
#     save_file() -- saving array file data to file
#
#  SYNOPSIS
#     save_file {filename array_name} 
#
#  FUNCTION
#     This procedure saves the data in the array to the file
#
#  INPUTS
#     filename   - filename
#     array_name - name of array to save
#
#  EXAMPLE
#     set data(0) 1
#     set data(1) "the file will have this line"
#     save_file myfile.txt data
#
#  SEE ALSO
#     file_procedures/read_file()
#*******************************************************************************
proc save_file {filename array_name} {
   upvar  $array_name data
   
   set file [open $filename "w"]
   set last_line $data(0)
   for {set i 1} {$i <= $last_line} {incr i} {
      puts $file $data($i)
   }
   close $file
}

#****** file_procedures/read_file() ********************************************
#  NAME
#     read_file() -- read fill into array (line by line)
#
#  SYNOPSIS
#     read_file {filename array_name {wait_timeout 0}} 
#
#  FUNCTION
#     This procedure reads the content of the given file and saves the lines
#     into the array
#
#  INPUTS
#     filename         - file
#     array_name       - name of array to store file content
#     {wait_timeout 0} - if > 0, we'll wait wait_timeout seconds for the file
#                        to appear
#
#  EXAMPLE
#     read_file myfile.txt data
#     set nr_of_lines $data(0)
#     for { set i 1 } { $i <= $nr_of_lines } { incr i 1 } {
#        puts $data($i)
#     }
#
#  SEE ALSO
#     file_procedures/save_file()
#*******************************************************************************
proc read_file {filename array_name {wait_timeout 0}} {
   upvar  $array_name data

   if {$wait_timeout > 0} {
      wait_for_file $filename $wait_timeout
   }

   if {[file isfile $filename] != 1} {
      set data(0) 0
      ts_log_finest "read_file - returning empty file data structure, no such file $filename"
      return
   }
   set file [open $filename "r"]
   set x 1
   while {[gets $file line] >= 0} {
       set data($x) $line
       incr x 1
   }
   close $file
   incr x -1
   set data(0) $x
   ts_log_finest "file \"$filename\" has $x lines"
}


#****** file_procedures/get_all_obj_names() ************************************
#  NAME
#     get_all_obj_names() -- return object(array) names from array spool file
#
#  SYNOPSIS
#     get_all_obj_names { file_array } 
#
#  FUNCTION
#     Returns all object (array) names from an array spool file
#
#  INPUTS
#     file_array - array name of file data array (see read_file())
#
#  SEE ALSO
#     file_procedures/read_file()
#*******************************************************************************
proc get_all_obj_names { file_array } {
   upvar $file_array file_dat

   set obj_names "" 
  
   for { set i 1 } { $i <= $file_dat(0)  } { incr i 1 } {
      set line $file_dat($i)
      if { [string first "OBJ_START:" $line ] == 0 } {
         set start [string first ":" $line ]
         set end   [string last ":" $line ] 
         incr start 1
         incr end -1
         set found_job_name [string range $line $start $end]
         lappend obj_names $found_job_name
      }
  }
  return $obj_names
}

#****** file_procedures/search_for_obj_start() *********************************
#  NAME
#     search_for_obj_start() --  search line of object start in file array
#
#  SYNOPSIS
#     search_for_obj_start { file_array obj_name } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     file_array - name of file array (see save_file())
#     obj_name   - name of object
#
#  RESULT
#     line number or -1 on error
#
#  SEE ALSO
#     file_procedures/search_for_obj_end()
#     file_procedures/save_file()
#*******************************************************************************
proc search_for_obj_start { file_array obj_name } {
   upvar $file_array file_dat
   
   for { set i 1 } { $i <= $file_dat(0)  } { incr i 1 } {
      set line $file_dat($i)
      if { [string first "OBJ_START:" $line ] == 0 } {
         set start [string first ":" $line ]
         set end   [string last ":" $line ] 
         incr start 1
         incr end -1
         set found_job_name [string range $line $start $end]
         if { [string compare $obj_name $found_job_name] == 0 } {
            incr i 1
            return $i
         }
      }
  }
  return -1
}

#****** file_procedures/search_for_obj_end() ***********************************
#  NAME
#     search_for_obj_end() -- search line of object end in file array
#
#  SYNOPSIS
#     search_for_obj_end { file_array obj_name } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     file_array - name of file array (see save_file())
#     obj_name   - name of object 
#
#  RESULT
#     line number or -1 on error
#
#  SEE ALSO
#     file_procedures/search_for_obj_start()
#     file_procedures/save_file()
#*******************************************************************************
proc search_for_obj_end { file_array obj_name } {
   upvar $file_array file_dat
   
   for { set i 1 } { $i <= $file_dat(0)  } { incr i 1 } {
      set line $file_dat($i)
      if { [string first "OBJ_END:" $line ] == 0 } {
         set start [string first ":" $line ]
         set end   [string last ":" $line ] 
         incr start 1
         incr end -1
         set found_job_name [string range $line $start $end]
         if { [string compare $obj_name $found_job_name] == 0 } {
            incr i -1
            return $i
         }
      }
  }
  return -1
}

#****** file_procedures/unpack_data_line() *************************************
#  NAME
#     unpack_data_line() -- convert file data line to orignial data
#
#  SYNOPSIS
#     unpack_data_line { line } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     line - data line in file
#
#  SEE ALSO
#     file_procedures/pack_data_line()
#*******************************************************************************
proc unpack_data_line { line } {
   set start [string first ":" $line]
   incr start 1
   set end [string last ":" $line]
   incr end -1
   set data [string range $line $start $end]
   set data [replace_string $data "_TS_NEW_LINE_TS_" "\n"]
   set data [replace_string $data "_TS_CR_RETURN_TS_" "\r"]
   return $data
}

#****** file_procedures/pack_data_line() ***************************************
#  NAME
#     pack_data_line() -- convert data line to file
#
#  SYNOPSIS
#     pack_data_line { line } 
#
#  FUNCTION
#     do transformation of data to ensure correct data saving
#
#  INPUTS
#     line - data line in file
#
#  SEE ALSO
#     file_procedures/unpack_data_line()
#*******************************************************************************
proc pack_data_line { line } {
   set data ":$line:"
   set data [replace_string $data "\n" "_TS_NEW_LINE_TS_"]
   set data [replace_string $data "\r" "_TS_CR_RETURN_TS_"]
   return $data
}

#****** file_procedures/read_array_from_file() *********************************
#  NAME
#     read_array_from_file() -- read array data from array spool file
#
#  SYNOPSIS
#     read_array_from_file { filename obj_name array_name 
#     { enable_washing_machine 0 } } 
#
#  FUNCTION
#     This procedure will read the content of an array spool file and store it
#     into a tcl array.
#
#  INPUTS
#     filename                     - filename of array spool file
#     obj_name                     - name of object in array spool file
#     array_name                   - array name to store data
#     { enable_washing_machine 0 } - show washing machine
#
#  RESULT
#     0 on success, -1 on error
#
#  SEE ALSO
#      file_procedures/spool_array_to_file()
#*******************************************************************************
proc read_array_from_file {filename obj_name array_name {enable_washing_machine 0}} {
  upvar $array_name data

   # output washing machine only on tty
   if {$enable_washing_machine} {
      if {![check_output_is_tty]} {
         set enable_washing_machine 0
      }
   }

  read_file $filename file_dat
  set obj_start [search_for_obj_start file_dat $obj_name]
  if {$obj_start < 0} {
     return -1
  }
  set obj_end [search_for_obj_end file_dat $obj_name]
  if {$obj_end < 0} {
     return -1
  }
  set wcount 0
  set time 0
  for {set i $obj_start} {$i <= $obj_end} {incr i} {
     if {[string first "#" $file_dat($i)] == 0} {
        incr i
     }
     set spec [unpack_data_line $file_dat($i)]
     incr i
     set spec_data [unpack_data_line $file_dat($i)]
     set data($spec) $spec_data
     if {$enable_washing_machine && $wcount > 20} {
        ts_log_progress
        set wcount 0
        incr time
     }
     incr wcount
  }
  if {$enable_washing_machine} {
     ts_log_progress FINE "." 1
  }
  return 0
}


#****** file_procedures/read_array_from_file_data() ****************************
#  NAME
#     read_array_from_file_data() -- read array data from file data array
#
#  SYNOPSIS
#     read_array_from_file_data { file_data obj_name array_name 
#     { enable_washing_machine 0 } } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     file_data                    - file data object name
#     obj_name                     - object to read from file data
#     array_name                   - array name to store object
#     { enable_washing_machine 0 } - optional: display washing machine
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
proc read_array_from_file_data {file_data obj_name array_name {enable_washing_machine 0}} {
  upvar $array_name data
  upvar $file_data file_dat

   # output washing machine only on tty
   if {$enable_washing_machine} {
      if {![check_output_is_tty]} {
         set enable_washing_machine 0
      }
   }

  set obj_start [search_for_obj_start file_dat $obj_name]
  if { $obj_start < 0 } {
     return -1
  }
  set obj_end   [search_for_obj_end file_dat $obj_name]
  if { $obj_end < 0 } {
     return -1
  }

  set wcount 0
  set time 0
  for {set i $obj_start} {$i <= $obj_end} {incr i} {
     if {[string first "#" $file_dat($i)] == 0} {
        incr i
     }
     set spec [unpack_data_line $file_dat($i)]
     incr i
     set spec_data [unpack_data_line $file_dat($i)]
     set data($spec) $spec_data
     if {$enable_washing_machine && $wcount > 20} {
        ts_log_progress
        set wcount 0
        incr time
     }
     incr wcount
     
  }
  return 0
}

#****** file_procedures/get_all_subdirectories() *******************************
#  NAME
#     get_all_subdirectories() -- returns all subdirectories in path 
#
#  SYNOPSIS
#     get_all_subdirectories { path } 
#
#  FUNCTION
#     This procedure returns a list of all sub directories (recursive) in
#     given path
#
#  INPUTS
#     path - root directory path
#
#  RESULT
#     list of subdirectories
#
#*******************************************************************************
proc get_all_subdirectories {path} {
  set directories ""
  set files [get_file_names $path] 
  set dirs [get_dir_names $path]
 
  foreach elem $dirs {
     lappend directories "$elem"
  }
  
  foreach element $dirs {
     set sub_dirs [get_all_subdirectories "$path/$element"]
     foreach elem $sub_dirs {
        lappend directories "$element/$elem"
     }
     ts_log_progress
  }
  return $directories
}


# get all file names of path
#                                                             max. column:     |
#****** file_procedures/get_file_names() ******
# 
#  NAME
#     get_file_names -- return all file names of directory 
#
#  SYNOPSIS
#     get_file_names { path {ext "*"} } 
#
#  FUNCTION
#     read in directory and return a list of file names in this directory 
#
#  INPUTS
#     path - path to read in (directory) 
#     ext  - file extension (default "*")
#
#  RESULT
#     list of file names 
#
#  EXAMPLE
#     set files [ get_file_names /tmp ] 
#
#  NOTES
#     ??? 
#
#  BUGS
#     ??? 
#
#  SEE ALSO
#     file_procedures/get_dir_names
#*******************************
proc get_file_names {path {ext "*"}} {
  catch {glob "$path/$ext"} r1
  set r2 ""
  foreach filename $r1 {
     if {[file isfile $filename] == 1} {
        lappend r2 [file tail $filename]
     }
  }
  return $r2
}


#****** file_procedures/generate_html_file() ***********************************
#  NAME
#     generate_html_file() -- generate html file
#
#  SYNOPSIS
#     generate_html_file { file headliner content { return_text 0 }
#                          {refresh_time 15} } 
#
#  FUNCTION
#     This procedure creates the html file with the given headline and
#     text content.
#
#  INPUTS
#     file              - html file name to create
#     headliner         - headline text
#     content           - html body
#     { return_text 0 } - if not 0: return file content
#     {refresh_time 15} - default refresh time for browser auto reload
#     
#
#  SEE ALSO
#     file_procedures/generate_html_file()
#     file_procedures/create_html_table()
#     file_procedures/create_html_link()
#     file_procedures/create_html_text()
#*******************************************************************************
proc generate_html_file { file headliner content {return_text 0} {refresh_time 0} {center true}} {

   global CHECK_USER

   set output ""

   set catch_return [ catch {
      set h_file [ open "$file" "w" ]
   } ]
   if { $catch_return != 0 } {
      ts_log_severe "could not open file $file for writing"
      return
   }
   lappend output "<!doctype html public \"-//w3c//dtd html 4.0 transitional//en\">"
   lappend output "<html>"
   lappend output "<head>"
   lappend output "   <meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\">"
   lappend output "   <meta http-equiv=\"expires\" content=\"0\">"
   if {$refresh_time != 0} {
      lappend output "   <meta http-equiv=\"refresh\" content=\"$refresh_time\">"
   }
   lappend output "   <meta name=\"Author\" content=\"Grid Engine Testsuite - user ${CHECK_USER}\">"
   lappend output "   <meta name=\"GENERATOR\" content=\"unknown\">"
   lappend output "</head>"
   lappend output "<body text=\"#000000\" bgcolor=\"#FFFFFF\" link=\"#CCCCCC\" vlink=\"#999999\" alink=\"#993300\">"
   lappend output ""
   lappend output "<hr WIDTH=\"100%\">"
   if {$center} {
      lappend output "<center><font size=+2>$headliner</font></center>"
   } else {
      lappend output "<font size=+2>$headliner</font>"
   }
   lappend output ""
   lappend output "<hr WIDTH=\"100%\">"
   lappend output ""
   lappend output "$content"
   lappend output ""
   lappend output "</body>"
   lappend output "</html>"
   foreach line $output {
      puts $h_file $line
   }
   flush $h_file
   close $h_file
   
   if { $return_text != 0 } {
      set return_value ""
      foreach line $output {
         append return_value "$line\n"
      }
      return $return_value
   }
}

#****** file_procedures/create_html_table() ************************************
#  NAME
#     create_html_table() -- returns tcl array in html format
#
#  SYNOPSIS
#     create_html_table { array_name } 
#
#  FUNCTION
#     This procedure tries to transform the given array into an html table
#
#  INPUTS
#     array_name - table content
#
#     table(COLS) = nr. of columns
#     table(ROWS) = nr. of rows
#     table(ROW number,BGCOLOR) = Background color for row
#     table(ROW number,FNCOLOR) = Fontcolor of row
#     table(ROW number,1 up to $COLS) = content
#
#
#  RESULT
#     html format
#
#  EXAMPLE
#     set test_table(COLS) 2
#     set test_table(ROWS) 3
#     set test_table(1,BGCOLOR) "#3366FF"
#     set test_table(1,FNCOLOR) "#66FFFF"
#     set test_table(1,1) "Host"
#     set test_table(1,2) "State"
#   
#     set test_table(2,BGCOLOR) "#009900"
#     set test_table(2,FNCOLOR) "#FFFFFF"
#     set test_table(2,1) "host1"
#     set test_table(2,2) "ok"
#     
#     set test_table(3,BGCOLOR) "#CC0000"
#     set test_table(3,FNCOLOR) "#FFFFFF"
#     set test_table(3,1) "host2"
#     set test_table(3,2) [create_html_link "linktext" "test.html"]
#   
#     set my_content    [ create_html_text "Date: [exec date]" ]
#     append my_content [ create_html_text "some text ..." ]
#     append my_content [ create_html_table test_table ]
#     generate_html_file test.html "My first HTML example!!!" $my_content
#
#  SEE ALSO
#     file_procedures/generate_html_file()
#     file_procedures/create_html_table()
#     file_procedures/create_html_link()
#     file_procedures/create_html_text()
#*******************************************************************************
proc create_html_table {array_name {border 0} {align LEFT} {center true}} {
   upvar $array_name table

   set back "\n"
   if {$center} {
      append back <center>
   }
   append back "<table BORDER=$border COLS=${table(COLS)} WIDTH=\"80%\" NOSAVE >\n" 
   for {set row 1} {$row <= $table(ROWS)} {incr row} {
      append back "<tr ALIGN=$align VALIGN=CENTER BGCOLOR=\"$table($row,BGCOLOR)\" NOSAVE>\n"
      for {set col 1} {$col <= $table(COLS)} {incr col} {
         if {[info exists table($row,$col)]} {
            if {[info exists table($row,$col,FNCOLOR)]} {
               append back "<td NOSAVE><b><font color=\"$table($row,$col,FNCOLOR)\"><font size=+1>$table($row,$col)</font></font></b></td>\n"
            } else {
               append back "<td NOSAVE><b><font color=\"$table($row,FNCOLOR)\"><font size=+1>$table($row,$col)</font></font></b></td>\n"
            }
         } else {
            if {[info exists table($row,$col,FNCOLOR)]} {
               append back "<td NOSAVE><b><font color=\"$table($row,$col,FNCOLOR)\"><font size=+1></font></font></b></td>\n"
            } else {
               append back "<td NOSAVE><b><font color=\"$table($row,FNCOLOR)\"><font size=+1></font></font></b></td>\n"
            }
         }
      }
      append back "</tr>\n"
   }
   append back "</table>"
   if {$center} {
      append back "</center>"
   }
   append back "\n"
   return $back
}

#****** file_procedures/create_html_link() *************************************
#  NAME
#     create_html_link() -- create html link
#
#  SYNOPSIS
#     create_html_link { linktext linkref } 
#
#  FUNCTION
#     This procedure returns a html format for a "link"
#
#  INPUTS
#     linktext - text to display for link
#     linkref  - link to destination
#
#  RESULT
#     html format
#
#  SEE ALSO
#     file_procedures/generate_html_file()
#     file_procedures/create_html_table()
#     file_procedures/create_html_link()
#     file_procedures/create_html_text()
#*******************************************************************************
proc create_html_link {linktext linkref} {
   set back ""
   append back "<a href=\"$linkref\">$linktext</a>" 
   return $back
}

#****** file_procedures/create_html_image() ************************************
#  NAME
#     create_html_image() -- integrate html image
#
#  SYNOPSIS
#     create_html_image { alternative_text path } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     alternative_text - alternative text of image
#     path             - path or link to image
#
#  RESULT
#     html output
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc create_html_image {alternative_text path} {
   set back ""
   append back "<center><img SRC=\"$path\" ALT=\"$alternative_text\" NOSAVE></center>"
   return $back
}

#****** file_procedures/create_html_target() ***********************************
#  NAME
#     create_html_target() -- append html target
#
#  SYNOPSIS
#     create_html_target { target_name } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     target_name - link, name of target
#
#  RESULT
#     html output
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc create_html_target {target_name} {
   set back ""
   append back "<p><a NAME=\"$target_name\"></a>"
   return $back
}

#****** file_procedures/create_html_text() *************************************
#  NAME
#     create_html_text() -- create html text
#
#  SYNOPSIS
#     create_html_text { content { center 0 } } 
#
#  FUNCTION
#     This procedure returns a html format for "text"
#
#  INPUTS
#     content      - text 
#     { center 0 } - if not 0: center text
#
#  RESULT
#     html format
#
#  SEE ALSO
#     file_procedures/generate_html_file()
#     file_procedures/create_html_table()
#     file_procedures/create_html_link()
#     file_procedures/create_html_text()
#*******************************************************************************
proc create_html_text {content {center 0}} {
   set back ""

   if {$content == ""}  {
      set content "<br>"
   }

   if {$center != 0} {
      append back "<center>\n"
   }
   append back "\n<p>$content</p>\n"
   if {$center != 0} {
      append back "</center>\n"
   }
   return $back
}

proc create_html_non_formated_text {content {center false} {color ""}} {
   set back ""

   if {$content == ""}  {
      set content "<br>"
   }

   if {$center} {
      append back "<center>"
   }
   if {$color == ""} {
      append back "<pre>$content</pre>"
   } else {
      append back "<pre><font color=$color>$content</font></pre>"
   }

   if {$center} {
      append back "</center>\n"
   }
   return $back
}

proc create_html_line {size {width 100%} {align center}} {
   return "<hr size=$size width=$width align=$align \>"
}

#                                                             max. column:     |
#****** file_procedures/del_job_files() ******
# 
#  NAME
#     del_job_files -- delete files that conain a specific jobid 
#
#  SYNOPSIS
#     del_job_files { jobid job_output_directory expected_file_count } 
#
#  FUNCTION
#     This function reads in the job_output_directory and is looking for 
#     filenames that contain the given jobid. If after a maximum time of 120 
#     seconds not the number of expected_file_count is reached, a timeout will 
#     happen. After that the files are deleted. 
#
#  INPUTS
#     jobid                - jobid of job which has created the output file 
#     job_output_directory - path to the directory that contains the output files 
#     expected_file_count  - number of output files that are expected 
#
#  RESULT
#     returns the number of deleted files 
#
#  SEE ALSO
#     file_procedures/get_dir_names
#*******************************
proc del_job_files {jobid job_output_directory expected_file_count} {
   set del_job_count 0

   set end_time [expr [timestamp] + 120]   ;# timeout after 120 seconds

   ts_log_fine "waiting for $expected_file_count jobfiles of job $jobid"
   while {[timestamp] < $end_time} {
      set files [glob -nocomplain $job_output_directory/*e${jobid} $job_output_directory/*o${jobid} $job_output_directory/*${jobid}.*]
      if {[llength $files] >= $expected_file_count} {
         break
      }
      ts_log_finer "files found: [llength $files]"
      ts_log_finer "file list  : \"$files\""
      after 500
   }

   # ok delete the list 
   ts_log_fine "job \"$jobid\" has written [llength $files] files"

   if {[llength $files] >= 1} {
      if {[string length $job_output_directory] > 5} {
         foreach name $files {
            delete_file $name
            ts_log_finest "del_job_files - file: $name"
            incr del_job_count
         }
      } else {
         ts_log_severe "job output directory name should have at least 5 characters"
      }
   }

   return $del_job_count
}


#****** file_procedures/create_shell_script() **********************************
#  NAME
#     create_shell_script() -- create a /bin/sh script file 
#
#  SYNOPSIS
#     create_shell_script { scriptfile host exec_command exec_arguments 
#     {envlist ""} { script_path "/bin/sh" } { no_setup 0 } 
#     { source_settings_file 1 } } 
#
#  FUNCTION
#     This procedure generates a script which will execute the given command. 
#     The script will restore the testsuite and SGE environment first. It will 
#     also echo _start_mark_:(x) and _exit_status_:(x) where x is the exit 
#     value from the started command. 
#
#  INPUTS
#     scriptfile                 - full path and name of scriptfile to generate
#     host                       - host on which the script will run
#     exec_command               - command to execute
#     exec_arguments             - command parameters
#     {cd_dir ""}                - change into this directory before executing command
#     {envlist ""}               - array with environment settings to export
#                                  Be aware that the specified environment is "added"
#                                  ontop of the default environment of the user. 
#                                  Variables of the users env can be redefined but not 
#                                  directly unset! (the ""-string is a value!)
#                                  
#                                  The users env variables can be unset wirh the meta entry 
#                                  UNSET_VARS in the envlist array. Lappend any env variable name
#                                  that should be unsetted before execution of the command.
#
#                                  Example:
#                                  lappend envlist (UNSET_VARS) SDM_SYSTEM     
#
#     { script_path "/bin/sh" }  - path to script binary (default "/bin/sh")
#     { no_setup 0 }             - if 0 (default): full testsuite framework script
#                                                  initialization
#                                  if not 0:       no testsuite framework init.
#
#     { source_settings_file 1 } - if 1 (default): source the file
#                                                  $SGE_ROOT/$SGE_CELL/settings.csh
#                                  if not 1:       don't source settings file
#     { set_shared_lib_path 1 }  - if 1:           set shared lib path
#                                  if 0(default):  don't set shared lib path
#     { without_start_output 0 } - if 0 (default): put out start/end mark of output
#                                  if not 0:       don't print out start/end marks
#     { without_sge_single_line 0} - if 0 (default): set SGE_SINGLE_LINE=1 and export it 
#                                    if not 0:       unset SGE_SINGLE_LINE
#     {disable_stty_echo 0}      - if 0 (default): no action
#                                  if not 0: disalbe stty echo before executing command,
#                                            enable again after command
#
#
#  EXAMPLE
#     set envlist(COLUMNS) 500
#     create_shell_script "/tmp/script.sh" "ps" "-ef" "envlist" 
#
#  SEE ALSO
#     file_procedures/get_dir_names
#     file_procedures/create_path_aliasing_file()
#*******************************************************************************
proc create_shell_script { scriptfile
                           host
                           exec_command
                           exec_arguments
                           {cd_dir ""}
                           {envlist ""}
                           {script_path "/bin/sh"}
                           {no_setup 0}
                           {source_settings_file 1}
                           {set_shared_lib_path 0}
                           {without_start_output 0}
                           {without_sge_single_line 0}
                           {disable_stty_echo 0}
                           {no_final_enter 0}
                         } {
   global CHECK_PRODUCT_TYPE
   global CHECK_DEBUG_LEVEL 

   get_current_cluster_config_array ts_config
   if {$envlist != ""} {
      upvar $envlist users_env
   }
    
   set script_tail_name [file tail $scriptfile]
   set_users_environment $host users_env

   set script "no_script"
   set catch_return [catch {
       set script [open "$scriptfile" "w" "0755"]
   }]
   if {$catch_return != 0} {
      ts_log_warning "could not open file $scriptfile for writing"
      return
   }

   set script_content ""

   # script header
   append script_content "#!${script_path}\n"
   append script_content "# Automatic generated script from Grid Engine Testsuite\n"
   if {$no_setup == 0} {
      # script command
      append script_content "trap 'echo \"\" ; echo \"_exit_status_:(91) script: $script_tail_name\" ; echo \"script done. (_END_OF_FILE_)\"' 0\n"
      append script_content "umask 022\n"

      if {$set_shared_lib_path == 1} {
         if {$source_settings_file != 0} {
            ts_log_frame
            ts_log_fine "WARNING: setting shared lib path should not be done if settings file is sourced!"
            ts_log_fine "Will not set the shared lib path!"
            ts_log_frame
         } else {
            append script_content "# settup shared library path\n"
            get_shared_lib_path $host shared_var shared_value
            append script_content "if \[ x\$$shared_var = x \]; then\n"
            append script_content "   $shared_var=$shared_value\n"
            append script_content "   export $shared_var\n"
            append script_content "else\n"
            append script_content "   $shared_var=\$$shared_var:$shared_value\n"
            append script_content "   export $shared_var\n"
            append script_content "fi\n"
         }
      }

      if {$source_settings_file == 1} {
         append script_content "# source settings file\n"
         append script_content "if \[ -f $ts_config(product_root)/$ts_config(cell)/common/settings.sh \]; then\n"
         append script_content "   if \[ -r $ts_config(product_root)/$ts_config(cell)/common/settings.sh \]; then\n"
         append script_content "   . $ts_config(product_root)/$ts_config(cell)/common/settings.sh\n"
         append script_content "   fi\n"
         append script_content "else\n"
      }

      append script_content "# set testsuite environment\n"
      append script_content "   unset GRD_ROOT\n"
      append script_content "   unset CODINE_ROOT\n"
      append script_content "   unset GRD_CELL\n"
      append script_content "   unset CODINE_CELL\n"
      if {[info exists ts_config(commd_port)]} {
         append script_content "   COMMD_PORT=$ts_config(commd_port)\n"
         append script_content "   export COMMD_PORT\n"
         append script_content "   SGE_QMASTER_PORT=$ts_config(commd_port)\n"
         append script_content "   export SGE_QMASTER_PORT\n"
         set my_execd_port [expr $ts_config(commd_port) + 1]
         append script_content "   SGE_EXECD_PORT=$my_execd_port\n"
         append script_content "   export SGE_EXECD_PORT\n"
      }

      if {[info exists ts_config(product_root)]} {
         append script_content "   SGE_ROOT=$ts_config(product_root)\n"
         append script_content "   export SGE_ROOT\n"
      }
      append script_content "   SGE_CELL=$ts_config(cell)\n"
      append script_content "   export SGE_CELL\n"
    
      if {$source_settings_file == 1} {
         append script_content "fi\n"
      }


      if {$without_sge_single_line == 0} {
         append script_content "# don't break long lines with qstat\n"
         append script_content "SGE_SINGLE_LINE=1\n"
         append script_content "export SGE_SINGLE_LINE\n"
      } else {
         append script_content "unset SGE_SINGLE_LINE\n"
      }
#      TODO (CR): check out if LS_COLORS settings may disable qtcsh or qrsh on linux
       append script_content "unset LS_COLORS\n" 
#      do not enable this without rework of qstat parsing routines
#      append script_content "SGE_LONG_QNAMES=40\n"
#      append script_content "export SGE_LONG_QNAMES\n"

      # change directory, if requested

      if {$cd_dir != ""} {
         append script_content "# change into working directory\n"
         append script_content "cd $cd_dir\n"
         append script_content "\n"
      }

      
      set user_env_names [array names users_env]
      # save script parts in these two buffers to append them to the script in a defined order
      set set_env_skript ""
      set un_set_env_skript ""
      
      if {[llength $user_env_names] > 0} {
         append set_env_skript "# setup users environment variables\n"
         foreach u_env $user_env_names {
            if {$u_env == "UNSET_VARS"} {
                #the "meta key" UNSET_VARS was found that defines variables to be unset
                set vars_to_unset [split $users_env($u_env)] ;# the delimiter is a space (list delimiter)
                append un_set_env_skript "# unsetting users default environment variables\n"
                foreach unset_var $vars_to_unset {
                    append un_set_env_skript "unset $unset_var\n"
                }
            } else { 
               set u_val $users_env($u_env)
               append set_env_skript "${u_env}=\"${u_val}\"\n"
               append set_env_skript "export ${u_env}\n"
            }
         }
      }
      
      
      # add $un_set_env_skript only if some variables are defined to be unset
      if {$un_set_env_skript != ""} {
         append script_content $un_set_env_skript
      }

      # add the set of defined env variables
      append script_content $set_env_skript
      
      # do a stty -echo ?
      if {$disable_stty_echo != 0} {
         append script_content "stty -echo\n"
      }
      
      if {$without_start_output == 0} {
         append script_content "echo \"_start_mark_:(\$?)\"\n"
      }
   }


   # don't try to find which,cd, test and other shell commands
   # don't try to do anything if $no_setup is set
   # don't try to do a which if exec_command contains a space or ;
   append script_content "$exec_command $exec_arguments\n"

   if {$no_setup == 0} { 
      append script_content "exit_val=\"\$?\"\n"
      # do a stty -echo ?
      if {$disable_stty_echo != 0} {
         append script_content "stty echo\n"
      }
      append script_content "trap 0\n"
      if {$without_start_output == 0} {
         if {$no_final_enter == 0} {
            append script_content "echo \"\"\n"
         }
         append script_content "echo \"_exit_status_:(\$exit_val) script: $script_tail_name\"\n"
         append script_content "echo \"script done. (_END_OF_FILE_)\"\n"
      }
   }
  
   puts -nonewline $script $script_content
   close $script

   if {$CHECK_DEBUG_LEVEL != 0} {
      set script [open "$scriptfile" "r"]
      ts_log_frame FINEST "*********** script content start *********"
      while {[gets $script line] >= 0} {
         ts_log_finest $line
      }
      ts_log_frame FINEST "*********** script content end *********"
      close $script
      if {$CHECK_DEBUG_LEVEL == 2} {
         wait_for_enter
      }
   }
}



#****** file_procedures/get_file_content() *************************************
#  NAME
#     get_file_content() -- read remote/local file with cat command
#
#  SYNOPSIS
#     get_file_content { host user file { file_a "file_array" } } 
#
#  FUNCTION
#     This procedure fills up the file_array with the content of the given
#     file. file_array(0) contains the number of lines (starting from 1)
#     file_array(1) - file_array($file_array(0)) contains the lines of the 
#     file.
#
#  INPUTS
#     host                    - hostname to connect
#     user                    - user which calls the cat command
#     file                    - full path name of file
#     { file_a "file_array" } - array name
#
#*******************************************************************************
proc get_file_content {host user file {file_a "file_array"}} {
   upvar $file_a back

   if {[info exists back]} {
      unset back
   }
   set program "cat"
   set program_arg $file
   set output [start_remote_prog $host $user $program $program_arg]
   set lcounter 0
   if {$prg_exit_state != 0} {
      ts_log_severe "\'cat\' on host \"$host\" returned error($prg_exit_state):\n$output"
   } else {
      set help [split $output "\n"]
      foreach line $help {
         incr lcounter 1
         set back($lcounter) [string trimright $line]
      }
      incr lcounter -1 ;# we have one line more because of start_remote_prog!
   }
   set back(0) $lcounter
}

#****** file_procedures/write_remote_file() **************************************************
#  NAME
#    write_remote_file() -- Write a file on a remote user
#
#  SYNOPSIS
#    write_remote_file { host user file array_name } 
#
#  FUNCTION
#     Stores the content of a data array in the tmp directory (shared directory)
#     and copies this file on a remote host into a local directory
#
#  INPUTS
#    host -- the remote host
#    user -- the user
#    file -- the on the remote host filename
#    array_name -- array with the content of the file
#
#  RESULT
#     the exit code of the copy command 
#
#  EXAMPLE
#     set data(0) 2
#     set data(1) "first line"
#     set data(2) "second line"
#     write_remote_file "foo.bar" $CHECK_USER /tmp/test.txt data
#
#
#  SEE ALSO
#     file_procedures/save_file
#*******************************************************************************
proc write_remote_file {host user file array_name {permissions ""}} {
   upvar $array_name data
   
   set tmp_file [get_tmp_file_name $host $user]
   save_file $tmp_file data
   wait_for_remote_file $host $user $tmp_file 
   start_remote_prog $host $user "cp" "$tmp_file $file"
   if {$permissions != ""} {
      ts_log_fine "setting permissions of file \"$file\" to $permissions"
      start_remote_prog $host $user "chmod" "$permissions $file"
   }
   wait_for_remote_file $host $user $file
   return $prg_exit_state
} 

#                                                             max. column:     |
#****** file_procedures/get_binary_path() ******
# 
#  NAME
#     get_binary_path -- get host specific binary path 
#
#  SYNOPSIS
#     get_binary_path { hostname binary } 
#
#  FUNCTION
#     This procedure will parse the host configuration file of the 
#     testsuite. In this file the user can configure his host specific binary 
#     path names. 
#
#  INPUTS
#     hostname - hostname where a binary should be found 
#     binary   - binary name (e.g. expect) 
#
#  RESULT
#     The full path name of the binary on the given host. The return value 
#     depends on the entries in the testsuite host configuration file.
#
#     If there is no entry in the host configuration file the path settings
#     from the CHECK_USER are used to find out the path of the binary by
#     doing a which call. If the CHECK_USER settings does also not return
#     the path the path settings fromt the root user are checked.
#
#     The testsuite will generate a configuration warning message that
#     a host configuration does not contain the path for a binary if the
#     path has to be resolved by using any users environment.
#
#     The path settings from the users's environments are cached. If a
#     cached entry is returned the testsuite will not report a configuration
#     warning. 
#
#     If the binary cannot be found at all the content of the binary argument
#     is returned.
#
#  SEE ALSO
#     file_procedures/get_dir_names
#*******************************

# This is the cache for users's binary which calls. The cache is erased 
# when the file is (re-)sourced!
global cached_binary_path_array
if {[info exists cached_binary_path_array]} {
   unset cached_binary_path_array
}
proc get_binary_path {nodename binary {raise_error 1}} {
   global ts_host_config 
   global ts_config
   global CHECK_USER
   global cached_binary_path_array

   # get node name of host
   set hostname [node_get_host $nodename]

   # Check if there is an entry for the binary in the host config
   if {[info exists ts_host_config($hostname,$binary)]} {
      return $ts_host_config($hostname,$binary)
   }

   # Check if we already have cached entry from the CHECK_USER user path settings
   if {[info exists cached_binary_path_array($hostname,$binary,$CHECK_USER)]} {
      return $cached_binary_path_array($hostname,$binary,$CHECK_USER)
   }

   # Check if we already have a cached entry from the root user path settings
   if {[info exists cached_binary_path_array($hostname,$binary,root)]} {
      return $cached_binary_path_array($hostname,$binary,root)
   }

   # This is for the special xterm binary 
   if {$binary == "xterm"} {
      set binary_path [private_get_xterm_path $hostname]
      set binary_path [string trim $binary_path]
      if {$binary_path != "xterm"} {
         # The binary path is not configured in the host configuration, report config warning
         set config_text "No entry for binary \"$binary\" on host \"$hostname\" in host configuration!\n"
         append config_text "Using \"$binary\" binary: \"$binary_path\"\n"
         ts_log_info $config_text
         # Now add the binary path to the cache
         set cached_binary_path_array($hostname,$binary,$CHECK_USER) $binary_path
         return $binary_path 
      }
      ts_log_warning "Cannot find path to binary \"$binary\" on host \"$hostname\"" $raise_error
      return $binary
   }

   # For "sh" we always expect sh shell at /bin/sh
   if {$binary == "sh"} {
      set binary_path "/bin/sh"
      set cached_binary_path_array($hostname,$binary,$CHECK_USER) $binary_path
      return $binary_path 
   }
   
      # Try to find out the path from CHECK_USER user's environment
      set binary_path [start_remote_prog $hostname $CHECK_USER "$ts_config(testsuite_root_dir)/scripts/mywhich.sh" $binary prg_exit_state 60 0 "" "" 1 0]
      set binary_path [string trim $binary_path]
   if {[is_remote_file $hostname $CHECK_USER $binary_path 0]} {
      # We have figured out the path from the user's environment
      # The binary path is not configured in the host configuration, report config warning
      set config_text "No entry for binary \"$binary\" on host \"$hostname\" in host configuration!\n"
      append config_text "Using \"$binary\" binary from testsuite user`s environment path setting: \"$binary_path\"\n"
      ts_log_info $config_text
      # Now add the binary path to the cache
      set cached_binary_path_array($hostname,$binary,$CHECK_USER) $binary_path
      return $binary_path
   } else {
      # If we have a root password we also try to get it from root's path environment
      if {[have_root_passwd] == 0} {
            set binary_path [start_remote_prog $hostname "root" "$ts_config(testsuite_root_dir)/scripts/mywhich.sh" $binary prg_exit_state 60 0 "" "" 1 0]
            set binary_path [string trim $binary_path]
         if {[is_remote_file $hostname "root" $binary_path 0]} {
            # We have figured out the path from the root user's environment
            # The binary path is not configured in the host configuration, report config warning
            set config_text "No entry for binary \"$binary\" on host \"$hostname\" in host configuration!\n"
            append config_text "Using \"$binary\" binary from root`s environment path setting: \"$binary_path\"\n"
            ts_log_info $config_text
            # Now add the binary path to the cache
            set cached_binary_path_array($hostname,$binary,root) $binary_path
            return $binary_path
         }
      }
   }
   ts_log_warning "Cannot find path to binary \"$binary\" on host \"$hostname\"" $raise_error
   return $binary
}

#                                                             max. column:     |
#****** file_procedures/copy_directory() ******
# 
#  NAME
#     copy_directory -- copy a directory recursively 
#
#  SYNOPSIS
#     copy_directory { source target } 
#
#  FUNCTION
#     This procedure will copy the given source directory to the target 
#     directory. The content of the target dir is deleted if it exists. 
#     (calling delete_directory, which will make a secure copy in the testsuite 
#     trash folder). 
#
#  INPUTS
#     source - path to the source directory 
#     target - path to the target directory 
#
#  RESULT
#     no results 
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
#     file_procedures/delete_directory
#*******************************
proc copy_directory {source target} {
  if {[string length $source] <= 10 || [string length $target] <= 10} {
     # just more security (do not create undefined dirs or something like that)
     ts_log_severe "please use path with size > 10 characters"
     return
  } 

  if {[string compare $source $target] == 0} {
     ts_log_severe "source and target are equal"
     return
  }
 
  set back [catch {file mkdir $target}]
  if {$back != 0} {
     ts_log_severe "can't create dir \"$target\""
     return
  }

  if {[file isdirectory $target] == 1} {
      set back [delete_directory $target]
      if {$back != 0} {
         ts_log_severe "can't delete dir \"$target\""
         return
      }
  }

  set back [catch {file copy -- $source $target}]
  if {$back != 0} {
     ts_log_severe "can't copy \"$source\" to \"$target\" "
     return
  }
}


#                                                             max. column:     |
#****** file_procedures/cleanup_spool_dir() ******
# 
#  NAME
#     cleanup_spool_dir -- create or cleanup spool directory for master/execd 
#
#  SYNOPSIS
#     cleanup_spool_dir { topleveldir subdir } 
#
#  FUNCTION
#     This procedure will create or cleanup old entries in the qmaster or execd 
#     spool directory 
#
#  INPUTS
#     topleveldir - path to spool toplevel directory ( updir of qmaster and execd ) 
#     subdir      - this paramter is master or execd 
#
#  RESULT
#     if ok the procedure returns the correct spool directory. It returns  on 
#     error 
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
#     file_procedures/delete_directory()
#*******************************
proc cleanup_spool_dir {topleveldir subdir} {
   get_current_cluster_config_array ts_config

   set spooldir "$topleveldir"

   ts_log_fine "cleaning spool directory is $spooldir"
   
   if {[file isdirectory $spooldir] == 1} {
      set spooldir "$spooldir/$ts_config(commd_port)"
      if {[file isdirectory $spooldir] != 1} { 
         ts_log_finer "creating directory \"$spooldir\""
         file mkdir $spooldir
         if {[file isdirectory $spooldir] != 1} {
            ts_log_severe "could not create directory \"$spooldir\""
         }
      }
      set spooldir "$spooldir/$subdir"

      if {[file isdirectory $spooldir] != 1} {
         ts_log_finer "creating directory \"$spooldir\""
         file mkdir $spooldir
         if {[file isdirectory $spooldir] != 1} {
            ts_log_severe "could not create directory \"$spooldir\""
         }
      } else {
         if {[string compare $spooldir ""] != 0 } {
            ts_log_finer "deleting old spool dir entries in \"$spooldir\""
            if {[delete_directory $spooldir] != 0} { 
               ts_log_warning "could not remove spool directory $spooldir"
            }
            ts_log_finer "creating directory \"$spooldir\""
            file mkdir $spooldir
            if {[file isdirectory $spooldir] != 1} {
               ts_log_severe "could not create directory \"$spooldir\""
            }
         }
      }
      
      ts_log_finer "local spooldir is \"$spooldir\""
   } else {
      ts_log_severe "toplevel spool directory \"$spooldir\" not found"
      ts_log_fine "using no spool dir"
      set spooldir ""
   }
   return $spooldir
}




#****** file_procedures/cleanup_spool_dir_for_host() ***************************
#  NAME
#     cleanup_spool_dir_for_host() -- create or cleanup spool directory
#
#  SYNOPSIS
#     cleanup_spool_dir_for_host { hostname topleveldir subdir } 
#
#  FUNCTION
#     This procedure will create or cleanup old entries in the qmaster or execd 
#     spool directory
#
#  INPUTS
#     hostname    - remote host where to cleanup spooldir
#     topleveldir - path to spool toplevel directory ( updir of qmaster and execd )
#     subdir      - this paramter is master or execd
#
#  RESULT
#     if ok the procedure returns the correct spool directory. It returns  on 
#     error 
#
#  SEE ALSO
#     file_procedures/cleanup_spool_dir()
#*******************************************************************************
proc cleanup_spool_dir_for_host {hostname topleveldir subdir} {
   get_current_cluster_config_array ts_config

   set spooldir $topleveldir

   ts_log_fine "cleanup spool  directory \"$spooldir\" on host \"$hostname\""
   
   if {[remote_file_isdirectory $hostname $spooldir 1] == 1} {
      set spooldir "$spooldir/$ts_config(commd_port)"
      if {[remote_file_isdirectory $hostname $spooldir 1] != 1} {
          ts_log_finer "creating directory \"$spooldir\""
          remote_file_mkdir $hostname $spooldir 1
          if {[remote_file_isdirectory $hostname $spooldir 1] != 1} {
              ts_log_severe "could not create directory \"$spooldir\""
          }
      }

      set spooldir "$spooldir/$subdir"
      
      # spooldir might be shared between multiple hosts - e.g. Solaris zones.
      # clean only the spooldir of the specific exec host.
      if {$subdir == "execd"} {
         set spooldir "$spooldir/$hostname"
      }

      if {[remote_file_isdirectory $hostname $spooldir 1] != 1} {
          ts_log_finer "creating directory \"$spooldir\""
          remote_file_mkdir $hostname $spooldir
          if {[remote_file_isdirectory $hostname $spooldir 1] != 1} {
              ts_log_severe "could not create directory \"$spooldir\""
          } 
      } else {
         if {[string compare $spooldir ""] != 0} {
             ts_log_finer "deleting old spool dir entries in \"$spooldir\""
             if {[remote_delete_directory $hostname $spooldir 1] != 0} { 
                ts_log_warning "could not remove spool directory $spooldir"
             }
             ts_log_finer "creating directory \"$spooldir\""
             remote_file_mkdir $hostname $spooldir 1
             if {[remote_file_isdirectory $hostname $spooldir 1] != 1} {
                ts_log_severe "could not create directory \"$spooldir\""
             } 
         }
      }
      ts_log_finer "local spooldir is \"$spooldir\""
   } else {
      ts_log_severe "toplevel spool directory \"$spooldir\" not found"
      ts_log_fine "using no spool dir"
      set spooldir ""
   }

   return $spooldir
}


# return 0 if not
# return 1 if is directory
proc remote_file_isdirectory {hostname dir {win_local_user 0}} {
  global CHECK_USER
  start_remote_prog $hostname $CHECK_USER "cd" "$dir" prg_exit_state 60 0 "" "" 1 0 0 1 $win_local_user
  if { $prg_exit_state == 0 } {
     return 1  
  }
  return 0
}

#****** file_procedures/remote_file_mkdir() ************************************
#  NAME
#     remote_file_mkdir() -- creates remote directory path
#
#  SYNOPSIS
#     remote_file_mkdir { hostname dir {win_local_user 0} } 
#
#  FUNCTION
#     Remote mkdir -p $dir call
#
#  INPUTS
#     hostname           - remote host where the mkdir command should be started
#     dir                - full directory path
#     {win_local_user 0} - optional parameter which goes into start_remote_prog
#     {user ""}          - optional parameter which specifies the user. Default
#                          mkdir user is CHECK_USER
#     {permissions ""}   - optional parameter which specifies the file permissions
#                          of the created dir. (chmod permission parameter) 
#
#  RESULT
#     command output
#*******************************************************************************
proc remote_file_mkdir {hostname dir {win_local_user 0} {user ""} {permissions ""}} {
  global CHECK_USER
  if {$user == ""} {
     set exec_user $CHECK_USER
  } else {
     set exec_user $user
  }
  set result [start_remote_prog $hostname $exec_user "mkdir" "-p $dir" prg_exit_state 60 0 "" "" 1 0 0 1 $win_local_user]
  if {$prg_exit_state != 0} {
     ts_log_severe "Cannot create directory $dir as user $exec_user on host $hostname: $result"
  }
  if {$permissions != ""} {
      ts_log_fine "setting permissions of dir \"$dir\" to $permissions"
      start_remote_prog $hostname $exec_user "chmod" "$permissions $dir"
  }
  return $result
}

#****** file_procedures/remote_file_get_mtime() ***************************************
#  NAME
#     remote_file_get_mtime() -- get file modification time
#
#  SYNOPSIS
#     remote_file_get_mtime {hostname user path} 
#
#  FUNCTION
#     Returns the file modification time of a file on a certain host.
#     On error, an error condition is raised (ts_log_severe)
#     and 0 is returned.
#
#  INPUTS
#     hostname - the host on which to check the mtime
#     user     - the user who will do the check
#     path     - absolute filepath
#
#  RESULT
#     the file modification time, or 0 on error
#*******************************************************************************
proc remote_file_get_mtime {hostname user path} {
   global ts_config

   set time 0

   # we start an expect script to call file mtime
   set expect_bin [get_binary_path $hostname "expect"]
   set script "$ts_config(testsuite_root_dir)/scripts/file_mtime.tcl"
   set output [start_remote_prog $hostname $user $expect_bin "$script $path" prg_exit_state 60 0 "" "" 0 0]
   if {$prg_exit_state != 0} {
      ts_log_severe "retrieving modification time of file $path on host $hostname failed:\n$output"
   } else {
      set time $output
   }

   return $time
}

#****** file_procedures/check_for_core_files() *********************************
#  NAME
#     check_for_core_files() -- search for core files
#
#  SYNOPSIS
#     check_for_core_files { hostname path {do_remove 0} } 
#
#  FUNCTION
#     This procedure is searching for core files in the specified directory
#     and subdirectories. If found the core is chowned to CHECK_USER and an
#     info e-mail is generated.
#
#  INPUTS
#     hostname      - hostname where the core search is done
#     path          - directory path for starting the search
#     {do_remove 0} - if 1: delete the core if found
#
#  RESULT
#     integer value: nr of cores found
#*******************************************************************************
proc check_for_core_files {hostname path {do_remove 0}} {
   global CHECK_USER

   set nr_of_cores_found 0
   ts_log_fine "looking for core files in directory $path on host $hostname"

   # if directory does not (yet) exist, there can be no cores
   if {![remote_file_isdirectory $hostname $path 1]} {
      return $nr_of_cores_found
   }

   # try to find core files in path (-type f => only find regular files, no directories)
   set core_files [start_remote_prog $hostname $CHECK_USER "find" "$path -name core -type f -print" prg_exit_state 60 0 "" "" 1 0 0 1 1]
   if {$prg_exit_state != 0} {
      ts_log_severe "find core files in directory $path on host $hostname failed: $core_files"
   } else {
      set core_list [split $core_files "\n"]
      # process all cores found
      foreach core $core_list {
         # strip trailing empty lines
         set core [string trim $core]
         if {[string length $core] > 0} {
            incr nr_of_cores_found 1
            ts_log_finer "found core $core"

            # we need root access to determine file type (file may belong root)
            # and to change owner (for later delete)
            if {[have_root_passwd] == -1} {
               set_root_passwd 
            }

            # get file info of core file
            set core_info [start_remote_prog $hostname "root" "file" "$core" prg_exit_state 60 0 "" "" 1 0 0]
            if {$prg_exit_state != 0} {
               ts_log_severe "determining file type of core file $core on host $hostname failed: $core_info"
            } else {
               ts_log_info "found core file $core on host $hostname\n$core_info"
            }

            # chown core to $CHECK_USER.
            ts_log_finer "changing owner of core file $core to $CHECK_USER"
            set output [start_remote_prog $hostname "root" "chown" "$CHECK_USER $core" prg_exit_state 60 0 "" "" 1 0 0]
            if {$prg_exit_state != 0} {
               ts_log_severe "changing owner of core file $core on host $hostname failed: $output"
            }

            # remove if set
            if {$do_remove} {
               delete_remote_file $hostname $CHECK_USER $core
            }
         }
      }
   }
   return $nr_of_cores_found
}

#****** file_procedures/remote_delete_directory() ******************************
#  NAME
#     remote_delete_directory() -- delete directory on host
#
#  SYNOPSIS
#     remote_delete_directory { hostname path {win_local_user 0} } 
#
#  FUNCTION
#     This procedure is deleting the specified path on the specified host. 
#     All actions are started as CHECK_USER. If TS has the root
#     password a chwon -R $CHECK_USER $path is done as root user. 
#     If the testsuite_trash parameter was specified at TS startup
#     the directory content is moved to testsuite_trash folder.
#
#  INPUTS
#     hostname           - host where commands should be started
#     path               - full path of directory to delete
#     {win_local_user 0} - used for windows arch only and used for
#                          start_remote_prog call 
#
#  RESULT
#     0 on success, -1 on error
#
#  SEE ALSO
#     file_procedures/delete_directory
#*******************************************************************************
proc remote_delete_directory {hostname path {win_local_user 0}} {
   global CHECK_USER
   global CHECK_TESTSUITE_TRASH CHECK_ADMIN_USER_SYSTEM
   get_current_cluster_config_array ts_config

   set return_value -1

   ts_log_fine "$hostname: delete directory \"$path\" ..."
   # we move data to a trash directory instead of deleting them immediately
   # create the trash directory, if it does not yet exist
   if {$CHECK_TESTSUITE_TRASH} {
      ts_log_fine "delete directory \"$path\" on host \"$hostname\""
      if {[file isdirectory "$ts_config(testsuite_root_dir)/testsuite_trash"] != 1} {
         file mkdir "$ts_config(testsuite_root_dir)/testsuite_trash"
      }
   }

   # verify if directory is visible on the remote machine
   if {[remote_file_isdirectory $hostname $path $win_local_user] != 1} {
      ts_log_severe "$hostname: no such directory: \"$path\""
      return -1     
   }

   # we want to be carefull not to delete system directories
   # therefore we only accept pathes longer than 10 bytes
   if {[string length $path] > 10} {

      # If we have no admin user system and we have a root password then do a chown
      if {[have_root_passwd] == 0 && $CHECK_ADMIN_USER_SYSTEM == 0 } {
         # make sure we actually can delete the directory with all its contents.
         map_special_users $hostname $CHECK_USER $win_local_user
         ts_log_fine "doing chown -R $connect_full_user $path on $hostname as user root ..."
         start_remote_prog $hostname "root" chown "-R $connect_full_user $path" prg_exit_state 60 0 "" "" 1 0 0 1 $win_local_user
      }

      # we move the directory as CHECK_USER (admin user)
      if {$CHECK_TESTSUITE_TRASH} {
         ts_log_finer "delete_directory - moving \"$path\" to trash folder ..."
         set new_name [file tail $path] 

         start_remote_prog $hostname $CHECK_USER "mv" "$path $ts_config(testsuite_root_dir)/testsuite_trash/$new_name.[timestamp]" prg_exit_state 300 0 "" "" 1 0 0 1 $win_local_user
         if {$prg_exit_state != 0} {
            ts_log_finer "delete_directory - mv error"
            ts_log_finer "delete_directory - try to copy the directory"
            start_remote_prog $hostname $CHECK_USER "cp" "-r $path $ts_config(testsuite_root_dir)/testsuite_trash/$new_name.[timestamp]" prg_exit_state 300 0 "" "" 1 0 0 1 $win_local_user
            if {$prg_exit_state != 0} {
               ts_log_severe "$hostname: could not mv/cp directory \"$path\" to trash folder"
               set return_value -1
            } else {
               ts_log_finer "copy ok -  removing directory"
               set rm_output [start_remote_prog $hostname $CHECK_USER "rm" "-rf $path" prg_exit_state 300 0 "" "" 1 0 0 1 $win_local_user]
               if {$prg_exit_state != 0} {
                  ts_log_severe "$hostname ($CHECK_USER): could not remove directory \"$path\"\nexit state =\"$prg_exit_state\"\noutput:\n$rm_output"
                  set return_value -1
               } else {
                  ts_log_finer "done"
                  set return_value 0
               }
            }
         } else {
            set return_value 0
         }
      } else {
         ts_log_finer "delete_directory - removing directory \"$path\""
         set rm_output [start_remote_prog $hostname $CHECK_USER "rm" "-rf $path" prg_exit_state 300 0 "" "" 1 0 0 1 $win_local_user]
         if {$prg_exit_state != 0} {
            ts_log_severe "$hostname ($CHECK_USER): could not remove directory \"$path\"\nexit state =\"$prg_exit_state\"\noutput:\n$rm_output"
            set return_value -1
         } else {
            ts_log_finer "done"
            set return_value 0
         }
      }
   } else {
      ts_log_severe "$hostname: path is to short. Will not delete\n\"$path\""
      set return_value -1
   }
   return $return_value
}


#                                                             max. column:     |
#****** file_procedures/delete_file_at_startup() ******
# 
#  NAME
#     delete_file_at_startup -- remember file for later deletion
#
#  SYNOPSIS
#     delete_file_at_startup { filename } 
#
#  FUNCTION
#     This procedure adds the file $filename to the "testsuite delete file".
#     All files that are listed in the "testsuite delete file" are deleted at
#     the start of a testrun. 
#
#  INPUTS
#     filename - (full path) file name of file to delete later
#
#  RESULT
#     no results 
#
#  SEE ALSO
#     file_procedures/get_testsuite_delete_filename()
#     file_procedures/delete_local_file_at_startup()
#*******************************
proc delete_file_at_startup {filename} {
   get_current_cluster_config_array ts_config

   set del_file_name [get_testsuite_delete_filename]
   if {![file isfile $del_file_name]} {
       set del_file [open $del_file_name "w"]
   } else {
       set del_file [open $del_file_name "a"]
   }
   puts $del_file $filename
   close $del_file    
}

#****** file_procedures/delete_local_file_at_startup() *************************
#  NAME
#     delete_local_file_at_startup() -- remember local file for later deletion
#
#  SYNOPSIS
#     delete_local_file_at_startup { host filename } 
#
#  FUNCTION
#     This procedure adds the file $filename to the "testsuite local delete file".
#     All files that are listed in the "testsuite local delete file" are deleted at
#     the start of a testrun. 
#
#  INPUTS
#     host     - host where the file must be deleted
#     filename - (full path) file name of file to delete later
#
#  RESULT
#     no returns
#
#  SEE ALSO
#     file_procedures/delete_file_at_startup()
#     file_procedures/get_testsuite_delete_filename()
#*******************************************************************************
proc delete_local_file_at_startup {host filename} {
   get_current_cluster_config_array ts_config
   set del_file_name [get_testsuite_delete_filename 1]
   if {![file isfile $del_file_name]} {
       set del_file [open $del_file_name "w"]
   } else {
       set del_file [open $del_file_name "a"]
   }
   puts $del_file "$host:$filename"
   close $del_file    
}

#                                                             max. column:     |
#****** file_procedures/delete_file() ******
# 
#  NAME
#     delete_file -- move/copy file to testsuite trashfolder 
#
#  SYNOPSIS
#     delete_file { filename { do_wait_for_file 1 } } 
#
#  FUNCTION
#     This procedure will delete the file,
#     or move it to the testsuite's trashfolder 
#     (Directory testsuite_trash in the testsuite root directory). 
#
#  INPUTS
#     filename             - full path file name of file 
#     {do_wait_for_file 1} - optional wait for file before removing
#
#  RESULT
#     no results 
#
#  TODO: use delete_remote_file where ever possible
#  SEE ALSO
#     file_procedures/delete_directory
#*******************************
proc delete_file {filename {do_wait_for_file 1}} {
   global CHECK_TESTSUITE_TRASH
   get_current_cluster_config_array ts_config

   ts_log_fine "deleting file \"$filename\""

   if {$do_wait_for_file == 1} {
      wait_for_file $filename 60 0 0 ;# wait for file, no error reporting!
   } else {
      if {[file isfile $filename] != 1} {
         ts_log_finer "delete_file - no such file: \"$filename\""
         return      
      }
   }

   if {[file isfile $filename] != 1} {
      ts_log_severe "no such file: \"$filename\""
      return      
   }

   if {$CHECK_TESTSUITE_TRASH} {
      if {[file isdirectory "$ts_config(testsuite_root_dir)/testsuite_trash"] != 1} {
         file mkdir "$ts_config(testsuite_root_dir)/testsuite_trash"
      }
   }

   set deleted_file 0 
   if {[string length $filename] > 10} {
      if {$CHECK_TESTSUITE_TRASH} {
         ts_log_finer "delete_file - moving \"$filename\" to trash folder ..."
         set new_name [file tail $filename] 
         set catch_return [catch { 
            file rename $filename $ts_config(testsuite_root_dir)/testsuite_trash/$new_name.[timestamp]
         } result] 
         if {$catch_return != 0} {
            ts_log_finer "delete_file - mv error:\n$result"
            ts_log_finer "delete_file - try to copy the file"
            set catch_return [catch { 
               file copy $filename $ts_config(testsuite_root_dir)/testsuite_trash/$new_name.[timestamp]
            } result] 
            if {$catch_return != 0} {
              ts_log_severe "could not mv/cp file \"$filename\" to trash folder:\n$result"
            } else {
              ts_log_finer "copy ok - deleting file \"$filename\""
              set catch_return [catch {file delete -force $filename} result] 
              if {$catch_return != 0} {
                 ts_log_severe "could not remove file \"$filename\":\n$result"
              } else {
                 ts_log_finer "done"
                 set deleted_file 1
              }
            }
         } else {
           set deleted_file 1
         }
      } else {
        set catch_return [catch {file delete -force $filename} result] 
        if {$catch_return != 0} {
           ts_log_severe "could not remove file \"$filename\":\n$result"
        } else {
           ts_log_finer "done"
           set deleted_file 1
        }
      }
      if {$deleted_file == 1} {
         wait_for_file "$filename" "200" "1" ;# wait for file do disappear in filesystem!
      }
   } else {
      ts_log_severe "file path is to short. Will not delete\n\"$filename\""
   }
}


#                                                             max. column:     |
#****** file_procedures/wait_for_file() ******
# 
#  NAME
#     wait_for_file -- wait for file to appear/dissappear/... 
#
#  SYNOPSIS
#     wait_for_file { path_to_file seconds { to_go_away 0 } 
#     { do_error_check 1 } } 
#
#  FUNCTION
#     Wait a given number of seconds fot the creation or deletion of a file. 
#
#  INPUTS
#     path_to_file         - full path file name of file 
#     seconds              - timeout in seconds 
#     { to_go_away 0 }     - flag, (0=wait for creation, 1 wait for deletion) 
#     { do_error_check 1 } - flag, (0=do not report errors, 1 report errors) 
#
#  RESULT
#     -1 for an unsuccessful waiting, 0 no errors 
#
#  SEE ALSO
#     file_procedures/delete_directory
#     sge_procedures/wait_for_load_from_all_queues
#     file_procedures/wait_for_file
#     sge_procedures/wait_for_jobstart
#     sge_procedures/wait_for_end_of_transfer
#     sge_procedures/wait_for_jobpending
#     sge_procedures/wait_for_jobend
#*******************************
proc wait_for_file {path_to_file seconds {to_go_away 0} {do_error_check 1}} {
   if {$to_go_away == 0} {
      ts_log_fine [format "looking for file \"%s\" to appear" $path_to_file]
   } else {
      ts_log_fine [format "looking for file \"%s\" to vanish" $path_to_file]
   }

   set time [expr [timestamp] + $seconds]
   set wasok -1
   
   if {$to_go_away == 0} {
      ts_log_finer "Looking for creation of the file \"$path_to_file\" ..."
      while {[timestamp] < $time} {
        if {[file isfile "$path_to_file"]} {
           set wasok 0
           break
        }
        after 500
      }
      if {$wasok != 0 && $do_error_check == 1} {
         ts_log_severe "timeout error while waiting for creation of file \"$path_to_file\""
      } 
   } else {
      ts_log_finer "Looking for deletion of the file \"$path_to_file\" ..."
      while {[timestamp] < $time}  {
        if {[file isfile "$path_to_file"] != 1} {
           set wasok 0
           break
        }
        after 1000
      }
      if {$wasok != 0 && $do_error_check == 1} {
         ts_log_severe "timeout error while waiting for deletion file \"$path_to_file\""
      } 
   }
   return $wasok
}


#****** file_procedures/wait_for_remote_file() *********************************
#  NAME
#     wait_for_remote_file() -- waiting for a file to apear (NFS-Check)
#
#  SYNOPSIS
#     wait_for_remote_file { hostname user path { mytimeout 60 } } 
#
#  FUNCTION
#     The function is using the ls command on the remote host. If the command
#     returns no error the procedure returns. Otherwise an error is reported
#     when reaching timeout value.
#
#  INPUTS
#     hostname         - host where the file should be checked
#     user             - user id who performs check
#     path             - full path to file
#     { mytimeout 60 } - timeout in seconds
#     {raise_error 1}  - do report errors?
#     {to_go_away}     - if 1 the method waits until the file disappears
#                        else it waits until the file appears
#     {method "complete_remote"}  - if this parameter is "complete_remote" the wait_for_remote_file.exp scripts is
#                        used. Otherwise the traditional method is used
#
#  RESULT
#     0 on success
#     -1 on error
#   
#  SEE ALSO
#     file_procedures/wait_for_file()
#     file_procedures/wait_for_remote_dir()
#*******************************************************************************
proc wait_for_remote_file {hostname user path {mytimeout 60} {raise_error 1} {to_go_away 0} { method "complete_remote"} } {
   global ts_host_config
   global ts_config


   if {$to_go_away == 0} {
      ts_log_fine "looking for file \"$path\" to appear on host $hostname"
   } else {
      ts_log_fine "looking for file \"$path\" to vanish on host $hostname"
   }

   set is_windows 0
   if {[host_conf_get_arch $hostname] == "win32-x86"} {
      set is_windows 1
      set method "tradditional"
   }
   if { $method == "complete_remote"} {
      set exp_cmd [get_binary_path $hostname "expect"]
      if {$exp_cmd != ""} {
         set cmd_timeout [expr $mytimeout + 10]
         set output [start_remote_prog $hostname $user "$exp_cmd" \
                                       "$ts_config(testsuite_root_dir)/scripts/wait_for_file.exp file $path $mytimeout $to_go_away" \
                                       prg_exit_state $cmd_timeout 0 "" "" 0 0]

         if {$to_go_away == 0} {
            switch -exact -- $prg_exit_state {
               "0" { ts_log_finer  "ok - file exists on host $hostname" }
               "1" { ts_log_severe "Timeout while waiting for remote file $path on host $hostname to appear" $raise_error }
               "2" { ts_log_severe "Invalid arguments for wait_for_file script" $raise_error }
               "3" { ts_log_severe "Expected that path $path is a file, however it is a directory" $raise_error }
               default { ts_log_severe "wait_for_file.exp script exited which unexpected error code ($prg_exit_state)" }
            }
         } else {
            switch -exact -- $prg_exit_state {
               "0" { ts_log_finer  "ok - file exists on host $hostname" }
               "1" { ts_log_severe "Timeout while waiting for remote file $path on host $hostname to vanish" $raise_error }
               "2" { ts_log_severe "Invalid arguments for wait_for_file script" $raise_error }
               "3" { ts_log_severe "Expected that path $path is a file, however it is a directory" $raise_error }
               default { ts_log_severe "wait_for_file.exp script exited which unexpected error code ($prg_exit_state)" }
           }
         }
         if {$prg_exit_state == 0} {
            return 0
         }
         return -1
      }
   }

   # Here starts the old legacy code for the case that expect is not defined in the host
   # configuration
   set is_ok 0
   set my_mytimeout [expr [timestamp] + $mytimeout] 
   set have_logged_a_dot 0
   set dir [file dirname $path]

   while {$is_ok == 0} {
      # It seems that a ls -al on the parent directory flush nfs caches
      # However on windows hosts the ls -al does not work
      if {$is_windows == 1} {
         set output [start_remote_prog $hostname $user "test" "-f $path" prg_exit_state 60 0 "" "" 0 0]
      } else {
         set output [start_remote_prog $hostname $user "ls" "-al $dir > /dev/null && test -f $path" prg_exit_state 60 0 "" "" 0 0]
      }
      if {$to_go_away == 0} {
         # The file must be here
         if {$prg_exit_state == 0} {
            set is_ok 1
            break
         } 
      } else {
         # The file must NOT be here
         if {$prg_exit_state != 0} {
            set is_ok 1
            break
         } 
      }
      ts_log_progress
      set have_logged_a_dot 1
      if {[timestamp] >= $my_mytimeout} {
         break
      }
      after 500
   }
   if {$have_logged_a_dot} {
      ts_log_newline
   }
   if {$is_ok == 1} {
      if {$to_go_away == 0} {
         ts_log_finer "ok - file exists on host $hostname"
         set prg_exit_state 101
         while {[timestamp] <= $my_mytimeout} {
            set output [start_remote_prog $hostname $user "cat" "$path > /dev/null" prg_exit_state 60 0 "" "" 0 0]
            if {$prg_exit_state == 0} {
               break
            }
            after 500
         }
         if {$prg_exit_state == 101} {
            ts_log_severe "$hostname: timeout while waiting for file $path"
         } else {
            if {$prg_exit_state != 0} {
               ts_log_severe "$hostname: output of cat $path (on a file which was tested with test -f): \n$output\nexit_state=$prg_exit_state"
            }
         }
         if {$have_logged_a_dot} {
            ts_log_newline
         }
      } else {
         ts_log_finer "ok - file does not exist anymore on host $hostname"
      }
      return 0;
   } else {
      if {$to_go_away == 0} {
         ts_log_severe "timeout while waiting for remote file $path on host $hostname to appear" $raise_error
      } else {
         ts_log_severe "timeout while waiting for remote file $path on host $hostname to vanish" $raise_error
      }
      return -1;
   }
}


#****** file_procedures/wait_for_remote_dir() *********************************
#  NAME
#     wait_for_remote_dir() -- waiting for a file to apear (NFS-Check)
#
#  SYNOPSIS
#     wait_for_remote_dir { hostname user path { mytimeout 60 } } 
#
#  FUNCTION
#     The function is using the ls command on the remote host. If the command
#     returns no error the procedure returns. Otherwise an error is reported
#     when reaching timeout value.
#
#  INPUTS
#     hostname         - host where the file should be checked
#     user             - user id who performs check
#     path             - full path to file
#     { mytimeout 60 } - timeout in seconds
#     {raise_error 1}  - do report errors?
#     {to_go_away}     - if 1 the method waits until the directory disappears
#                        else it waits until the directory appears
#     {method "fast}   - if this parameter is "complete_remote" the wait_for_remote_file.exp scripts is
#                        used. Otherwise the traditional method is used
#  RESULT
#     0 on success
#     -1 on error
#   
#  SEE ALSO
#     file_procedures/wait_for_file()
#     file_procedures/wait_for_remote_file()
#*******************************************************************************
proc wait_for_remote_dir { hostname user path { mytimeout 60 } {raise_error 1} {to_go_away 0} {method "complete_remote"}} {

   global ts_host_config
   global ts_config


   if {$to_go_away == 0} {
      ts_log_fine [format "looking for directory \"%s\" on host \"%s\" as user \"%s\" to appear" $path $hostname $user]
   } else {
      ts_log_fine [format "looking for directory \"%s\" on host \"%s\" as user \"%s\" to vanish" $path $hostname $user]
   }

   set is_windows 0
   if {[host_conf_get_arch $hostname] == "win32-x86"} {
      set is_windows 1
      set method "tradditional"
   }

   if {$method == "complete_remote"} {
      set exp_cmd [get_binary_path $hostname "expect"]
      if {$exp_cmd != ""} {
         set cmd_timeout [expr $mytimeout + 10]
         set output [start_remote_prog $hostname $user "$exp_cmd" \
                                       "$ts_config(testsuite_root_dir)/scripts/wait_for_file.exp dir $path $mytimeout $to_go_away" \
                                       prg_exit_state $cmd_timeout 0 "" "" 0 0]
         if {$to_go_away == 0} {
            switch -exact -- $prg_exit_state {
               "0" { ts_log_finer  "ok - directory exists on host $hostname" }
               "1" { ts_log_severe "Timeout while waiting for remote directory $path on host $hostname to appear" $raise_error }
               "2" { ts_log_severe "Invalid arguments for wait_for_file script" $raise_error }
               "3" { ts_log_severe "Expected that path $path is a directory, however it is a directory" $raise_error }
               default { ts_log_severe "wait_for_file.exp script exited which unexpected error code ($prg_exit_state)" }
            }
         } else {
            switch -exact -- $prg_exit_state {
               "0" { ts_log_finer  "ok - file exists on host $hostname" }
               "1" { ts_log_severe "Timeout while waiting for remote directory $path on host $hostname to vanish" $raise_error }
               "2" { ts_log_severe "Invalid arguments for wait_for_file script" $raise_error }
               "3" { ts_log_severe "Expected that path $path is a directory, however it is a file" $raise_error }
               default { ts_log_severe "wait_for_file.exp script exited which unexpected error code ($prg_exit_state)" }
            }
         }
         if {$prg_exit_state == 0} {
            return 0
         }
         return -1
      }
   }

   # Here starts the old legacy code for the case that expect is not defined in the host
   # configuration
   set is_ok 0
   set my_mytimeout [expr [timestamp] + $mytimeout] 
   set dir [file dirname $path]

   while {$is_ok == 0} {
      # It seems that a ls -al on the parent directory flush nfs caches
      # However on windows hosts the ls -al does not work
      if {$is_windows == 1} {
         set output [start_remote_prog $hostname $user "test" "-d $path" prg_exit_state 60 0 "" "" 0 0]
      } else {
         set output [start_remote_prog $hostname $user "ls" "-al $dir > /dev/null && test -d $path" prg_exit_state 60 0 "" "" 0 0]
      }
  
      if {$to_go_away == 0} {
         # The directory must be here
         if {$prg_exit_state == 0} {
            set is_ok 1
            break
         } 
      } else {
         # The directory must NOT be here
         if {$prg_exit_state != 0} {
            set is_ok 1
            break
         } 
      }
      ts_log_progress
      if {[timestamp] > $my_mytimeout} {
         break
      }
      after 500
   }
   if {$is_ok == 1} {
      if {$to_go_away == 0} {
         ts_log_finer "ok - directory exists on host $hostname"
      } else {
         ts_log_finer "ok - directory does not exist anymore on host $hostname"
      }
      return 0;
   } else {
      ts_log_finer "timeout"
      if {$raise_error} {
         ts_log_severe "timeout while waiting for remote directory $path on host $hostname"
      }
      return -1;
   }
}



#****** file_procedures/is_remote_file() ***************************************
#  NAME
#     is_remote_file() -- check if file exists on remote host
#
#  SYNOPSIS
#     is_remote_file {hostname user path} 
#
#  FUNCTION
#     This function is starting an ls command on the remote host as specified
#     user. If the exit status of the ls $path is 0 the function returns 1.
#
#  INPUTS
#     hostname - remote host name
#     user     - user who should start the ls
#     path     - full path name of file
#
#  RESULT
#     1 - file found
#     0 - file not found
#
#  SEE ALSO
#     file_procedures/wait_for_file()
#     file_procedures/wait_for_remote_file()
#*******************************************************************************
proc is_remote_file {hostname user fpath {be_quiet 0}} {
   set path [string trim $fpath]
   if {$path == ""} {
      ts_log_severe "got no path parameter!"
      return 0;
   }
   set output [start_remote_prog $hostname $user "test" "-f $path" prg_exit_state 60 0 "" "" 0]
   if {$prg_exit_state == 0} {
      if {$be_quiet == 0} {
         ts_log_finest "found file: $hostname:$path"
      }
      return 1;
   } 
   if {$be_quiet == 0} {
      ts_log_finest "file not found: $hostname:$path"
   }
   return 0;
}

#****** path_procedures/is_remote_path() ***************************************
#  NAME
#     is_remote_path() -- check if path exists on remote host
#
#  SYNOPSIS
#     is_remote_path { hostname user path {be_quiet 0}} 
#
#  FUNCTION
#     This function is starting an ls command on the remote host as specified
#     user. If the exit status of the ls $path is 0 the function returns 1.
#
#  INPUTS
#     hostname - remote host name
#     user     - user who should start the ls
#     path     - full path name of path
#     {be_quiet 0} - if 1 do not do logging of information
#
#  RESULT
#     1 - path found
#     0 - path not found
#
#  SEE ALSO
#     path_procedures/wait_for_path()
#     path_procedures/wait_for_remote_path()
#*******************************************************************************
proc is_remote_path {hostname user path} {
   set output [start_remote_prog $hostname $user "test" "-d $path" prg_exit_state 60 0 "" "" 0 0]
   if {$prg_exit_state == 0} {
      ts_log_finest "found path: $hostname:$path"
      return 1;
   } 
   ts_log_finest "path not found: $hostname:$path"
   return 0;
}



#****** file_procedures/delete_remote_file() ***********************************
#  NAME
#     delete_remote_file() -- delete a remote file if existing
#
#  SYNOPSIS
#     delete_remote_file { hostname user path } 
#
#  FUNCTION
#     This function will check if the file (full path name) $path is existing
#     on the remote host $host and delete the file if existing.
#     The remote actions are executed as user $user.
#
#  INPUTS
#     hostname - remote host name
#     user     - name of user which will delete the file
#     path     - full path name 
#
#  RESULT
#     ??? 
#
#  SEE ALSO
#     file_procedures/remote_file_mkdir()
#     file_procedures/remote_delete_directory()
#     file_procedures/wait_for_remote_file()
#     file_procedures/is_remote_file()
#     file_procedures/delete_remote_file()
#*******************************************************************************
proc delete_remote_file {hostname user path {win_local_user 0}} {
   if {[is_remote_file $hostname $user $path]} {
      ts_log_fine "deleting file $path on host $hostname as user $user ..."
      set output [start_remote_prog $hostname $user "rm" "$path" prg_exit_state 60 0 "" "" 0 0 0 1 $win_local_user]
      ts_log_finest $output
      wait_for_remote_file $hostname $user $path 90 1 1
   } else {
      ts_log_fine "file $path not found on host $hostname as user $user!"
   }
}

#                                                             max. column:     |
#****** file_procedures/delete_directory() ******
# 
#  NAME
#     delete_directory -- move/copy directory to testsuite trashfolder 
#
#  SYNOPSIS
#     delete_directory { path } 
#
#  FUNCTION
#     This procedure will delete the given directory,
#     or move it to the testsuite's 
#     trashfolder (Directory testsuite_trash in the testsuite root directory). 
#
#  INPUTS
#     path - full directory path 
#
#  RESULT
#     -1 on error, 0 ok 
#
#  SEE ALSO
#     file_procedures/delete_directory()
#*******************************
proc delete_directory {path} { 
   global CHECK_USER CHECK_TESTSUITE_TRASH
   get_current_cluster_config_array ts_config

   # try to delete on the file server
   set host [fs_config_get_server_for_path $path 0]
   if {$host == ""} {
      set host [gethostname]
   }

   ts_log_fine "delete directory \"$path\" on host \"$host\""

   return [remote_delete_directory $host $path]
}

#****** file_procedures/init_logfile_wait() ************************************
#  NAME
#     init_logfile_wait() -- observe logfiles by using tail functionality (1)
#
#  SYNOPSIS
#     init_logfile_wait { hostname logfile } 
#
#  FUNCTION
#     This procedure is using starting an open remote spawn connection
#     in order to start a tail process that observes the given
#     file. The open spawn id is stored in a global variable to make it
#     possible for the logfile_wait() procedure to expect data from
#     the tail process.
#     Each call of this procedure must follow a call of logfile_wait() in
#     order to close the open spawn process.
#
#  RETURN
#      spawn id of process (internal format, see close_spawn_process for details)
#
#  INPUTS
#     hostname - host where tail should be started
#     logfile  - full path name of (log)file
#
#  SEE ALSO
#     file_procedures/logfile_wait()
#     file_procedures/close_logfile_wait()
#*******************************************************************************
proc init_logfile_wait {hostname logfile} {
   global file_procedure_logfile_wait_sp_id CHECK_USER CHECK_DEBUG_LEVEL

   set sid [open_remote_spawn_process $hostname $CHECK_USER "tail" "-f $logfile"]
   set sp_id [lindex $sid 1]
   ts_log_finest "spawn id: $sp_id"

   if {$CHECK_DEBUG_LEVEL > 0} {
      log_user 1
   }
   set timeout 2
   expect {
      -i $sp_id full_buffer {
         ts_log_severe "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
      }
      -i $sp_id eof {
         ts_log_severe "eof while waiting for output from tail -f $logfile"
      }
      -i $sp_id "_exit_status_" {
         ts_log_severe "tail -f $logfile exited"
      }
      -i $sp_id timeout {
      }
      -i $sp_id "\n" {
         ts_log_finest $expect_out(buffer)
         exp_continue
      }
   }
   log_user 0
   ts_log_finest "init_logfile_wait done"
   set file_procedure_logfile_wait_sp_id $sid

   return $sid
}

#****** file_procedures/logfile_wait() *****************************************
#  NAME
#     logfile_wait() -- observe logfiles by using tail functionality (2)
#
#  SYNOPSIS
#     logfile_wait {
#                    { wait_string ""     } 
#                    { mytimeout 60       }
#                    { close_connection 1 } 
#                    { add_errors 1       } 
#                    { return_err_code "logfile_wait_error" }
#                  } 
#
#  FUNCTION
#     This procedure is called after an init_logfile_wait() call. It will
#     use the open spawn process started from that procedure. When the
#     output of the tail command contains the string given in "wait_string"
#     the procedure returns immediately. If the caller hasn't provided an
#     "wait_string" the procedure returns after the given timeout without
#     error.
#
#  INPUTS
#     { wait_string "" }     - if the tail process generates output 
#                              containing this string the procedure 
#                              returns
#     { mytimeout 60 }       - timeout in seconds
#
#     { close_connection 1 } - if 0, don't close tail process
#
#     { add_errors 1       } - if 0, don't raise an error condidition
#
#     { return_err_code "logfile_wait_error" } 
#                            - variable where the return
#                              value is stored:
#                              0  : no error
#                              -1 : timeout error
#                              -2 : full expect buffer 
#                              -3 : unexpected end of file
#                              -4 : unexpected end of tail command
#     {message_line_list {}} - list of messages which should be found in
#                              the tail output file. This is a per line
#                              message string search. All elements in the
#                              list must be found in the tail output before
#                              logfile_wait returns.
#
#
#  RESULT
#     This procedure returns the output of the tail command since the 
#     init_logfile_wait() call.
# 
#  SEE ALSO
#     file_procedures/init_logfile_wait()
#     file_procedures/close_logfile_wait()
#*******************************************************************************
proc logfile_wait {{wait_string ""} {mytimeout 60} {close_connection 1} {add_errors 1} {return_err_code "logfile_wait_error"} {message_line_list {}}} {
   global file_procedure_logfile_wait_sp_id

   upvar $return_err_code back_value

   set back_value 0

   set sp_id [lindex $file_procedure_logfile_wait_sp_id 1]
   ts_log_finest "spawn id: $sp_id"
   set real_timeout [ expr [timestamp] + $mytimeout]
   set timeout 3
   set my_tail_buffer ""
   log_user 0

   # init line list match memory array
   foreach line $message_line_list {
      set lines_ok($line) 0
   }

   ts_log_fine "starting log file wait ..."

   expect {
      -i $sp_id -- full_buffer {
         if {$add_errors == 1} {
            ts_log_severe "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
         }
         set back_value -2
      }

      -i $sp_id eof {
         if {$add_errors == 1} {
            ts_log_severe "unexpected end of file"
         }
         set back_value -3
      }
      -i $sp_id -- "_exit_status_" { 
         if {$add_errors == 1} {
            ts_log_severe "unexpected end of tail command"
         }
         set back_value -4
      }
      -i $sp_id timeout {
         if {[timestamp] > $real_timeout} {
            if {$wait_string != "" || [llength $message_line_list] > 0} {
               if {$add_errors == 1} {
                  ts_log_severe "timeout waiting for logfile content"
               }
               set back_value -1
            }
         } else {
            ts_log_progress
            exp_continue
         }
      }
      -i $sp_id -- "\n" {
         ts_log_fine "\r$expect_out(buffer)"
         append my_tail_buffer $expect_out(buffer)

         set do_continue 1

         # if we have a wait string ...
         if {$wait_string != ""} {
            if {[string match "*${wait_string}*" $my_tail_buffer] == 1} {
               ts_log_fine "found expected wait string: $wait_string"
               set do_continue 0
            }
         }

         # if we have a message list ...
         if {[llength $message_line_list] > 0} {
            foreach line [split $expect_out(buffer) "\n"] {
               foreach exp_line $message_line_list {
                  if {[string match "*$exp_line*" $line] == 1} {
                     ts_log_fine "found expected line: $exp_line"
                     set lines_ok($exp_line) 1
                  } 
               }
            }
            set do_leave 1
            foreach line $message_line_list {
               if {$lines_ok($line) == 0} { 
                  set do_leave 0
                  ts_log_fine "still missing: \"$line\""
               } else {
                  ts_log_fine "found string:  \"$line\""
               }
            }
            if {$do_leave == 1} {
               set do_continue 0
            }
         }

         if {$do_continue == 1} {
            exp_continue
         }
      }
   }

   ts_log_fine "log file wait returns now ..."
   if {$close_connection == 1} {
      close_spawn_process $file_procedure_logfile_wait_sp_id
   }
   log_user 1
   return $my_tail_buffer
}

#****** file_procedures/close_logfile_wait() ***********************************
#  NAME
#     close_logfile_wait() -- close open_spawn_connection id for tail process
#
#  SYNOPSIS
#     close_logfile_wait { } 
#
#  FUNCTION
#     This procedure is used for closing an open tail process, started with
#     init_logfile_wait(), when logfile_wait() is called with 
#     "close_connection != 1" parameter.
#
#  SEE ALSO
#     file_procedures/init_logfile_wait()
#     file_procedures/logfile_wait()
#*******************************************************************************
proc close_logfile_wait { } {
   global file_procedure_logfile_wait_sp_id

   close_spawn_process $file_procedure_logfile_wait_sp_id
}

#****** file_procedures/washing_machine() **************************************
#  NAME
#     washing_machine() -- showing a washing machine ;-)
#
#  SYNOPSIS
#     washing_machine { time { small 0 } } 
#
#  FUNCTION
#     This procedure returns "\r[/|\-] $time [/|\-]", depending on the 
#     given time value.
#
#  INPUTS
#     time      - timout counter 
#     { small } - if > 0 -> just return [/|\-], depending on $time
#
#  RESULT
#     string, e.g. "/ 40 /"
#*******************************************************************************
proc washing_machine {time {small 0}} {
   global CHECK_USE_HUDSON
   
   #No washing machine when running for Hudson
   if {$CHECK_USE_HUDSON == 1} {
      return
   }
   
   set ani [expr $time % 4]
   switch $ani {
      0 { set output "-" }
      1 { set output "/" }
      2 { set output "|" }
      3 { set output "\\" }
   }
   if {$small != 0} {
      return "$output"
   } else {
      return "\r              \r$output $time $output\r"
   }
}

#****** file_procedures/create_path_aliasing_file() ****************************
#  NAME
#     create_path_aliasing_file() -- ??? 
#
#  SYNOPSIS
#     create_path_aliasing_file { filename data elements } 
#
#  FUNCTION
#     This procedure will create a path aliasing file.
#
#  INPUTS
#     filename - full path file name of path aliasing file
#     data     - data array with following fields:
#                arrayname(src-path,$i)
#                arrayname(sub-host,$i)
#                arrayname(exec-host,$i)
#                arrayname(replacement,$i)
#                where $i is the index number of each entry 
#     elements - nr. of entries (starting from zero)
#
#  EXAMPLE
#     set data(src-path,0)     "/tmp_mnt/"
#     set data(sub-host,0)     "*"
#     set data(exec-host,0)    "*" 
#     set data(replacement,0)  "/home/"
#     create_path_aliasing_file /tmp/test.txt data 1
#      
#  SEE ALSO
#     file_procedures/create_shell_script()
#     
#    
#*******************************************************************************
proc create_path_aliasing_file {filename data elements} {
   upvar $data mydata
 
   ts_log_fine "creating path alias file: $filename"

# Path Aliasing File
# src-path                sub-host   exec-host   replacement
# /tmp_mnt/                  *          *           /
# /private/var/automount/    *          *           /
#     
# replaces any occurrence of /tmp_mnt/ by /
# if submitting or executing on any host.
# Thus paths on nfs server and clients are the same

#     <sge_root>/<cell>/common/sge_aliases    global alias file
#     $HOME/.sge_aliases                         user local aliases file

   if {[file isfile $filename] == 1} {
      ts_log_severe "file $filename already exists"
      return
   }

   set fout [open "$filename" "w"] 
   puts $fout "# testsuite automatic generated Path Aliasing File\n# \"$filename\""
   puts $fout "# src-path   sub-host   exec-host   replacement"
   puts $fout "#     /tmp_mnt/    *          *           /"
   puts $fout "# replaces any occurrence of /tmp_mnt/ by /"
   puts $fout "# if submitting or executing on any host."
   puts $fout "# Thus paths on nfs server and clients are the same"
   puts $fout "##########"
   puts $fout "# <sge_root>/<cell>/common/sge_aliases    global alias file"
   puts $fout "# \$HOME/.sge_aliases                         user local aliases file"
   puts $fout "##########"
   puts $fout "# src-path   sub-host   exec-host   replacement"
   for {set i 0} {$i < $elements} {incr i} {
       if {[info exists mydata(src-path,$i)] != 1} {
          ts_log_severe "array has no (src-path,$i) element"
          break
       } 
       set    line "[set mydata(src-path,$i)]\t"
       append line "[set mydata(sub-host,$i)]\t" 
       append line "[set mydata(exec-host,$i)]\t"
       append line "[set mydata(replacement,$i)]"
       puts $fout $line
   } 
   flush $fout
   close $fout
}

#****** file_procedures/add_to_path_aliasing_file() ****************************
#  NAME
#     add_to_path_aliasing_file() -- adds entries to the sge_aliases file
#
#  SYNOPSIS
#     add_to_path_aliasing_file { filename data elements } 
#
#  FUNCTION
#     This procedure will add entries to the path aliasing file.
#
#  INPUTS
#     filename - full path file name of path aliasing file
#     data     - data array with following fields:
#                arrayname(src-path,$i)
#                arrayname(sub-host,$i)
#                arrayname(exec-host,$i)
#                arrayname(replacement,$i)
#                where $i is the index number of each entry 
#     elements - nr. of entries (starting from zero)
#
#  EXAMPLE
#     set data(src-path,0)     "/tmp_mnt/"
#     set data(sub-host,0)     "*"
#     set data(exec-host,0)    "*" 
#     set data(replacement,0)  "/home/"
#     add_to_path_aliasing_file /tmp/test.txt data 1
#      
#  SEE ALSO
#     file_procedures/create_path_aliasing_file()
#*******************************************************************************
proc add_to_path_aliasing_file {filename data elements} {
   upvar $data mydata

   set fout [open "$filename" "a"] 

   for {set i 0} {$i < $elements} {incr i} {
       if {[info exists mydata(src-path,$i)] != 1} {
          ts_log_severe "array has no (src-path,$i) element"
          break
       } 
       set    line "[set mydata(src-path,$i)]\t"
       append line "[set mydata(sub-host,$i)]\t" 
       append line "[set mydata(exec-host,$i)]\t"
       append line "[set mydata(replacement,$i)]"
       puts $fout $line
   } 
   close $fout
}

# do we have access to a tty?
# returns true, if we have access to a tty (via stdout)
proc check_output_is_tty {} {
   set ret 0

   set result [catch stty output]
   # and we have a tty
   if {$result == 0} {
      set ret 1
   }

   return $ret
}

#****** file_procedures/get_local_spool_dir() ********************************************
#  NAME
#     get_local_spool_dir() -- get local spool dir for an host
#
#  SYNOPSIS
#     get_local_spool_dir { host subdir {do_cleanup 1} } 
#
#  FUNCTION
#     This procedure returns the path to the local spool directory for the given
#     host
#
#  INPUTS
#     host           - hostname
#     subdir         - "execd" or "qmaster" or "hedeby_spool"
#     {do_cleanup 1} - if 1: delete spool dir contents
#
#  RESULT
#     path to spool directory 
#
#  SEE ALSO
#     file_procedures/get_spool_dir()
#*******************************************************************************
proc get_local_spool_dir {host subdir {do_cleanup 1}} {
   global ts_host_config 
   global check_do_not_use_spool_config_entries
   get_current_cluster_config_array ts_config

   set spooldir ""
   set is_master_host 0
   if {$check_do_not_use_spool_config_entries == 2 &&
       $subdir == "qmaster"} {
      if {[resolve_host $host] == [resolve_host $ts_config(master_host)]} {
         ts_log_finer "\"no_local_qmaster_spool\" option is set, this is master host"
         set is_master_host 1
      }
   }

   # special case: suppress local spooldirectories
   # and even more special: In SGE 6.2, shared spooldirs are no longer possible
   # on Windows - here we really need a local spooldir.
   # And as shared spooldirs are causing problems on Windows,
   # we do not support them at all!
   if {$check_do_not_use_spool_config_entries == 1} {
      if {[resolve_arch $host] == "win32-x86"} {
         ts_log_finer "\"no_local_spool\" option is set, but we are on Windows - allowing local spool dir"
      } else {
         ts_log_finer "\"no_local_spool\" option is set - returning empty spool dir" 
         return $spooldir
      }
   }

   if {$check_do_not_use_spool_config_entries == 2 &&
       $is_master_host &&
       $subdir == "qmaster"} {
      if {[resolve_arch $host] == "win32-x86"} {
         ts_log_finer "\"no_local_qmaster_spool\" option is set, but we are on Windows - allowing local spool dir"
      } else {
         ts_log_finer "\"no_local_qmaster_spool\" option is set - returning empty spool dir" 
         return $spooldir
      }
   }

   # host might be a virtual host - to query local spooldir we need the real host
   set physical_host [node_get_host $host]

   # read local spool dir from host config
   if {[info exist ts_host_config($physical_host,spooldir)]} {
      set spooldir $ts_host_config($physical_host,spooldir)
      set local_spooldir 1
   }

   # if we have a toplevel spooldir, we can construct the real spooldir
   # and trigger cleanup if requested
   if {$spooldir != ""} {
      ts_log_finest "host \"$host\" has local toplevel spool directory $spooldir"
      if { $do_cleanup == 1 } {
         ts_log_finest "cleanup spooldir!"
         set result "cleanup spooldir"
         cleanup_spool_dir_for_host $host $spooldir $subdir
      } else {
         ts_log_finest "don't cleanup spooldir!"
         set result "no cleanup"
      }
      set spooldir "$spooldir/$ts_config(commd_port)/$subdir"
      ts_log_finest $result
      ts_log_finest $spooldir
   }

   return $spooldir
}

#****** file_procedures/get_execd_spooldir() ***********************************
#  NAME
#     get_execd_spooldir() -- get configured execd spool directory
#
#  SYNOPSIS
#     get_execd_spooldir { host type { only_base 0 } } 
#
#  FUNCTION
#     Returns the spool directory for the host and requested type
#     "cell", "local", "NFS-ROOT2NOBODY" or "NFS-ROOT2ROOT" with
#     testsuite configuration port and "execd" string.
#
#  INPUTS
#     host            - execd host name
#     type            - "cell"   => spool directory in $SGE_ROOT/$SGE_CELL
#                       "local"  => local spool dir from testsuite config
#                       "NFS-ROOT2NOBODY"
#                                => NFS-ROOT2NOBODY entry in host config
#                       "NFS-ROOT2ROOT"
#                                => NFS-ROOT2ROOT entry in host config
#
#     { only_base 0 } - if not 0: don't add port and "execd" string
#
#  RESULT
#     string to execds spool directory
#
#*******************************************************************************
proc get_execd_spooldir {host type {only_base 0}} {
   global ts_host_config 
   global check_do_not_use_spool_config_entries
   get_current_cluster_config_array ts_config

   set spooldir ""

   if {$check_do_not_use_spool_config_entries == 1} {
      ts_log_severe "check_do_not_use_spool_config_entries=1 can't set local spool directory"
      return $spooldir
   }
   
   # host might be a virtual host - to query local spooldir we need the real host
   set physical_host [node_get_host $host]

   # read local spool dir from host config
   switch -exact $type {
      "cell" {
         set spooldir "$ts_config(product_root)/$ts_config(cell)/spool"
      }

      "local" { 
         if {[info exist ts_host_config($physical_host,spooldir)]} {
            set spooldir $ts_host_config($physical_host,spooldir)
         }
      }

      "NFS-ROOT2NOBODY" {
         if {[info exist ts_host_config(NFS-ROOT2NOBODY)]} {
            set spooldir $ts_host_config(NFS-ROOT2NOBODY)
         }
      }

      "NFS-ROOT2ROOT" {
         if {[info exist ts_host_config(NFS-ROOT2ROOT)]} {
            set spooldir $ts_host_config(NFS-ROOT2ROOT)
         }
      }
   }

   # if we have a toplevel spooldir, we can construct the real spooldir
   if {$spooldir != "" && $only_base == 0} {
      set spooldir "$spooldir/$ts_config(commd_port)/execd"
   }

   return $spooldir
}


#****** file_procedures/get_file_uid() *****************************************
#  NAME
#     get_file_uid() -- get uid of file on host
#
#  SYNOPSIS
#     get_file_uid { user host file } 
#
#  FUNCTION
#     Returns the uid of the given file on the remote host.
#
#  INPUTS
#     user - user name
#     host - host name
#     file - full path to file
#
#  RESULT
#     string containing the uid of the file
#
#  SEE ALSO
#     file_procedures/get_file_uid()
#     file_procedures/get_file_gid()
#*******************************************************************************
proc get_file_uid {user host file} {
   wait_for_remote_file $host $user $file 
   set output [start_remote_prog $host $user ls "-ln $file"]
   set uid [lindex $output 2]
   if {$uid == ""} {
      ts_log_severe "can't get file uid on host $host"
   }
   return $uid
}


#****** file_procedures/get_dir_uid() *****************************************
#  NAME
#     get_dir_uid() -- get uid of dir on host
#
#  SYNOPSIS
#     get_dir_uid { user host dir } 
#
#  FUNCTION
#     Returns the uid of the given dir on the remote host.
#
#  INPUTS
#     user - user name
#     host - host name
#     dir - full path to dir
#
#  RESULT
#     string containing the uid of the dir
#
#  SEE ALSO
#     file_procedures/get_file_uid()
#     file_procedures/get_file_gid()
#*******************************************************************************
proc get_dir_uid {user host dir} {
   wait_for_remote_dir $host $user $dir 
   set output [start_remote_prog $host $user ls "-ldn $dir"]
   set uid [lindex $output 2]
   if {$uid == ""} {
      ts_log_severe "can't get dir uid on host $host"
   }
   return $uid
}



#****** file_procedures/get_file_perms() ***************************************
#  NAME
#     get_file_perm() -- get permission of file on host
#
#  SYNOPSIS
#     get_file_perms { user host file } 
#
#  FUNCTION
#     Returns the permission of the given file on the remote host
#
#  INPUTS
#     user - user name
#     host - host name
#     file - full path to file
#
#  RESULT
#     string containing the file permissions
#     eg: -rw-r--r--
#
#  SEE ALSO
#     file_procedures/get_file_uid()
#     file_procedures/get_file_gid()
#*******************************************************************************
proc get_file_perm {user host file} {
   wait_for_remote_file $host $user $file 
   set output [start_remote_prog $host $user ls "-l $file"]
   return [lindex $output 0]
}

#****** file_procedures/get_file_gid() *****************************************
#  NAME
#     get_file_gid() -- get gid of file on host
#
#  SYNOPSIS
#     get_file_gid { user host file } 
#
#  FUNCTION
#     Returns the gid of the given file on the remote host.
#
#  INPUTS
#     user - user name
#     host - host name
#     file - full path to file
#
#  RESULT
#     string containing the gid of the file
#
#  SEE ALSO
#     file_procedures/get_file_uid()
#     file_procedures/get_file_gid()
#*******************************************************************************
proc get_file_gid {user host file} {
   wait_for_remote_file $host $user $file 
   set output [start_remote_prog $host $user ls "-ln $file"]
   set gid [lindex $output 3]
   if {$gid == ""} {
      ts_log_severe "can't get file gid on host $host"
   }
   return $gid
}


#****** dir_procedures/get_dir_gid() *****************************************
#  NAME
#     get_dir_gid() -- get gid of dir on host
#
#  SYNOPSIS
#     get_dir_gid { user host dir } 
#
#  FUNCTION
#     Returns the gid of the given dir on the remote host.
#
#  INPUTS
#     user - user name
#     host - host name
#     dir - full path to dir
#
#  RESULT
#     string containing the gid of the dir
#
#  SEE ALSO
#     file_procedures/get_file_uid()
#     file_procedures/get_file_gid()
#*******************************************************************************
proc get_dir_gid {user host dir} {
   wait_for_remote_dir $host $user $dir 
   set output [start_remote_prog $host $user ls "-ldn $dir"]
   set gid [lindex $output 3]
   if {$gid == ""} {
      ts_log_severe "can't get dir gid on host $host"
   }
   return $gid
}



#****** file_procedures/get_spool_dir() ****************************************
#  NAME
#     get_spool_dir() -- get the spooldir for qmaster or an exec host
#
#  SYNOPSIS
#     get_spool_dir { host subdir } 
#
#  FUNCTION
#     Returns the spool directory for qmaster or an exec host.
#     This can either be a local or a global spool directory.
#
#  INPUTS
#     host   - host on which the component is running
#     subdir - qmaster or execd
#
#  RESULT
#     String in one of the following forms:
#     <local_toplevel_dir>/<port>/qmaster
#     <local_toplevel_dir>/<port>/execd/<host>
#     <sge_root>/<sge_cell>/spool/qmaster
#     <sge_root>/<sge_cell>/spool/<host>
#
#  SEE ALSO
#     file_procedures/get_local_spool_dir()
#*******************************************************************************
proc get_spool_dir {host subdir} {
   get_current_cluster_config_array ts_config

   # first try to get a local spooldir
   set spooldir [get_local_spool_dir $host $subdir 0]

   # if we have no local spooldir, build path of global spooldir
   if {$spooldir == ""} {
      set spooldir "$ts_config(product_root)/$ts_config(cell)/spool"
      ts_log_finer "host $host has global toplevel spool directory $spooldir"
   
      switch -exact $subdir {
         "qmaster" {
            set spooldir "$spooldir/$subdir"
         }
         "execd" {
            set spooldir "$spooldir/$host"
         }
      }
   } else {
      if {$subdir == "execd"} {
         append spooldir "/$host"
      }
   }
   return $spooldir
}

#****** file_procedures/get_bdb_spooldir() *************************************
#  NAME
#     get_bdb_spooldir() -- get configured berkeley db spool directory
#
#  SYNOPSIS
#     get_bdb_spooldir {{host ""}} 
#
#  FUNCTION
#     Returns the directory configured for berkeley db spooling.
#     If bdb_dir is configured in testsuite setup, this directory will be returned.
#     Otherwise, a local spool directory for the host will be returned.
#     If no local spooldirectory is configured, we'll return 
#     $SGE_ROOT/$SGE_CELL/default/spool/spooldb.
#
#  INPUTS
#     host        - host for lookup of local spool directory. 
#                   Default is the master host.
#     only_local  - do only return local spool directory, no global one.
#
#  RESULT
#     The spool directory.
#*******************************************************************************
proc get_bdb_spooldir {{host ""} {only_local 0}} {
   get_current_cluster_config_array ts_config

   # default host is master host
   if {$host == ""} {
      set host $ts_config(master_host)
   }

   # if no special bdb spool directory is given, use qmaster spooldir
   if {$ts_config(bdb_dir) == "none"} {
      set spooldir [get_local_spool_dir $host spooldb 0]
   } else {
      set spooldir $ts_config(bdb_dir)
   }

   # we have no local spooldir? Return global one.
   if {$spooldir == ""} {
      if {!$only_local} {
         set spooldir "$ts_config(product_root)/$ts_config(cell)/spool/spooldb"
      }
   }

   return $spooldir
}

#****** file_procedures/get_fstype() *******************************************
#  NAME
#     get_fstype() -- get filesystem type for a certain path
#
#  SYNOPSIS
#     get_fstype { path {host ""} } 
#
#  FUNCTION
#     Returns the type of the filesystem on which a certain <path> resides.
#     This is done by calling the utilbin fstype binary.
#
#     If fstype does not exist (it was introduced in 6.0u?), "unknown" will be
#     returned and a "unsupported" warning will be raised.
#
#     If fstype fails, an error will be raised and "unknown" will be returned.
#
#  INPUTS
#     path      - path to file or directory
#     {host ""} - host on which to do the check. Default is any host.
#
#  RESULT
#     The filesystem type (e.g. "nfs, nfs4, tmpfs, ufs), or
#     "unknown" in case of errors.
#
# TODO: do not use this function, new fs_config functions should be used, this 
# get_fstype will be removed soon.
#*******************************************************************************
proc get_fstype {path {host ""} {raise_error 1}} {
   set ret "unknown"

   # use the SGE utilbin fstype
   set output [start_sge_utilbin "fstype" $path $host]
   if {$prg_exit_state != 0 && $raise_error == 1} {
      ts_log_severe "$path failed:\n$output"
   } else {
      if {$prg_exit_state != 0 && $raise_error == 0} {
         ts_log_warning "$path failed:\n$output"
      } else {
         set ret [string trim $output]
      }
   }
   return $ret
}

#****** file_procedures/get_jobseqnum() ****************************************
#  NAME
#     get_jobseqnum() -- get current job sequence number fro jobseqnum file
#
#  SYNOPSIS
#     get_jobseqnum { } 
#
#  FUNCTION
#     The function reads in the jobseqnum file from the qmaster spooling 
#     directory and returns the content. If there is a problem reading the
#     file the procedure returns -1 and reports an error.
#  
#  INPUTS
#
#  RESULT
#     current job sequence number, -1 on error
#
#  SEE ALSO
#     file_procedures/set_jobseqnum()
#*******************************************************************************
proc get_jobseqnum {} {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   set ret -1

   set qmaster_spool_dir [get_qmaster_spool_dir]

   set output [start_remote_prog $ts_config(master_host) $CHECK_USER "cat" "$qmaster_spool_dir/jobseqnum"]
   if {$prg_exit_state == 0} {
      set ret [string trim $output]
   } else {
      ts_log_severe "retrieving job sequence number failed:\n$output"
   }

   return $ret
}

#****** file_procedures/set_jobseqnum() ****************************************
#  NAME
#     set_jobseqnum() -- set actual job sequence number
#
#  SYNOPSIS
#     set_jobseqnum { jobseqnum } 
#
#  FUNCTION
#     This procedure is used to change the current job sequence file. It will
#     automatically shutdown and restart the qmaster (and scheduler) process
#     to make the qmaster use of the changed sequence file content.
#
#  INPUTS
#     jobseqnum - new jobseqnum file content
#
#  RESULT
#     0 on success, 1 on error
#
#  SEE ALSO
#     file_procedures/get_jobseqnum()
#*******************************************************************************
proc set_jobseqnum {jobseqnum} {
   global CHECK_USER
   get_current_cluster_config_array ts_config

   set ret 0
   set qmaster_spool_dir [get_qmaster_spool_dir]

   shutdown_master_and_scheduler $ts_config(master_host) $qmaster_spool_dir
   set output [start_remote_prog $ts_config(master_host) $CHECK_USER "echo" "$jobseqnum > $qmaster_spool_dir/jobseqnum"]
   if {$prg_exit_state == 0} {
      set ret 1
   } else {
      ts_log_severe "setting job sequence number failed:\n$output"
   }
   startup_qmaster
   
   return $ret
}

#****** file_procedures/get_additional_config_file_path() **********************
#  NAME
#     get_additional_config_file_path() -- get the path to the configuration file 
#                                          of the additional project
#
#  SYNOPSIS
#     get_additional_config_file_name { project_name } 
#
#  FUNCTION
#     Returns the name of the configuration file for the additional project 
#     if the testsuite configuration file has the path: $config_path/sge.conf,
#     the function returns the path of the configuration file for the additional 
#     project_name: $config_path/sge.$project_name.conf
#
#  INPUTS
#     project_name  - the name of the project, i.e. arco, hedeby
#     {filename ""} - the name of the testsuite configuration file
#
#  RESULT
#     string containing the path to the file
#
#*******************************************************************************
proc get_additional_config_file_path {project_name {filename ""}} {
    global CHECK_DEFAULTS_FILE
    set ret ""

    if {[string compare $filename ""] == 0} {
       set filename $CHECK_DEFAULTS_FILE
    }
    if {[file isfile $filename] != 1} {
       # this should not happen
       break
    } else {
       set path_list [split $filename "/"]
       set last [llength $path_list]
       incr last -1
       # the name of the testsuite config file
       set config_file_name [lindex $path_list $last]           
       set var [split $config_file_name "."]
       set index [llength $var]
       if {$index > 1} {incr index -1}
       # the name of the addtional project config file
       set add_config_file_name [join [linsert $var $index "$project_name"] "."]  
       set ret [join [lreplace $path_list $last $last $add_config_file_name ] "/"]
    }
    ts_log_finest "Using configuration file for $project_name: $ret"
    return $ret
}


proc have_dirs_same_base_dir {dir_name1 dir_name2} {

   set tmp_dir1 $dir_name1
   set tmp_dir2 $dir_name2
   set ret 0

   while {[file dirname $tmp_dir1] != "/"} {
      set tmp_dir1 [file dirname $tmp_dir1]
   }

   while {[file dirname $tmp_dir2] != "/"} {
      set tmp_dir2 [file dirname $tmp_dir2]
   }

   if {[string compare $tmp_dir1 $tmp_dir2] == 0} {
      set ret 1
   }
   return $ret
}

#****** file_procedures/get_testsuite_delete_filename() ************************
#  NAME
#     get_testsuite_delete_filename() -- get filename of TS delete file
#
#  SYNOPSIS
#     get_testsuite_delete_filename { } 
#
#  FUNCTION
#     Returns the (full path) filename for the "testsuite delete file".
#
#     The "testsuite delete file" saves for each TS configuration the names of
#     the files that will be deleted at the start of the next test.  Each TS
#     configuration needs its own file so that additional TS clusters (started
#     from the current TS) don't influence the current TS.
#
#  INPUTS
#     {get_local_file 0} optional: return filename of deletion file for local
#                                  deletion files 
#     {config_file ""}   optional: return filename of deletion file specified
#                                  configuration file
#
#  RESULT
#     the full path to the "testsuite delete file" for the current
#     configuration
#
#  SEE ALSO
#     file_procedures/delete_file_at_startup()
#     check.exp/delete_temp_script_file()
#*******************************************************************************
proc get_testsuite_delete_filename { {get_local_file 0} {config_file ""}} {
   global ts_config
   global CHECK_DEFAULTS_FILE

   if {$config_file == ""} {
      set ts_config_name [file rootname [file tail $CHECK_DEFAULTS_FILE]]
   } else {
      set ts_config_name [file rootname [file tail $config_file]]
   }

   if {$get_local_file == 0} {
      set ret_file_name "$ts_config(testsuite_root_dir)/.testsuite_delete.$ts_config_name"
   } else {
      set ret_file_name "$ts_config(testsuite_root_dir)/.testsuite_delete_local.$ts_config_name"
   }
   return $ret_file_name
}

#****** file_procedures/get_uri_hostname() *************************************
#  NAME
#     get_uri_hostname() -- return hostname from file URI
#
#  SYNOPSIS
#     get_uri_hostname { uri } 
#
#  FUNCTION
#     This function is used to get out the hostname from the specified URI.
#
#  INPUTS
#     uri             - URI string (e.g.: "file://HOSTNAME/PATH")
#     {raise_error 1} - if set != 1: do not report errors 
#
#  RESULT
#     tcl string with hostname or an empty string ("") on error
#     
#     If the URI is valid and no hostname is set (e.g.: file:///tmp) the
#     local host name is returned.
#
#  NOTES
#     TODO: We might use the package uri (package require uri)
#     e.g.  uri 1.1.2 "Tcl Uniform Resource Identifier Management"
#     package require uri 1.1.2
#     if we want to support all URI Schemes
#
#     TODO: Currently only file uri is supported
#
#  SEE ALSO
#     file_procedures/get_uri_hostname()
#     file_procedures/get_uri_path()
#     file_procedures/get_uri_scheme()
#*******************************************************************************
proc get_uri_hostname { uri {raise_error 1}} { 
   set scheme [lindex [split $uri ":"] 0]

   switch -exact $scheme {
      "file" {
         set hostname [string trim [lindex [split $uri "/"] 2]]
         if {$hostname == ""} {
            set hostname [gethostname]
         }
         return $hostname
      }
      default {
         if {$raise_error == 1} {
            ts_log_severe "URI Scheme \"$scheme\" not implemented: $uri"
         }
         return ""
      }
   }
}

#****** file_procedures/get_uri_scheme() ***************************************
#  NAME
#     get_uri_scheme() -- return URI scheme
#
#  SYNOPSIS
#     get_uri_scheme { uri } 
#
#  FUNCTION
#     This function is used to parse the URI scheme of the specified URI string
#
#  INPUTS
#     uri             - URI string (e.g.: "file://HOSTNAME/PATH")
#     {raise_error 1} - if set != 1: do not report errors
#
#  RESULT
#     The name of the uri scheme or empty string ("") on error
#
#  NOTES
#     TODO: We might use the package uri (package require uri)
#     e.g.  uri 1.1.2 "Tcl Uniform Resource Identifier Management"
#     package require uri 1.1.2
#     if we want to support all URI Schemes
#
#     TODO: Currently only file uri is supported
#
#  SEE ALSO
#     file_procedures/get_uri_hostname()
#     file_procedures/get_uri_path()
#     file_procedures/get_uri_scheme()
#*******************************************************************************
proc get_uri_scheme { uri {raise_error 1}} {
   set scheme [lindex [split $uri ":"] 0]

   switch -exact $scheme {
      "file" {
         return $scheme
      }
      default {
         if {$raise_error == 1} {
            ts_log_severe "URI Scheme \"$scheme\" not implemented: $uri"
         }
         return ""
      }
   }
}

#****** file_procedures/get_uri_path() *****************************************
#  NAME
#     get_uri_path() -- return path from file URI
#
#  SYNOPSIS
#     get_uri_path { uri } 
#
#  FUNCTION
#     This function is used to get the path string from the specified URI.
#
#  INPUTS
#     uri             - URI string (e.g.: "file://HOSTNAME/PATH")
#     {raise_error 1} - if set != 1: do not report errors
#
#  RESULT
#     tcl string with path or empty string ("") on error
#
#  NOTES
#     TODO: We might use the package uri (package require uri)
#     e.g.  uri 1.1.2 "Tcl Uniform Resource Identifier Management"
#     package require uri 1.1.2
#     if we want to support all URI Schemes
#
#     TODO: Currently only file uri is supported
#
#  SEE ALSO
#     file_procedures/get_uri_hostname()
#     file_procedures/get_uri_path()
#     file_procedures/get_uri_scheme()
#*******************************************************************************
proc get_uri_path { uri  {raise_error 1} } { 
   set scheme [lindex [split $uri ":"] 0]
   switch -exact $scheme {
      "file" {
         set path "/"
         set split_list [split $uri "/"]
         set length [llength $split_list]
         if {$length <= 3} {
            if {$raise_error == 1} {
               ts_log_severe "URI Scheme \"$scheme\" needs at least 3 \"/\" characters: $uri"
            }
            return ""
         }
         for {set i 3} {$i < $length} {incr i 1} {
            set dname [string trim [lindex $split_list $i]]
            if {[string length $dname] > 0} {
               append path $dname
               append path "/"
            }
         }
         set str_length [string length $path]
         if {$str_length > 1} {
            # remove last "/"
            incr str_length -2
            set path [string range $path 0 $str_length]
         }
         return $path
      }
      default {
         if {$raise_error == 1} {
            ts_log_severe "URI Scheme \"$scheme\" not implemented: $uri"
         }
         return ""
      }
   }
}


#****** file_procedures/parse_testsuite_info_file() ****************************
#  NAME
#     parse_testsuite_info_file() -- framework for parsing testsuite.info file
#
#  SYNOPSIS
#     parse_testsuite_info_file { user uri info_file } 
#
#  FUNCTION
#     This procedure is used to parse a testsuite.info file. 
#
#     A testsuite.info file has following syntax:
#
#     #Sub dir       |Release|Description             |Enabled for testing
#     #-------------------------------------------------------------------
#     sge6.1/6.1u6   |6:1:6  |Sun Grid Engine 6.1u6   |true
#     sge6.1/6.1beta |6:1:0  |N1 Grid Engine 6.1 Beta |false
#     sge6.1/6.1u3   |6:1:3  |Sun Grid Engine 6.1u3   |false
#
#     Sub dir:     relative path to directory where the distribution
#                  is available
#
#     Release:     Syntax: MAJOR_NR:MINOR_NR:UPDATE_NR
#                  - FCS version gets UPDATE_NR 0
#
#     Description: Text description of the release
#
#     Enabled for testing: true - usable for testsuite, false - not usable
#
#
#  INPUTS
#     user      - user who should read the file
#     uri       - file URI to testsuite.info file (e.g.: file://hostfoo/tmp)
#     info_file - array for storing the parsed information
#
#        info_file(count)                - nr of entries
#        info_file(uri)                  - same as INPUTS uri
#        info_file(user)                 - same as INPUTS user
#        info_file(INDEX_NR,COLUMN_NAME) - data access
#
#        INDEX_NR: running number for valid distribution
#        COLUMN_NAME: "major_release",
#                     "minor_release",
#                     "update_release",
#                     "version",
#                     "description",
#                     "tag",
#                     "uri",
#                     "enabled"
#                     "macro_file_uri"
#  
#        version: e.g.: "61u2"
#
#  RESULT
#     1 on success, 0 on error
#
#  SEE ALSO
#     file_procedures/parse_testsuite_info_file()
#     file_procedures/get_release_packages()
#
#*******************************************************************************
proc parse_testsuite_info_file { user uri info_file } {
   upvar $info_file pack_info

   if {[info exists pack_info]} {
      unset pack_info
   }

   # get host and path to release packages directory
   set host [get_uri_hostname $uri]
   set path [get_uri_path $uri]

   set testsuite_info_file_name "$path/testsuite.info"
  
   # Check that we have a testsuite.info file
   if {![is_remote_file $host $user $testsuite_info_file_name]} {
      ts_log_severe "$host: Cannot open file \"$testsuite_info_file_name\""
      return 0
   }

   # We need a subdirectory with source code macros
   set ge_source_macro_dir "$path/source_code_macros"
   if {![is_remote_path $host $user $ge_source_macro_dir]} {
      ts_log_severe "$host: Directory \"$ge_source_macro_dir\" is missing!"
      return 0
   }

   ts_log_finer "${host}($user): reading \"$testsuite_info_file_name\" ..."
   get_file_content $host $user $testsuite_info_file_name farray

   set expected_columns 5
   set expected_release_columns 3
   set array_names {}
   lappend array_names "uri"
   lappend array_names "major_release"
   lappend array_names "minor_release"
   lappend array_names "update_release"
   lappend array_names "version"
   lappend array_names "description"
   lappend array_names "enabled"
   lappend array_names "tag"

   set pack_info_index 1

   for {set i 1} {$i <= $farray(0)} {incr i} {
      set line [string trim $farray($i)]

      # ignore comments
      if {[string index $line 0] == "#"} {
         continue
      }
     
      # ignore empty lines
      if {$line == ""} {
         continue
      }
      set columns [split $line "|"]
      if {[llength $columns] != $expected_columns} {
         ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: Column count not correct!"
         continue
      }
#      ts_log_fine "line $i: $line"
      
      set was_error 0
      for {set a 0} {$a < [llength $array_names]} {incr a 1} {
         # get the current array name
         set a_name [lindex $array_names $a]

         # parse release column
         set release [split [string trim [lindex $columns 0]] ":"]
         set release_columns [llength $release]
         if { $release_columns != $expected_release_columns } {
            ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: Column count of release column not correct!"
            incr was_error 1
            break
         }

         switch -exact $a_name {
            "uri" {
               set pack_info($pack_info_index,$a_name) [string trim [lindex $columns 4]]

               set uri_host [get_uri_hostname $pack_info($pack_info_index,$a_name)]
               set uri_path [get_uri_path $pack_info($pack_info_index,$a_name)]
               ts_log_finer "uri host: $uri_host"
               ts_log_finer "uri path: $uri_path"
               if {![is_remote_path $uri_host $user $uri_path]} {
                  ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: URI \"$pack_info($pack_info_index,$a_name)\" not correct!" 
                  incr was_error 1
                  break  ;# stop for loop
               }
            }
            "major_release" {
               set help [string trim [lindex $release 0]]
               set pack_info($pack_info_index,$a_name) $help
               if {![string is integer $help]} {
                  ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: Major release version should be integer number!" 
                  incr was_error 1
                  break ;# stop for loop
               }
               if {[string length $help] == 0} {
                  ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: Major release version missing!" 
                  incr was_error 1
                  break ;# stop for loop
               }
            }
            "minor_release" {
               set help [string trim [lindex $release 1]]
               set pack_info($pack_info_index,$a_name) $help
               if {![string is integer $help]} {
                  ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: Minor release version should be integer number!" 
                  incr was_error 1
                  break ;# stop for loop
               }
               if {[string length $help] == 0} {
                  ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: Minor release version missing!" 
                  incr was_error 1
                  break ;# stop for loop
               }
            }
            "update_release" {
               set help [string trim [lindex $release 2]]
               set pack_info($pack_info_index,$a_name) $help
               if {![string is integer $help]} {
                  ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: Update release version should be integer number!" 
                  incr was_error 1
                  break
               }
               if {[string length $help] == 0} {
                  ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: Update release version missing!" 
                  incr was_error 1
                  break ;# stop for loop
               }
            }
            "version" {
               if {[lindex $release 2] >= 1} {
                  set pack_info($pack_info_index,$a_name) "[lindex $release 0].[lindex $release 1]u[lindex $release 2]"
               } else {
                  set pack_info($pack_info_index,$a_name) "[lindex $release 0].[lindex $release 1]"
               }
            }
            "description" {
               set pack_info($pack_info_index,$a_name) [string trim [lindex $columns 2]]
            }
            "enabled" {
               set help [string tolower [string trim [lindex $columns 3]]]
               set pack_info($pack_info_index,$a_name) $help
               if {![string is boolean $help]} {
                  ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: Enabled for testing column value should be boolean!" 
                  incr was_error 1
                  break ;# stop for loop
               }
               if {$help} {
                  set pack_info($pack_info_index,$a_name) "true"
               } else {
                  set pack_info($pack_info_index,$a_name) "false"
               }
            }
            "tag" {
               set pack_info($pack_info_index,$a_name) [string trim [lindex $columns 1]]
            }
            default {
               set pack_info($pack_info_index,$a_name) "n.a."
            }
         }
      }
      # generate macro file name
      set pack_info($pack_info_index,macro_file_uri) "n.a."
      if {[info exists pack_info($pack_info_index,enabled)] && $pack_info($pack_info_index,enabled)} {
         if {[string length $pack_info($pack_info_index,$a_name)] == 0} {
            ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: No CVS tag specified (enabled for testing)!" 
            incr was_error 1
            break
         }
         set macro_dir "$ge_source_macro_dir/$pack_info($pack_info_index,tag)"
         if {![is_remote_path $host $user $macro_dir]} {
            ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: Directory \"$macro_dir\" not found!"
            incr was_error 1
            break
         }
         set macro_file "$macro_dir/"
         append macro_file $pack_info($pack_info_index,major_release)
         append macro_file $pack_info($pack_info_index,minor_release)
         append macro_file $pack_info($pack_info_index,update_release)
         append macro_file ".dump"
         set macro_file_uri_host [get_uri_hostname $pack_info($pack_info_index,uri)]
         set macro_file_uri "file://${macro_file_uri_host}${macro_file}"

         set pack_info($pack_info_index,macro_file_uri) $macro_file_uri
         if {![is_remote_file $macro_file_uri_host $user $macro_file]} {
            ts_log_severe "Syntax error in line $i of file $testsuite_info_file_name: File \"$macro_file\" not found on host \"$macro_file_uri_host\"!"
            incr was_error 1
            break
         }
      } else {
         ts_log_finer "skip tag check in line $i of file \"$testsuite_info_file_name\"! (not enabled for testing)"
         set pack_info($pack_info_index,tag) "n.a."
      }
#         ts_log_fine "$a_name=\"$pack_info($pack_info_index,$a_name)\""
      if {$was_error == 0} {
         incr pack_info_index 1
      }
   }
   set pack_info(count) [expr $pack_info_index - 1]
   set pack_info(uri) $uri
   set pack_info(user)  $user
#   ts_log_fine "nr. of valid entries found: $pack_info(count)"
   if {$was_error} {
      return 0
   }
   return 1
}


#****** file_procedures/get_release_packages() *********************************
#  NAME
#     get_release_packages() -- copy Grid Engine distribution to product root
#
#  SYNOPSIS
#     get_release_packages { host user dest_path info_file nr } 
#
#  FUNCTION
#     This function is used to copy and unpack the specified Grid Engine release
#     to a destination directory.
#
#  INPUTS
#     host      - hostname where the $dest_path is availabe 
#     user      - user who is executing commands
#     dest_path - absolut destination path on $host (Grid Engine SGE_ROOT dir)
#     info_file - array which contains testsuiten.info data
#     nr        - running number of distribution
#
#  RESULT
#     1 on success, 0 on error
#
#  NOTES
#     TODO: Currently only works for file URI.
#     TODO: Only works when file uri and destination file is avail.
#           on the same host
#     TODO: Only works for *.tar.gz files
#
#  SEE ALSO
#     file_procedures/parse_testsuite_info_file()
#     file_procedures/get_release_packages()
#*******************************************************************************
proc get_release_packages { host user dest_path info_file nr} {
   upvar $info_file pack_info

   if {![info exists pack_info($nr,version)]} {
      ts_log_severe "info array does not contain package nr $nr"
      return 0
   }

   set scheme [get_uri_scheme $pack_info(uri)]
   switch -exact $scheme {
      "file" {
         set source_host [get_uri_hostname $pack_info($nr,uri)]
         set source_release_path [get_uri_path $pack_info($nr,uri)]

         if {[resolve_host $source_host] == [resolve_host $host]} {

            # copy packages
            ts_log_fine "copy from $source_host:$source_release_path to $host $dest_path as user $user"
            set output [start_remote_prog $host $user [get_binary_path $host "cp"] "$source_release_path/*ge*.tar.gz $dest_path" prg_exit_state 300 0 "" "" 1 0]
            if {$output != ""} {
               ts_log_fine "output of cp: $output"
            }
            if {$prg_exit_state != 0} {
               ts_log_severe "${host}($user): Cannot copy distribution from $source_release_path !"
               return 0
            }

            # gunzip packages
            set output [start_remote_prog $host $user [get_binary_path $host "gunzip"] "*.gz" prg_exit_state 300 0 $dest_path "" 1 0]
            if {$output != ""} {
               ts_log_fine "output of gunzip: $output"
            }
            if {$prg_exit_state != 0} {
               ts_log_severe "${host}($user): Cannot gunzip distribution in $dest_path!"
               return 0
            }

            # untar packages
            analyze_directory_structure $host $user $dest_path "" files ""
            foreach filename $files {
               if {[string match "*.tar*" $filename]} {
                  ts_log_fine "untar $filename ..."
                  set output [start_remote_prog $host $user [get_binary_path $host "tar"] "-xf $filename" prg_exit_state 300 0 $dest_path "" 1 0]
                  if {$output != ""} {
                     ts_log_fine "output of tar: $output"
                  }
                  if {$prg_exit_state != 0} {
                     ts_log_severe "${host}($user): Cannot tar -xf $filename in $dest_path!"
                     return 0
                  }
                  # delete tar file
                  start_remote_prog $host $user "rm" "$filename" prg_exit_state 300 0 $dest_path "" 1 0
               } else {
                  ts_log_fine "ignore $filename ..."
               }
            } 
            return 1
         } else {
            ts_log_severe "execute copy from different host than file uri server not yet implemented"
            return 0
         }
      }
      default {
         ts_log_severe "URI Scheme \"$scheme\" not implemented: $pack_info(uri)"
         return 0
      }
   }
   ts_log_fine "unexpected error"
   return 0
}
