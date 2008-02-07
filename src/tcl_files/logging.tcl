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

#****** logging/--Introduction ****************************************
#  NAME
#     logging -- error and information output
#
#  FUNCTION
#     Framework for all logging activities of testsuite.
#     Replaces the former output to CHECK_OUTPUT, debug_puts,
#     and add_proc_error.
#
#     Output can be done to stdout, into a log file, and by mail,
#     controlled by output levels.
#     For each output media (stdout, log file, mail), a level can be configured,
#     up to which logging is done to the specific output media.
#
#     Default behavior is to send SEVERE, WARNING, and CONFIG messages as mail,
#     to output SEVERE .. FINE messages to stdout, and to write no logfile.
#
#     The following logging levels exist:
#        SEVERE:  severe error - test will be stopped after current test level
#                 The former add_proc_error <function name> -1 <message>
#        WARNING: something went wrong, but we can continue
#                 The former add_proc_error <function name> -2 <message>
#        CONFIG:  configuration issue, e.g. not enough hosts to run a certain test,
#                 something not supported in csp mode
#                 The former add_proc_error <function name> -3 <message>
#        INFO:    Info message (e.g. testsuite success messages, compile report, etc.)
#        FINE:    what is now "puts $CHECK_OUTPUT", e.g. steps of a test, "adding pe xyz"
#        FINER:   details of a test step
#        FINEST:  debugging output, e.g. command output parsed in expect blocks, 
#                 the commands to be sent to vi, etc.
#
#     Logging is triggered by calling one of the logging functions
#     ts_log_severe, ts_log_warning, ... , ts_log_finest.
#     
#  SEE ALSO
#     logging/ts_log_setup()
#     logging/ts_log_cleanup()
#     logging/ts_log_set_level()
#     logging/ts_log_set_logfile()
#
#     logging/ts_log_severe()
#     logging/ts_log_warning()
#     logging/ts_log_config()
#     logging/ts_log_info()
#     logging/ts_log_fine()
#     logging/ts_log_finer()
#     logging/ts_log_finest()
#     logging/ts_log()
#     logging/ts_log_progress()
#     logging/ts_log_frame()
#     logging/ts_log_newline()
#*******************************************************************************

# ================================================================================
# public interface
# ================================================================================

#****** logging/ts_log_setup() *************************************************
#  NAME
#     ts_log_setup() -- setup the logging framework
#
#  SYNOPSIS
#     ts_log_setup { } 
#
#  FUNCTION
#     Initialize the logging internal data structures.
#     Setup default behavior of the logging framework:
#     Loglevel INFO for sending mail, 
#     FINE for output to stdout,
#     FINER for logging to file.
#
#  SEE ALSO
#     logging/ts_log_cleanup()
#     logging/ts_log_set_level()
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log_setup {} {
   # ts_log_logfile is a file handle to the log file
   global ts_log_logfile
   set ts_log_logfile ""

   # ts_log_levels is a list of the log level names
   global ts_log_levels
   set ts_log_levels {"SEVERE" "WARNING" "CONFIG" "INFO" "FINE" "FINER" "FINEST"}

   # ts_log_media is a list of all output media
   global ts_log_media
   set ts_log_media {"mail" "output" "logging"}

   # initialize mapping between level names and numbers
   # this goes into the global variable ts_log_level_map
   ts_log_init_level_map

   # set default logging levels per media
   global ts_log_config
   set ts_log_config(mail) 3        ;# INFO
   set ts_log_config(output) 4      ;# FINE
   set ts_log_config(logging) 5     ;# FINER
}

#****** logging/ts_log_cleanup() ***********************************************
#  NAME
#     ts_log_cleanup() -- cleanup / shutdown the logging framework
#
#  SYNOPSIS
#     ts_log_cleanup {} 
#
#  FUNCTION
#     Shutdown the logging framework:
#     - close the logfile, if it was open
#
#  SEE ALSO
#     logging/ts_log_setup()
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log_cleanup {} {
   global ts_log_logfile

   # close the logfile
   if {$ts_log_logfile != ""} {
      close $ts_log_logfile
      set ts_log_logfile ""
   }
}

#****** logging/ts_log_set_level() *********************************************
#  NAME
#     ts_log_set_level() -- set the output level for a certain media
#
#  SYNOPSIS
#     ts_log_set_level {media level} 
#
#  FUNCTION
#     Sets the level, up to which logging is done on a certain media.
#
#  INPUTS
#     media - output media ("mail", "output", "logging")
#     level - output level ("SEVERE", ... , "FINEST")
#
#  EXAMPLE
#     ts_log_set_level "mail" "INFO"
#
#  SEE ALSO
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log_set_level {media level} {
   global ts_log_media
   global ts_log_config

   if {[lsearch -exact $ts_log_media $media] < 0} {
      puts "!!! invalid logging media $media !!!"
      here_we_trigger_a_TCL_stacktrace
   }

   set level [ts_log_get_level_number $level]

   set ts_log_config($media) $level
}

