#___INFO__MARK_BEGIN_
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


#                                                             max. column:     |
#****** parser_xml/qstat_xml_parse() ******
#
#  NAME
#     qstat_xml_parse -- Generate XML output and return assoc array 
#
#  SYNOPSIS
#     qstat_xml_parse { output {param ""} }
#                     -- Generate XML output and return assoc array with
#                        entries jobid, prior, name, user, state, total_time,
#                        queue slots and task_id if needed. Pass XML info
#                        to proc qstat_xml_jobid which does the bulk of
#                        the work.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 Output array is similar to that of 
#                 parse_qstat {input output {jobid ""} {ext 0} {do_replace_NA 1 } }
#
#      param -  pass in param to qstat
# 
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     None
#
#  NOTES
#     
#
#*******************************
proc qstat_xml_parse { output {param ""} } {
   upvar $output output_xml

   # Run now -xml command
   set XML [start_sge_bin "qstat" "$param -xml"]

   # JG: TODO: do we need additional options?
   # -keepEmpties: text  nodes,  which contain  only  whitespaces,  will  be  part of the resulting DOM tree
   set doc  [dom parse $XML]
   set root [$doc documentElement]

   if {$param == "-urg"} {
      set jobparam "urg"
   } elseif {$param == "-pri"} {
      set jobparam "pri"
   } elseif {$param == "-r"} {
      set jobparam "r"   
   } else {
      set jobparam "running"
   }
   
   # Parse the running jobs  using this node.
   set node [$root firstChild]   ; # <job-info/>
   set node1 [$node firstChild]  ; # <queue-info/>

   set result1 [qstat_xml_jobid $node1 $jobparam output_xml]

   # Parse the pending jobs info using this node. Need to start here
   # NOT at root.
   if {$param == "-urg"} {
      set jobparam "urgpending"
   } elseif {$param == "-pri"} {
      set jobparam "pripending"
   } elseif {$param == "-r"} {
      set jobparam "rpending"
    } else {
      set jobparam "pending"
   }
   set node [$root firstChild]   ; # <job-info/>
   set node12 [$node nextSibling]  ; # <queue-info/>
   set node121 [$node12 firstChild]  ; # <qname/>

   set result2 [qstat_xml_jobid $node121 $jobparam output_xml]

   # free the XML document
   $doc delete
}


#                                                             max. column:     |
#****** parser_xml/qstat_j_xml_parse() ******
#
#  NAME
#     qstat_j_xml_parse -- Generate XML output and return assoc array 
#
#  SYNOPSIS
#     qstat_j_xml_parse { output {param ""} }
#                     -- Generate XML output and return assoc array with
#                        entries jobid, prior, name, user, state, total_time,
#                        queue slots and task_id if needed. Pass XML info
#                        to proc qstat_xml_jobid which does the bulk of
#                        the work.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 Output array is similar to that of 
#                 parse_qstat {input output {jobid ""} {ext 0} {do_replace_NA 1 } }
#
#      param -  pass in param to qstat
# 
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     None
#
#  NOTES
#     
#
#*******************************

proc qstat_j_xml_parse { output  } {
   upvar $output output_xml

   # Run now -xml command
   set XML [start_sge_bin  "qstat" "-j -xml" ]

   set doc  [dom parse $XML]

   set root [$doc documentElement]

   
   # Parse the running jobs  using this node.
   set node [$root firstChild]   ; # <qmaster_response/>

   set result1 [qstat_j_xml_jobid $node output_xml]
}

 




#                                                             max. column:     |
#****** parser_xml/qstat_j_JOB_NAME_xml_parse() ******
#
#  NAME
#     qstat_j_JOB_NAME_xml_parse -- Generate XML output and return assoc array 
#
#  SYNOPSIS
#     qstat_j_JOB_NAME_xml_parse { output {param ""} }
#                     -- Generate XML output and return assoc array with
#                        entries jobid, prior, name, user, state, total_time,
#                        queue slots and task_id if needed. Pass XML info
#                        to proc qstat_xml_jobid which does the bulk of
#                        the work.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 Output array is similar to that of 
#                 parse_qstat {input output {jobid ""} {ext 0} {do_replace_NA 1 } }
#
#      param -  pass in param to qstat
# 
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     None
#
#  NOTES
#     
#
#*******************************

proc qstat_j_JOB_NAME_xml_parse { output {param ""} } {
   upvar $output output_xml

   # Run now -xml command
   set XML [start_sge_bin  "qstat" "-j $param -xml" ]

   set doc  [dom parse $XML]

   set root [$doc documentElement]
   
   # Parse the running jobs  using this node.
   set node [$root firstChild]   ; # <djob-info/>
   set node1 [$node firstChild]  ; # <qmaster_response/>

   set result1 [qstat_j_JOB_NAME_xml_jobid $node1 output_xml]
}

#                                                             max. column:     |
#****** parser_xml/qstat_f_xml_parse() ******
#
#  NAME
#     qstat_f_xml_parse -- Generate XML output and return assoc array
#
#  SYNOPSIS
#     qstat_f_xml_parse { output }
#                     -- Generate XML output and return assoc array with
#                        entries jobid, prior, name, user, state, total_time,
#                        queue slots and task_id if needed. Pass XML info
#                        to proc qstat_xml_jobid which does the bulk of
#                        the work.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 Output array is similar to that of
#                 parse_qstat {input output {jobid ""} {ext 0} {do_replace_NA 1 } }
#
#      param - pass in "ext" or  "-ne" as params for qstat -f
#
#
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     None
#
#  NOTES
#
#
#*******************************

proc qstat_f_xml_parse { output {param ""} } {
   upvar $output output_xml
   
   # Run now -xml command
   set XML [start_sge_bin  "qstat" "-f $param -xml" ]

   set doc  [dom parse $XML]

   set root [$doc documentElement]
   
   if { ($param == "-ext") } {
      set queueparam "fext"
   } elseif { ($param == "-r") } {
      set queueparam "fr"
   } elseif { ($param == "-urg") } {
      set queueparam "furg"   
   } else {
      set queueparam ""
   }
   
   # Parse the running jobs  using this node.
   set node [$root firstChild]   ; # <job-info/>
   set node1 [$node firstChild]  ; # <queue-info/>

   set result1 [qstat_xml_queue $node1 output_xml $queueparam]

   # Parse the pending jobs info using this node. Need to start here
   # NOT at root.
   
   if { ($param == "-ext") } {
      set jobparam "fextpending"
   } elseif { ($param == "-r") } {
      set jobparam "frpending"
   } elseif { ($param == "-urg") } {
      set jobparam "urgpending"   
   } else {
      set jobparam "full"
   }
   
   set node [$root firstChild]   ; # <job-info/>
   set node12 [$node nextSibling]  ; # <queue-info/>
   set node121 [$node12 firstChild]  ; # <qname/>

   set result2 [qstat_xml_jobid $node121 $jobparam output_xml]
}

 
#                                                             max. column:     |
#****** parser_xml/qstat_F_xml_parse() ******
#
#  NAME
#     qstat_F_xml_parse -- Generate XML output and return assoc array
#
#  SYNOPSIS
#     qstat_F_xml_parse { output {params ""} }
#                     -- Generate XML output and return assoc array with
#                        entries jobid, prior, name, user, state, total_time,
#                        queue slots and task_id if needed. Pass XML info
#                        to proc qstat_xml_jobid which does the bulk of
#                        the work.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 Output array is similar to that of
#                 parse_qstat {input output {jobid ""} {ext 0} {do_replace_NA 1 } }
#
#      params  - args passed to the "qstat -F" command
# 
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     None
#
#  NOTES
#
#
#*******************************

proc qstat_F_xml_parse { output {params ""} } {
   upvar $output output_xml

   # Transform the params list into a comma separated list
   regsub " " $params "," arguments ;
   # Run now -xml command
   set XML [start_sge_bin  "qstat" "-F $arguments -xml" ]

   set doc  [dom parse $XML]

   set root [$doc documentElement]
   
   # Parse the running jobs  using this node.
   set node [$root firstChild]   ; # <job_info/>
   set node1 [$node firstChild]  ; # <queue-info/>

   # Transform the args list back into a ""  separated list
   regsub "," $arguments " " params ;
   set result1 [qstat_F_xml_queue $node1 output_xml $params]

   # Parse the pending jobs info using this node. Need to start here
   # NOT at root.
   
   set node [$root firstChild]   ; # <job-info/>
   set node12 [$node nextSibling]  ; # <queue-info/>
   set node121 [$node12 firstChild]  ; # <qname/>

   set result2 [qstat_xml_jobid $node121 full output_xml]
}



