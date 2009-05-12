# ADOC see sge_procedures/get_sge_error_generic()
proc get_sge_error_generic_vdep {messages_var} {
   upvar $messages_var messages

   # CSP errors
   lappend messages(index) "-100"
   set messages(-100) "*[translate_macro MSG_CL_RETVAL_SSL_COULD_NOT_SET_CA_CHAIN_FILE]*"

   # generic communication errors
   lappend messages(index) "-120"
   set messages(-120) "*[translate_macro MSG_GDI_UNABLE_TO_CONNECT_SUS "qmaster" "*" "*"]*"
   set messages(-120,description) "probably sge_qmaster is down"

   lappend messages(index) "-121"
   set messages(-121) "*[translate_macro MSG_GDI_CANT_SEND_MSG_TO_PORT_ON_HOST_SUSS "qmaster" "*" "*" "*"]*"
   set messages(-121,description) "probably sge_qmaster is down"
}