#****** logging/ts_log_set_logfile() *******************************************
#  NAME
#     ts_log_set_logfile() -- open logfile
#
#  SYNOPSIS
#     ts_log_set_logfile {filename {mode "w"}}
#
#  FUNCTION
#     Opens the file <filename> for logging.
#     Open mode can be any valid mode for TCL function open, e.g.
#        - "w" to overwrite an existing file (default)
#        - "a" to append to an existing file
#
#     If logging to a logfile was already active, the former logfile is closed.
#
#  INPUTS
#     filename   - name of the logfile
#     {mode "w"} - open mode
#
#  SEE ALSO
#     logging/ts_log_set_level()
#*******************************************************************************
proc ts_log_set_logfile {filename {mode "w"}} {
   global ts_log_logfile
  
   # close currently open logfile
   if {$ts_log_logfile != ""} {
      close $ts_log_logfile
      set ts_log_logfile ""
   }

   # open new logfile
   set ts_log_logfile [open $filename "w"]
}

#****** logging/ts_log_severe() *******************************************************
#  NAME
#     ts_log_severe() -- log a severe error message
#
#  SYNOPSIS
#     ts_log_severe {message {raise_error 1} {function ""} {do_output 1}
#                    {do_logging 1} {do_mail 1}}
#
#  FUNCTION
#     Do logging of a severe error message.
#     
#     Severe error means, that with such an error, continuing the current
#     check will most probably fail, and doesn't make sense.
#     The current check shall be aborted (see NOTE).
#
#     When you call ts_log_severe within a check_function, you probably
#     want to abort the current check_function (return).
#
#     Depending on input parameters, and logging configuration, triggers
#     - doing output to stdout
#     - doing logging to logfile
#     - sending mail
#     - storing error information in case of errors
#
#     If no value is given for the parameter "function", the function name
#     of the calling function will be used in output.
#
#  INPUTS
#     message         - the message to log
#     {raise_error 1} - shall an error condition be raised, in case it is a
#                       SEVERE, WARNING, or CONFIG message
#     {function ""}   - a string to be used as calling function
#     {do_output 1}   - do write output to stdout
#     {do_logging 1}  - do write output to logfile
#     {do_mail 1}     - do sending of mail
#
#  NOTE
#     In the current implementation, the check is *not* aborted.
#     Testsuite will finish running the current check in the current runlevel,
#     but not enter the next runlevel.
#     When all checks are to be run, an installation (install re_init) will
#     be done once the current check finished, and the next check will be 
#     started.
#
#  SEE ALSO
#     logging/ts_log_warning()
#     logging/ts_log_config()
#     logging/ts_log_info()
#     logging/ts_log_fine()
#     logging/ts_log_finer()
#     logging/ts_log_finest()
#     logging/ts_log_set_level()
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log_severe {message {raise_error 1} {function ""} {do_output 1} {do_logging 1} {do_mail 1}} {
   ts_private_do_log SEVERE $message $raise_error $function $do_output $do_logging $do_mail
}

#****** logging/ts_log_warning() *******************************************************
#  NAME
#     ts_log_warning() -- log a warning message
#
#  SYNOPSIS
#     ts_log_warning {message {raise_error 1} {function ""} {do_output 1}
#                     {do_logging 1} {do_mail 1}}
#
#  FUNCTION
#     Do logging of a warning message.
#
#     Depending on input parameters, and logging configuration, triggers
#     - doing output to stdout
#     - doing logging to logfile
#     - sending mail
#     - storing error information in case of errors
#
#     If no value is given for the parameter "function", the function name
#     of the calling function will be used in output.
#
#  INPUTS
#     message         - the message to log
#     {raise_error 1} - shall an error condition be raised, in case it is a
#                       SEVERE, WARNING, or CONFIG message
#     {function ""}   - a string to be used as calling function
#     {do_output 1}   - do write output to stdout
#     {do_logging 1}  - do write output to logfile
#     {do_mail 1}     - do sending of mail
#
#  SEE ALSO
#     logging/ts_log_severe()
#     logging/ts_log_config()
#     logging/ts_log_info()
#     logging/ts_log_fine()
#     logging/ts_log_finer()
#     logging/ts_log_finest()
#     logging/ts_log_set_level()
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log_warning {message {raise_error 1} {function ""} {do_output 1} {do_logging 1} {do_mail 1}} {
   ts_private_do_log WARNING $message $raise_error $function $do_output $do_logging $do_mail
}

#****** logging/ts_log_config() *******************************************************
#  NAME
#     ts_log_config() -- log a config message
#
#  SYNOPSIS
#     ts_log_config {message {raise_error 1} {function ""} {do_output 1}
#                    {do_logging 1} {do_mail 1}}
#
#  FUNCTION
#     Do logging of a config message.
#
#     Depending on input parameters, and logging configuration, triggers
#     - doing output to stdout
#     - doing logging to logfile
#     - sending mail
#     - storing error information in case of errors
#
#     If no value is given for the parameter "function", the function name
#     of the calling function will be used in output.
#
#  INPUTS
#     message         - the message to log
#     {raise_error 1} - shall an error condition be raised, in case it is a
#                       SEVERE, WARNING, or CONFIG message
#     {function ""}   - a string to be used as calling function
#     {do_output 1}   - do write output to stdout
#     {do_logging 1}  - do write output to logfile
#     {do_mail 1}     - do sending of mail
#
#  SEE ALSO
#     logging/ts_log_severe()
#     logging/ts_log_warning()
#     logging/ts_log_info()
#     logging/ts_log_fine()
#     logging/ts_log_finer()
#     logging/ts_log_finest()
#     logging/ts_log_set_level()
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log_config {message {raise_error 1} {function ""} {do_output 1} {do_logging 1} {do_mail 1}} {
   ts_private_do_log CONFIG $message $raise_error $function $do_output $do_logging $do_mail
}

