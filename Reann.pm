package Reann;
use 5.010;
use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromString);
use SeqFile;
use Blast;
use LocalTaxonomy;
use Taxonomy;

my $NUMTHREADS  = 4;
my $OUTFOLDER   = 'annotator';
my $BLASTOUTFMT = 6;
my $RESTARTFILE = 'restart.txt';
my $CHUNK       = 0;
my $SEQFILE     = 'test.fa';
my $CONFIGFILE  = 'reann.config.txt';
my $OUTPUTFILE  = 'report.txt';
my $PREFIX      = 'ann';
my $SEQFORMAT   = 'fasta';
my $EVALUE      = 1e-5;
my $DELIM       = "\t";
my $RUNTAXONOMY = 0;
	
sub new{
	my $class = shift;
	my $self = shift;
	my @programs;

	$self->{'num_threads'} //= $NUMTHREADS;
	$self->{'outfmt'}      //= $BLASTOUTFMT;
	$self->{'restart'}     //= $RESTARTFILE;
	$self->{'chunk'}       //= $CHUNK;
	$self->{'output'}      //= $OUTPUTFILE;
	$self->{'prefix'}      //= $PREFIX;
	$self->{'file'}        //= $SEQFILE;
	$self->{'config'}      //= $CONFIGFILE;
	$self->{'folder'}      //= $OUTFOLDER;
	$self->{'format'}      //= $SEQFORMAT;
	$self->{'evalue'}      //= $EVALUE;
	$self->{'delim'}       //= $DELIM;
	$self->{'tax'}         //= $RUNTAXONOMY;

	mkdir $self->{'folder'} if ! -d $self->{'folder'};
	Copy($self->{'config'},$self->{'folder'});
	Copy($self->{'file'},$self->{'folder'});
	chdir($self->{'folder'});
	
	my %seqFile = %{$self};
	$self->{'seqs'} = new SeqFile(\%seqFile);
	my $file = shift;
	open IN, $self->{'config'};
	while(<IN>){
		next if $_ =~ /^\s+$|^\#/;
		chomp;
		push(@programs,new Blast($_,$self));
	}
	close IN;
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
	
	RM($self->{'config'});
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
		my $reportline = "$d" x 9;      # HARD CODING!!! Be careful here
		$reportline = join($d,$blast{$i}{'pid'},$blast{$i}{'coverage'},
			$blast{$i}{'evalue'},$blast{$i}{'accession'},$blast{$i}{'algorithm'},
			$blast{$i}{'db'},@{$blast{$i}{'pos'}}) if $blast{$i};
		print OUT join($d,$i,$seq->seq,$seq->length,$reportline),$/;
	}
	close OUT;
	$seqI = '';
	RM($self->{'file'});

}

sub Taxonomy {
	my $self = shift;
	return unless $self->{'tax'};    # check to see if Taxonomy sub should be executed
	
	print "taxonomy",$/;

	my $report = $self->{'prefix'}.".".$self->{'output'};
	open IN, "<", $report;

	my $header = <IN>;
	chomp $header;
	my @hf  = split (/\t/,$header);
	my $nhf = scalar @hf;

	my $taxout = $self->{'prefix'}.".wTax.".$self->{'output'};
	open OUT, ">", $taxout;

	print OUT join("\t", @hf[0..6],
			"desc","type","family","species","genome",
			@hf[7..$nhf-1]),"\n";

	my $lt = new LocalTaxonomy;

	while (<IN>) {
		chomp;
		my @rf = split (/\t/, $_, -1);      # row fields (rf); -1 for keeping trailing empty fields
		my $nrf = scalar @rf;

		my ($desc, $type, $family, $species, $genome) = ('') x 5;

		my $accession = $rf[6];
		unless ($accession eq "") {
			my $gi = (split (/\|/, $accession))[1];

			my $algo = $rf[7];
			my $lineage = $lt->GetLineage($algo, $gi);
			($type, $family, $species) = lineage2tfs($lineage);
			$genome = get_genome_type($family);    # get genome type for the family (index 1 of array)

			# get description from BLAST database
			my $db = $rf[8];
			use IO::String;
			my $fasta = `blastdbcmd -db $db -entry $gi`;
			my $seqio = Bio::SeqIO->new(-fh => IO::String->new($fasta), -format => 'fasta');
			my $seqobj = $seqio->next_seq;
			$desc = $seqobj->desc;
		}
		
		# output
		print OUT join ("\t", @rf[0..6],
				$desc,$type,$family,$species,$genome,
				@rf[7..$nrf-1]),"\n";

	}
	close OUT;

	use File::Copy;
	move ($taxout, $report);	
}

1;

=cut

Functions as Program object handlers and SeqFile object handler. Creates report file.

=cut