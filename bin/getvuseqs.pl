#!/usr/bin/env perl

# Script will get virus and unassigned sequences from a Annotator report file.

# You can perform entropy filtering on the report file with -t option.  Use
# -a option to recover non-vu seqs that have poor entropy hits (i.e. a
# bacterial hit with poor entropy) as an unannotated sequence

# You can perform blast filtering with -f option.  Blast filtering allows
# you to provide more relaxed settings of Qcov, PID and evalue than what you
# used for the Annotator run in order to eliminate virus and unassigned
# sequences.  These sequences would have gotten a significant hit during the
# BLASTN steps had you used the more relaxed filter settings.  Say for
# instance that you used Qcov = 90%, PID = 80% and Evalue = 1e-5 for the BN
# steps and that you have 20 unassigned sequences.  You notice that 5 of the
# unassigned sequences had a hit to a human sequence in the BLASTN steps
# with a Qcoverage = 70%.  So, by setting qcov = 70 (-q) on command line,
# you can eliminate these unassigned sequences.

use strict;
use warnings;
use Annotator::Blast;
use Getopt::Long;

my ($qc, $pid, $evalue, $report);
my @blast;
my $blastfilter = 0;
my $entropy = 0;
my $returnall = 0;
my $suffix;
my $delim = '|';
GetOptions ("querycoverage|q=s" => \$qc,
            "percentid|p=s"     => \$pid,
            "evalue|e=s"        => \$evalue,
            "blast|b=s@"        => \@blast,
            "blastfilter|f"     => \$blastfilter,
            "report|r=s"        => \$report,
            "returnall|a"       => \$returnall,
            "entropy|t"         => \$entropy,
            "delim=s"           => \$delim,
            "suffix|x=s"        => \$suffix,
            );
die "Please supply report file (report|r)\n" if (!$report);
die "Please supply blast output files (blast|b) since you have specified blastfiltering (-f)\n" if ($blastfilter && !@blast);

my %args;
$args{qc}     = $qc if ($qc);
$args{pid}    = $pid if ($pid);
$args{evalue} = $evalue if ($evalue);

my $ab = Annotator::Blast->new(blast => \@blast);
if ($blastfilter) {
  $ab->runfilter(%args);
}

my $pipe = '';
my $pipe_cut =  "cut -f 1,2,9";
my $pipe_grep = q{grep -P '\tvirus|\t\t'};
if ($entropy) {
  my $a = "";
  if ($returnall) {
    $a = "-a";
  }
  $pipe = "filterentropy.pl -r $report $a | $pipe_grep | $pipe_cut | ";
}
else {
  $pipe = "$pipe_grep $report | $pipe_cut | ";
}

open (my $rpt, $pipe);
while (<$rpt>) {
  chomp;
  my ($id, $seq, $type) = split (/\t/, $_);
  
  if ($blastfilter && $type eq '') {
    next if $ab->passfilter($id);      # skip over those unassigned sequences that would pass the filter criteria
  }
  
  my $mm = '';
  if ($suffix) {
    $mm = $delim . $suffix;
  } 
  print ">$id$mm\n$seq\n"; 
}