#****** logging/ts_log_info() *******************************************************
#  NAME
#     ts_log_info() -- log a info message
#
#  SYNOPSIS
#     ts_log_info {message {raise_error 1} {function ""} {do_output 1}
#                  {do_logging 1} {do_mail 1}}
#
#  FUNCTION
#     Do logging of a info message.
#
#     Depending on input parameters, and logging configuration, triggers
#     - doing output to stdout
#     - doing logging to logfile
#     - sending mail
#     - storing error information in case of errors
#
#     If no value is given for the parameter "function", the function name
#     of the calling function will be used in output.
#
#  INPUTS
#     message         - the message to log
#     {raise_error 1} - shall an error condition be raised, in case it is a
#                       SEVERE, WARNING, or CONFIG message
#     {function ""}   - a string to be used as calling function
#     {do_output 1}   - do write output to stdout
#     {do_logging 1}  - do write output to logfile
#     {do_mail 1}     - do sending of mail
#
#  SEE ALSO
#     logging/ts_log_severe()
#     logging/ts_log_warning()
#     logging/ts_log_config()
#     logging/ts_log_fine()
#     logging/ts_log_finer()
#     logging/ts_log_finest()
#     logging/ts_log_set_level()
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log_info {message {raise_error 1} {function ""} {do_output 1} {do_logging 1} {do_mail 1}} {
   ts_private_do_log INFO $message $raise_error $function $do_output $do_logging $do_mail
}

#****** logging/ts_log_fine() *******************************************************
#  NAME
#     ts_log_fine() -- log a fine level message
#
#  SYNOPSIS
#     ts_log_fine {message {raise_error 1} {function ""} {do_output 1}
#                    {do_logging 1} {do_mail 1}}
#
#  FUNCTION
#     Do logging of a fine level message.
#
#     Depending on input parameters, and logging configuration, triggers
#     - doing output to stdout
#     - doing logging to logfile
#     - sending mail
#     - storing error information in case of errors
#
#     If no value is given for the parameter "function", the function name
#     of the calling function will be used in output.
#
#  INPUTS
#     message         - the message to log
#     {raise_error 1} - shall an error condition be raised, in case it is a
#                       SEVERE, WARNING, or CONFIG message
#     {function ""}   - a string to be used as calling function
#     {do_output 1}   - do write output to stdout
#     {do_logging 1}  - do write output to logfile
#     {do_mail 1}     - do sending of mail
#
#  SEE ALSO
#     logging/ts_log_severe()
#     logging/ts_log_warning()
#     logging/ts_log_config()
#     logging/ts_log_info()
#     logging/ts_log_finer()
#     logging/ts_log_finest()
#     logging/ts_log_set_level()
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log_fine {message {raise_error 1} {function ""} {do_output 1} {do_logging 1} {do_mail 1}} {
   ts_private_do_log FINE $message $raise_error $function $do_output $do_logging $do_mail
}

#****** logging/ts_log_finer() *******************************************************
#  NAME
#     ts_log_finer() -- log a finer level message
#
#  SYNOPSIS
#     ts_log_finer {message {raise_error 1} {function ""} {do_output 1}
#                   {do_logging 1} {do_mail 1}}
#
#  FUNCTION
#     Do logging of a finer level message.
#
#     Depending on input parameters, and logging configuration, triggers
#     - doing output to stdout
#     - doing logging to logfile
#     - sending mail
#     - storing error information in case of errors
#
#     If no value is given for the parameter "function", the function name
#     of the calling function will be used in output.
#
#  INPUTS
#     message         - the message to log
#     {raise_error 1} - shall an error condition be raised, in case it is a
#                       SEVERE, WARNING, or CONFIG message
#     {function ""}   - a string to be used as calling function
#     {do_output 1}   - do write output to stdout
#     {do_logging 1}  - do write output to logfile
#     {do_mail 1}     - do sending of mail
#
#  SEE ALSO
#     logging/ts_log_severe()
#     logging/ts_log_warning()
#     logging/ts_log_config()
#     logging/ts_log_info()
#     logging/ts_log_fine()
#     logging/ts_log_finest()
#     logging/ts_log_set_level()
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log_finer {message {raise_error 1} {function ""} {do_output 1} {do_logging 1} {do_mail 1}} {
   ts_private_do_log FINER $message $raise_error $function $do_output $do_logging $do_mail
}

