use strict;
use warnings;
use Test::More tests => 7;


# Various ways to say "ok"
#         ok($got eq $expected, $test_name);
#         is  ($got, $expected, $test_name);
#         isnt($got, $expected, $test_name);


BEGIN {
	use_ok('Reann');
}


chdir("t");
my $ra = Reann->new( {'config' => 'tag.conf',
        	      'file'    => 'tag-fasta.fa',
                      'folder'  => 'tag-fasta',
		     }
		   );

$ra->run;
is( -d("../tag-fasta"),1, "output directory exists");
is( -s("ann.0.0.tblastx"), 4402, "tblastx output file"); 

$ra->Report;
is( -e("ann.report.txt"),     1, "report file exists");

$ra->Taxonomy;

chdir("..");




$ra = Reann->new( {'config' => 'tag.conf',
                   'file'   => 'tag-fastq.fq',
                   'folder' => 'tag-fastq',
		   'format' => 'fastq',
                  }
                );
$ra->run;
is( -d("../tag-fastq"),   1, "output directory exists");
is( -s("ann.0.0.tblastx"), 4402, "tblastx output file");

$ra->Report;
is( -e("ann.report.txt"),     1, "report file exists");

$ra->Taxonomy;





