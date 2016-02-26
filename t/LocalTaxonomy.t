use strict;
use warnings;
use Test::More; #tests => 4;
use Data::Dumper;

chdir("t/");

BEGIN {
	use_ok('LocalTaxonomy');
}

undef %ENV;
my $lt = LocalTaxonomy->new(gi_taxid_nucl => 'data/gi_taxid_nucl.sv40.hhv5.bin',
                            gi_taxid_prot => 'data/gi_taxid_prot.sv40.hhv5.bin',
                            names         => 'data/names.sv40.hhv5.dmp',
                            nodes         => 'data/nodes.sv40.hhv5.dmp',
                           );
# gitaxidnucl
#14      10359   hhv5 taxid
#15      10633   sv40 taxid
#16      10633   sv40 taxid - duplicate taxid

# gitaxidprot
#44      10359   hhv5 taxid
#45      10633   sv40 taxid
#46      10633   sv40 taxid - duplicate taxid

#
# GIs in local gi_taxid (nucl and prot), names, and nodes
#

# SV40

my $sv40lineage = "Viruses; dsDNA viruses, no RNA stage; Polyomaviridae; Polyomavirus; Simian virus 40";

my ($algo, $gi);
$algo = "BLASTN"; $gi = 15;
my $lineage = $lt->GetLineage($algo, $gi);
is( $lineage, $sv40lineage, "GetLineage $algo hit to SV40 gi $gi (in local bin)" );

$algo = "BLASTN"; $gi = 16;
$lineage = $lt->GetLineage($algo, $gi);
is( $lineage, $sv40lineage, "GetLineage $algo hit to SV40 gi $gi (in local bin)" );

$algo = "BLASTP"; $gi = 45;  # PROTEIN
$lineage = $lt->GetLineage($algo, $gi);
is( $lineage, $sv40lineage, "GetLineage $algo hit to SV40 gi $gi (in local bin)" );

$algo = "BLASTN"; $gi = 15;
$lineage = $lt->GetLineage($algo, $gi);
is( $lineage, $sv40lineage, "GetLineage $algo hit to SV40 gi $gi (in local bin)" );

# CMV - hhv5

$algo = "BLASTX"; $gi = 44;  # PROTEIN
$lineage = $lt->GetLineage($algo, $gi);  # hhv5 taxid 10359
is( $lineage,
    "Viruses; dsDNA viruses, no RNA stage; Herpesvirales; Herpesviridae; Betaherpesvirinae; Cytomegalovirus; Human herpesvirus 5",
    "GetLineage $algo hit to HHV5 gi $gi (in local bin)" );


#
# GIs in local gi_taxid but not in names and nodes
#

$algo = "BLASTP";  $gi = 39;
$lineage = $lt->GetLineage($algo, $gi);
is( $lineage, "", "GetLineage $algo hit to gi $gi (in local bin) but taxid not found in local names and nodes" );


#
# GIs that are NOT in local ncbi taxonomy files
#

$algo = "BLASTN";  $gi = 6;
my $expectedLineage = "cellular organisms; Eukaryota; Opisthokonta; Metazoa; Eumetazoa; Bilateria; Deuterostomia; Chordata; Craniata; Vertebrata; Gnathostomata; Teleostomi; Euteleostomi; Sarcopterygii; Dipnotetrapodomorpha; Tetrapoda; Amniota; Mammalia; Theria; Eutheria; Boreoeutheria; Laurasiatheria; Cetartiodactyla; Ruminantia; Pecora; Bovidae; Bovinae; Bos; Bos taurus";
$lineage = $lt->GetLineage($algo, $gi);
is( $lineage, $expectedLineage, "GetLineage $algo hit to $gi (NOT in local bin)" );

$algo = "BLASTN";  $gi = 6;
$lineage = $lt->GetLineage($algo, $gi);
is( $lineage, $expectedLineage, "GetLineage $algo hit to $gi (NOT in local bin)" );


#print Dumper($lt),"\n";

chdir("..");
done_testing();