#                                                           max. column:     |
#****** parser_xml/qstat_j_xml_jobid() ******
#
#  NAME
#     qstat_j_xml_jobid -- Take XML node and return assoc array 
#
#  SYNOPSIS
#     qstat_j_xml_jobid -- Take XML node and return assoc array with
#                          entries jobid, message. 
#
#  FUNCTION
#     Return assoc array
#
#  INPUTS
#     
#     qstat_j_xml_jobid {node121  output} 
#
#     node121  -  node in XML doc where we start navigation
#    
#     output  -  asscoc array with the entries mentioned above.
#
#  NOTES
#     
#
#*******************************

proc qstat_j_xml_jobid { node1  output} {
   upvar $output output_xml_qstat
   get_current_cluster_config_array ts_config
   
   set node121 [$node1 firstChild]  ; # <SME_message_list/>

   # If nothing, we have not started any jobs, so we return
   if { $node121 == "" } {
      return
   }
   set node1211 [$node121 firstChild]  ; # <element/>
   set node12111 [$node1211 firstChild]  ; # <SME_job_number_list/>
   set node124 [$node12111 firstChild] ; # <element/>
   
   set node125 [$node124 firstChild] ; # <ULNG/>
   set node126 [$node125 firstChild] ; # <elem/>
   set jobid [$node126 nodeValue]
                                
   set output_xml_qstat($jobid,jobid) $jobid
   lappend output_xml_qstat(jobid_list) $jobid

   ts_log_fine "jobid is $jobid ....\n"
   
   set column_vars "job_number jobid_msg"
      

   foreach column $column_vars {
      set node21 [$node12111 nextSibling] ;
      if { $node21 == "" } {
         break
      }
      set node211 [$node21 firstChild] ; # <jobid info/

      if { $node211 == "" } { ; # we have hit the empty queue entry
         append output_xml_qstat($jobid,$column) ""
         set node12111 $node21
         continue
      }
      
      set xml_param [$node211 nodeValue]

      set output_xml_qstat($jobid,$column) $xml_param   
      set node12111 $node21
      
   }
  
   # The next list of jobs 
   set node1311 [$node1211 nextSibling]  ; # <next element/>
   set node13111 [$node1311 firstChild]  ; # <SME_job_number_list/>
   set node131111 [$node13111 firstChild] ; # <element/>
   
   set node135 [$node131111 firstChild] ; # <ULNG/>
   set node136 [$node135 firstChild] ; # <elem/>
   set jobid [$node136 nodeValue]
   
   set output_xml_qstat($jobid,jobid) $jobid
   lappend output_xml_qstat(jobid_list) $jobid
         
   ts_log_fine "jobid is $jobid ....\n"
  
   foreach column $column_vars {
      set node31 [$node13111 nextSibling] ;
      if { $node31 == "" } {
         break
      }
      set node311 [$node31 firstChild] ; # <jobid info/

      if { $node311 == "" } { ; # we have hit the empty queue entry
         append output_xml_qstat($jobid,$column) ""
         set node13111 $node31
         continue
      }
      
      set xml_param [$node311 nodeValue]
      
      set output_xml_qstat($jobid,$column) $xml_param   
      set node13111 $node31
      
  }
}


#                                                           max. column:     |
#****** parser_xml/qstat_xml_jobid() ******
#
#  NAME
#     qstat_xml_jobid -- Take XML node and return assoc array 
#
#  SYNOPSIS
#     qstat_xml_jobid -- Take XML node and return assoc array with
#                        entries jobid, prior, name, user, state, total_time,
#                        queue slots and task_id if needed. 
#
#  FUNCTION
#     Return assoc array
#
#  INPUTS
#     
#     qstat_xml_jobid {node121 jobtype output} 
#
#     node121  -  node in XML doc where we start navigation
#     jobtype  -  "running" or "pending", "ext" or "extpending" which tells us which 
#                  fields to expect
#     output  -  asscoc array with the entries mentioned above.
#
#  NOTES
#     
#
#*******************************

