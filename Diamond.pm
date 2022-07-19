package Diamond;
use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromString);
use Data::Dumper;
use Bio::SeqIO;

sub new {
  my $class = shift;
  my $options = shift;   # this value comes from annotator config file (i.e. -exec diamond ...)
  my $default = shift;
  
  my $self;
  $self->{'num_threads'} = $default->{'num_threads'};   # options from Reann.pm
  $self->{'evalue'} = $default->{'evalue'};
  my @reqs = qw(exec=s type=s db|d=s num_threads|p=i evalue|e=f pid=f qc=f);   # -type blastx
  my @opts = qw(sensitive min_score=f);   # sensitive is toggle for fast mode
  GetOptionsFromString($options,$self, @reqs, @opts);

  if (! -e $self->{'db'} && ! -e $self->{'db'} . ".dmnd") {
    print "Please provide absolute path to DMND database file in the config file with -d option\n";
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
  $self->{'cutoffs'}{'evalue'} = 0.001 if !defined($self->{'cutoffs'}{'evalue'});   # default diamond evalue is 0.001
  $self->{'cutoffs'}{'pid'} = $self->{'pid'} if defined($self->{'pid'});
  $self->{'cutoffs'}{'pid'} = 0 if !defined($self->{'cutoffs'}{'pid'});
  $self->{'cutoffs'}{'qc'} = $self->{'qc'} if defined($self->{'qc'});
  $self->{'cutoffs'}{'qc'} = 0 if !defined($self->{'cutoffs'}{'qc'});
}

sub Build{
  my $self = shift;
  my %params;
  my $command;
  my $outfmt = '--outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen';
  $command = join(' ',$self->{'exec'}, $self->{'type'}, "-d", $self->{'db'}, "-p", $self->{'num_threads'});  # diamond blastx -d /path/to/db -p 6
  $command = join(' ',$command,"-e", $self->{'evalue'}) if (defined($self->{'evalue'}));
  $command = join(' ', $command, $outfmt);
  foreach my $o (@{$self->{'params'}{'vals'}}){
    $o =~ s/\=.+$//;
    if(defined($self->{$o})){
      $command = join(' ',$command,"--$o",$self->{$o});
    }	
  }
  $self->{'command'} = $command;
}

sub Version {
  my ($self) = @_;
  $self->{version} = `diamond dbinfo -d $self->{db} 2>&1`;
}

sub run {
  my $self = shift;
  my ($query, $i, $restart) = @_;
  $self->{'query'} = $query;
  my $out = $self->GetOutName($query, $i);
  if (!$restart) {
    my $cmd = join(' ', $self->{'command'}, '-q', $query, " > $out");
    print $cmd, $/;
    `$cmd`;
  } 

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

sub ParseOutfmt{      # parse file containing Diamond results
  my ($self,$file,$report) = @_;
  open IN, $file;
  my %idHash;
  
  while(<IN>){
    next if /^#/;
    chomp;
    my @cols = split /\t/, $_;
    next if (scalar @cols < 13);

    if($self->Pass(@cols)
              && (!$report->{$cols[0]} || $report->{$cols[0]}{'evalue'} > $cols[10])) {
      $report->{$cols[0]}{'evalue'} = $cols[10];
      $report->{$cols[0]}{'pid'} = $cols[2];	
      $report->{$cols[0]}{'accession'} = $cols[1];
      $idHash{$cols[1]} = 1;
      $report->{$cols[0]}{'qc'} = 100 * (abs($cols[6]-$cols[7]) + 1)/ $cols[12];
      $report->{$cols[0]}{'algorithm'} = $self->{'exec'} . "_" . $self->{'type'};
      $report->{$cols[0]}{'db'} = $self->{'db'};
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



1;
