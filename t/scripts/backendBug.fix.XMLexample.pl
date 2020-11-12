#!/usr/bin/env perl

# for fixing bug in commit 62a6fee3bac3

use strict;
use warnings;
use Taxonomy;
use XML::Simple;
use Data::Dumper;

my $taxid = 7159;
my $lineage = taxid2lineage($taxid);
print $lineage, "\n";

my $badxml = q|<!DOCTYPE TaxaSet PUBLIC "-//NLM//DTD Taxon, 14th January 2002//EN" "http://www.ncbi.nlm.nih.gov/entrez/query/DTD/taxon.dtd">
<TaxaSet> Error occurred: connection-errorRead from backend beTaxonomy_Info failed: timeout. Url : http%3A%2F%2F130.14.18.23%2FTaxonomy%2Fbackend%2Fgettax.cgi%3Fncbi_sid%3D08DD0F4DFC8A9991%255F0034SID%26ncbi_phid%3DCE890B47FC8A938100000000003A951A%26myncbi_id%3D0%26port%3Dlive
</TaxaSet>
|;

if ($badxml =~ /Error occurred/) {
  print "error occurred\n";
}


my $data = XMLin($badxml);
print "\n$data\n";
print Dumper ($data), $/;

$lineage = " Error occurred: connection-errorRead from backend beTaxonomy_Info failed: timeout. Url : http%3A%2F%2F130.14.18.23%2FTaxonomy%2Fbackend%2Fgettax.cgi%3Fncbi_sid%3D08DD0F4DFC8A9991%255F0034SID%26ncbi_phid%3DCE890B47FC8A938100000000003A951A%26myncbi_id%3D0%26port%3Dlive\n";
my ($type, $family, $species);
($type, $family, $species) = lineage2tfs($lineage);
my $genome = get_genome_type($family);    # get genome type for the family (index 1 of

print "type:<$type>\n";
print "fami:<$family>\n";
print "spec:<$species>\n";
print "geno:<$genome>\n";
