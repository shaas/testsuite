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

global ts_db_config                       ;# new testsuite database config array
global actual_ts_db_config_version      ;# actual database config version number
set    actual_ts_db_config_version "1.0"

if {![info exists ts_db_config]} {
   # ts_db_config defaults
   set parameter "version"
   set ts_db_config($parameter)            "$actual_ts_db_config_version"
   set ts_db_config($parameter,desc)       "Testuite database configuration setup"
   set ts_db_config($parameter,default)    "$actual_ts_db_config_version"
   set ts_db_config($parameter,setup_func) ""
   set ts_db_config($parameter,onchange)   "stop"
   set ts_db_config($parameter,pos)        1

   set parameter "dbtypelist"
   set ts_db_config($parameter)            ""
   set ts_db_config($parameter,desc)       "Supported database types"
   set ts_db_config($parameter,default)    ""
   set ts_db_config($parameter,setup_func) "db_config_$parameter"
   set ts_db_config($parameter,onchange)   ""
   set ts_db_config($parameter,pos)        2

   set parameter "databaselist"
   set ts_db_config($parameter)            ""
   set ts_db_config($parameter,desc)       "Testsuite cluster database list"
   set ts_db_config($parameter,default)    ""
   set ts_db_config($parameter,setup_func) "db_config_$parameter"
   set ts_db_config($parameter,onchange)   ""
   set ts_db_config($parameter,pos)        3

}

#****** config_database/db_config_dbtypelist() *********************************
#  NAME
#     db_config_dbtypelist() -- database list setup
#
#  SYNOPSIS
#     db_config_dbtypelist { only_check name config_array } 
#
#  FUNCTION
#     Testsuite supported database types configuration setup.
#     Examples of database types: oracle, postgres, mysql
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_user_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup_db_config()
#     check/verify_db_config()
#
#*******************************************************************************
proc db_config_dbtypelist { only_check name config_array } {
   upvar $config_array config

   set description   $config($name,desc)

   if { $only_check == 0 } {
      set not_ready 1
      while { $not_ready } {
         clear_screen
         puts "\nGlobal database types configuration setup"
         puts "========================================="
         puts "\n    database types configured: [llength $config(dbtypelist)]"
         db_config_dbtypelist_show_dbtypes config
         puts "\n\n(1)  add database type"
         puts "(2)  edit database type"
         puts "(3)  delete database type"
         puts "(10) exit setup"
         puts -nonewline "> "
         set input [ wait_for_enter 1]
         switch -- $input {
             1 {
                set result [db_config_dbtypelist_add_dbtype config]
                if { $result != 0 } {
                   wait_for_enter
                }
             }
             2 {
                set result [db_config_dbtypelist_edit_dbtype config]
                if { $result != 0 } {
                   wait_for_enter
                }
             }
             3 {
               set result [db_config_dbtypelist_delete_dbtype config]
                if { $result != 0 } {
                   wait_for_enter
                }
             }
             10 {
                set not_ready 0
             }
         }
      }
   }

   # check database type configuration
   ts_log_finest "db_config_dbtypelist:"
   foreach dbtype $config(dbtypelist) {
      ts_log_finest "checking database type \"$dbtype\" ... "
   }

   return $config(dbtypelist)
}

#****** config_database/db_config_dbtypelist_show_dbtypes() ********************
#  NAME
#     db_config_dbtypelist_show_dbtypes() -- show testsuite database type 
#                                            configuration
#
#  SYNOPSIS
#     db_config_dbtypelist_show_dbtypes { array_name } 
#
#  FUNCTION
#     This procedure will show the current testsuite database type configuration
#
#  INPUTS
#     array_name - ts_db_config
#
#  SEE ALSO
#     check/setup_db_config()
#     check/verify_db_config()
#
#*******************************************************************************
proc db_config_dbtypelist_show_dbtypes { array_name } {
   upvar $array_name config

   puts "\nDatabase type list:\n"
   if { [llength $config(dbtypelist)] == 0 } {
      puts "no database types defined"
   }
   set index 0
   foreach dbtype $config(dbtypelist) {
      incr index 1 
      puts "($index) $dbtype"
   }
}