proc qstat_xml_jobid { node121 jobtype output} {
   upvar $output output_xml_qstat
   

   # Add var to tell if doing a running job parse or pending job parse
   # jobtype = {runing, pending, full, ext, ext_pending}
   
   # If nothing, we have not started any jobs, so we return
   if { $node121 == "" } {
      return
   }
   set node1211 [$node121 firstChild]  ; # <qname1/>
   set node12111 [$node1211 firstChild]  ; # <jobid/
   if { $node12111 == "" } {
      return
   }
   set jobid [$node12111 nodeValue]

   set output_xml_qstat($jobid,jobid) $jobid
   lappend output_xml_qstat(jobid_list) $jobid

   # Use the names from the parse_plain_qstat output :)
   # set column_vars "prior name user state time queue master"
   # As in parse_plain_qstat case, for pending jobs, queue and task_id entries
   # are set to blank.
   
   # For -ext, column order is: job-ID prior ntckts name  user
   # project department state cpu mem io tckts ovrts otckt ftckt stckt share queue ja-task-ID
   # The -ext_pending has missing data for: cpu mem io tckts ovrtcts queue ja-task-ID
   
   if { $jobtype == "running" } { ; # this is for listing of qstat running jobs 
      set column_vars "prior name user state time queue master task_id"
   } elseif { $jobtype == "pending" } { ; # this is for listing of qstat pending jobs
      set column_vars "prior name user state time queue master"
      set output_xml_qstat($jobid,task_id) ""
   }  elseif { $jobtype == "full" } { ; # this is for listing of qstat -F jobs
      set column_vars "prior name user state time slots task_id"   
   }
   if { $jobtype == "extpending" } { ; # this is for listing qstat -ext pending jobs
      set column_vars "prior ntckts name  user project department state tckts ovrts job_share otckt ftckt  \
      stckt share slots slots"
      append output_xml_qstat($jobid,cpu) " "
      append output_xml_qstat($jobid,mem) " "
      append output_xml_qstat($jobid,io) " "
      append output_xml_qstat($jobid,queue) " "      
      append output_xml_qstat($jobid,task_id) " "
   }
   
   if { $jobtype == "fextpending" } { ; # this is for listing qstat -f -ext pending jobs
      set column_vars "prior ntckts name user project department state tckts ovrts job_share \
      otckt ftckt stckt share slots"
      append output_xml_qstat($jobid,cpu) " "
      append output_xml_qstat($jobid,mem) " "
      append output_xml_qstat($jobid,io) " "
      append output_xml_qstat($jobid,task_id) " "
   }
   if { $jobtype == "ext" } { ; # this is for listing qstat -ext jobs
      set column_vars "prior ntckts name  user project department state cpu mem io tckts \
      ovrts job_share otckt ftckt stckt share queue slots task_id"
      append output_xml_qstat($jobid,task_id) " "
   }
   if { $jobtype == "fext" } { ; # this is for listing qstat -f -ext jobs
      set column_vars "prior ntckts name  user project department state cpu mem io tckts \
      ovrts job_share otckt ftckt stckt share slots task_id"
   }
   if { $jobtype == "urg" } { ; # this is for listing qstat -urg jobs
      set column_vars "prior nurg urg rrcontr wtcontr dlcontr name user state time  \
      queue slots task_id"
      append output_xml_qstat($jobid,deadline) " "
      append output_xml_qstat($jobid,task_id) " "
   }
   
   if { $jobtype == "furg" } { ; # this is for listing qstat -f -urg jobs. See IZ 2072.
      set column_vars "prior nurg urg rrcontr wtcontr dlcontr name user state time  \
      slots task_id"
      append output_xml_qstat($jobid,deadline) " "
      append output_xml_qstat($jobid,task_id) " "
   }
   
   if { $jobtype == "urgpending" } { ; # this is for listing qstat -urg jobs
      set column_vars "prior nurg urg rrcontr wtcontr dlcontr name user state time  \
      slots slots"
      append output_xml_qstat($jobid,deadline) " "
      append output_xml_qstat($jobid,queue) " "
      append output_xml_qstat($jobid,task_id) " "
   }
   
   if { $jobtype == "pri" } { ; # this is for listing qstat -pri jobs
      set column_vars "prior npprior ppri name  user state time queue slots task_id "
   }
   if { $jobtype == "pripending" } { ; # this is for listing qstat -pri pending jobs
      set column_vars "prior npprior ppri name  user state time slots slots"
      append output_xml_qstat($jobid,queue) ""
      append output_xml_qstat($jobid,task_id) ""
   }
   if { $jobtype == "r" } { ; # this is for listing qstat -r jobs
      set column_vars "prior  name  user state time queue slots task_id \
                       hard_req_queue hard_resource "
      append output_xml_qstat($jobid,full_jobname) ""
      append output_xml_qstat($jobid,master_queue) ""
      append output_xml_qstat($jobid,hard_resource) ""
      append output_xml_qstat($jobid,soft_resource) ""
      append output_xml_qstat($jobid,hard_req_queue) ""
      append output_xml_qstat($jobid,req_pe_value) ""
      append output_xml_qstat($jobid,granted_pe_value) ""
   }
   if { $jobtype == "rpending" } { ; # this is for listing qstat -r pending jobs
      set column_vars "prior  name  user state time slots slots hard_req_queue"
      append output_xml_qstat($jobid,queue) ""
      append output_xml_qstat($jobid,task_id) ""
      append output_xml_qstat($jobid,full_jobname) ""
      append output_xml_qstat($jobid,master_queue) ""
      append output_xml_qstat($jobid,hard_resource) ""
      append output_xml_qstat($jobid,soft_resource) ""
      append output_xml_qstat($jobid,hard_req_queue) ""
      append output_xml_qstat($jobid,req_pe_value) ""
      append output_xml_qstat($jobid,granted_pe_value) ""
   }
   
	if { $jobtype == "frpending" } { ; # this is for listing qstat -f -r pending jobs
      set column_vars "prior  name  user state time slots  hard_req_queue"
      append output_xml_qstat($jobid,queue) ""
      append output_xml_qstat($jobid,task_id) ""
      append output_xml_qstat($jobid,full_jobname) ""
      append output_xml_qstat($jobid,master_queue) ""
      append output_xml_qstat($jobid,hard_resource) ""
      append output_xml_qstat($jobid,soft_resource) ""
      append output_xml_qstat($jobid,hard_req_queue) ""
      append output_xml_qstat($jobid,req_pe_value) ""
      append output_xml_qstat($jobid,granted_pe_value) ""
   }
	
    if { $jobtype == "fr" } { ; # this is for listing qstat -f -r jobs; See IZ 2071.
      set column_vars "prior name user state time slots task_id \
                       hard_req_queue hard_resource "
      append output_xml_qstat($jobid,full_jobname) ""
      append output_xml_qstat($jobid,master_queue) ""
      append output_xml_qstat($jobid,hard_resource) ""
      append output_xml_qstat($jobid,soft_resource) ""
      append output_xml_qstat($jobid,hard_req_queue) ""
      append output_xml_qstat($jobid,req_pe_value) ""
      append output_xml_qstat($jobid,granted_pe_value) ""
   }

   foreach column $column_vars {
      set node21 [$node1211 nextSibling] ;
      if { $node21 == "" } {
         break
      }
      set node211 [$node21 firstChild] ; # <jobid info/

      if { $node211 == "" } { ; # we have hit the empty queue entry
         append output_xml_qstat($jobid,$column) ""
         set node1211 $node21
         continue
      }
      
      set xml_param [$node211 nodeValue]
      
      # For time, need the UNIX value, to compare with plain output.
      if { ($column == "time") } {
         set xml_param [transform_date_time $xml_param 1]
      }   
      
      # In the case of qstat -r, we get hard_req_queue after slots, not task_id
      if { ($jobtype == "r") && ($column == "task_id") && [regexp "\[a-zA-Z.\]"  $xml_param] } {
          set output_xml_qstat($jobid,hard_req_queue) $xml_param
          set node1211 $node21
          continue
      }
      
      if { ($jobtype == "rpending") && ($column == "hard_req_queue") && [regexp "\[0-9\]"  $xml_param] } {
          set output_xml_qstat($jobid,slots) $xml_param
          set node1211 $node21
          continue
      }
      
      # In the case of qstat -f -r, we get hard_req_queue after slots, not task_id
      if { ($jobtype == "fr") && ($column == "task_id") && [regexp "\[a-zA-Z.\]"  $xml_param] } {
          set output_xml_qstat($jobid,hard_req_queue) $xml_param
          set node1211 $node21
          continue
      }
      
      if { ($column == "hard_req_queue") && ($jobtype == "r") && [regexp "lx" $xml_param] || \
           [regexp "sol" $xml_param]} {
          set output_xml_qstat($jobid,hard_resource) "arch=$xml_param"
          #set output_xml_qstat($jobid,$column) ""
          set node1211 $node21
          continue
      }
      
      if { ($column == "hard_req_queue") && ($jobtype == "fr") && [regexp "lx" $xml_param] || \
           [regexp "sol" $xml_param]} {
          set output_xml_qstat($jobid,hard_resource) "arch=$xml_param"
          set node1211 $node21
          continue
      }
      
      # For colums "queue" and others we need to append rather than set
      # since we can have more than one entries.
      if { ($column == "queue") || ($column == "master") || ($column == "slots") || ($column == "task_id")} {
         append output_xml_qstat($jobid,$column) "$xml_param "
         set node1211 $node21
      } else {
         set output_xml_qstat($jobid,$column) $xml_param      
         set node1211 $node21
      }
     
      if { ($column == "hard_resource") } {
         set output_xml_qstat($jobid,hard_resource) "arch=$xml_param"
      }
      
   }

   while { 1 } {

      set node13  [$node121 nextSibling]  ; # <next jobid/>
      if { $node13 == "" } {
         break
      }

      set node122 [$node13 firstChild] ; #
      set node1212 [$node122 firstChild]  ; # <next jobid info/>

      set next_jobid [$node1212 nodeValue]

      set output_xml_qstat($next_jobid,jobid) $next_jobid
      lappend output_xml_qstat(jobid_list) $next_jobid
      
      set node121 $node13 ; # yes, node121, NOT node122...
      
      foreach next_column $column_vars {
         set node22 [$node122 nextSibling] ;
         if { $node22 == "" } {
            continue
         }
         set node221 [$node22 firstChild] ; # <jobid info/>

         if { $node221 == "" } { ; # we hit the empty queue entry
            append output_xml_qstat($next_jobid,$next_column) ""
            set node122 $node22
            continue        
         }

         set next_xml_param [$node221 nodeValue]

         # In the case of qstat -r, we get hard_req_queue after slots, not task_id
         if { ($jobtype == "r")  && ($next_column == "task_id") && [regexp "\[a-zA-Z.\]" $next_xml_param] } {
            set output_xml_qstat($next_jobid,hard_req_queue) $next_xml_param
            set node1211 $node21
            continue
         }
         
         # In the case of qstat -f -r, we get hard_req_queue after slots, not task_id
         if { ($jobtype == "fr")  && ($next_column == "task_id") && [regexp "\[a-zA-Z.\]" $next_xml_param] } {
            set output_xml_qstat($next_jobid,hard_req_queue) $next_xml_param
            set node1211 $node21
            continue
         }
         
         
         if { ($jobtype == "rpending") && ($next_column == "hard_req_queue") && [regexp "\[0-9\]"  $next_xml_param] } {
            set output_xml_qstat($next_jobid,slots) $next_xml_param
            set node1211 $node21
            continue
         }
         
         
         if { ($next_column == "hard_req_queue") && ($jobtype == "r") && [regexp "lx" $next_xml_param] || \
              [regexp "sol" $next_xml_param] } {
           set output_xml_qstat($next_jobid,hard_resource) "arch=$next_xml_param"
           #set output_xml_qstat($next_jobid,$next_column) ""
           set node1211 $node21
           continue
         }
         
         if { ($next_column == "hard_req_queue") && ($jobtype == "fr") && [regexp "lx" $next_xml_param] || \
              [regexp "sol" $next_xml_param] } {
           set output_xml_qstat($next_jobid,hard_resource) "arch=$next_xml_param"
           #set output_xml_qstat($next_jobid,$next_column) ""
           set node1211 $node21
           continue
         }

         if { ($next_column == "time") } {
            set next_xml_param  [transform_date_time $next_xml_param 1]
         }   
            
         # For colums "queue", "master", "slots", "task_id" we need to append
         # rather than set since we can have more than one entries.
         if { ($next_column == "queue") || ($next_column == "master") || ($next_column == "slots") || ($next_column == "task_id")} {
            append output_xml_qstat($next_jobid,$next_column) "$next_xml_param "
            set node122 $node22
         } else {   
            set output_xml_qstat($next_jobid,$next_column) $next_xml_param
            set node122 $node22
         }
         
         if { ($next_column == "hard_resource") } {
            set output_xml_qstat($next_jobid,hard_resource) "arch=$next_xml_param"
         }
         
       }

    }
}