#****** logging/ts_log_finest() *******************************************************
#  NAME
#     ts_log_finest() -- log a finest level message
#
#  SYNOPSIS
#     ts_log_finest {message {raise_error 1} {function ""} {do_output 1}
#                    {do_logging 1} {do_mail 1}}
#
#  FUNCTION
#     Do logging of a finest level message.
#
#     Depending on input parameters, and logging configuration, triggers
#     - doing output to stdout
#     - doing logging to logfile
#     - sending mail
#     - storing error information in case of errors
#
#     If no value is given for the parameter "function", the function name
#     of the calling function will be used in output.
#
#  INPUTS
#     message         - the message to log
#     {raise_error 1} - shall an error condition be raised, in case it is a
#                       SEVERE, WARNING, or CONFIG message
#     {function ""}   - a string to be used as calling function
#     {do_output 1}   - do write output to stdout
#     {do_logging 1}  - do write output to logfile
#     {do_mail 1}     - do sending of mail
#
#  SEE ALSO
#     logging/ts_log_severe()
#     logging/ts_log_warning()
#     logging/ts_log_config()
#     logging/ts_log_info()
#     logging/ts_log_fine()
#     logging/ts_log_finer()
#     logging/ts_log_set_level()
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log_finest {message {raise_error 1} {function ""} {do_output 1} {do_logging 1} {do_mail 1}} {
   ts_private_do_log FINEST $message $raise_error $function $do_output $do_logging $do_mail
}

#****** logging/ts_log() *******************************************************
#  NAME
#     ts_log() -- log a message
#
#  SYNOPSIS
#     ts_log{level message {raise_error 1} {function ""} {do_output 1}
#            {do_logging 1} {do_mail 1}}
#
#  FUNCTION
#     Do logging of a message in the given level.
#
#     Depending on input parameters, and logging configuration, triggers
#     - doing output to stdout
#     - doing logging to logfile
#     - sending mail
#     - storing error information in case of errors
#
#     If no value is given for the parameter "function", the function name
#     of the calling function will be used in output.
#
#  INPUTS
#     level           - the logging level
#     message         - the message to log
#     {raise_error 1} - shall an error condition be raised, in case it is a
#                       SEVERE, WARNING, or CONFIG message
#     {function ""}   - a string to be used as calling function
#     {do_output 1}   - do write output to stdout
#     {do_logging 1}  - do write output to logfile
#     {do_mail 1}     - do sending of mail
#
#  SEE ALSO
#     logging/ts_log_severe()
#     logging/ts_log_warning()
#     logging/ts_log_config()
#     logging/ts_log_info()
#     logging/ts_log_fine()
#     logging/ts_log_finer()
#     logging/ts_log_finest()
#     logging/ts_log_set_level()
#     logging/ts_log_set_logfile()
#*******************************************************************************
proc ts_log {level message {raise_error 1} {function ""} {do_output 1} {do_logging 1} {do_mail 1}} {
   ts_private_do_log $level $message $raise_error $function $do_output $do_logging $do_mail
}

#****** logging/ts_log_progress() **********************************************
#  NAME
#     ts_log_progress() -- log progress
#
#  SYNOPSIS
#     ts_log_progress {{level FINE} {message "."}}
#
#  FUNCTION
#     Used to log progress of an action.
#     If the given log level is active for output to stdout,
#     a dot is printed per call of ts_log_progress,
#     otherwise the "washing machine" is printed.
#
#     Output is done only to stdout.
#
#  INPUTS
#     {level FINE}  - log level
#     {message "."} - message (default: dot) to print
#*******************************************************************************
proc ts_log_progress {{level FINE} {message "."}} {
   global ts_log_config

   set level [ts_log_get_level_name $level]

   if {$ts_log_config(output) >= $level} {
      puts -nonewline $message ; flush stdout
   } else {
      ts_log_washing_machine
   }
}

#****** logging/ts_log_frame() *************************************************
#  NAME
#     ts_log_frame() -- print a frame (horizontal line)
#
#  SYNOPSIS
#     ts_log_frame {{level FINE} {line ""}}
#
#  FUNCTION
#     Prints a horizontal line make of asterisks (*), if the given runlevel
#     is active, otherwise the "washing machine".
#     A different message (line pattern) can be given.
#
#     Output is done only to stdout.
#
#  INPUTS
#     {level FINE} - log level
#     {line ""}    - custom line pattern
#*******************************************************************************
proc ts_log_frame {{level FINE} {line ""}} {
   global ts_log_config
  
   set level [ts_log_get_level_name $level]
   if {$ts_log_config(output) >= $level} {
      if {$line == ""} {
         puts "********************************************************************************"
      } else {
         puts $line
      }
   } else {
      ts_log_washing_machine
   }
}

#****** logging/ts_log_newline() *************************************************
#  NAME
#     ts_log_newline() -- print a newline
#
#  SYNOPSIS
#     ts_log_newline {{level FINE}}
#
#  FUNCTION
#     Prints a newline, if the given runlevel
#     is active, otherwise the "washing machine".
#
#     Output is done only to stdout.
#
#  INPUTS
#     {level FINE} - log level
#*******************************************************************************
proc ts_log_newline {{level FINE}} {
   global ts_log_config
  
   set level [ts_log_get_level_name $level]
   if {$ts_log_config(output) >= $level} {
      puts "\n"
   } else {
      ts_log_washing_machine
   }
}

# ================================================================================
# private functions
# ================================================================================