#****** config_database/db_config_databaselist_add_database() ******************
#  NAME
#     db_config_dbtypelist_add_dbtype() -- add database type to database type 
#                                          configuration
#
#  SYNOPSIS
#     db_config_dbtypelist_add_dbtype { array_name { have_dbtype "" } }
#
#  FUNCTION
#     Add database type to testsuite database type configuration
#
#  INPUTS
#     array_name       - ts_db_config
#     { have_dbtype "" } - if not "": add this database type
#
#  SEE ALSO
#     check/setup_db_config()
#     check/verify_db_config()
#
#*******************************************************************************
proc db_config_dbtypelist_add_dbtype { array_name { have_dbtype "" } } {
   upvar $array_name config
  
   if { $have_dbtype == "" } {
      clear_screen
      puts "\nAdd database type to global database type configuration"
      puts "======================================================="

      db_config_dbtypelist_show_dbtypes config

      puts "\n"
      puts -nonewline "Please enter new database type: "
      set new_dbtype [wait_for_enter 1]
   } else {
      set new_dbtype $have_dbtype
   }

   if { [ string length $new_dbtype ] == 0 } {
      puts "no database type entered"
      return -1
   }
   
   if { [ string is integer $new_dbtype ] } {
      puts "invalid database type entered"
      return -1
   }
  
   if { [ lsearch $config(dbtypelist) $new_dbtype ] >= 0 } {
      puts "database type \"$new_dbtype\" is already in list"
      return -1
   }

   lappend config(dbtypelist) $new_dbtype
   set config($new_dbtype,port)   ""
   set config($new_dbtype,driver) ""
   set config($new_dbtype,url)    ""
   if { $have_dbtype == "" } {
      db_config_dbtypelist_edit_dbtype config $new_dbtype
   }
   return 0   
}

#****** config_database/db_config_dbtypelist_edit_dbtype() *********************
#  NAME
#     db_config_dbtypelist_edit_dbtype() -- edit database type configuration
#
#  SYNOPSIS
#     db_config_dbtypelist_edit_dbtype { array_name { have_dbtype "" } } 
#
#  FUNCTION
#     This procedure is used to edit the testsuite database type configuration
#
#  INPUTS
#     array_name       - ts_db_config
#     { have_database "" } - if not "": add this database type
#
#  SEE ALSO
#     check/setup_db_config()
#     check/verify_db_config()
#
#*******************************************************************************
proc db_config_dbtypelist_edit_dbtype { array_name { have_dbtype "" } } {
   upvar $array_name config

   set goto 0

   if { $have_dbtype != "" } {
      set goto $have_dbtype
   } 

   while { 1 } {

      clear_screen
      puts "\nEdit database type in global database type configuration"
      puts "========================================================"
   
      db_config_dbtypelist_show_dbtypes config

      puts "\n"
      puts -nonewline "Please enter database type/number or return to exit: "
      if { $goto == 0 } {
         set dbtype [wait_for_enter 1]
         set goto $dbtype
      } else {
         set dbtype $goto
         ts_log_fine $dbtype
      }
 
      if { [ string length $dbtype ] == 0 } {
         break
      }
     
      if { [string is integer $dbtype] } {
         incr dbtype -1
         set dbtype [ lindex $config(dbtypelist) $dbtype ]
      }

      if { [ lsearch $config(dbtypelist) $dbtype ] < 0 } {
         puts "database type \"$dbtype\" not found in list"
         wait_for_enter
         set goto 0
         continue
      }
      puts ""
      puts "   dbtype      : $dbtype"
      puts "   port        : $config($dbtype,port)"
      puts "   driver      : $config($dbtype,driver)"
      puts "   url         : $config($dbtype,url)"
   
      puts "\n"
      puts -nonewline "Please enter category to edit or hit return to exit > "
      set input [ wait_for_enter 1]
      if { [ string length $input ] == 0 } {
         set goto 0
         continue
      }

      if { [ string compare $input "dbtype"] == 0 } {
         puts "Setting \"$input\" is not allowed"
         wait_for_enter
         continue
      }

      if { [ info exists config($dbtype,$input) ] != 1 } {
         puts "Not a valid category"
         wait_for_enter
         continue
      }

      set extra 0
      switch -- $input {
         "port"    { set extra 1 }
         "driver"  { set extra 2 }
         "url"     { set extra 3 }
      }      

      if { $extra == 0 } {
         puts "\nPlease enter new $input value: "
         set value [ wait_for_enter 1 ]
      }
      
      if { $extra == 1 } {
         set help_text {  "Please enter the default port number:" }
         set value [ config_generic 0 "$dbtype,$input" config $help_text "string" ]
         if { [string is integer $value] && [ string length $value ] > 3 } {
            set config($dbtype,$input) $value
         } else {
            puts "$value is not a valid port number"
            wait_for_enter
         }
         continue
      }

      if { $extra == 2 } {
         set help_text {  "Please enter jdbc driver for $dbtype:" }
         set value [ config_generic 0 "$dbtype,$input" config $help_text "string" ]
         if { [string match "*.*.*" $value] } {
            set config($dbtype,$input) $value
         } else {
            puts "$value is not a valid jdbc driver"
            wait_for_enter
         }
         continue
      }

      if { $extra == 3 } {
         set help_text {  "Please enter url macro using for connection to the database:"
                          "use macros:  \$db_host for database host"
                          "             \$port    for port number"
                          "             \$db_name for database name\n" }
         set value [ config_generic 0 "$dbtype,$input" config $help_text "string" ]
         if { [string match "jdbc:*\$db_host*\$port*\$db_name" $value] } {
            set config($dbtype,$input) $value
         } else {
            puts "$value is not a valid url macro"
            wait_for_enter
         }
         continue
      }

      set config($dbtype,$input) $value
   }
   return 0
}

