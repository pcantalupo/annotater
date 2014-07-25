use strict;
use warnings;
use File::Path qw(make_path remove_tree);
use Test::File;
use Test::More  tests => 13;


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
ok( $size > 8300 && $size < 8310, "Default test - tblastx file size"); 

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
ok( $size > 4395 && $size < 4406,      "TAGFASTA: tblastx output file size");

$ra->Report;
is( -e("ann.report.txt"),     1,       "TAGFASTA: report file exists");

$ra->Taxonomy;
is( -s("ann.wTax.report.txt"),   551,  "TAGFASTA: taxonomy report file size");

$ra->add_entropy;
is( -s("ann.wTax.BE.report.txt"), 595, "TAGFASTA: taxonomy BE report file size");
chdir("..");


####################
# TAG FASTQ
#
remove_tree("tag-fastq");
$ra = Reann->new( {'config' => 'tag.conf',
                   'file'   => 'tag-fastq.fq',
                   'folder' => 'tag-fastq',
		   'format' => 'fastq',
			'evalue' => '1e-5',
                  }
                );
$ra->run;
$size = -s("ann.0.0.tblastx");
ok( $size > 4395 && $size < 4406,      "TAG FASTQ: tblastx output file size");
chdir("..");



##########################################################################
# Test for when sequence file and config file are not in current directory
#
mkdir("diffdir");
chdir("diffdir");
remove_tree("diffdir-tag-fastq");
$ra = Reann->new( {	'config' => '../tag.conf',
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
ok( $size > 4395 && $size < 4406,    "DIFFDIR: tblastx output file size OK");

$ra->Report;
is( -e("ann.report.txt"),     1,     "DIFFDIR: report file (with all hits) exists");
is( -s("ann.report.txt"),  5555,     "DIFFDIR: report file (with all hits) size");
chdir("../../");    # move up to t/ directory


#done_testing();