#****** logging/ts_log_init_level_map() ****************************************
#  NAME
#     ts_log_init_level_map() -- internal function - initialize datastructures
#
#  SYNOPSIS
#     ts_log_init_level_map {} 
#
#  FUNCTION
#     Initializes the ts_log_level_map.
#     ts_log_level_map is a TCL array, containing
#     - a mapping from level name to level number
#     - a mapping from level number to level name
#
#  SEE ALSO
#     logging/ts_log_get_level_name()
#     logging/ts_log_get_level_number()
#*******************************************************************************
proc ts_log_init_level_map {} {
   global ts_log_levels ts_log_level_map

   set num 0
   foreach level $ts_log_levels {
      set ts_log_level_map($num) $level
      set ts_log_level_map($level) $num
      incr num
   }
}

#****** logging/ts_log_get_function() ******************************************
#  NAME
#     ts_log_get_function() -- get name of function triggering logging
#
#  SYNOPSIS
#     ts_log_get_function {}
#
#  FUNCTION
#     Internal function!
#     Retrieve the name of the function which has triggered a logging call.
#
#  RESULT
#     A function name.
#
#  SEE ALSO
#     logging/ts_log_get_stacktrace()
#*******************************************************************************
proc ts_log_get_function {} {
   # assume that we got called from ts_private_do_log, 
   # called from ts_log, ts_log_severe, ts_log_warning, etc.
   # so we skip our own level, plus 2 other levels
   set stack_level [expr [info level] -3]
   if {$stack_level > 0} {
      set function [lindex [info level $stack_level] 0]
   } else {
      set function "toplevel"
   }

   return $function
}

#****** logging/ts_log_get_stacktrace() ****************************************
#  NAME
#     ts_log_get_stacktrace() -- get stacktrace of calling function
#
#  SYNOPSIS
#     ts_log_get_stacktrace {}
#
#  FUNCTION
#     Internal function!
#     Get a stacktrace up to the calling function.
#
#  RESULT
#     String containing the stack trace.
#
#  EXAMPLE
#     A stacktrace delivered by this function:
#     0: toplevel
#     1: menu
#     2: compile_source
#     3: shutdown_core_system 0 1
#     4: check_for_core_files oin /export/home/testsuite/7478/execd/oin
#
#  SEE ALSO
#     logging/ts_log_get_function()
#*******************************************************************************
proc ts_log_get_stacktrace {} {
   # assume that we got called from ts_private_log_send_mail, 
   # called from ts_private_do_log,
   # called from ts_log, ts_log_severe, ts_log_warning, etc.
   # so we skip our own level, plus 3 other levels
   set stack_level [expr [info level] -4]
   set stack_trace "  0: toplevel\n"
   for {set i 1} {$i <= $stack_level} {incr i} {
      append stack_trace [format "%3d: %s\n" $i [info level $i]]
   }

   return $stack_trace
}

#****** logging/ts_log_get_level_name() ****************************************
#  NAME
#     ts_log_get_level_name() -- return name of a logging level
#
#  SYNOPSIS
#     ts_log_get_level_name {level} 
#
#  FUNCTION
#     Returns the name of a given logging level.
#
#  INPUTS
#     level - number or name of a logging level
#
#  RESULT
#     name of the logging level
#
#  EXAMPLE
#     ts_log_get_level_name "INFO"     --> "INFO"
#     ts_log_get_level_name 3          --> "INFO"
#     ts_log_get_level_name 0          --> "SEVERE"
#     ts_log_get_level_name -1         --> invalid level, we get a TCL error
#
#  SEE ALSO
#     logging/ts_log_get_level_number()
#*******************************************************************************
proc ts_log_get_level_name {level} {
   global ts_log_level_map

   # check if we got a valid level name or number
   if {![info exists ts_log_level_map($level)]} {
      puts "!!! invalid logging level $level !!!"
      here_we_trigger_a_TCL_stacktrace
   }

   # if we got a level number, map it to the name
   if {[string is integer $level]} {
      set level $ts_log_level_map($level)
   }

   return $level
}

#****** logging/ts_log_get_level_number() ****************************************
#  NAME
#     ts_log_get_level_name() -- return number of a logging level
#
#  SYNOPSIS
#     ts_log_get_level_number {level} 
#
#  FUNCTION
#     Returns the number of a given logging level.
#
#  INPUTS
#     level - number or name of a logging level
#
#  RESULT
#     number of the logging level
#
#  EXAMPLE
#     ts_log_get_level_number "INFO"     --> 3
#     ts_log_get_level_number 3          --> 3
#     ts_log_get_level_number "SEVERE"   --> 0
#     ts_log_get_level_number "BLAH"     --> invalid level name, we get a TCL error
#
#  SEE ALSO
#     logging/ts_log_get_level_name()
#*******************************************************************************
proc ts_log_get_level_number {level} {
   global ts_log_level_map

   # check if we got a valid level name or number
   if {![info exists ts_log_level_map($level)]} {
      puts "!!! invalid logging level $level !!!"
      here_we_trigger_a_TCL_stacktrace
   }

   # if we got a level name, map it to the number
   if {![string is integer $level]} {
      set level $ts_log_level_map($level)
   }

   return $level
}
#****** logging/ts_log_get_level_abbreviation() ********************************
#  NAME
#     ts_log_get_level_abbreviation() -- get one character level abbreviation
#
#  SYNOPSIS
#     ts_log_get_level_abbreviation {level raise_error}
#
#  FUNCTION
#     Return an abbreviation of a logging level.
#     Abbreviation is the first character of the logging level.
#     When raise_error = 1, this is a capital case letter,
#     when raise_error = 0, it is the lower case letter.
#
#  INPUTS
#     level       - level name or number
#     raise_error - from the calling function: did caller intend to raise an
#                   error condition in case of errors?
#
#  RESULT
#     one letter abbreviation
#
#  EXAMPLE
#     ts_log_get_level_abbreviation INFO 1            --> I
#     ts_log_get_level_abbreviation INFO 0            --> i
#     ts_log_get_level_abbreviation SEVERE 1          --> S
#
#  NOTES
#     There is no differentiation between the "FINE", "FINER", "FINEST" levels.
#
#  SEE ALSO
#     logging/ts_log_get_level_name()
#*******************************************************************************
proc ts_log_get_level_abbreviation {level raise_error} {
   set level_name [ts_log_get_level_name $level]
   set abbrev [string range $level_name 0 0]
   if {!$raise_error} {
      set abbrev [string tolower $abbrev]
   }

   return $abbrev
}