#****** config_database/db_config_dbtypelist_delete_dbtype() *******************
#  NAME
#     db_config_dbtypelist_delete_dbtype() -- delete database type from database 
#                                             type configuration
#
#  SYNOPSIS
#     db_config_dbtypelist_delete_dbtype { array_name } 
#
#  FUNCTION
#     This procedure is called to delete database type from the database type 
#     configuration.
#
#  INPUTS
#     array_name       - ts_db_config
#
#  SEE ALSO
#     check/setup_db_config()
#     check/verify_db_config()
#
#*******************************************************************************
proc db_config_dbtypelist_delete_dbtype { array_name { have_dbtype "" } } {
   upvar $array_name config

   while { 1 } {

      clear_screen
      puts "\nDelete database type from global database type configuration"
      puts "============================================================"

   
      db_config_dbtypelist_show_dbtypes config

      puts "\n"
      puts -nonewline "Please enter database type/number or return to exit: "
      set dbtype [wait_for_enter 1]
 
      if { [ string length $dbtype ] == 0 } {
         break
      }
     
      if { [string is integer $dbtype] } {
         incr dbtype -1
         set dbtype [ lindex $config(dbtypelist) $dbtype ]
      }

      if { [ lsearch $config(dbtypelist) $dbtype ] < 0 } {
         puts "database type \"$dbtype\" not found in list"
         wait_for_enter
         continue
      }

      puts ""
      puts "   database type         : $dbtype"
      puts "   port                  : $config($dbtype,port)"
      puts "   driver                : $config($dbtype,driver)"
      puts "   url                   : $config($dbtype,url)"
      puts ""

      puts ""
   
      puts "\n"
      set index [lsearch $config(dbtypelist) $dbtype]
      foreach database $config(databaselist) {
         if { [string compare $config($database,dbtype) $dbtype] == 0 } {
            puts "Database of $dbtype type exists in the testsuite global database configuration."
            ts_log_fine "Database type $dbtype can't be deleted."
            return -1
         }
      }
      puts -nonewline "Delete this database type? (y/n): "
      set input [ wait_for_enter 1]
      if { [ string length $input ] == 0 } {
         continue
      }

      if { [ string compare $input "y"] == 0 } {
         set config(dbtypelist) [ lreplace $config(dbtypelist) $index $index ]
         unset config($dbtype,port)
         unset config($dbtype,driver)
         unset config($dbtype,url)
         wait_for_enter
         continue
      }
   }
   return 0   
}

