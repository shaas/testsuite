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
#  Copyright: 2008 by Sun Microsystems, Inc.
#
#  All Rights Reserved.
#
##########################################################################
#___INFO__MARK_END__

#****** tcl_utils/list_grep() ******************************************
#  NAME
#     list_grep() -- list_grep a list for values matching a regular expression
#
#  SYNOPSIS
#     list_grep { regexp list_var {opt ""} }
#
#  FUNCTION
#     This small helper function works like the command line list_grep on tcl
#     lists.  Given a regular expression, only the matching values are
#     returned.
#
#     Additional options to lsearch (which is used to implement this) can be
#     passed in.
#
#  INPUTS
#     regexp   - list of resources to be removed
#     listvar  - the list that needs filtering
#     {opt ""} - additional options to lsearch, e.g. "-not"
#
#  RESULT
#     filtered list
#
#  EXAMPLE
#     # cc dd
#     set res [list_grep ".." {a b cc dd}]
#
#     # a b
#     set res [list_grep ".." {a b cc dd} -not]
#
#  SEE ALSO
#     lsearch options
#*******************************************************************************
proc list_grep { regexp list_var {opt ""} } {
   if {$opt != ""} {
      lsearch -regexp -all -inline $opt $list_var $regexp
   } else {
      lsearch -regexp -all -inline $list_var $regexp
   }
}

#****** tcl_utils/format_array() ******************************************
#  NAME
#     format_array() -- formats an array into a multi-line string
#
#  SYNOPSIS
#     format_array { array { with_header 1 } }
#
#  FUNCTION
#     This small helper function can be used for debugging purposes and creates
#     a multi-line string out of the contents of an array in the form of
#         key => value, sorted by keys.
#     This string can be used with one of the logging functions.
#
#     The parameter with_header can be set to 0, then format_array can be used
#     to compare two arrays, like
#        if { [format_array a1 0] == [format_array a2 0] } { ... } 
#
#  INPUTS
#     array             - name of the array to format
#     { with_header 1 } - the return string contains a header
#
#  RESULT
#     the formatted multi-line string
#
#  EXAMPLE
#     set map(key1) value1
#     set map(key2) value2
#
#     ts_log_fine [format_array map]
#*******************************************************************************
proc format_array { a { with_header 1 } } {
   upvar $a ar 
   if { $with_header == 1 } {
      set ret "Contents of array \"$a\":\n"
   } else {
      set ret ""
   }
   foreach n [lsort [array names ar]] {
      append ret "   $n => $ar($n)\n"
   }
   return $ret
}