#****** logging/ts_private_do_log() ********************************************
#  NAME
#     ts_private_do_log() -- function doing the actual logging work
#
#  SYNOPSIS
#     ts_private_do_log {level message {raise_error 1} {function ""} 
#                        {do_output 1} {do_logging 1} {do_mail 1}}
#
#  FUNCTION
#     Internal function doing all logging work.
#     Depending on input parameters, triggers
#     - doing output to stdout
#     - doing logging to logfile
#     - sending mail
#     - storing error information in case of errors
#
#  INPUTS
#     level           - logging level
#     message         - the message to log
#     {raise_error 1} - raise an error condition in case of error messages
#                       (SEVERE, WARNING, CONFIG levels)
#     {function ""}   - Function name. If "" (default), figure out the function
#                       name from tcl stack.
#     {do_output 1}   - do output to stdout?
#     {do_logging 1}  - do logging to file?
#     {do_mail 1}     - do sending mail?
#*******************************************************************************
proc ts_private_do_log {level message {raise_error 1} {function ""} {do_output 1} {do_logging 1} {do_mail 1}} {
   # get level as integer - we might have got the level name
   set level [ts_log_get_level_number $level]

   # remove trailing garbage
   # do *not* remove formatting characters at message begin!
   set message [string trimright $message]

   # request the function name of the calling function
   if {$function == ""} {
      set function [ts_log_get_function]
   }

   # make sure error conditions are stored
   ts_private_log_store_error $level $message $raise_error $function

   # do output to stdout
   if {$do_output} {
      ts_private_log_do_output $level $message $raise_error $function
   }

   # do logging to file
   if {$do_logging} {
      ts_private_log_do_logging $level $message $raise_error $function
   }
   
   # send mail
   if {$do_mail} {
      ts_private_log_send_mail $level $message $raise_error $function
   }
}

#****** logging/ts_private_log_store_error() ***********************************
#  NAME
#     ts_private_log_store_error() -- store error description
#
#  SYNOPSIS
#     ts_private_log_store_error {level message raise_error function}
#
#  FUNCTION
#     If called from error logging (level SEVERE, WARNING, or CONFIG),
#     and raise_error is 1, 
#     stores the error description in the global variables
#     check_errno and check_errstr.
#     
#     The error information is used by the testsuite framework to 
#     figure out, if a check was successfull, and is stored in 
#     per check information.
#
#  INPUTS
#     level       - logging level
#     message     - error message
#     raise_error - shall an error condition be raised?
#     function    - name of the function having triggered error output
#
#  SEE ALSO
#     check/print_errors()
#     check/save_result()
#*******************************************************************************
proc ts_private_log_store_error {level message raise_error function} {
   global CHECK_CUR_PROC_NAME check_name
   global check_errno check_errstr
   global DISABLE_ADD_PROC_ERROR
  
   # only if error logging is not disabled
   # not during setup
   # only store SEVERE, WARNING, CONFIG (the former "unsupported")
   if {$DISABLE_ADD_PROC_ERROR || !$raise_error || $level > 2} {
      return
   }

   # this is our error descriptor
   set new_error "$function|$check_name|$CHECK_CUR_PROC_NAME|$message"

   # store the list of errors that occured during the run of a test
   if {![info exists check_errno($CHECK_CUR_PROC_NAME)]} {
      set check_errno($CHECK_CUR_PROC_NAME) {}
      set check_errstr($CHECK_CUR_PROC_NAME) {}
   }
   lappend check_errno($CHECK_CUR_PROC_NAME) [expr -1 -$level]
   lappend check_errstr($CHECK_CUR_PROC_NAME) $new_error
}

