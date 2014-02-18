#!/usr/bin/env perl
use strict;
use warnings;
use Annotator::Report;
use Data::Dumper;
use Getopt::Long;

my $report;
my $refseqs;
GetOptions ("report|r=s"  => \$report,
#           "refseqs|s=s" => \$refseqs,
            );

#die "Supply report|r FILE and refseqs|s FILE\n" if (!$report || !$refseqs);
die "Supply report|r FILE\n" if (!$report);

my $ar = Annotator::Report->new(report => $report); #, -verbose => 1);

#my $passed = $ar->pass_entropy(refseqs => $refseqs);
my $passed = $ar->pass_entropy(use_report => 1);

print $_, "\n" foreach (@$passed);

