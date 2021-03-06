#!/usr/bin/env perl
use warnings;
use strict;
use SeqUtils;
use Getopt::Long;
use Bio::SeqIO;
use LocalTaxonomy;
use Taxonomy;

my $seqfile;
my $blasttable;
my $algo = "blastx"; my $db = "nr";
my $c_qcov = 13;    # column number for blast table 'qcovs'
my $c_taxid =15;    # column number for blast table 'staxid' 
my $c_king = 16;    # column number for blast table 'sskingdom'
my $c_desc = 17;    # column number for blast table 'stitle'
my $help = 0;

GetOptions ("s|seqfile=s"    => \$seqfile,
            "b|blasttable=s" => \$blasttable,
            "algo=s"         => \$algo,
            "db=s"           => \$db,
            "desc=i"         => \$c_desc,
            "qcov=i"         => \$c_qcov,
            "taxid=i"        => \$c_taxid,
            "kingdom=i"      => \$c_king,
            "help|h"         => \$help,
            );
&usage if ($help);
die "Please supply a sequence file (s|seqfile) and blast table (outfmt 6; b|blasttable)" if (!$seqfile || !$blasttable);

sub usage {
  print <<HEREDOC;

Usage: $0 -s QUERYSEQS -b BLASTTABLE

    Optional args:
        --algo    The BLAST flavor (i.e. blastx, etc...) (default blastx)
        --db      The BLAST database used (default nr)
        --qcov    Column num in table for the 'qcovs' field (default 13)
        --taxid   Column num in table for the 'staxid' field (default 15)
        --kingdom Column num in table for the 'sskingdom' field (default 16)
        --desc    Column num in table for the 'stitle' field (default 17)

    Converts a blast table (outfmt 6) that was created with the outfmt string:
     -outfmt "6 std qcovs qcovhsp staxids sskingdoms stitle"
    to Reann report format.

HEREDOC
exit;
}


my $seqio = Bio::SeqIO->new(-file => $seqfile);
my %seqs;
while (my $seq = $seqio->next_seq()) {
  $seqs{$seq->display_id} = $seq;
}

open (my $table, "<", $blasttable) or die "Can't open $blasttable: $!\n";
my %hits;
while (<$table>) {
  chomp;
  my ($id) = $_ =~ /^(\S+)\t/;
  push (@{$hits{$id}}, $_);
}

my $localTax = LocalTaxonomy->new();
my $VIRUS = 'virus';
foreach my $id (keys %hits) {
  # get the kingdom from the first (best evalue) hit as the default value
  my $type = 'unknown';
  my $hit = @{$hits{$id}}[0]; # the default hit is the first one
  foreach ( @{$hits{$id}} ) {
    if ($_ =~ /phage|marine/i) {
      $type = 'phage';
      $hit = $_;
      last;
    }
    elsif ($_ =~ /virus/i) {
      $type = $VIRUS;
      $hit = $_;
      last;
    }    
  }
  
  # there are 12 standard columns in blast table (outfmt 6)
  my ($id,$acc,$pid,undef,undef,undef,$qs,$qe,$ss,$se,$eval,$bs,@rest) = split (/\t/, $hit);
  if ($type eq 'unknown') {
    $type = $rest[$c_king-13];
  } 
  my $qc    = $rest[$c_qcov-13];
  my $desc  = $rest[$c_desc-13];
  my $taxid = $rest[$c_taxid-13];
  my $sequence = $seqs{$id}->seq;
  my $nsf = has_nsf($sequence);
  my $family = ""; my $species = ""; my $genome = "";
  if ($type eq $VIRUS) {
    my @taxids = split(/;/, $taxid);
    my @lineage = $localTax->get_taxonomy($taxids[0]);
    (undef, $family, $species) = lineage2tfs(join("; ", @lineage));   # lineage2tfs is in Taxonomy
    $genome = get_genome_type($family);
  }
  
  print join ("\t", $id, $sequence, $seqs{$id}->length, $pid, $qc, $eval,
                    $acc, $desc, $type, $family, $species, $genome,
                    $algo, $db, $qs, $qe, $ss, $se, $nsf), "\n";
  delete $seqs{$id};
}


# output the remaining sequences that did not have a hit
foreach my $id (keys %seqs) {
  my $sequence = $seqs{$id}->seq;
  print join ("\t", $id, $sequence, $seqs{$id}->length, ("\t"x14), has_nsf($sequence)), "\n";
}
