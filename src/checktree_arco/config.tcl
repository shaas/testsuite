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

#****** config/arco_verify_config() ********************************************
#  NAME
#     arco_verify_config() -- verify arco configuration setup
#
#  SYNOPSIS
#     arco_verify_config { config_array only_check parameter_error_list }
#
#  FUNCTION
#     This procedure will verify or enter arco setup configuration
#
#  INPUTS
#     config_array         - array name with configuration (arco_config)
#     only_check           - if 1: don't ask user, just check
#     parameter_error_list - returned list with error information
#
#  SEE ALSO
#     check/verify_config()
#     config/arco_init_config()
#     config/arco_save_configuration()
#
#*******************************************************************************
proc arco_verify_config {config_array only_check parameter_error_list} {
   global ts_checktree arco_checktree_nr
   upvar $config_array config
   upvar $parameter_error_list param_error_list
   
   arco_config_upgrade_1_1 config
   arco_config_upgrade_1_2 config
   arco_config_upgrade_1_3 config
   arco_config_upgrade_1_4 config
   arco_config_upgrade_1_5 config

   return [verify_config2 config $only_check param_error_list $ts_checktree($arco_checktree_nr,setup_hooks_0_version)]   
}

#****** config/arco_save_configuration() ***************************************
#  NAME
#     arco_save_configuration() -- save testsuite configuration (arco_config array)
#
#  SYNOPSIS
#     arco_save_configuration { filename } 
#
#  FUNCTION
#     This procedure will save the actual arco_config array settings to the
#     filename.
#
#  SEE ALSO
#     check/save_configuration()
#     check/verify_config()
#     config/arco_init_config()
#
#*******************************************************************************
proc arco_save_configuration { filename } {
   global arco_config ts_checktree arco_checktree_nr

   set conf_name $ts_checktree($arco_checktree_nr,setup_hooks_0_name)
   
   if { [ info exists arco_config(version) ] == 0 } {
      puts "no version"
      wait_for_enter
      return -1
   }

   # first get old configuration
   read_array_from_file  $filename $conf_name old_config
   # save old configuration 
   spool_array_to_file $filename "$conf_name.old" old_config
   spool_array_to_file $filename $conf_name arco_config  
   ts_log_fine "new $conf_name saved"

   wait_for_enter

   return 0
}

#****** config/arco_init_config() **********************************************
#  NAME
#     arco_init_config() -- init configuration hook for arco
#
#  SYNOPSIS
#     arco_init_config { config_array } 
#
#  FUNCTION
#     This hook is used to create arco configuration array.
#
#  INPUTS
#     config_array - the array where the configuration values should be stored

#  SEE ALSO
#     config/arco_save_configuration()
#     config/arco_verify_config()
#
#*******************************************************************************
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
   arco_config_upgrade_1_4 config
   arco_config_upgrade_1_5 config
}

