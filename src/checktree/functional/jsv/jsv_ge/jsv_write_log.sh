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
      level=`jsv_sub_get_param ac level`

      if [ "$level" = "info" ]; then
         jsv_log_info "JSV - $level - MESSAGE"
      elif [ "$level" = "warning" ]; then
         jsv_log_warning "JSV - $level - MESSAGE"
      elif [ "$level" = "error" ]; then
         jsv_log_error "JSV - $level - MESSAGE"
      fi
   fi

   jsv_accept
}

. ${SGE_ROOT}/util/resources/jsv/jsv_include.sh

jsv_main

