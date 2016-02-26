use strict;
use warnings;
use Test::More; # tests => 12;
use File::Copy;

chdir ("t/Report/");

# Various ways to say "ok"
#         ok($got eq $expected, $test_name);
#         is  ($got, $expected, $test_name);
#         isnt($got, $expected, $test_name);


BEGIN {
  use_ok('Annotator::Report');
}

my $refseqs = {"viral.1.protein"   => "$ENV{BLASTDB}/viral.1.protein.faa",
                 "viral.1.1.genomic" => "$ENV{BLASTDB}/viral.1.1.genomic.fna"};

my $ar = Annotator::Report->new(report => "report.wTax.tsv",
                                refseqs => $refseqs,);
my $tmp = $ar->run_entropy;
my $gotHash = `sha1sum $tmp | cut -f 1 -d ' '`;
my $expectHash = `sha1sum report.wTax.BE.tsv| cut -f 1 -d ' '`;
is( $gotHash, $expectHash, "Entropy added to report.wTax.tsv");


TODO: {
	todo_skip "To lazy right to write pass_entropy tests", 2;

	my $ar2 = Annotator::Report->new(report => "NEED REPORT");

	my $expected = "";
  	my $got_noremove = $ar2->pass_entropy(use_report => 1);
	is ($got_noremove, $expected, "pass_entropy without remove option");

 	my $got_withremove = $ar2->pass_entropy(use_report => 1, remove => 1);
	is ($got_withremove, $expected, "pass_entropy with remove option");
}



chdir ("../..");
done_testing();