#                                                             max. column:     |
#****** parser_xml/qstat_j_JOB_NAME_xml_jobid() ******
#
#  NAME
#     qstat_j_JOB_NAME_xml_jobid -- Take XML node and return assoc array
#
#  SYNOPSIS
#     qstat_j_JOB_NAME_xml_jobid -- Take XML node and return assoc array with
#                        entries jobid, prior, name, user, state, total_time,
#                        queue slots and task_id if needed. Pass XML info
#                        to proc qstat_xml_jobid which does the bulk of
#                        the work.
#
#  FUNCTION
#     Return assoc array
#
#  INPUTS
#
#     qstat_j_JOB_NAME_xml_jobid {node121  output}
#
#     node121  -  node in XML doc where we start navigation
#
#     output  -  asscoc array with the entries mentioned above.
#
#  NOTES
#
#
#*******************************

proc qstat_j_JOB_NAME_xml_jobid { node121 output} {
   upvar $output output_xml_qstat


   # If nothing, we have not started any jobs, so we return
   if { $node121 == "" } {
      return
   }
   set node1211 [$node121 firstChild]  ; # <qname1/>
   set node12111 [$node1211 firstChild]  ; # <jobid/
   if { $node12111 == "" } {
      return
   }
   set jobid [$node12111 nodeValue]


   set output_xml_qstat($jobid,jobid) $jobid
   lappend output_xml_qstat(jobid_list) $jobid

   set  column_vars "job_name version session department exec_file script_file \
                     script_size submission_time execution_time deadline owner uid group \
                     gid account notify type reserve priority jobshare shell_list verify \
                     env_list job_args checkpoint_attr checkpoint_object checkpoint_interval \
                     restart stdout_path_list merge_stderr hard_queue_list mail_options \
                     mail_list ja_structure ja_template ja_tasks host verify_suitable_queues \
                     nrunning soft_wallclock_gmt hard_wallclock_gmt override_tickets urg nurg \
                     nppri rrcont dlcontr wtcont"; # .... stop at </qmaster_response>

  
   # Here are sub-vars for some of the  vars above.
   set shell_list_vars "path host file_host file_staging"

   # sge_o_home_tag sge_o_home sge_o_logname_tag sge_o_logname ... then
   set env_list_vars "sge_o_path_tag sge_o_path sge_o_shell_tag sge_o_shell \
                      sge_o_mail_tag sge_o_mail sge_o_host_tag \
                      sge_o_host sge_o_workdir_tag sge_o_workdir"

   set job_args_vars "job_args_value"

   set stdout_path_list_vars "path host file_host file_staging"

   set hard_queue_list_args "hard_queue_list_value"

   set mail_list_vars "user host"

   set ja_structure_vars "min max step"

   set ja_template_vars "task_number status start_time end_time hold job_restarted stat pvm_ckpt_pid \
                         pending_signal pending_signal_delivery_time pid fshare tix oticket _fticket \
                         sticket share suitable pe_object next_pe_task_id stop_initiate_time prio ntix"

   set ja_tasks_vars "task_number status start_time end_time hold job_restarted state pvm_ckpt_pid pending_signal \
                      pending_signal_delivery_time pid usage_list fshare tix oticket fticket sticket share \
                      suitable previous_usage_list pe_object next_pe_task_id stop_initiate_time pri \
                      ntix message_list"

   set usage_list_vars "usage_list_submission_time usage_list_submission_time_value usage_list_priority \
                        usage_list_priority_value"

   set previous_usage_list_vars "previous_usage_list_submission_time previous_usage_list_submission_time_value \
                                 previous_usage_list_priority previous_usage_list_priority_value"

   set message_list_vars "type message"

   foreach column $column_vars {
      set node21 [$node1211 nextSibling] ;
      if { $node21 == "" } {
         break
      }
      set node211 [$node21 firstChild] ; # <jobid info/

      if { $node211 == "" } { ; # we have hit the empty queue entry
         append output_xml_qstat($jobid,$column) ""
         set node1211 $node21
         continue
      }

      set xml_param [$node211 nodeValue]

       if { ($column == "env_list") } { ; # get the sge_o vars

         set node1311 [$node211  firstChild]

         foreach env_column "sge_o_home_tag sge_o_home"  {
            ##set node31 [$node1311 nextSibling] ; works
            set node31 $node1311
            if { $node31 == "" } {
               continue
            }
            set node311 [$node31 firstChild] ; # <jobid info/

            if { $node311 == "" } { ; # we have hit the empty queue entry
               append output_xml_qstat($jobid,$env_column) ""
               set node1311 [$node31 nextSibling]
               continue
            }

            set env_xml_param [$node311 nodeValue]
            set output_xml_qstat($jobid,$env_column) $env_xml_param
            set node1311 [$node31 nextSibling] ; # works
          }

          set node1312 [$node211 nextSibling]
          set node1311 [$node1312 firstChild]

          foreach env_column "sge_o_log_name_tag sge_o_log_name" {
             set node31 $node1311
            if { $node31 == "" } {
               continue
            }
            set node311 [$node31 firstChild] ; # <jobid info/

            if { $node311 == "" } { ; # we have hit the empty queue entry
              append output_xml_qstat($jobid,$env_column) ""
              set node1311 [$node31 nextSibling]
             continue
            }

            set env_xml_param [$node311 nodeValue]
            set output_xml_qstat($jobid,$env_column) $env_xml_param
            set node1311 [$node31 nextSibling]
          }

          set node1313 [$node1312 nextSibling]
          set node1311 [$node1313 firstChild]

          foreach env_column "sge_o_path_tag sge_o_path" {
             set node31 $node1311
             if { $node31 == "" } {
                continue
             }
             set node311 [$node31 firstChild] ; # <jobid info/
          
               if { $node311 == "" } { ; # we have hit the empty queue entry
               append output_xml_qstat($jobid,$env_column) ""
               set node1311 [$node31 nextSibling]
               continue
            }

            set env_xml_param [$node311 nodeValue]
            set output_xml_qstat($jobid,$env_column) $env_xml_param
            set node1311 [$node31 nextSibling]
          }

          set node1314 [$node1313 nextSibling]
          set node1311 [$node1314 firstChild]

          foreach env_column "sge_o_shell_tag sge_o_shell " {
             set node31 $node1311
             if { $node31 == "" } {
                continue
             }
             set node311 [$node31 firstChild] ; # <jobid info/

             if { $node311 == "" } { ; # we have hit the empty queue entry
                append output_xml_qstat($jobid,$env_column) ""
                set node1311 [$node31 nextSibling]
                continue
             }

             set env_xml_param [$node311 nodeValue]
             set output_xml_qstat($jobid,$env_column) $env_xml_param
             set node1311 [$node31 nextSibling]
          }

          set node1315 [$node1314 nextSibling]
          set node1311 [$node1315 firstChild]

          foreach env_column "sge_o_mail_tag sge_o_mail" {
             set node31 $node1311
             if { $node31 == "" } {
                continue
             }
             set node311 [$node31 firstChild] ; # <jobid info/

             if { $node311 == "" } { ; # we have hit the empty queue entry
                append output_xml_qstat($jobid,$env_column) ""
                set node1311 [$node31 nextSibling]
                continue
             }

             set env_xml_param [$node311 nodeValue]
             set output_xml_qstat($jobid,$env_column) $env_xml_param
             set node1311 [$node31 nextSibling]
          }

          # If we have time zone info, we are off by 1 set of
          # params. Need to do mail again

          if { ($output_xml_qstat($jobid,sge_o_mail_tag) == "__SGE_PREFIX__O_TZ") } {

             set node1315 [$node1315 nextSibling]
             set node1311 [$node1315 firstChild]

             foreach env_column "sge_o_mail_tag sge_o_mail" {
                set node31 $node1311
                if { $node31 == "" } {
                   continue
                }
                set node311 [$node31 firstChild] ; # <jobid info/

                if { $node311 == "" } { ; # we have hit the empty queue entry
                   append output_xml_qstat($jobid,$env_column) ""
                   set node1311 [$node31 nextSibling]
                   continue
                }

                set env_xml_param [$node311 nodeValue]
                set output_xml_qstat($jobid,$env_column) $env_xml_param
                set node1311 [$node31 nextSibling]
             }

          }

          set node1316 [$node1315 nextSibling]
          set node1311 [$node1316 firstChild]

          foreach env_column "sge_o_host_tag sge_o_host" {
             set node31 $node1311
             if { $node31 == "" } {
                continue
              }
             set node311 [$node31 firstChild] ; # <jobid info/

             if { $node311 == "" } { ; # we have hit the empty queue entry
                append output_xml_qstat($jobid,$env_column) ""
                set node1311 [$node31 nextSibling]
                continue
             }

             set env_xml_param [$node311 nodeValue]
             set output_xml_qstat($jobid,$env_column) $env_xml_param
             set node1311 [$node31 nextSibling]
          }

          set node1317 [$node1316 nextSibling]
          set node1311 [$node1317 firstChild]

          foreach env_column "sge_o_workdir_tag sge_o_workdir" {
             set node31 $node1311
             if { $node31 == "" } {
                continue
             }
             set node311 [$node31 firstChild] ; # <jobid info/

             if { $node311 == "" } { ; # we have hit the empty queue entry
                append output_xml_qstat($jobid,$env_column) ""
                set node1311 [$node31 nextSibling]
                continue
             }

             set env_xml_param [$node311 nodeValue]
             set output_xml_qstat($jobid,$env_column) $env_xml_param
             set node1311 [$node31 nextSibling]
          }

     }

      set output_xml_qstat($jobid,$column) $xml_param
      set node1211 $node21

   }

}


