#!/usr/bin/perl

use strict;
use warnings;
no warnings qw/uninitialized/;

use Env qw(SGE_ROOT);
use lib "$SGE_ROOT/util/resources/jsv";
use JSV qw( :DEFAULT jsv_send_env jsv_log_info);

jsv_on_start(sub {
   jsv_send_env();
});

jsv_on_verify(sub {
   my %params = jsv_get_param_hash();
   my %evs = jsv_get_env_hash();
   my $do_correct = 0;
   my $do_wait = 0;

   if ($params{b} eq 'y') {
      jsv_reject('Binary job is rejected.');
      return;
   }

   if ($params{pe_name}) {
      my $slots = $params{pe_slots};

      if (($slots % 16) != 0) {
         jsv_reject('Parallel job does not request a multiple of 16 slots');
         return;
      }
   }

   if (exists $params{l_hard}) {
      if (exists $params{l_hard}{h_vmem}) {
         jsv_sub_del_param('l_hard', 'h_vmem');
         $do_wait = 1;
         if ($params{CONTEXT} eq 'client') {
            jsv_log_info('h_vmem as hard resource requirement has been deleted');
         }
      }
      if (exists $params{l_hard}{h_data}) {
         jsv_sub_del_param('l_hard', 'h_data');
         $do_correct = 1;
         if ($params{CONTEXT} eq 'client') {
            jsv_log_info('h_data as hard resource requirement has been deleted');
         }
      }
   }

   if (exists $params{ac}) {
      if (exists $params{ac}{a}) {
         jsv_sub_add_param('ac','a',$params{ac}{a}+1);
      } else {
         jsv_sub_add_param('ac','a',1);
      }
      if (exists $params{ac}{b}) {
         jsv_sub_del_param('ac','b');
      }
      jsv_sub_add_param('ac','c');
   }

   if (exists $evs{X}) {
      if ($evs{X} eq 'a\\tb\\nc\\td') {
         jsv_add_env('ENV_RESULT','TRUE')
      }
   }

   if (exists $evs{Y}) {
      if ($evs{Y} eq '1') {
         jsv_mod_env('ENV_RESULT','TRUE')
      }
   }

   if (exists $evs{Z}) {
      if ($evs{Z} eq '1') {
         jsv_del_env('Z')
      }
   }

   if ($do_wait) {
      jsv_reject_wait('Job is rejected. It might be submitted later.');
   } elsif ($do_correct) {
      jsv_correct('Job was modified before it was accepted');
   } else {
      jsv_accept('Job is accepted');
   }
}); 

jsv_main();