#****** config_database/db_config_databaselist() *******************************
#  NAME
#     db_config_databaselist() -- database list setup
#
#  SYNOPSIS
#     db_config_databaselist { only_check name config_array } 
#
#  FUNCTION
#     Testsuite database configuration setup - called from verify_db_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_user_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup_db_config()
#     check/verify_db_config()
#
#*******************************************************************************
proc db_config_databaselist { only_check name config_array } {
   upvar $config_array config

   set description   $config($name,desc)

   if { [string compare $config(dbtypelist) ""] == 0 } {
      puts "\nNo database type configured."
      return -1
   }

   if { $only_check == 0 } {
      set not_ready 1
      while { $not_ready } {
         clear_screen
         puts "\nGlobal database configuration setup"
         puts "==================================="
         puts "\n\n    databases configured: [llength $config(databaselist)]"
         db_config_databaselist_show_databases config
         puts "\n\n(1)  add database"
         puts "(2)  edit database"
         puts "(3)  delete database"
         puts "(10) exit setup"
         puts -nonewline "> "
         set input [ wait_for_enter 1]
         switch -- $input {
             1 {
                set result [db_config_databaselist_add_database config]
                if { $result != 0 } {
                   wait_for_enter
                }
             }
             2 {
                set result [db_config_databaselist_edit_database config]
                if { $result != 0 } {
                   wait_for_enter
                }
             }
             3 {
               set result [db_config_databaselist_delete_database config]
                if { $result != 0 } {
                   wait_for_enter
                }
             }
             10 {
                set not_ready 0
             }
         }
      }
   }

   # check database configuration
   ts_log_finest "db_config_databaselist:"
   foreach database $config(databaselist) {
      ts_log_finest "checking database \"$database\" ... "
   }

   return $config(databaselist)

}

#****** config_database/db_config_databaselist_show_databases() ****************
#  NAME
#     db_config_databaselist_show_databases() -- show testsuite database 
#                                                configuration
#
#  SYNOPSIS
#     db_config_databaselist_show_databases { array_name } 
#
#  FUNCTION
#     This procedure will show the current testsuite database configuration
#
#  INPUTS
#     array_name - ts_db_config
#
#  SEE ALSO
#     check/setup_db_config()
#     check/verify_db_config()
#
#*******************************************************************************
proc db_config_databaselist_show_databases { array_name } {
   upvar $array_name config

   puts "\nDatabase list:\n"
   if { [llength $config(databaselist)] == 0 } {
      puts "no databases defined"
   }
   set index 0
   foreach database $config(databaselist) {
      incr index 1 
      puts "($index) $database     ($config($database,dbtype)/$config($database,dbhost))"
   }
}

#****** config_database/db_config_databaselist_add_database() ******************
#  NAME
#     db_config_databaselist_add_database() -- add database to database 
#                                              configuration
#
#  SYNOPSIS
#     db_config_databaselist_add_database { array_name { have_database "" } } 
#
#  FUNCTION
#     Add database to testsuite database configuration
#
#  INPUTS
#     array_name       - ts_db_config
#     { have_database "" } - if not "": add this database
#
#  SEE ALSO
#     check/setup_db_config()
#     check/verify_db_config()
#
#*******************************************************************************
proc db_config_databaselist_add_database { array_name { have_database "" } } {
   upvar $array_name config
  
   if { $have_database == "" } {
      clear_screen
      puts "\nAdd database to global database configuration"
      puts "============================================="
      db_config_databaselist_show_databases config
      puts "\n"
      puts -nonewline "Please enter new database name: "
      set new_database [wait_for_enter 1]
   } else {
      set new_database $have_database
   }

   if { [ string length $new_database ] == 0 } {
      puts "no database entered"
      return -1
   }
   
   if { [ string is integer $new_database ] } {
      puts "invalid database name entered"
      return -1
   }
  
   if { [ lsearch $config(databaselist) $new_database ] >= 0 } {
      puts "database \"$new_database\" is already in list"
      return -1
   }

   lappend config(databaselist) $new_database
   set config($new_database,dbtype)      ""
   set config($new_database,dbhost)      ""
   set config($new_database,dbport)      ""
   set config($new_database,dbname)      ""
   set config($new_database,username)    ""
   set config($new_database,password)    ""
   set config($new_database,driverpath)  ""

   if { $have_database == "" } {
      db_config_databaselist_edit_database config $new_database
   }
   return 0   
}

