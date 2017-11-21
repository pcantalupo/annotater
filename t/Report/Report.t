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

my $refseqs = {"viral.1.1.genomic" => "report.wTax.seqs_from_vrs.fa"};

my $ar = Annotator::Report->new(report => "report.wTax.tsv",
                                refseqs => $refseqs,);
my $tmp = $ar->run_entropy;
my $gotHash = `shasum $tmp | cut -f 1 -d ' '`;
my $expectHash = `shasum report.wTax.BE.tsv| cut -f 1 -d ' '`;
is( $gotHash, $expectHash, "Entropy added to report.wTax.tsv");


# Test Baculo filter

my $tmpfile = "tmp.baculo.tsv";

# 3 hits to baculo - all are to the same subject sequence
my $reportBE = "report.wTax.BE.Baculo1";
my $reportfile = $reportBE . ".tsv";
my $ar_baculo = Annotator::Report->new(report => $reportfile);
my $pass = $ar_baculo->pass_filters( use_report => 1 );
open (my $out1, ">", $tmpfile);
print $out1 join("\n", @{$pass}),$/;
close ($out1);
is( `shasum $tmpfile | cut -f 1 -d ' '`,
    `shasum "$reportBE.expected.tsv" | cut -f 1 -d ' '`,
    "Baculo test1 OK");
unlink $tmpfile;

# 3 hits to baculo - 2 are same subject and 1 is different
$reportBE = "report.wTax.BE.Baculo2";
$reportfile = $reportBE . ".tsv";
$ar_baculo = Annotator::Report->new(report => $reportfile);
$pass = $ar_baculo->pass_filters( use_report => 1 );
open (my $out2, ">", $tmpfile);
print $out2 join("\n", @{$pass}),$/;
close ($out2);
is( `shasum $tmpfile | cut -f 1 -d ' '`,
    `shasum "$reportBE.expected.tsv" | cut -f 1 -d ' '`,
    "Baculo test2 OK");
unlink $tmpfile;



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
