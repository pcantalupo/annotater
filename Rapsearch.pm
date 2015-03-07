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
  if(!$self->{'cutoffs'}{'report_all'}){
    return $self->ParseOutfmt(@_);	
  }
  # need code for REPORT_ALL
}

sub ParseOutfmt{      # parse file containing Rapsearch results
  my ($self,$file,$report) = @_;
  open IN, $file;
  my %idHash;
  while(<IN>){
    next if /^#/;
    chomp;
    my @cols = split /\t/, $_;
    next if (scalar @cols < 12);
    if($self->Pass(@cols)
              && (!$report->{$cols[0]} || $report->{$cols[0]}{'evalue'} > $cols[10])) {
      $report->{$cols[0]}{'evalue'} = $cols[10];
      $report->{$cols[0]}{'pid'} = $cols[2];	
      $report->{$cols[0]}{'accession'} = $cols[1];
      $idHash{$cols[1]} = 1;
      $report->{$cols[0]}{'qc'} = abs (100*(($cols[7]+1-$cols[6])/  $self->{'qlen'}{$cols[0]}  ));     
      $report->{$cols[0]}{'algorithm'} = $self->{'exec'};
      ($report->{$cols[0]}{'db'} = $self->{'d'}) =~ s|^/.*/||;
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
  print "output name is $o\n";
  return $o;
}

sub CalculateQueryLengths {
  my $self = shift;
  my $seqin = Bio::SeqIO->new(-file => $self->{'query'}, -format => $self->{cutoffs}{seqs}{format});
  while (my $seq = $seqin->next_seq) {
    my $qid = $seq->id;
    $self->{'qlen'}{$qid} = $seq->length;
  }
}




1;
