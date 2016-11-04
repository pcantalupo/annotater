package SeqUtils;
use strict;
use warnings;
use Exporter;
use Bio::SeqUtils;
use Bio::Seq;
use List::Util qw(sum);

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(has_nsf
                  entropy
                  );


sub has_nsf {
  my ($seq) = @_;
  
  unless (ref $seq eq 'Bio::Seq') {
    # convert raw sequence into a Bio::Seq
    $seq = Bio::Seq->new(-seq => $seq, -id => "foobar");
  }

   my @orfs_6frames = Bio::SeqUtils->translate_6frames($seq);

   my $toReturn = 0;
   foreach my $orfseq (@orfs_6frames) {
   # search for at least one frame that does not have a stop codon '*'
      if ($orfseq->seq !~ /\*/) {   # if you don't find an '*', the sequence contains an ORF throughout entire frame
         $toReturn = 1;
      }
   }

   return $toReturn;
}



sub entropy {
    my ($seqn) = @_; 
    return unless ($seqn);

    my $WINDOWSIZE = 64;
    my $WINDOWSTEP = 32;
    my @WINDOWSIZEARRAY = (0..61);
    my $LOG62 = log(62);
    my $ONEOVERLOG62 = 1/log(62);
    
    my ($rest,$steps,@vals,$str,$num,$bynum);
    my $length = length($seqn);
    if($length <= $WINDOWSIZE) {
        $rest = $length;
        $steps = 0;
    } else {
        $steps = int(($length - $WINDOWSIZE) / $WINDOWSTEP) + 1;
        $rest = $length - $steps * $WINDOWSTEP;
        unless($rest > $WINDOWSTEP) {
            $rest += $WINDOWSTEP;
            $steps--;
        }
    }
    $num = $WINDOWSIZE-2;
    $bynum = 1/$num;
    $num--;
    my $mean = 0;
    my $entropyval;
    foreach my $i (0..$steps-1) {
        $str = substr($seqn,($i * $WINDOWSTEP),$WINDOWSIZE);
        my %counts = ();
        foreach my $i (@WINDOWSIZEARRAY) {
            $counts{substr($str,$i,3)}++;
        }
        $entropyval = 0;
        foreach(values %counts) {
            $entropyval -= ($_ * $bynum) * log($_ * $bynum);
        }
        push(@vals,($entropyval * $ONEOVERLOG62));
    }
    #last step
    if($rest > 5) {
        $str = substr($seqn,($steps * $WINDOWSTEP),$rest);
        my %counts = ();
        $num = $rest-2;
        foreach my $i (0..($num - 1)) {
            $counts{substr($str,$i,3)}++;
        }
        $entropyval = 0;
        $bynum = 1/$num;
        foreach(values %counts) {
            $entropyval -= ($_ * $bynum) * log($_ * $bynum);
        }
        push(@vals,($entropyval / log($num)));
    } else {
        push(@vals,0);
    }
    $mean = &getArrayMean(@vals);
    return $mean * 100;
}

sub getArrayMean {
    return @_ ? sum(@_) / @_ : 0;
}



1;