#                                                             max. column:     |
#****** parser_xml/qstat_xml_queue() ******
#
#  NAME
#     qstat_xml_queue -- Take XML node and return assoc array
#
#  SYNOPSIS
#     qstat_xml_queue -- Take XML node and return assoc array with
#                        queuename, qtype, used slots,total slots, load_avg,
#                        arch, states.
#
#  FUNCTION
#     Return assoc array
#
#  INPUTS
#
#     qstat_xml_queue {node1 output {param ""} }
#
#     node1  -  node in XML doc where we start navigation
#     output  -  asscoc array with the entries mentioned above.
#     param  - pass in param ext for -ext output
#
#  NOTES
#
#
#*******************************

proc qstat_xml_queue { node1 output {param ""} } {
   upvar $output output_xml_qstat
   # Try this way to look at the data....

   # Queue info (except that jobid info might be in
   # here as well....

   set node11 [$node1 firstChild]   ; #  <Queue-list/>
   set node111 [$node11 firstChild]  ; # <qname/>

   set queue [$node111 nodeValue]
   set output_xml_qstat($queue,qname) $queue
   append output_xml_qstat($queue,state) ""
   lappend output_xml_qstat(queue_list) $queue

   set column_vars  "qtype used_slots total_slots load_avg arch state"

   foreach column $column_vars {

     set node12 [$node11 nextSibling]  ; # <queue name data/>


      if { $node12 == "" } { ;# Get out if at the end of tree
         break
      }
      set node122 [$node12 firstChild] ; # <parameters in queue listing/>
      set xml_param [$node122 nodeValue]
      set output_xml_qstat($queue,$column) $xml_param

      if { ($column == "load_avg") } {
            set output_xml_qstat($queue,$column) [format "%3.2f" $output_xml_qstat($queue,$column)]
      }

      set node11 $node12  ; # Shift to next paramter in the list

   }

   # Once we are done with the queue parameters, the next Sibling will be the
   # node pointing to job id information. We re-use queue_xml_jobid with
   # the  following flags:  "ext" for -ext; "fext" for -f -ext; and "full"
   # for -f.

   if { ($param == "ext") } {
      set jobparam "ext"
   } elseif { ($param == "fext") } {
      set jobparam "fext"
   } elseif { ($param == "fr") } {
      set jobparam "fr"
   } elseif { ($param == "furg") } {
      set jobparam "furg"   
   } else {
      set jobparam "full"
   }
   
   set result12 [qstat_xml_jobid $node11 $jobparam output_xml_qstat]
   set  node11 $node12


   while { 1 } {
      set node22 [$node1 nextSibling]  ; # <queue-info/>
      if { $node22 ==""} { ;  # Get out if at the end of tree
         break
      }

      set node222 [$node22 firstChild]  ; # <Queue-list/>
      set name [$node222 firstChild]    ; # <qname2>
      set node1 $node22

      set queue [$name nodeValue]
      set output_xml_qstat($queue,qname) $queue
      append output_xml_qstat($queue,state) ""
      lappend output_xml_qstat(queue_list) $queue

      foreach column $column_vars {
         set node2 [$node222 nextSibling]  ; # <queue name data/>
         if { $node2 == "" } { ; # break if no more info
            continue
         }

         set node221 [$node2 firstChild] ; #
         set xml_param [$node221 nodeValue]
         set output_xml_qstat($queue,$column) $xml_param

         if { ($column == "load_avg") } {
            set output_xml_qstat($queue,$column) [format "%3.2f" $output_xml_qstat($queue,$column)]
         }

         set node222 $node2 ; # move to the next paramter

      }

      # Once we are done with the queue parameters, the next Sibling will be the
      # node pointing to job id information. We re-use queue_xml_jobid with
      # the  following flags: "extpending" for -ext; "fextpending" for -f -ext;
      # "full" for -f;

      if { ($param == "ext") } {
         set jobparam "ext"
      } elseif { ($param == "fext") } {
         set jobparam "fext"
      } elseif { ($param == "fr") } {
         set jobparam "fr"
      } elseif { ($param == "furg") } {
      set jobparam "furg"   
      } else {
         set jobparam "full"
      }
   
      set result222 [qstat_xml_jobid $node222 $jobparam output_xml_qstat]

    }
}

#                                                             max. column:     |
#****** parser_xml/qstat_F_xml_queue() ******
#
#  NAME
#     qstat_F_xml_queue -- Take XML node and return assoc array
#
#  SYNOPSIS
#     qstat_xml_queue -- Take XML node and return assoc array with
#                        queuename, qtype, used slots,total slots, load_avg, 
#                        arch, states.
#
#  FUNCTION
#     Return assoc array
#
#  INPUTS
#
#     qstat_F_xml_queue {node1 output {params ""} }
#
#     node1   -  node in XML doc where we start navigation
#     output  -  asscoc array with the entries mentioned above.
#     params  - args for qstat -F; "" for the whole set, or
#              "rerun h_vmem" for a subset.
#
#  NOTES    This parser only works for default complexes configuration
#
#
#*******************************

proc qstat_F_xml_queue { node1 output {params ""} } {
   upvar $output output_xml_qstat
   # Try this way to look at the data....

   # Queue info (except that jobid info might be in
   # here as well....

   set node11 [$node1 firstChild]   ; #  <Queue-list/>
   set node111 [$node11 firstChild]  ; # <qname/>

   set queue [$node111 nodeValue]
   set output_xml_qstat($queue,qname) $queue
   append output_xml_qstat($queue,state) ""
   lappend output_xml_qstat(queue_list) $queue
   
   if { $params == "" } {  
      set column_vars  "qtype used_slots total_slots load_avg arch \
                     hl:arch hl:num_proc hl:mem_total hl:swap_total hl:virtual_total \
                     hl:load_avg hl:load_short hl:load_medium hl:load_long hl:mem_free \
                     hl:swap_free hl:virtual_free hl:mem_used hl:swap_used hl:virtual_used \
                     hl:cpu hl:np_load_avg hl:np_load_short hl:np_load_medium hl:np_load_long \
                     qf:qname qf:hostname qc:slots qf:tmpdir qf:seq_no qf:rerun qf:calendar \
                     qf:s_rt qf:h_rt qf:s_cpu qf:h_cpu qf:s_fsize qf:h_fsize qf:s_data \
                     qf:h_data qf:s_stack qf:h_stack qf:s_core qf:h_core qf:s_rss \
                     qf:h_rss qf:s_vmem qf:h_vmem qf:min_cpu_interval"
      
   } elseif { $params == "rerun h_vmem" } {             
      set column_vars  "qtype used_slots total_slots load_avg arch \
                        qf:rerun qf:h_vmem"
   }
   
   foreach column $column_vars {

     set node12 [$node11 nextSibling]  ; # <queue name data/>

      if { $node12 == "" } { ;# Get out if at the end of tree
         break
      }
      set node122 [$node12 firstChild] ; # <parameters in queue listing/>
      set xml_param [$node122 nodeValue]
      set output_xml_qstat($queue,$column) $xml_param
      
      if { ($column == "load_avg") } {
            set output_xml_qstat($queue,$column) [format "%3.2f" $output_xml_qstat($queue,$column)]
         }           

      set node11 $node12  ; # Shift to next paramter in the list
      
   }
   
   # Once we are done with the queue parameters, the next Sibling will be the
   # node pointing to job id information. We re-user queue_xml_jobid with
   # the  "full" flag, to pick information as listed in "qstat -F"
   # We use a slightly different list of column vars, since it seems
   # that is what the XML schema does! See IZ 2049.
   
   if { $params == ""  } { 
      set column_vars  "qtype used_slots total_slots load_avg arch \
                     hl:load_avg hl:load_short hl:load_medium hl:load_long \
                     hl:arch hl:num_proc hl:mem_free hl:swap_free hl:virtual_free \
                     hl:mem_total hl:swap_total hl:virtual_total hl:mem_used \
                     hl:swap_used hl:virtual_used hl:cpu hl:np_load_avg \
                     hl:np_load_short hl:np_load_medium hl:np_load_long \
                     qf:qname qf:hostname qc:slots qf:tmpdir qf:seq_no qf:rerun \
                     qf:calendar qf:s_rt qf:h_rt qf:s_cpu qf:h_cpu qf:s_fsize \
                     qf:h_fsize qf:s_data qf:h_data qf:s_stack qf:h_stack \
                     qf:s_core qf:h_core qf:s_rss qf:h_rss qf:s_vmem \
                     qf:h_vmem qf:min_cpu_interval"
              
   } elseif { $params == "rerun h_vmem" } {             
      set column_vars  "qtype used_slots total_slots load_avg arch \
                        qf:rerun qf:h_vmem"
   }
   
   set node13 [$node11 nextSibling]
   set result12 [qstat_xml_jobid $node13 full output_xml_qstat]
   
   while { 1 } {
      set node22 [$node1 nextSibling]  ; # <queue-info/>
      if { $node22 ==""} { ;  # Get out if at the end of tree
         break
      }

      set node222 [$node22 firstChild]  ; # <Queue-list/>
      set name [$node222 firstChild]    ; # <qname2>
      set node1 $node22

      set queue [$name nodeValue]
      set output_xml_qstat($queue,qname) $queue
      append output_xml_qstat($queue,state) ""
      lappend output_xml_qstat(queue_list) $queue

      foreach column $column_vars {

         set node2 [$node222 nextSibling]  ; # <queue name data/>
         if { $node2 == "" } { ; # break if no more info
            continue
         }

         set node221 [$node2 firstChild] ; #
         set xml_param [$node221 nodeValue]
         set output_xml_qstat($queue,$column) $xml_param
      
         if { ($column == "load_avg") } {
            set output_xml_qstat($queue,$column) [format "%3.2f" $output_xml_qstat($queue,$column)]
         }           

         set node222 $node2 ; # move to the next paramter

      }
      
      # Once we are done with the queue parameters, the next Sibling will be the
      # node pointing to job id information. We re-user queue_xml_jobid with
      # the  "full" flag, to pick information as listed in "qstat -F"
      
      set node223 [$node222 nextSibling]
      set result222 [qstat_xml_jobid $node223 full output_xml_qstat]

   }
}


