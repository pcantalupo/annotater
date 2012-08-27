use strict;
use warnings;
use Getopt::Long;
use Reann;

my %h = ("num_threads",4,
		"folder","annotator",
		"outfmt",6,
		"restart",'restart.txt',
		"file","test.fa",
		"config","reann.config.txt");

my $r = GetOptions(\%h,qw(qc=i pid=i e=i num_threads=i folder=s)); 

my $run = new Reann(\%h);
$run->run;
$run->Report;


=cut

Define all global parameters:
	-num_threads - default:4 if set 
	-outfmt - default:6 defines outfmt of blast programs
	-folder defualt:annotator defined output folder

=cut