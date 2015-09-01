#!/usr/bin/env perl
use strict;
use warnings;
use Annotator::Report;
use Data::Dumper;
use Getopt::Long;

# Purpose of script is to either
# 1. remove rows from an annotator report file that do not pass entropy filters (default)
# 2. keep all rows except change those rows to unannotated that did not pass entropy filter

my $report;
my $refseqs;
my $returnall = 0;    # default is to filter out rows that do not pass entropy
GetOptions ("report|r=s"  => \$report,
            "returnall|a"    => \$returnall,
#           "refseqs|s=s" => \$refseqs,
            );

#die "Supply report|r FILE and refseqs|s FILE\n" if (!$report || !$refseqs);
die "Supply report|r FILE\n" if (!$report);

my $ar = Annotator::Report->new(report => $report); #, -verbose => 1);

#my $passed = $ar->pass_entropy(refseqs => $refseqs);
my $passed;
if ($returnall) {
  $passed = $ar->pass_entropy(use_report => 1);
}
else {
  $passed = $ar->pass_entropy(use_report => 1, remove => 1);
}


print $_, "\n" foreach (@$passed);