#                                                             max. column:     |
#****** parser_xml/qstat_g_c_xml_parse() ******
#
#  NAME
#     qstat_g_c_xml_parse -- Generate XML output and return assoc array
#
#  SYNOPSIS
#     qstat_g_c_xml_parse { output }
#                     -- Generate XML output and return assoc array with
#                        entries clusterqueue, cqload, used, avail, total,
#                        aoACDS, cdsuE.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 Output array is similar to that of
#                 parse_qstat {input output {jobid ""} {ext 0} {do_replace_NA 1 } }
#
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     None
#
#  NOTES
#
#
#*******************************

proc qstat_g_c_xml_parse { output } {
   upvar $output output_xml

   # Run now -xml command
   set XML [start_sge_bin  "qstat" "-g c -xml" ]

   set doc  [dom parse $XML]

   set root [$doc documentElement]
   
   # Parse the running jobs  using this node.
   set node [$root firstChild]   ; # <cluster-queue-info/>
   #set node1 [$node firstChild]  ; # 

   set result1 [qstat_g_c_xml_queue $node output_xml]
}

#                                                             max. column:     |
#****** parser_xml/qstat_g_c_xml_queue() ******
#
#  NAME
#     qstat_g_c_xml_queue -- Take XML node and return assoc array
#
#  SYNOPSIS
#     qstat_g_c_xml_queue -- Take XML node and return assoc array with
#     clusterqueue, cqload, used, avail, total,aoACDS, cdsuE.
#
#  FUNCTION
#     Return assoc array
#
#  INPUTS
#
#     qstat_g_c_xml_queue {node1 output}
#
#     node1  -  node in XML doc where we start navigation
#     output  -  asscoc array with the entries mentioned above.
#
#  NOTES
#
#
#*******************************

proc qstat_g_c_xml_queue { node output } {
   upvar $output output_xml_qstat
   # Try this way to look at the data....

   # Queue info (except that jobid info might be in
   # here as well....

   set node1 [$node firstChild]
   set node11 [$node1 firstChild]  ; # <cluster_queue_summary/>

   if { $node11 == "" } { ;# Get out if at the end of tree
      break
   }
   
   set queue [$node11 nodeValue]
   set output_xml_qstat($queue,clusterqueue) $queue
   lappend output_xml_qstat(queue_list) $queue

   set column_vars  "cqload used avail total aoACDS cdsuE"

   foreach column $column_vars {

      set node12 [$node1 nextSibling]  ; # <cluster queue data/>

      set node122 [$node12 firstChild] ; # <parameters in listing/>
      set xml_param [$node122 nodeValue]
      set output_xml_qstat($queue,$column) $xml_param
      # Format the cqload output, so we can compare it to the plain output
      if { ($column == "cqload") } {
         set output_xml_qstat($queue,$column) [format "%3.2f" $output_xml_qstat($queue,$column)]
      }

      set node1 $node12  ; # Shift to next paramter in the list

   }

   while { 1 } {
      set node22 [$node nextSibling]  ; # <cluster-queue-info/>
      if { $node22 ==""} { ;  # Get out if at the end of tree
         break
      }

      set node $node22
      set node222 [$node22 firstChild]  
      set node222 [$node22 firstChild]  
      set node2222 [$node222 firstChild]  
      set queue [$node2222 nodeValue]

      set output_xml_qstat($queue,clusterqueue) $queue
      lappend output_xml_qstat(queue_list) $queue

      foreach column $column_vars {
         set node2 [$node222 nextSibling]  ; # <queue name data/>
         if { $node2 == "" } { ; # continue if no more info
            continue
         }

         set node221 [$node2 firstChild] ; #
         set xml_param [$node221 nodeValue]
         set output_xml_qstat($queue,$column) $xml_param
         # Format the cqload output, so we can compare it to the plain output
         if { ($column == "cqload") } {
            set output_xml_qstat($queue,$column) [format "%3.2f" $output_xml_qstat($queue,$column)]
         }

         set node222 $node2 ; # move to the next paramter
      }

   }
}

 
#                                                             max. column:     |
#****** parser_xml/qstat_ext_xml_parse() ******
#
#  NAME
#     qstat_ext_xml_parse -- Generate XML output and return assoc array 
#
#  SYNOPSIS
#     qstat_ext_xml_parse { output }
#                     -- Generate XML output and return assoc array with
#                        entries jobid, prior, name, user, state, total_time,
#                        queue slots and task_id if needed. Pass XML info
#                        to proc qstat_xml_jobid which does the bulk of
#                        the work.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 Output array is similar to that of 
#                 parse_qstat {input output {jobid ""} {ext 0} {do_replace_NA 1 } }
#
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     None
#
#  NOTES
#     
#
#*******************************

proc qstat_ext_xml_parse { output } {
   upvar $output output_xml

   # Run now -xml command
   set XML [start_sge_bin  "qstat" "-ext -xml" ]

   set doc  [dom parse $XML]

   set root [$doc documentElement]

   # Parse the running jobs  using this node.
   set node [$root firstChild]   ; # <job-info/>
   set node1 [$node firstChild]  ; # <joblisting/>
  
   set job_type1 "ext"
   set result1 [qstat_xml_jobid $node1 $job_type1 output_xml]

   # Parse the pending jobs info using this node. Need to start here
   # NOT at root.
   set node [$root firstChild]   ; # <job-info/>
   set node12 [$node nextSibling]  ; # <queue-info/>
   set node121 [$node12 firstChild]  ; # <qname/>

   set job_type2 "extpending"
   set result2 [qstat_xml_jobid $node121 $job_type2 output_xml]
}

#****** parser_xml/qhost_xml_parse() ******
#
#  NAME
#     qhost_xml_parse -- Generate XML output and return assoc array 
#
#  SYNOPSIS
#     qhost_xml_parse { output }
#                     -- Generate XML output and return assoc array with
#                        entries hostname, arch, ncpu, load, memory total,
#                        memory used, swap total, swap used.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 
#
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     varialbe into which will be stored the parsed xml array
#     additional params that qhost should use.
#
#  NOTES
#     
#
#*******************************
proc qhost_xml_parse { output {params ""} } {
   upvar $output xml

   # capture xml output
   set xmloutput [start_sge_bin "qhost" "$params -xml"]
   
   set doc [dom parse $xmloutput]
   set root [$doc documentElement]

   # parse xml output and create lists based on the attributes
   set qhost [$root childNodes]
   set job -1
   foreach elem $qhost {
      set hostvalue [$elem childNodes]
      set inc 1      
      foreach elemin $hostvalue {
         if {$inc == "1"} {
            incr job 1 
            set xml(host$job,name) [$elem getAttribute name]
         } 
         set xml(host$job,[$elemin getAttribute name]) [[$elemin firstChild] nodeValue]            
         incr inc 1
      }     
   }
}

