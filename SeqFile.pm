package SeqFile;
use strict;
use warnings;
use Bio::SeqIO;
use Getopt::Long qw(GetOptionsFromString);

sub new{
	my $class = shift;
	my $self = shift;
	bless $self,$class;
	$self->Chunk if $self->{'chunk'};
	push(@{$self->{'files'}},$self->{'file'}) if !$self->{'chunk'};
	return $self;
}
sub Chunk{
	my $self = shift;
	my $seqI = new Bio::SeqIO(-file => $self->{'file'}, -format => $self->{'format'});	
	my $count = 0;
	my $seqO;
	my @files;
	my $seq;
	for(my $i = 0; $seq = $seqI->next_seq; $i++){
		if((($i % ($self->{'chunk'})) == 0)){
			my $file = join(".",$self->{'prefix'},$count,$self->{'format'});
			$count++;
			push(@files,$file);
			$seqO = new Bio::SeqIO(-file => ">$file", -format => $self->{'format'});
		}
		$seqO->write_seq($seq);
	}
	$self->{'files'} = \@files;
}
sub GetFileCount{
	my $self = shift;
	return scalar @{$self->{'files'}};	
}
sub GetFiles{
	my $self = shift;
	return @{$self->{'files'}};	
}
sub FilterSeqs{
	my $self = shift;
	my $i = shift;
	my $filter = shift;
	my $seqI = new Bio::SeqIO(-file => $self->{'files'}[$i], -format => $self->{'format'});	
	my $seqO = new Bio::SeqIO(-file => ">".$self->{'files'}[$i].".temp",-format => $self->{'format'});
	
	while(my $seq = $seqI->next_seq){
		$seqO->write_seq($seq) if !$filter->{$seq->id};	
	}
	$seqO = '';
	$seqI = '';
	$self->Overwrite($self->{'files'}[$i].".temp",$self->{'files'}[$i]);
}
sub Overwrite{
	my $self = shift;
	my $cmd;
	if($^O eq 'MSWin32'){
		$cmd = join(' ','move',@_);	
	}
	else{
		$cmd = join(' ','mv',@_);
	}
	`$cmd`;	
}
sub PrintParams{
	my $self = shift;
	foreach my $k (keys %{$self}){
		print join "\t", $k, $self->{$k},$/;	
	}	
}
1;

=cut

Functions as fasta handler and parser

=cut