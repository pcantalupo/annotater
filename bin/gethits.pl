#!/usr/bin/perl -w

# Return the top X hits (maxhits) from a Reannotator report file. You can
# specify max evalue as well.

use strict;

exec('perldoc', $0) unless @ARGV;


my $file = shift;
my $hits = shift;
$hits = 1 unless (defined $hits);         # default maxhits is 1
my $evalue = shift;
$evalue ||= 10;         # default evalue is 10


#print "hits: $hits\n";
#exit;


open (INFILE, "<", $file);
<INFILE>;   # remove header

my %blast;
while(<INFILE>) {
  my @fields = split /\t/, $_;
  
  next unless ($fields[5]);
  if ($hits == 0) {
    print;
    next;
  }
 
  $blast{$fields[0]}++;          # keep track of how many blast hits for query id  
  print $_ if ($blast{$fields[0]} <= $hits);
}



=head1 NAME

gethits.pl - Get up to N hits for each query from a Reann report file

=head1 SYNOPSIS

  gethits.pl FILE [MAXHITS [EVALUE]]
    
    FILE    - Reann report file
    HITS    - get N top blast hits from report file (default 1 = top blast hit)
            - set to 0 to get all hits in report file (cool way to remove
              unannotated sequences from report file)
    EVALUE  - max evalue for hits (default is 10)


=head1 EXAMPLE

gethits.pl 5 1e-50
    - Get the top 5 blast hits for each query as long as evalue <= 1e-50

gethits.pl
    - Get top blast hit for each query

gethits.pl 0
    - Get all hits (nice side effect is that unannotated rows are removed)


=head1 DESCRIPTION 


=head1 TODO


=head1 FEEDBACK

Any feedback should be sent to Paul Cantalupo (see email below)

=head1 BUGS

  Contact Paul Cantalupo pcantalupo_at_gmail-dot-com
  
=head1 AUTHOR

  Paul Cantalupo
  
=head1 VERSIONS

  0.01

=cut

