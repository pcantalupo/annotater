#!/usr/bin/perl -w

use strict;
use LocalTaxonomy;
use Taxonomy;

my $lt = new LocalTaxonomy;

my ($type, $family, $species, $genome);

while (<>) {
  next if /^#/;
  
  chomp;
  
  # $t can be 'nucleotide' or 'protein'
  #          OR it can be a blast algorithm name like 'blastn', 'blastp', etc...
  my ($gi, $t) = split /\t/;         # change this to just 'split' for testing <DATA>
  
  my $lineage = $lt->GetLineage($t, $gi);

  $type = "";
  $family = "";
  $species = "";
  $genome = "";
  
  if ($lineage eq "") {
    print STDERR "Can't get taxonomy from local database...attempting to get it remotely from NCBI\n";
    
    $lineage = gi2lineage($gi);
    
    unless ($lineage) {
      print STDERR "Can't get lineage from $gi\n";
      next;
    }
    
    sleep 1;   # or sleep 10;    
  } 

  ($type, $family, $species) = lineage2tfs($lineage);
  $genome = get_genome_type($family);    # get genome type for the family (index 1 of array)
  
  print $gi, "\t",
        $type, "\t",
        $family, "\t",
        $species, "\t",
        $genome, "\t",
        $lineage, "\n";
}


__DATA__
9628421 BLASTN SV40 genome (nucleotide seq)
297591899 BLASTX SV40 agnoprotein (protein seq)
#gi|149931032|gb|CP000139.1|  BLASTN  bacterial com.genome (nucleotide)
#gi|149931032 BLASTN  bacterial com.genome (nucleotide)
149931032 BLASTN bacterial com.genome (nucleotide)
