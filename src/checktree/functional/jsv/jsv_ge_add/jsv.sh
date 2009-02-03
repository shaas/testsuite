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
   return
}

jsv_on_verify()
{
   ac=`jsv_get_param ac`
   if [ "$ac" != "" ]; then
      name=`jsv_sub_get_param ac name`
      value=`jsv_sub_get_param ac value`
      islist=`jsv_sub_get_param ac islist`

      if [ "$islist" = "false" ]; then
         jsv_set_param $name $value
      else
         operation=`jsv_sub_get_param ac operation`
         list_param=`jsv_sub_get_param ac list_param`

         if [ "$operation" = "add" ]; then
            jsv_sub_add_param $name $list_param $value
         elif [ "$operation" = "mod" ]; then
            jsv_sub_add_param $name $list_param $value
         elif [ "$operation" = "del" ]; then
            jsv_sub_del_param $name $list_param 
         fi
      fi
   fi

   jsv_correct "Job was modified by JSV"
}

. ${SGE_ROOT}/util/resources/jsv/jsv_include.sh

jsv_main