#****** logging/ts_private_log_do_output() *************************************
#  NAME
#     ts_private_log_do_output() -- write output to stdout
#
#  SYNOPSIS
#     ts_private_log_do_output {level message raise_error function}
#
#  FUNCTION
#     Outputs a message to stdout.
#     For error messages (SEVERE, WARNING, CONFIG), additional information
#     like the runlevel, the check_name, check_function etc. are output.
#     Expected error messages (raise_error = 0) are marked as such.
#
#     If messages of the given level shall not be output,
#     a "washing machine" is output instead.
#
#  INPUTS
#     level       - logging level
#     message     - message to output
#     raise_error - raise an error condition?
#     function    - name of the function having called logging
#*******************************************************************************
global last_debug_msec
set last_debug_msec [clock clicks -milliseconds]
proc ts_private_log_do_output {level message raise_error function} {
   global ts_log_config
   global CHECK_ACT_LEVEL CHECK_CUR_PROC_NAME CHECK_DEBUG_LEVEL check_name

   if {$level <= $ts_log_config(output)} {
      # in debug mode, we want to see the milliseconds since last output
      if {$CHECK_DEBUG_LEVEL > 0} {
         global last_debug_msec
         set now [clock clicks -milliseconds]
         set time [expr $now - $last_debug_msec]
         set last_debug_msec $now
         set message "$time: $message"
      }
      # for SEVERE, WARNING, and CONFIG, we output some more info
      if {$level <= 2} {
         if {$raise_error} {
            puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
            puts [ts_log_get_level_name $level]
            puts "runlevel    : \"[get_run_level_name $CHECK_ACT_LEVEL]\", ($CHECK_ACT_LEVEL)"
            puts "check       : $check_name"
            puts "procedure   : $function"
            puts "called from : $CHECK_CUR_PROC_NAME"
            puts "----------------------------------------------------------------"
            puts $message
            puts "----------------------------------------------------------------"
            puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
         } else {
            puts "----------------------------------------------------------------"
            puts "!!   The following message is an *expected* error condition   !!"
            puts $message  
            puts "----------------------------------------------------------------"
         }
      } else {
         puts $message
      }
   } else {
      ts_log_washing_machine
   }
}