proc arco_config_upgrade_1_1 { config_array } {

   upvar $config_array config

   if { $config(version) == "1.0" } {
      ts_log_fine "Upgrade to version 1.1"
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
   
   upvar $config_array config

   if { $config(version) == "1.1" } {
   
      ts_log_fine "Upgrade to version 1.2"

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
   
   upvar $config_array config

   if { $config(version) == "1.2" } {

      ts_log_fine "Upgrade to version 1.3"

      # insert new parameter after jdbc_driver host parameter
      set insert_pos $config(jdbc_driver,pos)
      incr insert_pos 1

      # new parameter TABLESPACE
      set parameter "tablespace"
      set config($parameter)            ""
      set config($parameter,desc)       "TABLESPACE for tables"
      set config($parameter,default)    ""
      set config($parameter,setup_func) "config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos

      incr insert_pos 1

      # new parameter TABLESPACE_INDEX
      set parameter "tablespace_index"
      set config($parameter)            ""
      set config($parameter,desc)       "TABLESPACE for indexes"
      set config($parameter,default)    ""
      set config($parameter,setup_func) "config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos

      # now we have a configuration version 1.3
      set config(version) "1.3"
   }

}

proc arco_config_upgrade_1_4 { config_array } {
   
   upvar $config_array config

   if { $config(version) == "1.3" } {

      ts_log_fine "Upgrade to version 1.4"

      # insert new parameter after tablespace_index parameter
      set insert_pos $config(tablespace_index,pos)
      incr insert_pos 1

      # new parameter DB_SCHEMA
      set parameter "database_schema"
      set config($parameter)            ""
      set config($parameter,desc)       "Database schema"
      set config($parameter,default)    "public"
      set config($parameter,setup_func) "config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos
      
      # now we have a configuration version 1.4
      set config(version) "1.4"
   }
}

proc arco_config_upgrade_1_5 { config_array } {
   upvar $config_array config

   if { $config(version) == "1.4" } {

      ts_log_fine "Upgrade to version 1.5"

      # using global database configuration
      # delete unnecessary parameters
      set param_list ""
      lappend param_list "database_type"
      lappend param_list "database_host"
      lappend param_list "database_port"
      lappend param_list "database_name"
      lappend param_list "database_write_user"
      lappend param_list "database_write_pw"
      lappend param_list "jdbc_driver"

      foreach param $param_list {
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
      }

      # add a new parameter database before tablespace
      set insert_pos $config(tablespace,pos)
      set names [array names config "*,pos"]
      foreach name $names {
         if { $config($name) >= $insert_pos } {
            set config($name) [ expr ( $config($name) + 1 ) ]
         }
      }

      set parameter "database"
      set config($parameter)            ""
      set config($parameter,desc)       "Database"
      set config($parameter,default)    ""
      set config($parameter,setup_func) "config_$parameter"
      set config($parameter,onchange)   "install"
      set config($parameter,pos) $insert_pos

      # now we have a configuration version 1.5
      set config(version) "1.5"
   }
}

#****** config/config_*() ******************************************************
#  NAME
#     config_*() -- configuration procedures for each parameter
#
#  SYNOPSIS
#     config_* { only_check name config_array } 
#
#  FUNCTION
#     These procedures are used to configure parameters of arco configuration.
#
#  INPUTS
#     only_check   - If set != 0: no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#
#  SEE
#     config_arco_source_dir()
#     config_dbwriter_host()
#     config_database_schema()
#     config_database_write_user()
#     config_database_read_user()
#     config_database_write_pw()
#     config_arco_dbwriter_debug_level()
#     config_arco_dbwriter_interval()
#     config_jdbc_driver()
#     config_swc_host()
#     config_tablespace()
#     config_tablespace_index()
#     config_database()
#
#  DEPRECATED
#     config_database_type()
#     config_database_host()
#     config_database_port()
#     config_database_name()
#     config_database_read_pw()
#     config_arco_spool_dir()
#     config_java_home()
#
#  SEE ALSO
#     check/config_database()
#
#*******************************************************************************
proc config_arco_source_dir { only_check name config_array } {
   global fast_setup
   
   upvar $config_array config
   
   set help_text {  "Enter the full path to ARCo source directory."
                    "The testsuite needs this directory to build ARCo." }
   
   set value [config_generic $only_check $name config $help_text "directory" 0]

   if { $value == -1 } { return -1 }

   if {!$fast_setup} {
      if { [ file isfile $value/build.sh ] != 1 } {
         puts "File \"$value/build.sh\" not found"
         return -1
}
   }
   return $value
}

proc config_dbwriter_host { only_check name config_array } {

   upvar $config_array config
   
   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts "Could not get local host name" 
         return -1
      }

   set config($name,default) $local_host
   array set params { verify "compile" }

   return [config_generic $only_check $name config "" "host" 0 1 "" params]

}

# @deprecated
proc config_database_type { only_check name config_array } {
   upvar $config_array config
   
   set help_text {  "Enter the database type, or press >RETURN<"
                    "to use the default value."
                    "Valid values are \"postgres\", \"oracle\" or \"mysql\"" }
                    
       
   set db_type [config_generic $only_check $name config $help_text "string" ]

   if { $db_type == "postgres" || $db_type == "oracle" || $db_type == "mysql" } {
      default_config_values $db_type config
      return $db_type
   }
   return -1
}

# @deprecated
proc config_database_host { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter the name of your database host, or press >RETURN<"
                    "to use the default value." }

   return [config_generic $only_check $name config $help_text "string"]
}

