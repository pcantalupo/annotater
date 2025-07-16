package Rapsearch;
use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromString);
use Data::Dumper;
use Bio::SeqIO;

sub new {
  my $class = shift;
  my $options = shift;   # this value comes from annotator config file (i.e. -exec rapsearch -d ...)
  my $default = shift;
  
  my $self;
  $self->{'num_threads'} = $default->{'num_threads'};   # options from Reann.pm
  $self->{'evalue'} = ($default->{'evalue'} == 10) ? 1 : $default->{'evalue'};    # not 10 like BLAST
  my @reqs = qw(exec=s num_threads|z=i evalue|e=f pid=f qc=f);
  my @opts = qw(d=s s=s i=f l=i v=i b=i p=s g=s a=s w=s x=s);  # not allowing -q, -o -u, -t options
  GetOptionsFromString($options,$self, @reqs, @opts);

  if (! -e $self->{'d'}) {
    print "Please provide absolute path to a rapsearch swift database file in the config file with -d option\n";
    exit;
  }

  $self->{'params'}{'vals'} = \@opts;
  $self->{'params'}{'reqs'} = \@reqs;
  bless $self,$class;
  
  $self->SetCutOffs($default);
  $self->Build;
  $self->Version;
  return $self;
}

sub SetCutOffs{
  my $self = shift;
  my $default = shift;
  $self->{'cutoffs'} = $default;
  $self->{'cutoffs'}{'evalue'} = $self->{'evalue'} if defined($self->{'evalue'});
  $self->{'cutoffs'}{'pid'} = $self->{'pid'} if defined($self->{'pid'});
  $self->{'cutoffs'}{'qc'} = $self->{'qc'} if defined($self->{'qc'});
  $self->{'cutoffs'}{'evalue'} = 10 if !defined($self->{'cutoffs'}{'evalue'});   # 10 is correct even though default evalue to run rapsearch is 1 (1 corresponds to evalue 10 in output)
  $self->{'cutoffs'}{'pid'} = 0 if !defined($self->{'cutoffs'}{'pid'});
  $self->{'cutoffs'}{'qc'} = 0 if !defined($self->{'cutoffs'}{'qc'});
}

sub Build{
  my $self = shift;
  my %params;
  my $command;
  #my $outfmt_s = $self->{'outfmt_s'};
  #my $outfmt = '-outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen';
  #$outfmt .= " $outfmt_s" if defined($outfmt_s);
  #$outfmt .= '"';
  $command = join(' ',$self->{'exec'}, "-z", $self->{'num_threads'});
  $command = join(' ',$command,"-e", $self->{'evalue'}) if (defined($self->{'evalue'}) && $self->{'evalue'} != 1);
  foreach my $o (@{$self->{'params'}{'vals'}}){
    $o =~ s/\=.+$//;
    if(defined($self->{$o})){
      $command = join(' ',$command,"-$o",$self->{$o});
    }	
  }
  $self->{'command'} = $command;
}

sub Version {
  my ($self) = @_;
  $self->{version} = `blastdbcmd -info -db $self->{d}`;
}

sub run {
  my $self = shift;
  my ($query, $i, $restart) = @_;
  $self->{'query'} = $query;
  my $out = $self->GetOutName($query, $i);
  if (!$restart) {
    my $cmd = join(' ', $self->{'command'}, '-q', $query, "-u 1 > $out");
    print $cmd, $/;
    `$cmd`;
  } 

  $self->CalculateQueryLengths;   # rapsearch doesn't output 'qlen' so we need to determine lengths manually. Query lengths are used in query coverage calculation

  my %report; 
  $self->Parse($out, \%report);
  return ($out, \%report);
}

sub Parse{
  my $self = shift;  
  
  $self->{'query'} = $self->{'cutoffs'}{'file'} if (! $self->{'query'} );
  
  if(!$self->{'cutoffs'}{'report_all'}){
    return $self->ParseOutfmt(@_);	
  }
  # need code for REPORT_ALL
}

sub ParseOutfmt{      # parse file containing Rapsearch results
  my ($self,$file,$report) = @_;
  open IN, $file;
  my %idHash;

  if (! exists $self->{qlen}) {
    $self->CalculateQueryLengths
  }
  
  while(<IN>){
    next if /^#/;
    chomp;
    my @cols = split /\t/, $_;
    next if (scalar @cols < 12);

    $cols[10] = clean_evalue($cols[10]);

    if($self->Pass(@cols)
              && (!$report->{$cols[0]} || $report->{$cols[0]}{'evalue'} > $cols[10])) {
      $report->{$cols[0]}{'evalue'} = $cols[10];
      $report->{$cols[0]}{'pid'} = $cols[2];	
      $report->{$cols[0]}{'accession'} = $cols[1];
      $idHash{$cols[1]} = 1;
      $report->{$cols[0]}{'qc'} = 100 * (abs($cols[6]-$cols[7]) + 1)/ $self->{'qlen'}{$cols[0]};
      $report->{$cols[0]}{'algorithm'} = $self->{'exec'};
      $report->{$cols[0]}{'db'} = $self->{'d'};
      my @pos = @cols[6..9];
      $report->{$cols[0]}{'pos'} = \@pos;
    }
  }
  close IN;
  return \%idHash;   # for @id_list in Reann::Report
}

sub Pass{
  my $self = shift;
  my @cols = @_;	
  return 1 if($self->{'cutoffs'}{'evalue'} >= $cols[10]
              && $self->{'cutoffs'}{'pid'} <= $cols[2] 
              && $self->{'cutoffs'}{'qc'} <= $cols[3]
            );
  return 0;
}


sub GetOutName{
  my $self = shift;
  my $in = shift;
  my $i = shift;
  my @out = split /\./,$in;
  pop @out;
  my $e = $self->{'exec'};
  my $o = join('.',@out,$i,$e);
  return $o;
}

sub CalculateQueryLengths {
  my $self = shift;
  return if (!defined $self->{'query'} || ! -e $self->{'query'}); # this is needed here for Reann.pm->Report->Parse when there were no sequences left to search during rapsearch step. The query file is removed at the end of Reann.pm->run. Then since no querylengths were obtained during the Reann->run step in rapsearch, now when it tries to get querylengths, the query file had already been deleted therefore we need to catch this situation and return from subroutine.
   
  my $seqin = Bio::SeqIO->new(-file => $self->{'query'}, -format => $self->{cutoffs}{seqs}{format});
  while (my $seq = $seqin->next_seq) {
    my $qid = $seq->id;
    $self->{'qlen'}{$qid} = $seq->length;
  }
}


sub clean_evalue {
  my ($e) = @_;

  # zero evalue: 0x0p+0
  # other examples:
  #   0x1.3fa9b55ddbf92p-178
  #   0x1.e49bd1ea65088p-134

  $e =~ s/p(-|\+)/e-/g;   # convert p- or p+ to e-
  $e =~ s/e-0$//;      # for a zero evalue
  $e =~ /0x\d+(\.\S+)e-\d+$/;    # remove '.e49bd1ea65088'
  if ($1) {
    $e =~ s/$1//;
  }
  $e =~ s/^0x//;
  return $e;
}


1;