#****** logging/ts_private_log_do_logging() ************************************
#  NAME
#     ts_private_log_do_logging() -- write output to logfile
#
#  SYNOPSIS
#     ts_private_log_do_logging {level message raise_error function}
#
#  FUNCTION
#     Writes a message to the logfile.
#     The logfile format has fixed column width, columns separated by "|".
#     A logfile entry contains
#     - Timestamp
#     - level abbreviation
#     - name of the function having called logging
#     - the message itself
#
#     Multi line messages are formatted in multiple lines.
#
#  INPUTS
#     level       - logging level
#     message     - message to output
#     raise_error - raise an error condition?
#     function    - name of the function having called logging
#
#  EXAMPLE:
#     ts_log_severe "message with function name passed" 1 "my function"
#     2008-01-14 11:59:40|S|         my function|message with function name passed
#
#     ts_log_severe "multi line message\nsecond line\nthird line\nlast line"
#     2008-01-14 11:59:44|S|         ts_log_test|multi line message
#                      + |S|                  + |second line
#                      + |S|                  + |third line
#                      + |S|                  + |last line
#
#     ts_log_warning "a warning message"
#     ts_log_warning "a warning message" 0
#     2008-01-14 11:59:52|W|         ts_log_test|a warning message
#     2008-01-14 11:59:53|w|         ts_log_test|a warning message
#
#     ts_log_info "a info message"
#     2008-01-14 11:59:56|I|         ts_log_test|a info message
#*******************************************************************************
proc ts_private_log_do_logging {level message raise_error function} {
   global ts_log_logfile ts_log_config

   if {$ts_log_logfile == "" || $level > $ts_log_config(logging)} {
      return
   }

   set FORMAT "%19s|%1s|%25s|%s"
   set date_time [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
   set level_abbrev [ts_log_get_level_abbreviation $level $raise_error]
   set lines [split $message "\n"]
   puts $ts_log_logfile [format $FORMAT $date_time $level_abbrev $function [lindex $lines 0]]
   for {set i 1} {$i < [llength $lines]} {incr i} {
      puts $ts_log_logfile [format $FORMAT " + " $level_abbrev " + " [lindex $lines $i]]
   }
   flush $ts_log_logfile
}

#****** logging/ts_private_log_send_mail() *************************************
#  NAME
#     ts_private_log_send_mail() -- send a message by mail
#
#  SYNOPSIS
#     ts_private_log_send_mail {level message raise_error function}
#
#  FUNCTION
#     Sends a message by mail.
#     Receiver / CC is taken from the testsuite configuration.
#     The mail contains additional information like
#     - runlevel, check_name, check_function
#     - a stack trace up to the caller of the logging function
#     - the testsuite configuration
#
#  INPUTS
#     level       - logging level
#     message     - message to output
#     raise_error - raise an error condition?
#     function    - name of the function having called logging
#
#  EXAMPLE
#     ts_log_severe "multi line message\nsecond line\nthird line\nlast line"
#     generates the following mail content:
#
#     Date            : Mon Jan 14 11:59:44 MET 2008
#     check_name      : enhanced_setup
#     category        : SEVERE
#     runlevel        : short (level: 0)
#     check host      : oin
#     product version : system not running
#     --------------------------------------------------------------------------------
#     multi line message
#     second line
#     third line
#     last line
#     --------------------------------------------------------------------------------
#     
#     
#     Stack Trace:
#     ============
#      0: toplevel
#      1: ts_log_test
#     
#     
#     Testsuite configuration (ts_config):
#     ====================================
#     Testsuite configuration setup:                                               "1.14"
#     Gridengine Version, e.g. 53 for SGE(EE) 5.3, or 60 for N1GE 6.0:             "61"
#     ...
#*******************************************************************************
global ts_private_do_log_recursive
set ts_private_do_log_recursive 0
proc ts_private_log_send_mail {level message raise_error function} {
   global ts_log_config
   global CHECK_CUR_PROC_NAME check_name
   global CHECK_ACT_LEVEL
   global CHECK_SEND_ERROR_MAILS
   global DISABLE_ADD_PROC_ERROR
   global ts_private_do_log_recursive

   # shall we send mail at all, and for this level?
   if {!$CHECK_SEND_ERROR_MAILS || $level > $ts_log_config(mail)} {
      return
   }

   # only if error logging is not disabled,
   # not during setup
   if {$DISABLE_ADD_PROC_ERROR == 1 || !$raise_error || $check_name == "setup"} {
      return
   }

   # ts_private_do_log could be called recursively, for example, 
   # if errors occur while sending the error message as mail.
   # In this case, just output the error message - Otherwise we might 
   # end up in endless recursion.
   if {$ts_private_do_log_recursive} {
      puts ""
      puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      puts "recursive call of logging (ts_log_*) at"
      puts [ts_log_get_stacktrace]
      puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      puts ""
      return
   }
   set ts_private_do_log_recursive 1

   get_current_cluster_config_array ts_config
   set stack_trace [ts_log_get_stacktrace]
   set category [ts_log_get_level_name $level]

   append mail_body "\n"
   append mail_body "Date            : [clock format [clock seconds]]\n"
   append mail_body "check_name      : $check_name\n"
   append mail_body "category        : $category\n"
   append mail_body "runlevel        : [get_run_level_name $CHECK_ACT_LEVEL] (level: $CHECK_ACT_LEVEL)\n"
   append mail_body "check host      : $ts_config(master_host)\n"
   append mail_body "product version : [get_version_info]\n"
   append mail_body "--------------------------------------------------------------------------------\n"
   append mail_body $message
   append mail_body "\n--------------------------------------------------------------------------------\n"

   append mail_body "\n\nStack Trace:\n"
   append mail_body "============\n"
   append mail_body $stack_trace

   append mail_body "\n\nTestsuite configuration (ts_config):\n"
   append mail_body "====================================\n"
   show_config ts_config 0 mail_body

   mail_report "testsuite $category - $check_name" $mail_body

   set ts_private_do_log_recursive 0
}

#****** logging/ts_log_washing_machine() ***************************************
#  NAME
#     ts_log_washing_machine() -- print "washing machine"
#
#  SYNOPSIS
#     ts_log_washing_machine {}
#
#  FUNCTION
#     Prints the "washing machine" on stdout.
#*******************************************************************************
global ts_log_washing_machine_next_timestamp ts_log_washing_machine_counter ts_log_washing_machine_enabled
set ts_log_washing_machine_next_timestamp 0
set ts_log_washing_machine_counter 0
set ts_log_washing_machine_enabled 1
proc ts_log_washing_machine {} {
   global ts_log_washing_machine_next_timestamp
   global ts_log_washing_machine_counter
   global ts_log_washing_machine_enabled

   if {!$ts_log_washing_machine_enabled} {
      return
   }
   set now [clock clicks -milliseconds]
   if {$ts_log_washing_machine_next_timestamp < $now} {
      set ts_log_washing_machine_next_timestamp [expr $now + 100]
      switch [expr $ts_log_washing_machine_counter % 4] {
         0 { puts -nonewline "\r-\r"  ; flush stdout }
         1 { puts -nonewline "\r\\\r" ; flush stdout }
         2 { puts -nonewline "\r|\r"  ; flush stdout }
         3 { puts -nonewline "\r/\r"  ; flush stdout }
      }
      incr ts_log_washing_machine_counter
   }
}

proc set_ts_log_washing_machine { value } {
   global ts_log_washing_machine_enabled
   set ts_log_washing_machine_enabled $value
}

proc get_ts_log_washing_machine { } {
   global ts_log_washing_machine_enabled
   return $ts_log_washing_machine_enabled
}


# end of private functions
# ================================================================================
# some tests
# call via 
# expect check.exp execute_func ts_log_test

proc ts_log_sub_test {arg1 arg2} {
   ts_log_severe "message from function sub_test"
}

proc ts_log_test {} {
   ts_log_severe "message with function name passed" 1 "my function"
   ts_log_severe "multi line message\nsecond line\nthird line\nlast line"
   ts_log_sub_test "foo bar" 1

   ts_log_info "now we want to see the washing machine"
   for {set i 0} {$i < 50} {incr i} {
      ts_log_finest "blah"
      after 50
   }

   ts_log_warning "a warning message"
   ts_log_warning "a warning message" 0
   ts_log_config "a config message"
   ts_log_config "a config message" 0
   ts_log_info "a info message"
   ts_log_fine "a fine message"
   ts_log_finer "a finer message"
   ts_log_finest "a finest message"
}