#****** parser_xml/qhost_u_xml_parse() ******
#
#  NAME
#     qhost_u_xml_parse -- Generate XML output and return assoc array 
#
#  SYNOPSIS
#     qhost_u_xml_parse { output }
#                     -- Generate XML output and return assoc array with
#                        entries based on the output of qhost -u -xml.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 
#
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     varialbe into which will be stored the parsed xml array
#     additional params that qhost should use.
#
#  NOTES
#     
#
#*******************************
proc qhost_u_xml_parse { output_var {params ""} } {
   upvar $output_var xml
   
   # capture xml output
   set xmloutput [start_sge_bin "qhost" "$params -xml"]
   
   set doc [dom parse $xmloutput]
   set root [$doc documentElement]
   
   # parse xml output and create lists based on the attributes
   
   set children [$root getElementsByTagName job]
   set jobs [$children childNodes]   
   
   foreach jobvalue $jobs {   
      set xml(job,jobid) [$jobvalue getAttribute jobid] 
      set cNode [$jobvalue childNode]
      set xml(job,[$jobvalue getAttribute name]) [$cNode nodeValue]            
   }
}

#****** parser_xml/qhost_q_xml_parse() ******
#
#  NAME
#     qhost_q_xml_parse -- Generate XML output and return assoc array 
#
#  SYNOPSIS
#     qhost_q_xml_parse { output }
#                     -- Generate XML output and return assoc array with
#                        entries based on the output of qhost -q -xml.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 
#
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     varialbe into which will be stored the parsed xml array
#     additional params that qhost should use.
#
#  NOTES
#     
#
#*******************************
proc qhost_q_xml_parse { output_var } {
   upvar $output_var xml

   # capture xml output
   set xmloutput [start_sge_bin "qhost" "-q -xml"]

   set doc [dom parse $xmloutput]
   set root [$doc documentElement]

   # parse xml output and create lists based on the attributes
   
   set qhost [$root childNodes]
   set job -1
   foreach elem $qhost {
      set hostvalue [$elem childNodes]
      set inc 1
      
      foreach elemin $hostvalue {
         if {$inc == "1"} {
            incr job 1 
            set xml(host$job,name) [$elem getAttribute name]
         } 
            set xml(host$job,[$elemin getAttribute name]) [[$elemin firstChild] nodeValue]
            if { [$elemin hasChildNodes] == "1"} {
               set queue [$elemin childNodes]
               foreach innerelem $queue {
                  if { [$innerelem nodeType] == "ELEMENT_NODE" } {
                     if { [$innerelem getAttribute name] == "state_string" } {
                        if { [$innerelem nodeValue] != "" } {
                           set xml(host$job,[$innerelem getAttribute name]) [$innerValue nodeValue]
                        } else {
                           set xml(host$job,state_string) ""
                        }
                     } else {
                        set xml(host$job,[$innerelem getAttribute name]) [[$innerelem firstChild] nodeValue]
                     }
                  }
                  
               }
            }
         incr inc 1
      }     
   }
}

#****** parser_xml/qstat_gdr_xml_parse() ******
#
#  NAME
#     qstat_gdr_xml_parse -- Generate XML output and return assoc array 
#
#  SYNOPSIS
#     qstat_gdr_xml_parse { output }
#                     -- Generate XML output and return assoc array with
#                        entries jobid, prior, name, owner, state, total_time,
#                        queue, slots, task_id and full name.
#
#      output  -  asscoc array with the entries mentioned above.
#                 
#
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     varialbe into which will be stored the parsed xml array
#
#  NOTES
#     
#
#*******************************
proc qstat_gdr_xml_parse { output } {
   upvar $output xml
   
   if {[info exists xml]} {
      unset xml
   }

   set xmloutput [start_sge_bin "qstat" "-g d -r -xml"]
   set doc [dom parse $xmloutput]
   set root [$doc documentElement]
   
   # parse xml output and create lists based on the attributes
   set jobNumberList [$root selectNodes /job_info/queue_info/job_list/JB_job_number/text()]
   
   set prioList [$root selectNodes /job_info/queue_info/job_list/JAT_prio/text()]
   set nameList [$root selectNodes /job_info/queue_info/job_list/JB_name/text()]
   set ownerList [$root selectNodes /job_info/queue_info/job_list/JB_owner/text()]
   set stateList [$root selectNodes /job_info/queue_info/job_list/state/text()]
   set startTimeList [$root selectNodes /job_info/queue_info/job_list/JAT_start_time/text()]
   set queueNameList [$root selectNodes /job_info/queue_info/job_list/queue_name/text()]
   set slotsList [$root selectNodes /job_info/queue_info/job_list/slots/text()]
   set tasksList [$root selectNodes /job_info/queue_info/job_list/tasks/text()]
   set fullJobNameList [$root selectNodes /job_info/queue_info/job_list/full_job_name/text()]

   # create array with xml output for each job
   for {set ind 0} {$ind < 5 } {incr ind 1} {
      set node [lindex $jobNumberList $ind]
      set xml(job$ind,jobNumber) [$node nodeValue]
      set node [lindex $prioList $ind]
      set xml(job$ind,prio) [$node nodeValue]
      set node [lindex $nameList $ind]
      set xml(job$ind,name) [$node nodeValue]
      set node [lindex $ownerList $ind]
      set xml(job$ind,owner) [$node nodeValue]
      set node [lindex $stateList $ind]
      set xml(job$ind,state) [$node nodeValue]
      set node [lindex $startTimeList $ind]
      set xml(job$ind,time) [$node nodeValue]
      set node [lindex $queueNameList $ind]
      set xml(job$ind,queue) [$node nodeValue]
      set node [lindex $slotsList $ind]
      set xml(job$ind,slots) [$node nodeValue]
      set node [lindex $tasksList $ind]
      set xml(job$ind,tasks) [$node nodeValue]
      set node [lindex $fullJobNameList $ind]
      set xml(job$ind,fullName) [$node nodeValue]        
   }
   
}

#****** parser_xml/qstat_r_xml_parse() ******
#
#  NAME
#     qstat_r_xml_parse -- Generate XML output and return assoc array 
#
#  SYNOPSIS
#     qstat_r_xml_parse { output }
#                     -- Generate XML output and return assoc array with
#                        entries jobid, prior, name, owner, state, total_time,
#                        queue, slots, hard resources, and soft resources.
#
#      output  -  asscoc array with the entries mentioned above.#
#                 
#
#  FUNCTION
#     Print out parsed xml output
#
#  INPUTS
#     varialbe into which will be stored the parsed xml array
#
#  NOTES
#     
#
#*******************************
proc qstat_r_xml_parse { output } {
   upvar $output xml
   
   set xmloutput [start_sge_bin "qstat" "-r -xml"]
   set doc [dom parse $xmloutput]
   set root [$doc documentElement]
   
   # parse xml output and create array based on the attributes
   set jobNumber [$root selectNodes /job_info/queue_info/job_list/JB_job_number/text()] 
   set prio [$root selectNodes /job_info/queue_info/job_list/JAT_prio/text()] 
   set name [$root selectNodes /job_info/queue_info/job_list/JB_name/text()] 
   set owner [$root selectNodes /job_info/queue_info/job_list/JB_owner/text()] 
   set state [$root selectNodes /job_info/queue_info/job_list/state/text()] 
   set time [$root selectNodes /job_info/queue_info/job_list/JAT_start_time/text()] 
   set queue [$root selectNodes /job_info/queue_info/job_list/queue_name/text()] 
   set slots [$root selectNodes /job_info/queue_info/job_list/slots/text()] 
   set fullName [$root selectNodes /job_info/queue_info/job_list/full_job_name/text()] 
   set hard [$root selectNodes /job_info/queue_info/job_list/hard_request/text()] 
   set soft [$root selectNodes /job_info/queue_info/job_list/soft_request/text()]
   
   set xml(jobNumber) [$jobNumber nodeValue]
   set xml(prio)  [$prio nodeValue]
   set xml(name) [$name nodeValue]
   set xml(owner) [$owner nodeValue]
   set xml(state) [$state nodeValue]
   set xml(time) [$time nodeValue]
   set xml(queue) [$queue nodeValue]
   set xml(slots) [$slots nodeValue]
   set xml(hard) [[$hard parentNode] getAttribute name]=[$hard nodeValue]
   set xml(soft) [[$soft parentNode] getAttribute name]=[$soft nodeValue]
   
}

