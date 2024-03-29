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
  PREREQ_PM => {
    "XML::Simple" => '2.20',
    "BioPerl" => 0,
    "Bio::DB::EUtilities" => 0,
  },

  PMLIBDIRS => ['Annotator'],
  EXE_FILES => [qw( ./Reann.pl bin/add_nsf_field.pl bin/annotator.job
                     bin/annotator.slurm.job bin/blastentropy.pl bin/blasttable2report.pl
                     bin/filterentropy.pl bin/gethits.pl bin/getvuseqs.pl )
                ],
  test => {TESTS => 't/*.t t/Report/*.t'}
);
