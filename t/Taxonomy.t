use strict;
use warnings;
use Test::More tests => 17;


BEGIN {
	use_ok('Taxonomy');
}


# SV40 genome
my $lineage = "Viruses; dsDNA viruses, no RNA stage; Polyomaviridae; Polyomavirus; Simian virus 40";
my ($type, $family, $species) = lineage2tfs($lineage);
my $genome = get_genome_type($family);

is( $type, "virus", "SV40 type");
is( $family, "Polyomaviridae", "SV40 family");
is( $species, "Simian virus 40", "SV40 species");
is( $genome, "dsDNA,circular,nonsegmented", "SV40 genome");

is( accession2gi('J02400'), "965480", "acc2gi - eutils dependency");
is( gi2taxid('965480'), "10633", "gi2taxid - eutils dependency");
is( taxid2lineage('10633'),
	"Viruses; dsDNA viruses, no RNA stage; Polyomaviridae; Polyomavirus; Simian virus 40",
	"taxid2lineage - eutils dependency");
is( gi2lineage('965480'),
	"Viruses; dsDNA viruses, no RNA stage; Polyomaviridae; Polyomavirus; Simian virus 40",
	"gi2lineage - eutils dependency");

 
# Bacterial sequence
# gi|397335222|gb|CP003726.1|     Enterococcus faecalis D32, complete genome      other   NoFamily
$lineage = "cellular organisms; Bacteria; Firmicutes; Bacilli; Lactobacillales; Enterococcaceae; Enterococcus; Enterococcus faecalis; Enterococcus faecalis D32";
($type, $family, $species) = lineage2tfs($lineage);
$genome = get_genome_type($family);

is( $type, "bacteria", "Bacteria type");
is( $family, "NoFamily", "Bacteria family");
is( $species, "Enterococcus faecalis D32", "Bacteria species");
is( $genome, "Unknown", "Bacteria genome");


# Archaea testing
# VERSION     AJ299206.1  GI:12666990
$lineage = "cellular organisms; Archaea; Euryarchaeota; Archaeoglobi; Archaeoglobales; Archaeoglobaceae; Ferroglobus; Ferroglobus placidus; Ferroglobus placidus DSM 10642";
($type, $family, $species) = lineage2tfs($lineage);
$genome = get_genome_type($family);

is( $type, "archaea", "Archaea type");
is( $family, "NoFamily", "Archaea family");
is( $species, "Ferroglobus placidus DSM 10642", "Archaea species");
is( $genome, "Unknown", "Archaea genome");







