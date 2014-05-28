use strict;
use warnings;
use File::Path qw(make_path remove_tree);
use Test::More; # tests => 12;


# Various ways to say "ok"
#         ok($got eq $expected, $test_name);
#         is  ($got, $expected, $test_name);
#         isnt($got, $expected, $test_name);


BEGIN {
	use_ok('Annotator::Report');
        use_ok('Reann');
}

# this code is not working
my $ra = Reann->new( {'config' => 'annot.conf', 'file' => 'dummy.fa',
			'taxout' => 'ann.wTax.report.txt'} );
$ra->add_entropy();
my $outputfile = "ann.wTax.BE.report.txt";
unlink ($outputfile);
my $size = -s("ann.wTax.BE.report.txt");
ok( $size == 435414, "size of BE report file is OK"); 
unlink ($outputfile);

done_testing();