#****** config_database/db_config_databaselist_edit_database() *****************
#  NAME
#     db_config_databaselist_edit_database() -- edit database configuration
#
#  SYNOPSIS
#     db_config_databaselist_edit_database { array_name { have_database "" } } 
#
#  FUNCTION
#     This procedure is used to edit the testsuite database configuration
#
#  INPUTS
#     array_name       - ts_db_config
#     { have_database "" } - if not "": add this database
#
#  SEE ALSO
#     check/setup_db_config()
#     check/verify_db_config()
#
#*******************************************************************************
proc db_config_databaselist_edit_database { array_name { have_database "" } } {
   global CHECK_USER
   upvar $array_name config

   set goto 0

   if { $have_database != "" } {
      set goto $have_database
   } 

   while { 1 } {

      clear_screen
      puts "\nEdit database in global database configuration"
      puts "=============================================="
      db_config_databaselist_show_databases config
      puts "\n"
      puts -nonewline "Please enter database/number or return to exit: "
      if { $goto == 0 } {
         set database [wait_for_enter 1]
         set goto $database
      } else {
         set database $goto
         ts_log_fine $database
      }
 
      if { [ string length $database ] == 0 } {
         break
      }
     
      if { [string is integer $database] } {
         incr database -1
         set database [ lindex $config(databaselist) $database ]
      }

      if { [ lsearch $config(databaselist) $database ] < 0 } {
         puts "database \"$database\" not found in list"
         wait_for_enter
         set goto 0
         continue
      }
      puts ""
      puts "   database     : $database"
      puts "   dbtype       : $config($database,dbtype)"
      puts "   dbhost       : $config($database,dbhost)"
      puts "   dbport       : $config($database,dbport)"
      puts "   dbname       : $config($database,dbname)"
      puts "   username     : $config($database,username)"
      puts "   password     : $config($database,password)"
      puts "   driverpath   : $config($database,driverpath)"
      puts "\n"
      puts -nonewline "Please enter category to edit or hit return to exit > "
      set input [ wait_for_enter 1]
      if { [ string length $input ] == 0 } {
         set goto 0
         continue
      }

      if { [ string compare $input "database"] == 0 } {
         puts "Setting \"$input\" is not allowed"
         wait_for_enter
         continue
      }

      if { [ info exists config($database,$input) ] != 1 } {
         puts "Not a valid category"
         wait_for_enter
         continue
      }

      set extra 0
      switch -- $input {
         "dbtype"       { set extra 1 }
         "dbhost"       { set extra 2 }
         "dbport"       { set extra 3 }
         "dbname"       { set extra 4 }
         "username"     { set extra 5 }
         "password"     { set extra 6 }
         "driverpath"   { set extra 7 }
      }

      if { $extra == 0 } {
         puts "\nPlease enter new $input value: "
         set value [ wait_for_enter 1 ]
      }

      if { $extra == 1 } {
         set help_text "\nDatabase type list:"
         set value [ config_generic 0 "$database,$input" config $help_text "choice" config(dbtypelist) ]
         if { [ lsearch $config(dbtypelist) $value ] >= 0 } {
            set config($database,$input) $value
            set config($database,dbport) $config($value,port)
         } else {
           wait_for_enter
         }
         continue
      }

      if { $extra == 2} {
         set help_text {  "Please enter the name of database host:" }
         set value [ config_generic 0 "$database,$input" config $help_text "string" ]
         if { [string compare $value "none" ] != 0 } {
            set config($database,$input) $value
         } else {
            wait_for_enter
         }
         continue
      }

      if { $extra == 3 } {
         set help_text {  "Please enter the database port:" }
         set value [ config_generic 0 "$database,$input" config $help_text "string" ]
         if { [string is integer $value] && [ string length $value ] > 3 } {
            set config($database,$input) $value
         } else {
            puts "$value is not a valid port number"
            wait_for_enter
         }
         continue
      }

      if { $extra == 4 } {
         set help_text {  "Please enter the name of database:" }
         set value [ config_generic 0 "$database,$input" config $help_text "string" ]
         if { [string compare $value "none" ] != 0 } {
            set config($database,$input) $value
         } else {
            wait_for_enter
         }
         continue
      }

      if { $extra == 5 } {
         set help_text {  "Please enter the name of database user with write access:" }
         set value [ config_generic 0 "$database,$input" config $help_text "string" ]
         if { [string compare $value "none" ] != 0 } {
            set config($database,$input) $value
         } else {
            wait_for_enter
         }
         continue
      }
 
      if { $extra == 6 } {
         set help_text {  "Please enter the password for the database user with write access:" }
         set value [ config_generic 0 "$database,$input" config $help_text "string" ]
         if { [string compare $value "none" ] != 0 } {
            set config($database,$input) $value
         } else {
            wait_for_enter
         }
         continue
      }

      if { $extra == 7 } {
         set help_text {  "Please enter the path to jdbc driver:" }
         set value [ config_generic 0 "$database,$input" config $help_text "filename" ]
         if { [string compare $value "-1" ] != 0 } {
            set config($database,$input) $value
         } else {
            wait_for_enter
         }
         continue
      }
   }
   return 0   

}

