use strict;
use warnings;
use File::Path qw(make_path remove_tree);
use Test::More tests => 11;


# Various ways to say "ok"
#         ok($got eq $expected, $test_name);
#         is  ($got, $expected, $test_name);
#         isnt($got, $expected, $test_name);


BEGIN {
	use_ok('Reann');
}

chdir("t");    # enter the Test directory

#
# JOSH DEFAULT TEST
#
remove_tree("annotator");
my $ra = Reann->new( { 'chunk' => 10,
		     }
		   );
$ra->run;
is( -d("../annotator"),1, "output dir 'annotator' exists");
is( -s("ann.0.0.tblastx"), 8306, "tblastx output file size OK"); 

$ra->Report;
is( -e("ann.report.txt"),     1, "report file exists");

chdir("..");


#
# TAG FASTA
#
remove_tree("tag-fasta");
$ra = Reann->new( {     'config' => 'tag.conf',
			'file'   => 'tag-fasta.fa',
			'folder' => 'tag-fasta',
			'format' => 'fasta',
			'evalue' => '1e-5',
			'tax'	 => 1,
			}
		);
$ra->run;
is( -s("ann.0.0.tblastx"), 4402, "tblastx output file size OK");

$ra->Report;
is( -e("ann.report.txt"),     1, "report file exists");

#$ra->Taxonomy;
#is( -s("ann.report.txt"),   545, "taxonomy report file size OK");
chdir("..");			


#
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
is( -s("ann.0.0.tblastx"), 4402, "tblastx output file size OK");
chdir("..");



#
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
is( -d("../diffdir-tag-fastq"),   1, "output directory 'diffdir' exists");
is( -s("ann.0.0.tblastx"),     4402, "tblastx output file size OK");

$ra->Report;
is( -e("ann.report.txt"),     1, "report file (with all hits) exists");
is( -s("ann.report.txt"),  3695, "report file (with all hits) size");
chdir("../../");    # move up to t/ directory

