#!/usr/bin/env perl
use strict;
use warnings;
use Bio::LITE::Taxonomy::NCBI::Gi2taxid qw/new_dict/;
use Getopt::Long;

my $force = 0;
GetOptions ("force|f" => \$force) or exit;

print "Version of Gi2taxid module: ", $Bio::LITE::Taxonomy::NCBI::Gi2taxid::VERSION, $/;

my $prot = "gi_taxid_nucl.sv40.hhv5";
if ( ! -e $prot || (-e $prot && $force)) {
   print "Making prot.bin...";
   new_dict (in => $prot . ".dmp",
            out => $prot . ".bin", chunk_size => 15);
   print "done\n";
}

my $nucl = "gi_taxid_prot.sv40.hhv5";
if ( ! -e $nucl || (-e $nucl && $force)) {
   print "Making nucl.bin...";
   new_dict (in => $nucl . ".dmp",
            out => $nucl . ".bin", chunk_size => 15);
   print "done\n";
}