#****** config_database/db_config_databaselist_delete_database() ***************
#  NAME
#     db_config_databaselist_delete_database() -- delete database from database 
#                                                 configuration
#
#  SYNOPSIS
#     db_config_databaselist_delete_database { array_name } 
#
#  FUNCTION
#     This procedure is called to delete database from the database configuration.
#
#
#  INPUTS
#     array_name       - ts_db_config
#
#  SEE ALSO
#     check/setup_db_config()
#     check/verify_db_config()
#
#*******************************************************************************
proc db_config_databaselist_delete_database { array_name } {
   upvar $array_name config

   while { 1 } {

      clear_screen
      puts "\nDelete database from global database configuration"
      puts "=================================================="
      db_config_databaselist_show_databases config
      puts "\n"
      puts -nonewline "Please enter database/number or return to exit: "
      set database [wait_for_enter 1]
 
      if { [ string length $database ] == 0 } {
         break
      }
     
      if { [string is integer $database] } {
         incr database -1
         set database [ lindex $config(databaselist) $database ]
      }

      if { [ lsearch $config(databaselist) $database ] < 0 } {
         puts "\"$database\" not found in list"
         wait_for_enter
         continue
      }

      puts ""
      puts "   database          : $database"
      puts "   dbtype            : $config($database,dbtype)"
      puts "   dbhost            : $config($database,dbhost)"
      puts "   dbport            : $config($database,dbport)"
      puts "   dbname            : $config($database,dbname)"
      puts "   username          : $config($database,username)"
      puts "   password          : $config($database,password)"
      puts "   driverpath        : $config($database,driverpath)"
      puts ""

      puts ""
   
      puts "\n"
      puts -nonewline "Delete this database? (y/n): "
      set input [ wait_for_enter 1]
      if { [ string length $input ] == 0 } {
         continue
      }
 
      if { [ string compare $input "y"] == 0 } {
         set index [lsearch $config(databaselist) $database]
         set config(databaselist) [ lreplace $config(databaselist) $index $index ]
         unset config($database,dbtype)
         unset config($database,dbhost)
         unset config($database,dbport)
         unset config($database,dbname)
         unset config($database,username)
         unset config($database,password)
         unset config($database,driverpath)
         wait_for_enter
         continue
      }
   }
   return 0   
}

