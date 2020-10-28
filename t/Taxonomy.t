use strict;
use warnings;
use Test::More tests => 27;


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
is( accession2gi('J02400'), "965480", "SV40 acc2gi - eutils dependency");
is( gi2taxid('965480'), "1891767", "SV40 gi2taxid - eutils dependency");
my $sv40lineage = "Viruses; Monodnaviria; Shotokuvirae; Cossaviricota; Papovaviricetes; Sepolyvirales; Polyomaviridae; Betapolyomavirus; Macaca mulatta polyomavirus 1";
is( gi2lineage('965480'),
	$sv40lineage,
	"SV40 gi2lineage - eutils dependency");
# will work with an acc.ver value as well
is( gi2lineage('J02400.1'),
	$sv40lineage,
	"SV40 gi2lineage (with J02400.1) - eutils dependency");
# will work with protein acc.ver value too
is( gi2lineage('AAB59924.1'),
	$sv40lineage,
	"SV40 gi2lineage (with J02400.1) - eutils dependency");

# Bacterial sequence
# gi|397335222|gb|CP003726.1|     Enterococcus faecalis D32, complete genome      other   NoFamily
$lineage = "cellular organisms; Bacteria; Firmicutes; Bacilli; Lactobacillales; Enterococcaceae; Enterococcus; Enterococcus faecalis; Enterococcus faecalis D32";
($type, $family, $species) = lineage2tfs($lineage);
$genome = get_genome_type($family);

is( $type, "bacteria", "Bacteria type");
is( $family, "NoFamily", "Bacteria family");
is( $species, "Enterococcus faecalis D32", "Bacteria species");
is( $genome, "Unknown", "Bacteria genome");


#
# Bacterial sequences that are really PhiX174
# gi|463121759|gb|APEK01000004.1|   Helicobacter pylori GAMchJs117Ai
$lineage = "cellular organisms; Bacteria; Proteobacteria; delta/epsilon subdivisions; Epsilonproteobacteria; Campylobacterales; Helicobacteraceae; Helicobacter; Helicobacter pylori; Helicobacter pylori GAMchJs117Ai";
($type, $family, $species) = lineage2tfs($lineage);
is( $type, "phage", "Helicobacter pylori GAMchJs117Ai is really a phage");
is( $family, "Microviridae", "Helicobacter pylori GAMchJs117Ai is really a Microviridae");

# gi|463121701|gb|APEJ01000005.1|   Helicobacter pylori GAMchJs114i
$lineage = "cellular organisms; Bacteria; Proteobacteria; delta/epsilon subdivisions; Epsilonproteobacteria; Campylobacterales; Helicobacteraceae; Helicobacter; Helicobacter pylori; Helicobacter pylori GAMchJs114i";
($type, $family, $species) = lineage2tfs($lineage);
is( $type, "phage", "Helicobacter pylori GAMchJs114i is really a phage");
is( $family, "Microviridae", "Helicobacter pylori GAMchJs114i is really a Microviridae");


#
# Archaea testing
# VERSION     AJ299206.1  GI:12666990
$lineage = "cellular organisms; Archaea; Euryarchaeota; Archaeoglobi; Archaeoglobales; Archaeoglobaceae; Ferroglobus; Ferroglobus placidus; Ferroglobus placidus DSM 10642";
($type, $family, $species) = lineage2tfs($lineage);
$genome = get_genome_type($family);

is( $type, "archaea", "Archaea type");
is( $family, "NoFamily", "Archaea family");
is( $species, "Ferroglobus placidus DSM 10642", "Archaea species");
is( $genome, "Unknown", "Archaea genome");


#
# taxid2lineage testing
#
sleep(1);
is( taxid2lineage('10633'),
	$sv40lineage,
	"taxid2lineage tested in scalar context");
my @sv40_expected = ("Viruses", "Monodnaviria", "Shotokuvirae", "Cossaviricota", "Papovaviricetes", "Sepolyvirales", "Polyomaviridae", "Betapolyomavirus", "Macaca mulatta polyomavirus 1");
sleep(1);
my @sv40_test     = taxid2lineage(10633);
is("@sv40_expected", "@sv40_test", "taxid2lineage tested in array context");

is( taxid2lineage(10239), "Viruses", "taxid2lineage tested for empty lineage hash ('Viruses' superkingdom)"); 

is( taxid2lineage(2), "cellular organisms; Bacteria", "taxid2lineage for bacteria taxid 2");

is( taxid2lineage(), undef, "taxid2lineage no arguments returns undef");

#done_testing();



