package Reann;
use 5.010;
use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromString);
use File::Copy;
use SeqFile;
use Blast;
use Rapsearch;
use LocalTaxonomy;
use Taxonomy;
use SeqUtils;
use Annotator::Report;

my $NUMTHREADS  = 4;
my $OUTFOLDER   = 'annotator';
my $BLASTOUTFMT = 6;
my $RESTARTFILE = 'restart.txt';
my $CHUNK       = 0;
my $SEQFILE     = 'tag-fasta.fa';
my $CONFIGFILE  = 'tag.conf';
my $OUTPUTFILE  = 'report.txt';
my $PREFIX      = 'ann';
my $SEQFORMAT   = 'fasta';
my $EVALUE      = 10;
my $DELIM       = "\t";
my $RUNTAXONOMY = 0;
my $REPORTALL   = 0;
my $REMOTETAX   = 0;


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
	$self->{'remotetax'}   //= $REMOTETAX;

	if (! -e $self->{config}) {
		print "Please supply an appropriate config file (config)\n";
		exit;
	}

	umask 0022;
	mkdir $self->{'folder'} if ! -d $self->{'folder'};
	my $f = $self->{'file'};
	$f =~ s/^.+\\|^.+\///;
	copy($self->{'config'},$self->{'folder'});
	copy($self->{'file'},$self->{'folder'});
	$self->{'file'}  = $f;
	$self->{'config'} =~ s/^.+\\|^.+\///;
	chdir($self->{'folder'});

	my %seqFile = %{$self};
	$self->{'seqs'} = new SeqFile(\%seqFile);
	my $file = shift;
	open IN, $self->{'config'};
	print $self->{'config'},$/;
	while(<IN>){
		next if $_ =~ /^\s+$|^\#/;
		chomp;

		my @f = split;
		if ($f[3] =~ /^~/) {
          print "Tilde (~) are not allowed in database file paths. Use a full path instead.\n";
          exit;
        }
		if ($f[1] =~ /blast/) {
                  push(@programs, Blast->new($_,$self));
                }
                elsif ($f[1] =~ /rapsearch/) {
                  push(@programs, Rapsearch->new($_,$self));
                }
                else {
                  die "Program $f[1] not recognized\n";
                }
	}
	close IN;
	$self->{'programs'} = \@programs;
	open (my $version, ">", "version.txt") or die "Can't open version.txt: $!\n";
	foreach (@{$self->{programs}}) {
          print $version $_->{version},"\n";
        }
        close ($version);

	$self->{'out'} = ();
	bless $self,$class;
	return $self;
}
sub run{
	my $self = shift;
	my ($i,$p) = $self->Restart;   # $i is chunk number, $p is Program number
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
sub Report{ # edit here to add get all
	my $self = shift;
	my @h = qw(seqID seq seqLength pid coverage e accession algorithm db qstart qend sstart ssend);
	print "Report",$/;
	my $d = $self->{'delim'};
	my %blast;
	my $out = $self->{'prefix'}.".".$self->{'output'};
	my @id_list;
	for(my $x = 0; $x < scalar @{$self->{'out'}}; $x++){
		for(my $y = 0; $y < scalar @{$self->{'out'}[$x]}; $y++){
			push(@id_list,$self->{'programs'}[$y]->Parse($self->{'out'}[$x][$y],\%blast));
		}
	}
	foreach my $h (@id_list){
		foreach my $k (keys %{$h}){
			$self->{'hit_list'}{$k} = 1;
		}
	}
	open OUT, ">$out";
	print OUT join($d,@h),$/;
	my $seqI = new Bio::SeqIO(-file => $self->{'file'},-format => $self->{'format'});
	if(!$self->{'report_all'}){
		while(my $seq = $seqI->next_seq){
			my $i = $seq->id;
			my $reportline = "$d" x 9;      # HARD CODING!!! Be careful here
			$reportline = join($d,$blast{$i}{'pid'},$blast{$i}{'qc'},
				$blast{$i}{'evalue'},$blast{$i}{'accession'},$blast{$i}{'algorithm'},
				$blast{$i}{'db'},@{$blast{$i}{'pos'}}) if $blast{$i};
			print OUT join($d,$i,$seq->seq,$seq->length,$reportline),$/;
		}
	}
	else{
		#finish all report here
		while(my $seq = $seqI->next_seq){
			my $i = $seq->id;
			my $reportline = "$d" x 9;
			if(defined($blast{$i})){
				foreach my $b (@{$blast{$i}}){
					$reportline = join($d,$b->{'pid'},$b->{'qc'},
						$b->{'evalue'},$b->{'accession'},$b->{'algorithm'},
						$b->{'db'},@{$b->{'pos'}});
					print OUT join($d,$i,'',$seq->length,$reportline),$/;
				}
			}
			else{
				print OUT join($d,$i,'',$seq->length,$reportline),$/;
			}
		}
	}
	close OUT;
	$seqI = '';
	RM($self->{'file'});
}

sub Taxonomy {
	my ($self, %args) = @_;

	print "Taxonomy",$/;

	my $report = $self->{'prefix'}.".".$self->{'output'};
	open IN, "<", $report;

	my $header = <IN>;
	chomp $header;
	my @hf  = split (/\t/,$header);
	my $nhf = scalar @hf;

	$self->{taxout} = $self->{'prefix'}.".wTax.".$self->{'output'};
	open OUT, ">", $self->{taxout};

	print OUT join("\t", @hf[0..6],
			"desc","type","family","species","genome",
			@hf[7..$nhf-1], "nsf"),"\n";

	#
	# get fasta seqs and descriptions from BLAST databases
	my %acc;
	while (<IN>) {
		my ($acc, $db) = (split (/\t/, $_, -1))[6,8];
		$acc{$db}{$acc}++ unless ($acc eq "");
	}

	foreach my $db (keys %acc) {
		print "\tGetting fasta seqs for $db\n";
		my $gis_outfile = "$db.gis.txt";
		open (TMPOUT, ">", $gis_outfile) or die "Can't open $gis_outfile for writing: $!\n";
		foreach (keys %{$acc{$db}}) {
			print TMPOUT $_, "\n";
		}
		close TMPOUT;

		my $fasta_outfile = $gis_outfile . ".fa";
		$self->{dbfastafile}{$db} = $fasta_outfile;   # save fasta filename for each database; these files will be used in add_entropy()
		`blastdbcmd -db $db -entry_batch $gis_outfile > $fasta_outfile`;

		my $seqio = Bio::SeqIO->new(-file => $fasta_outfile, -format => 'fasta');
		while (my $seqobj = $seqio->next_seq) {
			(my $primary_id = $seqobj->primary_id) =~ s/^lcl\|//;  # some versions of blastdbcmd prepend accession number with 'lcl|'
			$acc{$db}{$primary_id} = $seqobj->desc;
		}
		unlink($gis_outfile);
	}

	#
	# get lineage information
	my $lt;
	if ($self->{'tax'}) {
	  print "\tStarting LocalTaxonomy - ";
	  ($self->{remotetax}) ?
		print "getting taxonomy solely from NCBI\n" :
		print "getting taxonomy locally\n";
          $lt = ($self->{remotetax}) ? LocalTaxonomy->new(remotetax => 1) : LocalTaxonomy->new;
        }
        else {
          print "\tSkipping LocalTaxonomy\n";
        }

	seek IN, 0, 0;                  # seek to beginning of report file
	<IN>;
	while (<IN>) {
		chomp;
		my @rf = split (/\t/, $_, -1);      # row fields (rf); -1 for keeping trailing empty fields
		my $nrf = scalar @rf;

		my ($desc, $type, $family, $species, $genome) = ('') x 5;

		my $accession = $rf[6];
		unless ($accession eq "") {
			($type, $family, $species, $genome) = ('NULL') x 4;
			my $gi = (split (/\|/, $accession))[1];
			if (!$gi) {
				$gi = $accession;   # for when the subject id in blast output is not a fullgi but rather just an ACC.VER value (i.e. APS85757.2)
			}

			my $algo = $rf[7];
			if ($self->{'tax'}) {
			  my $lineage = $lt->GetLineage($algo, $gi, $self->{'remotetax'});
			  if ($lineage ne "") {
				($type, $family, $species) = lineage2tfs($lineage);
				$genome = get_genome_type($family);    # get genome type for the family (index 1 of array)
                          }
			}
                        # get description from %acc hash
                        if ($gi) {
				my $db = $rf[8];
				$desc = $acc{$db}{$accession};
                        }
		}

		my $is_nsf = has_nsf($rf[1]);

		# output
		print OUT join ("\t", @rf[0..6],
				$desc,$type,$family,$species,$genome,
				@rf[7..$nrf-1], $is_nsf),"\n";

	}
	close OUT;

	unlink ($report);
}

sub add_entropy {
	print "Entropy\n";
  my ($self, %args) = @_;

  my $refseqs = $self->{dbfastafile};

  my $entropyReport = $self->{prefix} . ".wTax.BE." . $self->{output};
  if (-e $self->{taxout}) {
    my $ar = Annotator::Report->new(report => $self->{taxout},
                                    refseqs => $refseqs,);
    my $tmp = $ar->run_entropy;
    move ($tmp, $entropyReport);
    #move ($tmp, $self->{taxout});
  }
  else {
    print "Add_entropy will not run since Reann taxReport does not exist.\n";
    return
  }

	# delete db fasta files
	foreach my $db ( keys %{ $self->{dbfastafile} } ) {
		print "\tDeleting db fastafile: ", $self->{dbfastafile}->{$db}, $/;
		unlink ($self->{dbfastafile}->{$db});
	}
}



1;

=cut

Functions as Program object handlers and SeqFile object handler. Creates report file.

=cut
