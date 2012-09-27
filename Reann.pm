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
	my %seqFile = %{$self};
	mkdir $self->{'folder'} if ! -d $self->{'folder'};
	Copy($self->{'config'},$self->{'folder'});
	Copy($self->{'file'},$self->{'folder'});
	chdir($self->{'folder'});
	$self->{'seqs'} = new SeqFile(\%seqFile);
	my $file = shift;
	open IN, $self->{'config'};
	while(<IN>){
		next if $_ =~ /^\s+$|^\#/;
		chomp;
		push(@programs,new Blast($_,$self));
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
	$self->WriteRestart($i,$p);
	foreach my $f(@files){
		RM($f);	
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
sub RM{
	my $cmd;
	my $f = shift;
	if($^O eq 'MSWin32'){
		$cmd = "del ".$f;
	}
	else{
		$cmd = "rm ".$f;
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
	my @h = qw(seqID seq seqLength pid coverage e accession algorithm db qstart qend sstart ssend);
	print "report",$/;
	my $d = $self->{'delim'};
	my %blast;
	my $out = $self->{'prefix'}.".".$self->{'output'};
	for(my $x = 0; $x < scalar @{$self->{'out'}}; $x++){
		for(my $y = 0; $y < scalar @{$self->{'out'}[$x]}; $y++){
			$self->{'programs'}[$y]->Parse($self->{'out'}[$x][$y],\%blast);
		}	
	}
	open OUT, ">$out";
	print OUT join($d,@h),$/;
	my $seqI = new Bio::SeqIO(-file => $self->{'file'},-format => $self->{'format'});
	while(my $seq = $seqI->next_seq){
		my $i = $seq->id;
		my $reportline = '';
		$reportline = join($d,$blast{$i}{'pid'},$blast{$i}{'coverage'},
			$blast{$i}{'evalue'},$blast{$i}{'accession'},$blast{$i}{'algorithm'},
			$blast{$i}{'db'},@{$blast{$i}{'pos'}}) if $blast{$i};
		print OUT join($d,$i,$seq->seq,$seq->length,$reportline),$/;
	}
	close OUT;
}

sub Taxonomy {
	my $self = shift;
	print "taxonomy",$/;

	# open report file, read header line and output it to taxout reportfile
	my $report = $self->{'prefix'}.".".$self->{'output'};
	open IN, "<", $report;
	my $header = <IN>;
	chomp $header;
	my $taxout = $self->{'prefix'}.".wTax.".$self->{'output'};
	open OUT, ">", $taxout;

	print OUT join("\t",$header,"type","family","species","genome","lineage"),"\n";

	use LocalTaxonomy;
	use Taxonomy;

	my $lt = new LocalTaxonomy;

	while (<IN>) {
		chomp;
		my @fields = split /\t/, $_;

		my $accession = $fields[6];
		my $algo = $fields[7];

		my $gi = (split (/\|/, $accession))[1];

		# I should build a hash of gi2lineage to save results
		my $lineage = $lt->GetLineage($algo, $gi);
		my $type = "";
		my $family = "";
		my $species = "";
		my $genome = "";
		($type, $family, $species) = lineage2tfs($lineage);
		$genome = get_genome_type($family);    # get genome type for the family (index 1 of array)

		# I need to figure out how to get description
		print OUT join ("\t", $_,$type,$family,$species,$genome,$lineage), "\n";
	}

	close OUT
}

1;

=cut

Functions as Program object handlers and SeqFile object handler. Creates report file.

=cut