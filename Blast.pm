package Blast;
use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromString);
sub new{
	my $class = shift;
	my $self;
	my $options = shift;
	my $cutoffs = shift;
	my %mm = ('outfmt',6,
				'num_threads', 4);
	my $r = GetOptionsFromString($options,\%mm,qw(exec=s outfmt type=s num_threads=i db=s max_target_seqs=i evalue=s),
									qw(b_evalue=s f_evalue=s pid=i coverage=i));
	$self = \%mm;
	bless $self,$class;
	$self->{'cutoffs'} = $self->SetCutOffs($cutoffs);
	$self->TestOptions();
	$self->Build;
	return $self;
}
sub Build{
	my $self = shift;
	my $command;
	$command = join(' ',$self->{'exec'},'-show_gis',"-num_threads",
		$self->{'num_threads'},"-outfmt",$self->{'outfmt'}, "-db",$self->{'db'});
	$command = join(' ',$command,"-max_target_seqs",$self->{'max_target_seqs'}) if $self->{'max_target_seqs'};
	$command = join(' ',$command,"-evalue",$self->{'b_evalue'}) if defined($self->{'b_evalue'});
	$self->{'command'} = $command;
}
sub run{
	my $self = shift;
	my ($in,$i,$r) = @_;
	my $out = $self->GetOutName(@_);
	if(!$r){
		my $cmd = join(' ',$self->{'command'},'-query',$in,'-out',$out);
		`$cmd`;
	}
	my $f = $self->GetFilter($out);
	return ($out,$f);
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
sub TestOptions{
	
}
sub Pass{
	my $self = shift;
	my @cols = @_;	
}
sub SetCutOffs{
	my $self = shift;
	my $cuts = shift;
	my %set = %{$cuts};
	$set{'evalue'} = $self->{'c_evalue'} if defined($self->{'c_evalue'});
	$set{'pid'} = $self->{'c_pid'} if defined($self->{'c_pid'});
	$set{'coverage'} = $self->{'c_coverage'} if defined($self->{'c_coverage'});
	$set{'evalue'} = 10 if !defined($set{'evalue'});
	$set{'pid'} = 0 if !defined($set{'pid'});
	$set{'coverage'} = 0 if !defined($set{'coverage'});
	return \%set;
}
1;


=cut

Functions as Blast caller and parser

=cut