package LocalTaxonomy;
use strict;
use warnings;
use Bio::LITE::Taxonomy;
use Bio::LITE::Taxonomy::NCBI;
use Bio::LITE::Taxonomy::NCBI::Gi2taxid;
use Taxonomy;

=head2 new

Params  : hash with possible names:
		remotetax       set to 1 to only perform remote taxonomy lookup at NCBI
		gi_taxid_nucl   the gi_taxid_nucl BIN file
		gi_taxid_prot   the gi_taxid_prot BIN file
		names           NCBI taxonomy names file
		nodes           NCBI taxonomy nodes file
Usage   : 
=cut

sub new{
	my ($class, %args) = @_;
	my $self = \%args;
	$self->{'gi_taxid_nucl'} = $ENV{'NGT'}      if !(defined($self->{'gi_taxid_nucl'}) && -e $self->{'gi_taxid_nucl'});
	$self->{'gi_taxid_prot'} = $ENV{'PGT'}      if !(defined($self->{'gi_taxid_prot'}) && -e $self->{'gi_taxid_prot'});
	
	unless (exists $self->{remotetax}) {
		$self->{'names'} = $ENV{'NAMESDMP'} if !(defined($self->{names}) && -e $self->{names});
		$self->{'nodes'} = $ENV{'NODESDMP'} if !(defined($self->{nodes}) && -e $self->{nodes});
		$self->{'dict'} = new Bio::LITE::Taxonomy::NCBI(db => 'NCBI', names => $self->{names}, nodes => $self->{nodes});
	}
	#$self->{'gi2lineage'} = ();
	bless $self, $class;
	return $self; 
}
sub Load{
	my ($self,$type) = @_;
	if("nucleotide" =~ $type){
		if($self->{'gi_taxid_prot_loaded'}){
			$self->{'gi_taxid_prot_loaded'} = 0;
		}
		if($self->{'gi_taxid_nucl_loaded'}){
			return $self->{'gi_taxid_nucl_loaded'};
		}
		else{
			$self->{'gi_taxid_nucl_loaded'} = new Bio::LITE::Taxonomy::NCBI::Gi2taxid(dict => $self->{'gi_taxid_nucl'});
			return $self->{'gi_taxid_nucl_loaded'};
		}
	}
	if("protein" =~ $type){
		if($self->{'gi_taxid_nucl_loaded'}){
			$self->{'gi_taxid_nucl_loaded'} = 0;
		}
		if($self->{'gi_taxid_prot_loaded'}){
			return $self->{'gi_taxid_prot_loaded'};
		}
		else{
			$self->{'gi_taxid_prot_loaded'} = new Bio::LITE::Taxonomy::NCBI::Gi2taxid(dict => $self->{'gi_taxid_prot'});
			return $self->{'gi_taxid_prot_loaded'};
		}
	}
}


# Tries to get taxonomy lineage from local installation of taxonomy db
# but if it fails, then it sends query to NCBI (gi2lineage subroutine)
#
# Return value: scalar (taxonomy levels separated by '; ') or empty
#		string if lineage could not be obtained for GI number
#
sub GetLineage{
	my($self,$type,$gi,$remotetax) = @_;
	my $taxid;
	return 0 if !$type || !$gi;

	# check if we have lineage saved for this gi
	if ($self->{'gi2taxid'}{$gi}) {
		my $taxid = $self->{'gi2taxid'}{$gi};
		if ($self->{'taxid2lineage'}{$taxid}) {
			print STDERR "GetLineage: have lineage for gi $gi through taxid $taxid\n";
			return join ("; ", @{$self->{'taxid2lineage'}{$taxid}});
		}
	}
	elsif ($self->{'gi2lineage'}{$gi}) {   # this is true when no taxid was found locally and then lineage gets retrieved remotely
		print STDERR "GetLineage: have lineage for gi $gi but not through a taxid\n";
		return join ("; ", @{$self->{'gi2lineage'}{$gi}});
	}
	
	# no lineage saved for this gi; therefore, go get it
	my @lineage = ();
	if ($remotetax) {   # get taxonomy information from NCBI
		@lineage = gi2lineage($gi);
		sleep 1;
	} else {
		if($type =~ /blast/i){
			$type = AlgorithmToType($type);
		}
		if("nucleotide" =~ $type){
			my $d = $self->Load("nucl");
			$taxid = $d->get_taxid($gi);
		}
		if("protein" =~ $type){
			my $d = $self->Load("prot");
			$taxid = $d->get_taxid($gi);
		}
		
		# if we dont' get a taxid, get lineage from NCBI
		if (!defined $taxid || $taxid == 0) {
			print STDERR "GetLineage: didn't get valid taxid:<$taxid> for GI:$gi so getting lineage from NCBI\n";
			@lineage = gi2lineage($gi);
		}
		# else, get taxid from LOCAL taxonomy database
		else {
			# check if already have lineage for taxid
			if ($self->{'taxid2lineage'}{$taxid}) {
				print STDERR "GetLineage: have lineage for taxid $taxid (current gi $gi)\n";
				return join ("; ", @{$self->{'taxid2lineage'}{$taxid}});
			}

			@lineage = $self->get_taxonomy($taxid);
			if ($lineage[0] eq "") {
				print STDERR "GetLineage: cannot get lineage from local taxonomy even with valid taxid:<$taxid> for GI:$gi\n";
			}
		}
	}
	
	# save gi and lineage information
	if ($taxid) {
		$self->{'taxid2lineage'}{$taxid} = \@lineage;
		$self->{'gi2taxid'}{$gi} = $taxid;
	}
	else {
		$self->{'gi2lineage'}{$gi} = \@lineage;
	}

	#print STDERR "Lineage is ", join ("; ", @lineage), " for GI:$gi and Taxid:$taxid\n";
	return join("; ", @lineage);
}

sub AlgorithmToType{
	my $alg = shift;
	if($alg =~ /blastn|tblastx|tblastn/i){
		return "nucleotide";
	}
	else{
		return "protein";
	}
}


sub get_taxonomy {
	my ($self, $taxid) = @_;
	return $self->{dict}->get_taxonomy($taxid);
}

1;

=head1 LocalTaxonomy

=head2 Constructor

The new() method takes the location of the binary files for gi to taxid nucleotide then protein. Next it takes the location of the names, then nodes files. Returns self

=head2 GetLineage

Takes the sequecne type in the form of a string as close to either nucleotide or protein as wanted. Then the corresponding gi number. 
Returns string of lineage from general to specific seperated by "; ".

=cut