# @deprecated
proc config_database_port { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter the name of your database port, or press >RETURN<"
                    "to use the default value." }

   return [config_generic $only_check $name config $help_text "string"]
}

# @deprecated
proc config_database_name { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter the name of your database, or press >RETURN<"
                    "to use the default value." }

   return [config_generic $only_check $name config $help_text "string"]
}

proc config_database_schema { only_check name config_array } {
   global ts_db_config
   
   upvar $config_array config
   
   set db_type ""
   if {[info exists ts_db_config($config(database),dbtype)] } { set db_type $ts_db_config($config(database),dbtype) }

   switch -- $db_type {
      "postgres" {
         set help_text { "Enter the name of the tablespace used for tables,"
                         "or press >RETURN< to use the default value." }
         return [config_generic $only_check $name config $help_text "string" 0]
}
      default {
         array set choices {}
         return [config_generic $only_check $name config "" "choice" 1 1 choices]
      }
   }
}

# @deprecated
proc config_database_write_user { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter the name of the user which has write permissions on the database, or press >RETURN<"
                    "to use the default value." }

   return [config_generic $only_check $name config $help_text "string"]
}

# @deprecated
proc config_database_read_user { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter the name of the user which has read permissions on the database, or press >RETURN<"
                    "to use the default value." }

   return [config_generic $only_check $name config $help_text "string"]
}

# @deprecated
proc config_database_write_pw { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter the password of the user which has write permissions on the database, or press >RETURN<"
                    "to use the default value." }

   return [config_generic $only_check $name config $help_text "string" 0]
}

# @deprecated
proc config_database_read_pw { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter the password of the user which has read permissions on the database, or press >RETURN<"
                    "to use the default value." }

   return [config_generic $only_check $name config $help_text "string"]
}

# @deprecated
proc config_arco_spool_dir { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter path to the ARCo spool directory, or press >RETURN<"
                    "to use the default value." }

   return [config_generic $only_check $name config $help_text "directory"]
}

proc config_arco_dbwriter_debug_level { only_check name config_array } {
   
   upvar $config_array config
   
   array set levels {
      WARNING ""
      INFO ""
      FINE ""
}
   return [config_generic $only_check $name config "" "choice" 0 1 levels]
}

proc config_arco_dbwriter_interval { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter the dbwriter interval in seconds, or press >RETURN<"
                    "to use the default value."  }

   return [config_generic $only_check $name config $help_text "string" 0]
}

# @deprecated
proc config_jdbc_driver { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter the path to the JDBC driver or press >RETURN<"
                    "to use the default value."  }
     
   return [config_generic $only_check $name config $help_text "string"]
   
}

proc config_swc_host {only_check name config_array} {
   global ts_config fast_setup

   upvar $config_array config

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts "Could not get local host name" 
      return -1
   }
   
   set config($name,default) $local_host
      
   set swc_host [config_generic $only_check $name config "" "host" 0 1 ]

   if { $swc_host == -1 } { return -1 }

   if {$fast_setup == 0} {
      
      array set swc_version {}
      
      if {[get_java_web_console_version swc_version $swc_host]  < 0} {
         ts_log_severe "Can not determine version of java webconsole on host $swc_host"
         return -1
      }
   
      set num_version [expr $swc_version(major) * 10000 + $swc_version(minor) * 100 + $swc_version(micro)]
      if { $ts_config(gridengine_version) < 62 } {
         set exp_version [expr 2 * 10000 + 2 * 100 + 1]
         set err_msg "Version 2.2.1 or higher is required"
      } else {
         set exp_version [expr 3 * 10000]
         set err_msg "Version 3.0.0 or higher is required"
      }

      if {$num_version < $exp_version} {
         ts_log_severe $err_msg
         return -1
      }
   }

   return $swc_host
}

# @deprecated
proc config_java_home { only_check name config_array } {
   
   upvar $config_array config
   
   set help_text {  "Enter the JAVA_HOME path or press >RETURN<"
                    "to use the default value."  }
     
   return [config_generic $only_check $name config $help_text "directory"]
   
}