#****** config_database/verify_db_config() *************************************
#  NAME
#     verify_db_config() -- verify testsuite database configuration setup
#
#  SYNOPSIS
#     verify_db_config { config_array only_check parameter_error_list 
#     { force 0 } } 
#
#  FUNCTION
#     This procedure will verify or enter database setup configuration
#
#  INPUTS
#     config_array         - array name with configuration (ts_db_config)
#     only_check           - if 1: don't ask user, just check
#     parameter_error_list - returned list with error information
#     { force 0 }          - force ask user
#
#  RESULT
#     number of errors
#
#  SEE ALSO
#     check/verify_host_config()
#     check/verify_user_config()
#     check/verify_config()
#     
#*******************************************************************************
proc verify_db_config { config_array only_check parameter_error_list { force 0 } } {
   global actual_ts_db_config_version be_quiet
   upvar $config_array config
   upvar $parameter_error_list error_list

   set errors 0
   set error_list ""

   if { [ info exists config(version) ] != 1 } {
      puts "Could not find version info in database configuration file"
      lappend error_list "no version info"
      incr errors 1
      return -1
   }

   if { $config(version) != $actual_ts_db_config_version } {
      ts_log_severe "Database configuration file version \"$config(version)\" not supported."
      ts_log_severe "Expected version is \"$actual_ts_database_config_version\""
      lappend error_list "unexpected version"
      incr errors 1
      return -1
   } else {
      ts_log_finest "Database Configuration Version: $config(version)"
   }


   foreach dbtype $config(dbtypelist) {
      set not_init ""
      if { [string compare $config($dbtype,port) ""] == 0 } {
         lappend not_init "default port number"
      }
      if { [string compare $config($dbtype,driver) ""] == 0 } {
         lappend not_init " jdbc driver "
      }
      if { [string compare $config($dbtype,url) ""] == 0 } {
         lappend not_init "url macro"
      }
      if { [string length $not_init] != 0 } {
         ts_log_warning "no value for $dbtype value(s): $not_init"
      }
   }
   
   foreach database $config(databaselist) {
      set not_init ""
      if { [string compare $config($database,dbtype) ""] == 0 } {
         lappend not_init "database type"
      }
      if { [string compare $config($database,dbhost) ""] == 0 } {
         lappend not_init "database host"
      }
      if { [string compare $config($database,dbport) ""] == 0 } {
         lappend not_init "database port"
      }
      if { [string compare $config($database,dbname) ""] == 0 } {
         lappend not_init "database name"
      }
      if { [string compare $config($database,username) ""] == 0 } {
         lappend not_init "write user name"
      }
      if { [string compare $config($database,password) ""] == 0 } {
         lappend not_init "write user password"
      }
      if { [string compare $config($database,driverpath) ""] == 0 } {
         lappend not_init "database driver path"
      }
      if { [string length $not_init] != 0 } {
         ts_log_warning "no value for $dbtype value(s): $not_init"
      }
   }

   set max_pos [get_configuration_element_count config]
   set uninitalized ""
   if { $be_quiet == 0 } { 
      puts ""
   }

   for { set param 1 } { $param <= $max_pos } { incr param 1 } {
      set par [ get_configuration_element_name_on_pos config $param ]
      if { $be_quiet == 0 } { 
         puts -nonewline "      $config($par,desc) ..."
      }
      if { $config($par) == "" || $force != 0 } {
         ts_log_finest "not initialized or forced!"
         lappend uninitalized $param
         if { $only_check != 0 } {
            lappend error_list ">$par< configuration not initalized"
            incr errors 1
         }
      } else {
         set procedure_name  $config($par,setup_func)
         set default_value   $config($par,default)
         set description     $config($par,desc)
         if { [string length $procedure_name] == 0 } {
             ts_log_finest "no procedure defined"
         } else {
            if { [info procs $procedure_name ] != $procedure_name } {
               ts_log_warning "unkown procedure name: \"$procedure_name\" !!!"
               lappend uninitalized $param
               if { $only_check == 0 } { 
                  wait_for_enter 
               }
            } else {
               # call procedure only_check == 1
               ts_log_finest "starting >$procedure_name< (verify mode) ..."
               set value [ $procedure_name 1 $par config ]
               if { $value == -1 } {
                  incr errors 1
                  lappend error_list $par
                  ts_log_warning "verify error in procedure \"$procedure_name\" !!!"
                  lappend uninitalized $param
               }
            }
         }
      }
      if { $be_quiet == 0 } { 
         puts "\r      $config($par,desc) ... ok"   
      }
   }
   if { [set count [llength $uninitalized]] != 0 && $only_check == 0 } {
      ts_log_warning "$count parameters are not initialized!"
      puts "Entering setup procedures ..."
      
      foreach pos $uninitalized {
         set p_name [get_configuration_element_name_on_pos config $pos]
         set procedure_name  $config($p_name,setup_func)
         set default_value   $config($p_name,default)
         set description     $config($p_name,desc)
       
         ts_log_frame
         ts_log_fine  $description
         ts_log_frame
         ts_log_finest "Starting configuration procedure for parameter \"$p_name\" ($config($p_name,pos)) ..."
         set use_default 0
         if { [string length $procedure_name] == 0 } {
            ts_log_fine "no procedure defined"
            set use_default 1
         } else {
            if { [info procs $procedure_name ] != $procedure_name } {
               ts_log_warning "unkown procedure name: \"$procedure_name\" !!!"
               if { $only_check == 0 } { wait_for_enter }
               set use_default 1
            }
         } 

         if { $use_default != 0 } {
            # check again if we have value ( force flag) 
            if { $config($p_name) == "" } {
               # we have no setup procedure
               if { $default_value != "" } {
                  puts "using default value: \"$default_value\"" 
                  set config($p_name) $default_value 
               } else {
                  puts "No setup procedure and no default value found!!!"
                  if { $only_check == 0 } {
                     puts -nonewline "Please enter value for parameter \"$p_name\": "
                     set value [wait_for_enter 1]
                     puts "using value: \"$value\"" 
                     set config($p_name) $value
                  } 
               }
            }
         } else {
            # call setup procedure ...
            ts_log_finest "starting >$procedure_name< (setup mode) ..."
            set value [ $procedure_name 0 $p_name config ]
            if { $value != -1 } {
               puts "using value: \"$value\"" 
               set config($p_name) $value
            }
         }
         if { $config($p_name) == "" } {
            ts_log_warning "no value for \"$p_name\" !!!"
            incr errors 1
            lappend error_list $p_name
         }
      } 
   }
   return $errors
}

