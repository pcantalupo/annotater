#!/usr/bin/env perl
use strict;
use warnings;
use SeqUtils;

my $header = <>;
print $header;

while (<>) {
  chomp;
  my @fields = split (/\t/, $_);
  
  my $is_nsf = has_nsf($fields[1]);

  print $_, "\t", $is_nsf, "\n";
}