proc config_tablespace { only_check name config_array } {
   global ts_db_config

   upvar $config_array config

   set db_type ""
   if {[info exists ts_db_config($config(database),dbtype)] } { set db_type $ts_db_config($config(database),dbtype) }
   switch -- $db_type {
      "mysql" {
         array set choices {}
         return [config_generic $only_check $name config "" "choice" 1 1 choices]
}
      default {
         set help_text { "Enter the name of the tablespace used for tables,"
                         "or press >RETURN< to use the default value." }
         set allow_null 0
         if { [string compare $db_type ""] == 0 } { set allow_null 1 }
         return [config_generic $only_check $name config $help_text "string" $allow_null]
      }
   }
}

proc config_tablespace_index { only_check name config_array } {
   global ts_db_config

   upvar $config_array config
   
   set db_type ""
   if {[info exists ts_db_config($config(database),dbtype)] } { set db_type $ts_db_config($config(database),dbtype) }
     
   switch -- $db_type {
      "mysql" {
         array set choices {}
         return [config_generic $only_check $name config "" "choice" 1 1 choices]
}
      default {
         set help_text { "Enter the name of the tablespace used for indexes,"
                         "or press >RETURN< to use the default value." }
         set allow_null 0
         if { [string compare $db_type ""] == 0 } { set allow_null 1 }
         return [config_generic $only_check $name config $help_text "string" $allow_null]
      }
   }   
}

proc config_database { only_check name config_array } {
   global ts_db_config

   upvar $config_array config

   set old_value $config(database)

   set value [config_generic $only_check $name config "" "database" 0 1]

   if { $value == -1 } { return -1 }

   # set the default values for tablespaces
   if { [info exists ts_db_config($value,dbtype)] } {
      default_config_values $ts_db_config($value,dbtype) config

      if { [string compare $old_value $value] != 0 } {
         ts_log_fine "setting tablespace to:"
         ts_log_fine "\"$config(tablespace,default)\""
         set config(tablespace) $config(tablespace,default)
         ts_log_fine "setting tablespace_index to:"
         ts_log_fine "\"$config(tablespace_index,default)\""
         set config(tablespace_index) $config(tablespace_index,default)
         ts_log_fine "setting database_schema to:"
         ts_log_fine "\"$config(database_schema,default)\""
         set config(database_schema) $config(database_schema,default)
      }
   } else {
      ts_log_severe "Database $old_value was removed from database configuration."
      return -1
   }
   return $value
}

#****** config/default_config_values() *****************************************
#  NAME
#     default_config_values() -- set the default values dependent on database type
#
#  SYNOPSIS
#     default_config_values { db_type config_array } 
#
#  FUNCTION
#     This procedure will set the default values for parameters dependent on the 
#     given database type (tablespace, tablespace_index, database_schema)
#
#  INPUTS
#     db_type      - database type
#     config_array - The configuration array where the value is stored
#
#  SEE ALSO
#     config/config_database()
#
#*******************************************************************************
proc default_config_values { db_type config_array } {

   upvar $config_array config

   if { $db_type == "oracle" } {
      if { $config(version) >= "1.3" } {
         set config(tablespace,default)          "USERS"
         set config(tablespace_index,default)    "USERS"
      }
      if { $config(version) >= "1.4" } {
         set config(database_schema,default)     "none"
      }
   }
   if { $db_type == "postgres" } {
      if { $config(version) >= "1.3" } {
         set config(tablespace,default)          "pg_default"
         set config(tablespace_index,default)    "pg_default"
      }
      if { $config(version) >= "1.4" } {
         set config(database_schema,default)     "public"
      }
   }
   if { $db_type == "mysql" } {
      if { $config(version) >= "1.3" } {
         set config(tablespace,default)          "none"
         set config(tablespace_index,default)    "none"
      }
      if { $config(version) >= "1.4" } {
         set config(database_schema,default)     "none"
      }
   }
   return 0
}

