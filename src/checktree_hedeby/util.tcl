

#****** util/do_ssh_login() ****************************************************
#  NAME
#     do_ssh_login() -- do ssl login on open spawn id
#
#  SYNOPSIS
#     do_ssh_login { spawn_id user host } 
#
#  FUNCTION
#     This procedure is used to login via ssh
#
#  INPUTS
#     spawn_id - spawn id of open spawn process
#     user     - user name for haithabu_passwd array
#     host     - host name for haithabu_passwd array
#
#  RESULT
#     0 on success 
#
#  EXAMPLE
#
#   set id [open_remote_spawn_process "$CHECK_HOST" "$CHECK_USER" "ssh" "$haithabu_config(n1sm_user)@$haithabu_config(n1sm_host)" ]
#   set sp_id [ lindex $id 1 ]
#
#   set exit_state [do_ssh_login sp_id "n1sm_user" "n1sm_host"]
#   
#   if { $exit_state == 0 } {
#      send -i $sp_id -- "exit\n"
#
#      expect {
#         -i $sp_id "_exit_status_:*\n" {
#                set exit_state [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]
#                puts $CHECK_OUTPUT "exit state is: \"$exit_state\""
#            }
#      }
#   }
#   close_spawn_process $id
#
#
#  NOTES
#     very specific haithabu function
#
#  SEE ALSO
#      util/do_ssh_login()
#      util/do_sftp_login()
#*******************************************************************************
proc do_ssh_login { spawn_id user host } {
   global haithabu_config CHECK_OUTPUT
   global haithabu_passwd CHECK_HOST CHECK_USER CHECK_SHELL_PROMPT

   upvar sp_id $spawn_id

   # set id [open_remote_spawn_process "$CHECK_HOST" "$CHECK_USER" "ssh" "$haithabu_config(n1sm_user)@$haithabu_config(n1sm_host)" ]
   set exit_state 1
   log_user 1

   set exit_state -1
   expect {
         -i $sp_id full_buffer { 
            add_proc_error "haithabu_get_required_passwords" -1 "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
         }

         -i $sp_id timeout {
            add_proc_error "haithabu_get_required_passwords" -1 "unexpected timeout"
         } 
         -i $sp_id eof {
            add_proc_error "haithabu_get_required_passwords" -1 "unexpected eof"
         } 
         -i $sp_id "_exit_status_:*\n" {
            set exit_state [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]
            puts $CHECK_OUTPUT "exit state is: \"$exit_state\""
            puts $CHECK_OUTPUT "process should not have finished here"

         }
         -i $sp_id "password:" {
            log_user 0
            send -i $sp_id -- "$haithabu_passwd($haithabu_config($user),$haithabu_config($host))\n"
            log_user 1
            puts $CHECK_OUTPUT "password send"
         } 
   }

   set timeout 1
   set nr_of_timeouts 0
   expect {
         -i $sp_id "$haithabu_config($user)*gid" {
            puts $CHECK_OUTPUT "got user name"
            set exit_state 0
         }
         -i $sp_id timeout {
            puts $CHECK_OUTPUT "sending id command ..."
            send -i $sp_id -- "id\n"
            incr nr_of_timeouts 1
            if { $nr_of_timeouts > 15 } {
               add_proc_error "haithabu_get_required_passwords" -1 "unexpected timeout"
               break
            }
            exp_continue
         } 
   }

#   close_spawn_process $id
   return $exit_state
}

proc do_sftp_login { spawn_id user host } {
   global haithabu_config CHECK_OUTPUT
   global haithabu_passwd CHECK_HOST CHECK_USER CHECK_SHELL_PROMPT

   upvar sp_id $spawn_id

   # set id [open_remote_spawn_process "$CHECK_HOST" "$CHECK_USER" "ssh" "$haithabu_config(n1sm_user)@$haithabu_config(n1sm_host)" ]
   set exit_state 1
   log_user 1

   set exit_state -1
   expect {
         -i $sp_id full_buffer { 
            add_proc_error "haithabu_get_required_passwords" -1 "buffer overflow please increment CHECK_EXPECT_MATCH_MAX_BUFFER value"
         }

         -i $sp_id timeout {
            add_proc_error "haithabu_get_required_passwords" -1 "unexpected timeout"
         } 
         -i $sp_id eof {
            add_proc_error "haithabu_get_required_passwords" -1 "unexpected eof"
         } 
         -i $sp_id "_exit_status_:*\n" {
            set exit_state [get_string_value_between "_exit_status_:(" ")" $expect_out(0,string)]
            puts $CHECK_OUTPUT "exit state is: \"$exit_state\""
            puts $CHECK_OUTPUT "process should not have finished here"

         }
         -i $sp_id "password:" {
            log_user 0
            send -i $sp_id -- "$haithabu_passwd($haithabu_config($user),$haithabu_config($host))\n"
            log_user 1
            puts $CHECK_OUTPUT "password send"
         } 
   }

   expect {
         -i $sp_id "sftp>" {
            puts $CHECK_OUTPUT "got shell prompt"
            set exit_state 0
         }
         -i $sp_id timeout {
            add_proc_error "haithabu_get_required_passwords" -1 "unexpected timeout"
         } 
   }


#   close_spawn_process $id
   return $exit_state
}


