use strict;
use warnings;
use Test::More tests => 4;


BEGIN {
	use_ok('LocalTaxonomy');
}

my $lt = LocalTaxonomy->new;


# SV40 genome (use acc2tax.pl J02400 to get information directlty from NCBI)
my $algo  = "BLASTN";
my $gi    = "965480";
my $acc   = "J02400";
my $taxid = "10633";
my $lineage = $lt->GetLineage($algo, $gi);
is( $lineage,
	"Viruses; dsDNA viruses, no RNA stage; Polyomaviridae; Polyomavirus; Simian virus 40",
	"lineage string for SV40 genome (gi 965480)"
	);


# Bacteria testing
# gi|397335222|gb|CP003726.1|     Enterococcus faecalis D32, complete genome      other   NoFamily

$algo = "BLASTX";
$gi   = "397335222";
$lineage = $lt->GetLineage($algo, $gi);
is( $lineage,
	"cellular organisms; Bacteria; Firmicutes; Bacilli; Lactobacillales; Enterococcaceae; Enterococcus; Enterococcus faecalis; Enterococcus faecalis D32",
	"lineage string for Bacteria");


# Archaea testing
# AJ299206.1  GI:12666990)
$algo = "BLASTN";
$gi   = "12666990";
$lineage = $lt->GetLineage($algo,$gi);
is( $lineage,
	"cellular organisms; Archaea; Euryarchaeota; Archaeoglobi; Archaeoglobales; Archaeoglobaceae; Ferroglobus; Ferroglobus placidus; Ferroglobus placidus DSM 10642",
	"lineage string for Archaea");

