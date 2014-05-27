#!/usr/bin/env perl
use strict;
use warnings;
use diagnostics;
use SeqUtils;
use Getopt::Long;
use Bio::Seq;
use Segmasker;

# This script adds 4 columns to Annotator report file.
# qent     - entropy of the query sequence
# qhsp_ent - entropy of the query HSP sequence
# shsp_ent - entropy of the subject HSP sequence (only calculated for sequences found in viral.1.1.genomic.fna)
# shsp_%lc - percent of low complexity (as determined by 'segmasker') residues in subject HSP sequence (only calculated for sequences found in viral.1.1.genomic.fna)

my $refseqs;
my $header  = 0;
my $increase_field_index = 0;
GetOptions ('file|f=s%'      => \$refseqs,
            'header|h'      => \$header,
            'increase|i=i' => \$increase_field_index,
          ) or &usage;
foreach my $algo (keys %$refseqs) {
  &usage if (!$refseqs->{$algo} || !-e $refseqs->{$algo});
}
my ($seq_col, $subjid_col, $db_col, $qs_col, $qe_col, $ss_col, $se_col) =
      map { $_ + $increase_field_index } (2,7,14,15,16,17,18);

sub usage {

  my $output=<<HEREDOC;

$0 -f BLASTDB=FILE [-f ...] [-h -i]

  -f BLASTDB=FILE Specify fasta file for each blast database in the algorithm field. Format is:
                  -f viral.1.1.genomic=/PATH/TO/SEQS.fna -f viral.1.protein=/PATH/TO/SEQS.faa
  -h              The first row is the column names (default: no)
  -i INT          Number of non-Annotator columns at the beginning of the file. This might occur if
                  you inserted an analysisID or other metagenome identifier in the first column. Therefore,
                  you would need to add '-i 1' to command line. This will increase the field indexes by 1

  
HEREDOC
  print $output;
  exit;
}


while (<>) {
  chomp;
  print ($_ . "\tqent\tqhsp_ent\tshsp_ent\tshsp_%lc\n") && next if ($. == 1 && $header);
  my @F = split(/\t/, $_, -1);
  my $sequence = $F[$seq_col-1];
  my $subjid   = $F[$subjid_col-1];
  my ($qs, $qe, $ss, $se) = @F[($qs_col-1, $qe_col-1, $ss_col-1, $se_col-1)];
  
  # Query_hsp entropy
  my $qhsp_ent = -1;
  if ($qs && $qe) {
    my $s = ($qs, $qe)[$qs >  $qe];
    my $e = ($qs, $qe)[$qs <= $qe];
    $qhsp_ent = entropy( substr($sequence,$s-1,$e-$s+1) );
  }

  # Subject_hsp entropy
  my $shsp_ent = -1;
  my $shsp_perlc = -1;

  foreach my $algo (keys %$refseqs) {
    if ($algo eq $F[$db_col-1]) { # only going to get SubHSP_entropy for sequences provided by user
      my $s = ($ss, $se)[$ss >  $se];
      my $e = ($ss, $se)[$ss <= $se];

      my $tmp = faidxsubstr($refseqs->{$algo}, $subjid, $s, $e);
      $tmp =~ s/^>.+?\n//;
      $tmp =~ s/\n//g;
      my $shsp_seqobj = Bio::Seq->new(-seq => $tmp);

      my $shsp = '';
      if ($shsp_seqobj->alphabet eq 'dna') {
        $shsp_ent = entropy($shsp_seqobj->seq);   # get nucleotide entropy for shsp

        if ($ss > $se) {
          # blast hit was on the reverse complement of subject
          $shsp = $shsp_seqobj->revcom()->translate()->seq;
        }
        else {
          $shsp = $shsp_seqobj->translate()->seq;
        }
      }
      else {
        $shsp = $shsp_seqobj->seq;
      }
      (undef, $shsp_perlc) = Segmasker->new()->run($shsp);   # get protein % low complexity
    }
  }

  print join("\t", @F); 
  printf "\t%.0f\t%.0f\t%.0f\t%.0f\n", entropy($sequence), $qhsp_ent, $shsp_ent, $shsp_perlc;
}

sub faidxsubstr {
  my ($refseqs, $id, $s, $e) = @_;
  my $command = "samtools faidx $refseqs '$id:$s-$e'";
  my $seq = `$command`;
  return $seq;
}