#****** config/get_*() *********************************************************
#  NAME
#     get_*() -- getter procedures for each parameter
#
#  SYNOPSIS
#     get_* {  } or get_* { { use_admin_db 0 } }
#
#  FUNCTION
#     These procedures are used to retrieve arco configuration parameters.
#
#  INPUTS
#     dependent on parameter
#     { use_admin_db 0 }   - 0 for tested database (arco_xxxx)
#                            1 for admin database  (arco)
#     dbname               - database name
#  SEE
#     get_database_type()
#     get_database_name()
#     get_database_host()
#     get_database_port()
#     get_jdbc_driver_path()
#     get_jdbc_driver()
#     get_jdbc_url()
#     get_arco_write_user()
#     get_arco_user_pwd()
#     get_arco_read_user()
#     get_database_schema()
#
#*******************************************************************************
proc get_database_type { } {
   global arco_config
   if { $arco_config(version) >= "1.5" } {
      global ts_db_config
      set db_type $ts_db_config($arco_config(database),dbtype)
   } else {
      set db_type $arco_config(database_type)
   }
   return $db_type
}

proc get_database_name { { use_admin_db 0 } } {
   global arco_config
   if { $use_admin_db == 0 && [get_database_type] != "oracle" } {
      global ts_config
      set db_name  "arco_${ts_config(commd_port)}"
   } else {
      if { $arco_config(version) >= "1.5" } {
         global ts_db_config
         set db_name $ts_db_config($arco_config(database),dbname)
      } else {
         set db_name $arco_config(database_name)
      }
   }
   return $db_name
}

proc get_database_host { } {
   global arco_config
   if { $arco_config(version) >= "1.5" } {
      global ts_db_config
      set db_host $ts_db_config($arco_config(database),dbhost)
   } else {
      set db_host $arco_config(database_host)
   }
   return $db_host
}

proc get_database_port { } {
   global arco_config
   if { $arco_config(version) >= "1.5" } {
      global ts_db_config
      set db_port $ts_db_config($arco_config(database),dbport)
   } else {
      set db_port $arco_config(database_port)
   }
   return $db_port
}

proc get_jdbc_driver_path { } {
   global arco_config
   if { $arco_config(version) >= "1.5" } {
      global ts_db_config
      set jdbc_driver $ts_db_config($arco_config(database),driverpath)
   } else {
      set jdbc_driver $arco_config(jdbc_driver)
   }
   return $jdbc_driver
}

proc get_jdbc_driver { } {
   global ts_db_config
   return $ts_db_config([get_database_type],driver)
}

proc get_jdbc_url { dbname } {
   global ts_db_config
   set url $ts_db_config([get_database_type],url)
   set url [replace_string $url "\$db_host" [get_database_host]]
   set url [replace_string $url "\$port" [get_database_port]]
   set url [replace_string $url "\$db_name" $dbname]
   return $url
}

proc get_arco_write_user { { use_admin_db 0 } } {
   global arco_config
   if { $use_admin_db == 0 } {
      global ts_config
      if { [get_database_type] == "oracle" } {
         set write_user "ARCO_WRITE_${ts_config(commd_port)}"
      } else {
         set write_user "arco_write_${ts_config(commd_port)}"
      }
   } else {
      if { $arco_config(version) >= "1.5" } {
         global ts_db_config
         set write_user $ts_db_config($arco_config(database),username)
      } else {
         set write_user $arco_config(database_write_user)
      }
   }
   return $write_user
}

proc get_arco_user_pwd { { use_admin_db 0 } } {
   global arco_config
   if { $use_admin_db == 0 } {
      set user_pwd "secret"
   } else {
      if { $arco_config(version) >= "1.5" } {
         global ts_db_config
         set user_pwd $ts_db_config($arco_config(database),password)
      } else {
         set user_pwd $arco_config(database_write_pw)
      }
   }
   return $user_pwd
}

proc get_arco_read_user {} {
   global arco_config ts_config
   if { [get_database_type] == "oracle" } {
      return "ARCO_READ_${ts_config(commd_port)}"
   } else {
      return "arco_read_${ts_config(commd_port)}"
   }
}

proc get_database_schema { } {
   global arco_config
   set db_type [get_database_type]
   switch -- $db_type {
      "oracle" { 
         set db_schema   [get_arco_write_user]
      }
      "mysql" {
         set db_schema   [get_database_name]
      }
      default {
         set db_schema $arco_config(database_schema)
      }
   }
   return $db_schema
}
