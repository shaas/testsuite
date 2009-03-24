#!/bin/sh
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

########################################################################### 
#
# example for a job verification script 
#
# Be careful:  Job verification scripts are started with sgeadmin 
#              permissions if they are executed within the master process
#

PATH=/bin:/usr/bin

jsv_on_start()
{
   jsv_send_env
   return
}

jsv_on_verify()
{
   do_correct="true"
   ac=`jsv_get_param ac`

   if [ "$ac" != "" ]; then
      has_ac_a=`jsv_sub_is_param ac B`

      if [ "$has_ac_a" = "true" ]; then
         do_correct="false"
         ac_a_value=`jsv_sub_get_param ac B`
         if [ "$ac_a_value" != "" ]; then

            is_env=`jsv_is_env JSV_COUNT`
            if [ "$is_env" != "true" ]; then
               jsv_add_env JSV_COUNT 0
            fi

            tmp_value=`jsv_get_env JSV_COUNT`
            new_value=`echo $tmp_value + 1 | bc`
            jsv_mod_env JSV_COUNT $new_value
            jsv_sub_add_param ac B $new_value
            do_correct="true"

         fi
      fi
   fi

   if [ "$do_correct" = "true" ]; then
      jsv_correct "B=$new_value"
   else
      jsv_reject "Job was rejected"
   fi

   return
}

. ${SGE_ROOT}/util/resources/jsv/jsv_include.sh

# main routine handling the protocol between client/master and JSV script
jsv_main

