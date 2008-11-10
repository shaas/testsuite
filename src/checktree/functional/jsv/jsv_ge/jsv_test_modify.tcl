#!/usr/bin/tclsh
#
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
#  Copyright: 2008 by Sun Microsystems, Inc.
#
#  All Rights Reserved.
#
##########################################################################
#___INFO__MARK_END__

set sge_root $env(SGE_ROOT)
set sge_arch [exec $sge_root/util/arch]

source "$sge_root/util/resources/jsv/jsv_include.tcl"

proc jsv_on_start {} {
   jsv_send_env
}

proc jsv_on_verify {} {
   set par_list {}
   set val_list {}
   set res ""

   # VERSION; read-only 
   lappend par_list "VERSION"
   lappend val_list "1.0"
   append res "0"

   # CONTEXT; read-only 
   lappend par_list "CONTEXT"
   lappend val_list "troete"
   append res "0"

   # CLIENT; read-only 
   lappend par_list "CLIENT"
   lappend val_list "troete"
   append res "0"

   # USER; read-only 
   lappend par_list "USER"
   lappend val_list "troete"
   append res "0"

   # GROUP; read-only 
   lappend par_list "GROUP"
   lappend val_list "troete"
   append res "0"

   # JOB_ID; read-only 
   lappend par_list "JOB_ID"
   lappend val_list "9999"
   append res "0"

   # -ac; variable list
   lappend par_list "ac"
   lappend val_list "a"
   append res "1"
   lappend par_list "ac"
   lappend val_list "a=1"
   append res "1"
   lappend par_list "ac"
   lappend val_list "a=1,b"
   append res "1"
   lappend par_list "ac"
   lappend val_list "a=1,b,c=1"
   append res "1"
   lappend par_list "ac"
   lappend val_list ""
   append res "1"

   # -ar; u_long32 
   lappend par_list "ar"
   lappend val_list "5"
   append res "1"
   lappend par_list "ar"
   lappend val_list "0"
   append res "1"
   lappend par_list "ar"
   lappend val_list ""
   append res "1"

   # -b; boolean
   lappend par_list "b"
   lappend val_list "y"
   append res "1"
   lappend par_list "b"
   lappend val_list "n"
   append res "1"
   lappend par_list "b"
   lappend val_list "troete"
   append res "0"
   lappend par_list "b"
   lappend val_list ""
   append res "0"
   
   # -j; boolean
   lappend par_list "j"
   lappend val_list "y"
   append res "1"
   lappend par_list "j"
   lappend val_list "n"
   append res "1"
   lappend par_list "j"
   lappend val_list "troete"
   append res "0"
   lappend par_list "j"
   lappend val_list ""
   append res "0"

   # -js; u_long32 
   lappend par_list "js"
   lappend val_list "0"
   append res "1"
   lappend par_list "js"
   lappend val_list "10"
   append res "1"
   lappend par_list "js"
   lappend val_list "troete"
   append res "0"
   lappend par_list "js"
   lappend val_list ""
   append res "1"

   # -notify; boolean
   lappend par_list "notify"
   lappend val_list "y"
   append res "1"
   lappend par_list "notify"
   lappend val_list "n"
   append res "1"
   lappend par_list "notify"
   lappend val_list "troete"
   append res "0"
   lappend par_list "notify"
   lappend val_list ""
   append res "0"

   # -p; boolean
   lappend par_list "p"
   lappend val_list "-2000"
   append res "0"
   lappend par_list "p"
   lappend val_list "2000"
   append res "0"
   lappend par_list "p"
   lappend val_list "-1023"
   append res "1"
   lappend par_list "p"
   lappend val_list "1024"
   append res "1"
   lappend par_list "p"
   lappend val_list "0"
   append res "1"
   lappend par_list "p"
   lappend val_list ""
   append res "1"

   # -pe .. n-m; u_long32 range 
   lappend par_list "pe_name"
   lappend val_list "troete"
   append res "1"
   lappend par_list "pe_name"
   lappend val_list ""
   append res "1"
   lappend par_list "pe_min"
   lappend val_list "2"
   append res "1"
   lappend par_list "pe_min"
   lappend val_list "2"
   append res "1"
   lappend par_list "pe_min"
   lappend val_list "0"
   append res "1"
   lappend par_list "pe_min"
   lappend val_list ""
   append res "1"
   lappend par_list "pe_max"
   lappend val_list "2"
   append res "1"
   lappend par_list "pe_max"
   lappend val_list "0"
   append res "1"
   lappend par_list "pe_max"
   lappend val_list ""
   append res "1"

   # -R; boolean
   lappend par_list "R"
   lappend val_list "y"
   append res "1"
   lappend par_list "R"
   lappend val_list "n"
   append res "1"
   lappend par_list "R"
   lappend val_list "troete"
   append res "0"
   lappend par_list "R"
   lappend val_list ""
   append res "0"

   # -r; boolean
   lappend par_list "r"
   lappend val_list "y"
   append res "1"
   lappend par_list "r"
   lappend val_list "n"
   append res "1"
   lappend par_list "r"
   lappend val_list "troete"
   append res "0"
   lappend par_list "r"
   lappend val_list ""
   append res "0"

   # -t n-m:s; boolean
   lappend par_list "t_min"
   lappend val_list "0"
   append res "1"
   lappend par_list "t_min"
   lappend val_list ""
   append res "1"
   lappend par_list "t_min"
   lappend val_list "1"
   append res "1"
   lappend par_list "t_max"
   lappend val_list ""
   append res "1"
   lappend par_list "t_max"
   lappend val_list "0"
   append res "1"
   lappend par_list "t_max"
   lappend val_list "1"
   append res "1"
   lappend par_list "t_step"
   lappend val_list ""
   append res "1"
   lappend par_list "t_step"
   lappend val_list "0"
   append res "1"
   lappend par_list "t_step"
   lappend val_list "1"
   append res "1"

   # -shell; boolean
   lappend par_list "shell"
   lappend val_list "y"
   append res "1"
   lappend par_list "shell"
   lappend val_list "n"
   append res "1"
   lappend par_list "shell"
   lappend val_list "troete"
   append res "0"
   lappend par_list "shell"
   lappend val_list ""
   append res "0"

   # send the result which we expect
   jsv_set_param "__JSV_TEST_RESULT" $res

   # send all parameters
   set i 0
   set max [llength $par_list]
   while {$i < $max} {
      jsv_set_param [lindex $par_list $i] [lindex $val_list $i]
      incr i
   } 

   jsv_accept 
}

jsv_main

