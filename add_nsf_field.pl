#!/usr/bin/env perl
use strict;
use warnings;
use SeqUtils;
use Getopt::Long;

my $header = 0;
GetOptions("header|h" => \$header,
          );

if ($header) {
  my $h = <>;
  print $h;
}

while (<>) {
  chomp;
  my @fields = split (/\t/, $_);
  
  my $is_nsf = has_nsf($fields[1]);

  print $_, "\t", $is_nsf, "\n";
}

