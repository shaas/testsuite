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

   # CMDARG<id>
   lappend par_list "CMDARG0"
   lappend val_list "troete0"
   append res "1"
   lappend par_list "CMDARG1"
   lappend val_list "troete1"
   append res "1"
   lappend par_list "CMDARG2"
   lappend val_list "troete2"
   append res "1"
   lappend par_list "CMDARG7"
   lappend val_list "troete7"
   append res "1"
   lappend par_list "CMDARG2"
   lappend val_list ""
   append res "1"
   lappend par_list "CMDARGtroete"
   lappend val_list "rabarber"
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

   # -a; data_time
   lappend par_list "a"
   lappend val_list "200802010304.05"
   append res "1"
   lappend par_list "a"
   lappend val_list "200899999999.05"
   append res "0"
   lappend par_list "a"
   lappend val_list "troete"
   append res "0"

   # -A
   lappend par_list "A"
   lappend val_list "account_string"
   append res "1"
   lappend par_list "A"
   lappend val_list ""
   append res "1"

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

   # -ckpt
   lappend par_list "ckpt"
   lappend val_list "ckpt_name"
   append res "1"
   lappend par_list "ckpt"
   lappend val_list ""
   append res "1"

   # -cwd
   lappend par_list "cwd"
   lappend val_list "/path"
   append res "1"
   lappend par_list "cwd"
   lappend val_list ""
   append res "1"

   # -display
   lappend par_list "display"
   lappend val_list "troete:0.0"
   append res "1"
   lappend par_list "display"
   lappend val_list ""
   append res "1"

   # -dl; data_time
   lappend par_list "dl"
   lappend val_list "200802010304.05"
   append res "1"
   lappend par_list "dl"
   lappend val_list "209999010304.05"
   append res "0"
   lappend par_list "dl"
   lappend val_list "troete"
   append res "0"

   # -e
   lappend par_list "e"
   lappend val_list "host0:/path0,host1:/path2"
   append res "1"
   lappend par_list "e"
   lappend val_list ""
   append res "1"

   # -h
   lappend par_list "h"
   lappend val_list "u"
   append res "1"
   lappend par_list "h"
   lappend val_list ""
   append res "1"
   
   # -i
   lappend par_list "i"
   lappend val_list "host0:/path0,host1:/path2"
   append res "1"
   lappend par_list "i"
   lappend val_list ""
   append res "1"
   
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

   # -hold_jid
   lappend par_list "hold_jid"
   lappend val_list "1"
   append res "1"
   lappend par_list "hold_jid"
   lappend val_list "1,2,3"
   append res "1"
   lappend par_list "hold_jid"
   lappend val_list "1,,3"
   append res "1"
   lappend par_list "hold_jid"
   lappend val_list ""
   append res "1"

   # -hold_jid_ad
   lappend par_list "hold_jid_ad"
   lappend val_list "1"
   append res "1"
   lappend par_list "hold_jid_ad"
   lappend val_list "1,2,3"
   append res "1"
   lappend par_list "hold_jid_ad"
   lappend val_list "1,,3"
   append res "1"
   lappend par_list "hold_jid_ad"
   lappend val_list ""
   append res "1"

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

   # -l -hard -soft
   lappend par_list "l_hard"
   lappend val_list "a=troete"
   append res "1"
   lappend par_list "l_hard"
   lappend val_list "h_vmem=5G,a=troete"
   append res "1"
   lappend par_list "l_hard"
   lappend val_list ""
   append res "1"
   lappend par_list "l_soft"
   lappend val_list "a=troete"
   append res "1"
   lappend par_list "l_soft"
   lappend val_list "h_vmem=5G,a=troete"
   append res "1"
   lappend par_list "l_soft"
   lappend val_list ""
   append res "1"
      
   # -m
   lappend par_list "m"
   lappend val_list "troete"
   append res "0"
   lappend par_list "m"
   lappend val_list "beas"
   append res "1"
   lappend par_list "m"
   lappend val_list "n"
   append res "1"
   lappend par_list "m"
   lappend val_list ""
   append res "1"

   # -masterq
   lappend par_list "masterq"
   lappend val_list "all.q"
   append res "1"
   lappend par_list "masterq"
   lappend val_list "all.q,all2.q"
   append res "1"
   lappend par_list "masterq"
   lappend val_list ""
   append res "1"
   
   # -M
   lappend par_list "M"
   lappend val_list "root@es-ergb01-01.germany.sun.com,codadmin@localhost"
   append res "1"
   lappend par_list "M"
   lappend val_list "root@es-ergb01-01.germany.sun.com,codadmin@localhost"
   append res "1"
   lappend par_list "M"
   lappend val_list ""
   append res "1"

   # -N
   lappend par_list "N"
   lappend val_list "job_name"
   append res "1"
   lappend par_list "N"
   lappend val_list ""
   append res "0"

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

   # -o
   lappend par_list "o"
   lappend val_list "host0:/path0,host1:/path2"
   append res "1"
   lappend par_list "o"
   lappend val_list ""
   append res "1"

   # -P
   lappend par_list "P"
   lappend val_list "project"
   append res "1"
   lappend par_list "P"
   lappend val_list ""
   append res "1"

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

   # -q -hard -soft
   lappend par_list "q_hard"
   lappend val_list "all.q"
   append res "1"
   lappend par_list "q_hard"
   lappend val_list "all.q,all2.q"
   append res "1"
   lappend par_list "q_hard"
   lappend val_list ""
   append res "1"
   lappend par_list "q_soft"
   lappend val_list "all.q"
   append res "1"
   lappend par_list "q_soft"
   lappend val_list "all.q,all2.q"
   append res "1"
   lappend par_list "q_soft"
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

   # -S
   lappend par_list "S"
   lappend val_list "host0:/path0,host1:/path2"
   append res "1"
   lappend par_list "S"
   lappend val_list ""
   append res "1"

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

   # -w
   lappend par_list "w"
   lappend val_list "troete"
   append res "0"
   lappend par_list "w"
   lappend val_list "e"
   append res "1"
   lappend par_list "w"
   lappend val_list "w"
   append res "1"
   lappend par_list "w"
   lappend val_list "n"
   append res "1"
   lappend par_list "w"
   lappend val_list "p"
   append res "1"
   lappend par_list "w"
   lappend val_list "v"
   append res "1"
   lappend par_list "w"
   lappend val_list ""
   append res "1"

   # env
   lappend enam_list "JSV_GE_NAME1"
   lappend eval_list "value1"
   lappend emod_list "1"
   append eres "1"
   lappend enam_list "JSV_GE_NAME1"
   lappend eval_list "value2"
   lappend emod_list "2"
   append eres "1"
   lappend enam_list "JSV_GE_NAME1"
   lappend eval_list ""
   lappend emod_list "3"
   append eres "1"

   # send the result which we expect
   jsv_set_param "__JSV_TEST_RESULT" $res

   # send all parameters
   set i 0
   set max [llength $par_list]
   while {$i < $max} {
      jsv_set_param [lindex $par_list $i] [lindex $val_list $i]
      incr i
   }

   # send the result for the env we expect
   jsv_add_env "__JSV_TEST_RESULT" $eres

   # send all env commands
   set i 0
   set max [llength $enam_list]
   while {$i < $max} {
      set mod [lindex $emod_list $i]
      set nam [lindex $enam_list $i]
      set val [lindex $eval_list $i]

      if {$mod == 1} {
         jsv_add_env $nam $val
      } elseif {$mod == 2} {
         jsv_mod_env $nam $val 
      } else {
         jsv_del_env $nam 
      }
      incr i
   }
   jsv_accept 
}

jsv_main