proc qstat_j_xml_par { output job_id xmloutput} {
   upvar $output xml
   get_current_cluster_config_array ts_config
      
   set doc [dom parse $xmloutput]
   set root [$doc documentElement]
   
   # parse xml output and create array based on the attributes
   # JB_job_number
   set jobNumber [$root getElementsByTagName JB_job_number]
   foreach elem $jobNumber {
      set xml(job_number) [[$elem firstChild] nodeValue]
   }
   # JB_project
   set project [$root getElementsByTagName JB_project]
   foreach elem $project {
      set xml(project) [[$elem firstChild] nodeValue]
   }
   # JB_exec_file
   set execFile [$root getElementsByTagName JB_exec_file]
   foreach elem $execFile {
      set xml(exec_file) [[$elem firstChild] nodeValue]
   }
   # JB_submission_time
   set subTime [$root getElementsByTagName JB_submission_time]
   foreach elem $subTime {
      set xml(submission_time) [[$elem firstChild] nodeValue]
   }
   # JB_owner
   set owner [$root getElementsByTagName JB_owner]
   foreach elem $owner {
      set xml(owner) [[$elem firstChild] nodeValue]
   }
   # JB_uid
   set uid [$root getElementsByTagName JB_uid]
   foreach elem $uid {
      set xml(uid) [[$elem firstChild] nodeValue]
   }
   # JB_gid
   set gid [$root getElementsByTagName JB_gid]
   foreach elem $gid {
      set xml(gid) [[$elem firstChild] nodeValue]
   }
   # JB_group
   set group [$root getElementsByTagName JB_group]
   foreach elem $group {
      set xml(group) [[$elem firstChild] nodeValue]
   }
   # JB_account
   set account [$root getElementsByTagName JB_account]
   foreach elem $account {
      set xml(account) [[$elem firstChild] nodeValue]
   }
   # JB_merge_stderr
   set merge [$root getElementsByTagName JB_merge_stderr]
   foreach elem $merge {
      if {[string compare [[$elem firstChild] nodeValue] "true"] == 0} {  
         set xml(merge) y
      } else {
         set xml(merge) n
      }
   }
   # JB_notify
   set notify [$root getElementsByTagName JB_notify]
   foreach elem $notify {
      set xml(notify) [string toupper [[$elem firstChild] nodeValue]]
   }
   # JB_job_name
   set jobName [$root getElementsByTagName JB_job_name]
   foreach elem $jobName {
      set xml(job_name) [[$elem firstChild] nodeValue]
   }
   # JB_jobshare
   set jobShare [$root getElementsByTagName JB_jobshare]
   foreach elem $jobShare {
      set xml(jobshare) [[$elem firstChild] nodeValue]
   }
   # JB_env_list
   set envList [$root getElementsByTagName JB_env_list]
   foreach elemin $envList {
      set jobList [$elemin getElementsByTagName job_sublist]
      foreach elem $jobList {
         set var [$elem selectNodes VA_variable/text()]
         set varName [string range [$var nodeValue] 15 [string length [$var nodeValue]]]
         set val [$elem selectNodes VA_value/text()]
         set xml(sge_o[string tolower $varName]) [$val nodeValue]
      }
   }
   # JAT_scaled_usage_list
   set usgList [$root getElementsByTagName JAT_scaled_usage_list]
   foreach usg $usgList {
      set paramList [$usg getElementsByTagName scaled]
      foreach param $paramList {
         set var [$param selectNodes UA_name/text()]
         set val [$param selectNodes UA_value/text()]
         if {[$var nodeValue] == "vmem" || [$var nodeValue] == "maxvmem"} {
            set xml([$var nodeValue]) [format %.3f [expr [$val nodeValue] / 1048576]]M
         } else {
            if {[$var nodeValue] == "cpu"} {
               set xml([$var nodeValue]) "00:00:[format %2.0f [$val nodeValue]]"
            } else {
               set xml([$var nodeValue]) [format %.5f [$val nodeValue]]
            }
         }
         
      }
   }
   # JB_stderr_path_list
   set stderrPath [$root getElementsByTagName JB_stderr_path_list]
   foreach elem $stderrPath {
      set path [$elem getElementsByTagName PN_path]
      set pnHost [$elem getElementsByTagName PN_host]
      set fileHost [$elem getElementsByTagName PN_file_host]
      if {$ts_config(gridengine_version) < 62} {
         set xml(stderr_path_list) [[$path firstChild] nodeValue]
      } else {
         if {[$pnHost hasChildNodes] == 0} {
            set pnHost "NONE"
         } else {
            set pnHost [[$pnHost firstChild] nodeValue]
         }
         if {[$fileHost hasChildNodes] == 0} {
            set fileHost "NONE"
         } else {
            set fileHost [[$fileHost firstChild] nodeValue]
         }
         set xml(stderr_path_list) "$pnHost:$fileHost:[[$path firstChild] nodeValue]"
      }
   }
   # JB_stdout_path_list
   set stdoutPath [$root getElementsByTagName JB_stdout_path_list]
   foreach elem $stdoutPath {
      set path [$elem getElementsByTagName PN_path]
      set pnHost [$elem getElementsByTagName PN_host]
      set fileHost [$elem getElementsByTagName PN_file_host]
      if {$ts_config(gridengine_version) < 62} {
         set xml(stdout_path_list) [[$path firstChild] nodeValue]
      } else {
         if {[$pnHost hasChildNodes] == 0} {
            set pnHost "NONE"
         } else {
            set pnHost [[$pnHost firstChild] nodeValue]
         }
         if {[$fileHost hasChildNodes] == 0} {
            set fileHost "NONE"
         } else {
            set fileHost [[$fileHost firstChild] nodeValue]
         }
         set xml(stdout_path_list) "$pnHost:$fileHost:[[$path firstChild] nodeValue]"
      }      
   }
   # JB_mail_list
   set mailList [$root getElementsByTagName JB_mail_list]
   foreach elem $mailList {
      set user [$elem getElementsByTagName MR_user]
      set host [$elem getElementsByTagName MR_host]
      set xml(mail_list) [[$user firstChild] nodeValue]@[[$host firstChild] nodeValue]
   }
   # JB_shell_list
   set shellList [$root getElementsByTagName JB_shell_list]
   foreach elem $shellList {
      set path [$elem getElementsByTagName PN_path]
      set pnHost [$elem getElementsByTagName PN_host]
      if {$ts_config(gridengine_version) < 62} {
         set xml(shell_list) [[$path firstChild] nodeValue]
      } else {
         if {[$pnHost hasChildNodes] == 0} {
            set pnHost "NONE"
         } else {
            set pnHost [[$pnHost firstChild] nodeValue]
         }
         set xml(shell_list) "$pnHost:[[$path firstChild] nodeValue]"
      }      
   }
   # JB_job_args
   set jobArgs [$root getElementsByTagName JB_job_args]
   foreach elem $jobArgs {
      set name [$elem getElementsByTagName ST_name]
      set xml(job_args) [[$name firstChild] nodeValue]
   }
   # JB_script_file
   set scriptFile [$root getElementsByTagName JB_script_file]
   foreach elem $scriptFile {
      set xml(script_file) [[$elem firstChild] nodeValue]
   }
   # JB_hard_queue_list
   set hardQueue [$root getElementsByTagName JB_hard_queue_list]
   foreach elem $hardQueue {
      set name [$elem getElementsByTagName QR_name]
      set xml(hard_queue_list) [[$name firstChild] nodeValue]
   }
   # JB_soft_queue_list
   set softQueue [$root getElementsByTagName JB_soft_queue_list]
   foreach elem $softQueue {
      set name [$elem getElementsByTagName QR_name]
      set xml(soft_queue_list) [[$name firstChild] nodeValue]
   }
   # JB_hard_resource_list
   set hardRes [$root getElementsByTagName JB_hard_resource_list]
   foreach elem $hardRes {
      set stringVal [$elem getElementsByTagName CE_stringval]
      set name [$elem getElementsByTagName CE_name]
      set hrl "hard resource_list"
      set xml($hrl) "[[$name firstChild] nodeValue]=[[$stringVal firstChild] nodeValue]"
   }
   # JB_soft_resource_list
   set softRes [$root getElementsByTagName JB_soft_resource_list]
   foreach elem $softRes {
      set stringVal [$elem getElementsByTagName CE_stringval]
      set name [$elem getElementsByTagName CE_name]
      set srl "soft resource_list"
      set xml($srl) "[[$name firstChild] nodeValue]=[[$stringVal firstChild] nodeValue]"
   }
   # SME_global_message_list
   set schedInfo [$root getElementsByTagName SME_global_message_list]
   foreach elem $schedInfo {
      set message [$elem getElementsByTagName MES_message]
      set sched "scheduling info"
      set xml($sched) [[$message firstChild] nodeValue]
   }
      
}

