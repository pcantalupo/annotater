use strict;
use warnings;
use File::Path qw(make_path remove_tree);
#use Test::File;
use Test::More  tests => 12;


# Various ways to say "ok"
#         ok($got eq $expected, $test_name);
#         is  ($got, $expected, $test_name);
#         isnt($got, $expected, $test_name);


BEGIN {
	use_ok('Reann');
}

chdir("t");    # enter the Test directory

####################
#
# JOSH DEFAULT TEST
#
#
remove_tree("annotator");

my $ra = Reann->new( { 'chunk' => 10, });
$ra->run;
is( -d("../annotator"), 1,        "Default test - directory 'annotator' exists");

my $size = -s("ann.0.0.tblastx");
ok( $size > 0, "Default test - tblastx file size: $size");

$ra->Report;
is( -e("ann.report.txt"),     1,  "Default test - report file");

chdir("..");


####################
# TAG FASTA
#
remove_tree("tag-fasta");
$ra = Reann->new( {     'config' => 'tag.conf',
			'file'   => 'tag-fasta.fa',
			'folder' => 'tag-fasta',
			'format' => 'fasta',
			'evalue' => '1e-5',
			'tax'	 => 1,
			'remotetax' => 1,
			}
		);
$ra->run;
$size = -s("ann.0.0.tblastx");
ok( $size > 575 && $size < 625,      "TAGFASTA: tblastx output file size: $size");

$ra->Report;
is( -e("ann.report.txt"),     1,       "TAGFASTA: report file exists");

$ra->Taxonomy;
$size = -s("ann.wTax.report.txt");
ok( $size > 525 && $size < 535, "TAGFASTA: taxonomy report file size: $size");

$ra->add_entropy;
$size = -s("ann.wTax.BE.report.txt");
ok( $size > 570 && $size < 580, "TAGFASTA: taxonomy BE report file size: $size");
chdir("..");



##########################################################################
# Test for when sequence file and config file are not in current directory
#
mkdir("diffdir");
chdir("diffdir");
remove_tree("diffdir-tag-fastq");
my $conf = "my.conf";
open (my $out, ">", $conf);
print $out "-exec tblastx -db ../../data/tag-fasta\n";
close ($out);
$ra = Reann->new( {	'config' => $conf,
                   	'file'   => '../tag-fastq.fq',
                  	'folder' => 'diffdir-tag-fastq',
                   	'format' => 'fastq',
                        'evalue' => '1e-5',
			'report_all' => 1,
                  }
                );
$ra->run;
is( -d("../diffdir-tag-fastq"),   1, "DIFFDIR: output directory 'diffdir' exists");
$size = -s("ann.0.0.tblastx");
ok( $size > 0, "DIFFDIR: tblastx output file size OK: $size");

$ra->Report;
is( -e("ann.report.txt"),     1,     "DIFFDIR: report file (with all hits) exists");
$size = -s("ann.report.txt");
ok( $size > 0, "DIFFDIR: report file (with all hits) size: $size");
chdir("../../");    # move up to t/ directory


#done_testing();
