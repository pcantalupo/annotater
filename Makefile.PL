use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => "Reann",
  LICENSE => "MIT",
  MIN_PERL_VERSION => "5.010",
  CONFIGURE_REQUIRES => {
    "ExtUtils::MakeMaker" => 0
  },
  BUILD_REQUIRES => {
    "Test::File" => 0,
    "Bio::LITE::Taxonomy::NCBI::Gi2taxid" => '0.13',
  },
  PREREQ_PM => {
    "XML::Simple" => '2.22',
    "Bio::LITE::Taxonomy" => '0.07',
    "Bio::LITE::Taxonomy::NCBI" => '0.1',
    "Bio::Perl" => 0,
    "Bio::DB::EUtilities" => 0,
  },

  PMLIBDIRS => ['Annotator'],
  EXE_FILES => [qw( ./Reann.pl bin/add_nsf_field.pl bin/annotator.job
                     bin/annotator.slurm.job bin/blastentropy.pl bin/blasttable2report.pl
                     bin/filterentropy.pl bin/gethits.pl bin/getvuseqs.pl )
                ],
#  test => {TESTS => 't/*.t t/Report/*.t'}
);