#****** config_database/setup_db_config() **************************************
#  NAME
#     setup_db_config() -- testsuite database configuration initalization
#
#  SYNOPSIS
#     setup_db_config { file { force 0 } } 
#
#  FUNCTION
#     This procedure will initalize the testsuite database configuration
#
#  INPUTS
#     file        - database configuration file
#     { force 0 } - if 1: edit configuration setup
#
#  SEE ALSO
#
#*******************************************************************************
proc setup_db_config { file { force 0 }} {
   global ts_db_config actual_ts_db_config_version do_nomain
   global fast_setup

   if { [read_array_from_file $file "testsuite database configuration" ts_db_config ] == 0 } {
      if { $ts_db_config(version) != $actual_ts_db_config_version } {
         ts_log_fine "unknown database configuration file version: $ts_db_config(version)"
         exit -1
      }

      # got config
      if { $do_nomain == 0 } {
         if { [verify_db_config ts_db_config 1 err_list $force ] != 0 } {
            # configuration problems
            foreach elem $err_list {
               ts_log_fine "$elem"
            } 
            set not_ok 1
            while { $not_ok } {
               if { [verify_db_config ts_db_config 0 err_list $force ] != 0 } {
                  set not_ok 1
                  ts_log_fine "Database configuration error. Stop."
                  foreach elem $err_list {
                     ts_log_fine "error in: $elem"
                  } 
                  ts_log_fine "try again? (y/n)"
                  set answer [wait_for_enter 1]
                  if { $answer == "n" } {
                     ts_log_fine "Do you want to save your changes? (y/n)"
                     set answer [wait_for_enter 1]
                     if { $answer == "y" } {
                        if { [ save_db_configuration $file] != 0} {
                           ts_log_fine "Could not save database configuration"
                           wait_for_enter
                        }
                     }
                     return
                  } else {
                    continue
                  }
               } else {
                 set not_ok 0
               }
            }
            if { [ save_db_configuration $file] != 0} {
               ts_log_fine "Could not save database configuration"
               wait_for_enter
               return
            }

         }
         if { $force == 1 } {
            if { [ save_db_configuration $file] != 0} {
               ts_log_fine "Could not save database configuration"
               wait_for_enter
            }
         }
         return
      }
      return 
   } else {
      ts_log_fine "could not open database config file \"$file\""
      ts_log_fine "press return to create new database configuration file"
      wait_for_enter 1
      if { [ save_db_configuration $file] != 0} {
         exit -1
      }
      setup_db_config $file
   }
}
