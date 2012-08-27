package Reann;
use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromString);
use SeqFile;
use Blast;

sub new{
	my $class = shift;
	my $self = shift;
	
	my @programs;
	
	mkdir $self->{'folder'} if ! -d $self->{'folder'};
	Copy($self->{'config'},$self->{'folder'});
	Copy($self->{'file'},$self->{'folder'});
	chdir($self->{'folder'});
	my $file = shift;
	open IN, $self->{'config'};
	while(<IN>){
		next if $_ =~ /^\s+$|^\#/;
		chomp;
		my $type = '';
		my $r = GetOptionsFromString($_, "t|type=s" => \$type);
		#Help("Line is not correctly formated\n$_") if !$r;
		Help("Line does not contain type\n$_") if !$type;
		push(@programs,new $type($_)) if $type ne 'SeqFile';
		$self->{'seqs'} = new SeqFile($self->{'file'},$_) if $type eq 'SeqFile';
	}
	
	$self->{'programs'} = \@programs;
	$self->{'out'} = ();
	bless $self,$class;
	return $self;
}
sub run{
	my $self = shift;
	my ($i,$p) = $self->Restart;
	my $r = ($i || $p);
	my @files = $self->{'seqs'}->GetFiles;
	for(;$i < scalar @files; $i++){
		print $files[$i],$/;
		for(; $p < scalar @{$self->{'programs'}}; $p++){
			my $f = $files[$i];
			my ($out,$filter) = $self->{'programs'}[$p]->run($f,$p,$r);
			$r = 0;
			$self->WriteRestart($i,$p);
			$self->{'out'}[$i][$p] = $out;
			$self->{'seqs'}->FilterSeqs($i,$filter);
		}	
		$p = 0;
	}	
}
sub Restart{
	my $self = shift;
	my ($x,$y) = (0,0);
	if(! -s $self->{'restart'}){
		open OUT, ">".$self->{'restart'};
		print OUT "0,0",$/;
		close OUT;
	}
	else{
		open IN, $self->{'restart'};
		while(<IN>){
			chomp $_;
			my @mm = split ',', $_;
			($x,$y) = @mm;
			$self->GetCompleted($x,$y);
		}
		close IN;
	}
	return ($x,$y);
}
sub GetCompleted{
	my $self = shift;
	my $fasta = shift;
	my $program = shift;
	my @files = $self->{'seqs'}->GetFiles;
	for(my $x = 0; $x <= $fasta; $x++){
		for(my $y = 0; $y < @{$self->{'programs'}}; $y++){
			last if $x == $fasta && $y == $program;
			$self->{'out'}[$x][$y] = $self->{'programs'}[$y]->GetOutName($files[$x],$y);	
		}	
	}
}
sub WriteRestart{
	my $self = shift;
	my $t = $self->{'restart'}.".temp";
	open OUT, ">$t";
	print OUT join(",",@_),$/;
	close OUT;
	$self->Overwrite($self->{'restart'}.".temp",$self->{'restart'});
}
sub Copy{
	my $cmd;	
	if($^O eq 'MSWin32'){
		$cmd = join(' ','copy',@_);	
	}
	else{
		$cmd = join(' ','cp',@_);
	}
	`$cmd`;
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
	$self->{'seqs'}->PrintParams;
}	
sub Report{
	my $self = shift;
	
	print "report",$/;
	for(my $x = 0; $x < scalar @{$self->{'out'}}; $x++){
		for(my $y = 0; $y < scalar @{$self->{'out'}[$x]}; $y++){
			print $self->{'out'}[$x][$y],$/;
		}	
	}	
}
1;

=cut

Functions as Program object handlers and SeqFile object handler. Creates report file.

=cut