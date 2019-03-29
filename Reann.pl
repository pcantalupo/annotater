#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Reann;

$| = 1;

my $h = {};
my @keys = qw(  qc=f pid=f evalue=f num_threads=i
		folder=s file=s output=s chunk=i
		delim=s config=s outfmt=i
		prefix=s format=s outfmt_str=s tax report_all remotetax);
GetOptions($h,@keys) or exit;

my $run = new Reann($h);
$run->run;
$run->Report;
$run->Taxonomy;
$run->add_entropy;


=pod

=head1 Reann.pl
Perl pipline for blast annotation of sequences

=head1 Command Line Parameters
=head2 Required
	-file - the input sequence file
	-config - the file defining your blast pipeline
	-format - format of sequence file

=head2 Optional
	-coverage - set default query coverage for filter
	-evalue - set default evalue for filter
	-pid - set default percent identity for filter
	-chunk - default:0 number of sequences per file
	-delim - delimiter for report table
	-prefix - default:ann string to be added at begining of blast and sequence files
	-output - default:output.txt name of the final report 
	-num_threads - default:4 sets num_threads for the blast commands 
	-outfmt - default:6 defines outfmt of blast programs
	-outfmt_str - defines extra columns to add to outfmt (not operational)
	-folder defualt:annotator defined output folder
	-restart default restart.txt defines name of restart file

=cut
