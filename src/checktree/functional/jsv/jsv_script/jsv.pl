#!/usr/bin/perl

use strict;
use warnings;
no warnings qw/uninitialized/;

use Env qw(SGE_ROOT);
use lib "$SGE_ROOT/util/resources/jsv";
use JSV qw( :DEFAULT send_env log_info );

# my $sge_root = $ENV{SGE_ROOT};
# my $sge_arch = qx{$sge_root/util/arch};

on_start(sub {
   send_env();
});

on_verify(sub {
   my %params = get_param_hash();
   my $do_correct = 0;
   my $do_wait = 0;

   if ($params{b} eq 'y') {
      job_reject('Binary job is rejected.');
      return;
   }

   if ($params{pe_name}) {
      my $slots = $params{pe_slots};

      if (($slots % 16) != 0) {
         job_reject('Parallel job does not request a multiple of 16 slots');
         return;
      }
   }

   if (exists $params{l_hard}) {
      if (exists $params{l_hard}{h_vmem}) {
         sub_del_param('l_hard', 'h_vmem');
         $do_wait = 1;
         if ($params{CONTEXT} eq 'client') {
            log_info('h_vmem as hard resource requirement has been deleted');
         }
      }
      if (exists $params{l_hard}{h_data}) {
         sub_del_param('l_hard', 'h_data');
         $do_correct = 1;
         if ($params{CONTEXT} eq 'client') {
            log_info('h_data as hard resource requirement has been deleted');
         }
      }
   }

   if (exists $params{ac}) {
      if (exists $params{ac}{a}) {
         sub_add_param('ac','a',$params{ac}{a}+1);
      } else {
         sub_add_param('ac','a',1);
      }
      if (exists $params{ac}{b}) {
         sub_del_param('ac','b');
      }
      sub_add_param('ac','c');
   }

   if ($do_wait) {
      job_reject_wait('Job is rejected. It might be submitted later.');
   } elsif ($do_correct) {
      job_correct('Job was modified before it was accepted');
   } else {
      job_accept('Job is accepted');
   }
}); 

main();

