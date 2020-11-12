#!/usr/bin/env perl
use strict;
use warnings;


# for fixing backend beTaxonomy errors in report files
#    see commit 62a6fee3bac3fa3e in 'annotator' repository

# usage $0 ann.wTax.report.txt
#       $0 ann.wTax.BE.report.txt


while (<>) {
  my $line = $_;
  chomp $line;

  if (/backend beTaxonomy/) {
    my @fields = split (/\t/, $line);
    
    my $next = <>;
    chomp $next;
    
    my @genomefields = (split /\t/, $next)[1..8];
    
    #$line = join("\t", @fields[0..10], @genomefields, @fields[11..14]);
  
    $line = join("\t", @fields[0..10], @genomefields);   # ann.wTax.report.tsv
    
    if (defined $fields[11]) {   # ann.wTax.BE.report.tsv
      $line = join("\t", $line, @fields[11..14]);
    }
  }
  
  print $line,$/;
}


