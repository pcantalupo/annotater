package Blast;
use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromString);
sub new{
	my $class = shift;
	my $self;
	my $options = shift;
	my $default = shift;
	my %mm;
	$mm{'num_threads'} = $default->{'num_threads'};
	$mm{'outfmt'} = $default->{'outfmt'};
	$mm{'evalue'} = $default->{'evalue'};
	my @reqs = qw(exec=s type=s num_threads=i db=s evalue=s f_evalue=s pid=i qc=i);
	my @opts = (qw(word_size=i gapopen=i gapextend=i matrix=s threshold=f comp_based_stats=s seg=s),
		qw(gilist=s seqidlist=s negative_gilist=s entrez_query=s db_soft_mask=s db_hard_mask=s),
		qw(culling_limit=i best_hit_overhang=f best_hit_score_edge=f max_target_seqs=i dbsize=i searchsp=i),
		qw(import_search_strategy=s export_search_strategy=s xdrop_ungap=f xdrop_gap=f xdrop_gap_final=f),
		qw(window_size=i));
	my @bools = (qw(ungapped parse_deflines remote use_sw_tback lcase_masking soft_masking));
	my $r = GetOptionsFromString($options,\%mm,@reqs,@opts,@bools);
	$self = \%mm;
	$self->{'params'}{'bools'} = \@bools;
	$self->{'params'}{'vals'} = \@opts;
	$self->{'params'}{'reqs'} = \@reqs;
	bless $self,$class;
	$self->{'cutoffs'} = $self->SetCutOffs($default);
	$self->Build;
	return $self;
}
sub Build{
	my $self = shift;
	my %params;
	my $command;
	my $outfmt_s = $self->{'outfmt_s'};
	my $outfmt = '-outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen';
	$outfmt .= " $outfmt_s" if defined($outfmt_s);
	$outfmt .= '"';
	$command = join(' ',$self->{'exec'},'-show_gis',"-num_threads",
		$self->{'num_threads'}, $outfmt,"-db",$self->{'db'});
	$command = join(' ',$command,"-max_target_seqs",$self->{'max_target_seqs'}) if $self->{'max_target_seqs'};
	$command = join(' ',$command,"-evalue",$self->{'evalue'}) if defined($self->{'evalue'});
	foreach my $o (@{$self->{'params'}{'vals'}}){
		$o =~ s/\=.+$//;
		if(defined($self->{$o})){
			$command = join(' ',$command,"-$o",$self->{$o});
		}	
	}
	foreach my $o (@{$self->{'params'}{'bools'}}){
		if(defined($self->{$o})){
			$command = join(' ',$command,"-$o");
		}	
	}
	$self->{'command'} = $command;
}
sub run{
	my $self = shift;
	my ($in,$i,$r) = @_;
	my $out = $self->GetOutName(@_);
	my %filter;
	if(!$r){
		my $cmd = join(' ',$self->{'command'},'-query',$in,'-out',$out);
		print $cmd,$/;
		`$cmd`;
	}
	$self->Parse($out,\%filter);
	return ($out,\%filter);
}
sub GetFilter{
	my $self = shift;
	my $out = shift;
	my %filter;
	if($self->{'outfmt'} == 6){
		open IN, $out;
		while(<IN>){
			my @cols = split "\t", $_;
			$filter{$cols[0]} = 1 if $self->Pass(@cols);
		}	
	}
	return \%filter;
}
sub GetOutName{
	my $self = shift;
	my $in = shift;
	my $i = shift;
	my @out = split /\./,$in;
	pop @out;
	my $e = $self->{'exec'};
	$e =~ s/\..+$/\.txt/;
	my $o = join('.',@out,$i,$e);
	return $o;
}
sub PrintParams{
	my $self = shift;
	foreach my $k (keys %{$self}){
		print join "\t", $k, $self->{$k},$/;	
	}	
}
sub Pass{
	my $self = shift;
	my @cols = @_;	
	
	return 1 if($self->{'cutoffs'}{'evalue'} >= $cols[10]
		&& $self->{'cutoffs'}{'pid'} <= $cols[2] 
		&& $self->{'cutoffs'}{'coverage'} <= (100*($cols[3]/$cols[12])));
	return 0;
}
sub SetCutOffs{
	my $self = shift;
	my $cuts = shift;
	my %set = %{$cuts} if $cuts;
	$set{'evalue'} = $self->{'evalue'} if defined($self->{'f_evalue'});
	$set{'pid'} = $self->{'pid'} if defined($self->{'pid'});
	$set{'coverage'} = $self->{'coverage'} if defined($self->{'coverage'});
	$set{'evalue'} = 10 if !defined($set{'evalue'});
	$set{'pid'} = 0 if !defined($set{'pid'});
	$set{'coverage'} = 0 if !defined($set{'coverage'});
	return \%set;
}
sub Parse{
	my $self = shift;
	if($self->{'outfmt'}){
		$self->ParseOutfmt(@_);	
	}
	else{
		
	}
}
sub ParseOutfmt{
	my $self = shift;
	my $file = shift;
	my $report = shift;
	my $delim = $self->GetDelim;
	open IN, $file;
	while(<IN>){
		chomp $_;
		my @cols = split $delim, $_;
		if($self->Pass(@cols) 
			&& (!$report->{$cols[0]} || $report->{$cols[0]}{'evalue'} > $cols[10])){
			$report->{$cols[0]}{'evalue'} = $cols[10];
			$report->{$cols[0]}{'pid'} = $cols[2];	
			$report->{$cols[0]}{'accession'} = $cols[1];
			$report->{$cols[0]}{'coverage'} = (100*($cols[3]/$cols[12]));
			$report->{$cols[0]}{'length'} = $cols[12];
			$report->{$cols[0]}{'algorithm'} = $self->{'exec'};
			$report->{$cols[0]}{'db'} = $self->{'db'};
			my @pos = @cols[6..9];
			$report->{$cols[0]}{'pos'} = \@pos;
		}
	}
	close IN;
}
sub GetDelim{
	my $self = shift;
	return "\t" if $self->{'outfmt'} == 6;
	return "," if $self->{'outfmt'} == 10;	
}
1;


=cut

Functions as Blast caller and parser

=cut