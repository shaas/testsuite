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

#****** tcl_utils/pick_random() ******************************************
#  NAME
#     pick_random() -- picks random elements from a list
#
#  SYNOPSIS
#     pick_random { alist { how_many 1 } } {
#
#  FUNCTION
#     This procedure selects one or more random elements from the alist TCL
#     list. The parameter how_many determines how many elements are returned.
#
#     This procedure never returns the same element twice, so if how_many is
#     equal to the size of alist then all elements of alist are returned
#     (though the order of the elements may have changed).
#
#     In case how_many > [llength alist] an empty string is returned and an
#     error is logged with ts_log_severe.
#
#  INPUTS
#     alist          - TCL list from which to pick the random element(s)
#     { how_many 1 } - how many elements to pick (default: 1)
#
#  RESULT
#     A TCL list containing the random element(s).
#
#  EXAMPLE
#     set mylist {host1 host2}
#
#     set random_element [pick_random $mylist]    ;# "host1"       or "host2" 
#     set random_list    [pick_random $mylist 2]  ;# "host1 host2" or "host2 host1"
#
#  NOTE
#     The chosen implementation is not the most performant solution. If you are
#     planning to do calls like [pick_random alist 10000] then think about
#     reimplementing this procedure!
#*******************************************************************************
proc pick_random { alist { how_many 1 } } {
   set len [llength $alist]

   if { $how_many > $len } {
      ts_log_severe "Cannot pick $how_many elements. The list '$alist' only contains $len elements!"
      return ""
   }

   set ret {}
   unset -nocomplain picked ;# stores the indices of values that have been picked already

   while { $how_many > 0 } {
      set rnd [expr {int(rand()*$len)}]

      if { ![info exists picked($rnd)] } {
         set picked($rnd) 1
         lappend ret [lindex $alist $rnd]
         incr how_many -1
      }
   }

   return $ret
}

#****** tcl_utils/double_backslashes() ***********************************
#  NAME
#     double_backslashes() -- doubles all backslashes in a string
#
#  SYNOPSIS
#     double_backslashes {original_string}
#
#  FUNCTION
#     This procedure doubles all backslashes that occur in a string. A use
#     case is handling Windows pathes - as TCL and sh interpret single
#     backslashes as escape sequence, it's necessary to double the
#     backslashes in order to get it interpreted right.
#
#  INPUTS
#     original_string - the string whose backslashes shall be doubled.
#
#  RESULT
#     The string with doubled backslashes. 
#
#  EXAMPLE
#     set doubled_path [double_backslashes "C:\Windows\system32\cmd.exe"]
#     puts $doubled_path
#
#     C:\\Windows\\system32\\cmd.exe
#*******************************************************************************
proc double_backslashes {original_string} {
   set doubled_string ""

   # Split the given string at existing backslashes and combine the resulting
   # list of words to a new string with double backslashes in between.
   set splitted [split $original_string "\\"]
   set token [llength $splitted]
   set backslashes $token
   incr backslashes -1

   for {set i 0} {$i<$token} {incr i} {
      set word [lindex $splitted $i]
      set doubled_string "$doubled_string$word"
      if {$i<$backslashes} {
         set doubled_string "$doubled_string\\\\"
      }
   }
   return $doubled_string
}

#****** tcl_utils/min() **************************************************
#  NAME
#     min() -- return the lesser of two operands
#
#  SYNOPSIS
#     min {arg1 arg2}
#
#  FUNCTION
#     This procedure returns the lesser of the two operands.
#
#  INPUTS
#     arg1 - operand 1
#     arg2 - operand 2
#
#  RESULT
#     The lesser of the two operands
#
#  EXAMPLE
#     set value [min 3 17]
#     puts $value
#
#     3
#*******************************************************************************
proc min {arg1 arg2} {
   set ret 0

   if {$arg1 < $arg2} {
      set ret $arg1
   } else {
      set ret $arg2
   }
   return $ret
}

#****** tcl_utils/max() **************************************************
#  NAME
#     max() -- return the greater of two operands
#
#  SYNOPSIS
#     max {arg1 arg2}
#
#  FUNCTION
#     This procedure returns the greater of the two operands.
#
#  INPUTS
#     arg1 - operand 1
#     arg2 - operand 2
#
#  RESULT
#     The greater of the two operands
#
#  EXAMPLE
#     set value [max 3 17]
#     puts $value
#
#     17
#*******************************************************************************
proc max {arg1 arg2} {
   set ret 0

   if {$arg1 > $arg2} {
      set ret $arg1
   } else {
      set ret $arg2
   }
   return $ret
}
