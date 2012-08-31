package LocalTaxonomy;
use strict;
use warnings;
use Bio::LITE::Taxonomy;
use Bio::LITE::Taxonomy::NCBI;
use Bio::LITE::Taxonomy::NCBI::Gi2taxid;
use Taxonomy;

sub new{
	my $class = shift;
	my $self;
	$self->{'gi_taxid_nucl'} = shift;
	$self->{'gi_taxid_prot'} = shift;
	my $names = shift;
	my $nodes = shift;
	$self->{'gi_taxid_nucl'} = $ENV{'NGT'} if !(defined($self->{'gi_taxid_nucl'}) && -e $self->{'gi_taxid_nucl'});
	$self->{'gi_taxid_prot'} = $ENV{'PGT'} if !(defined($self->{'gi_taxid_prot'}) && -e $self->{'gi_taxid_prot'});
	$names = $ENV{'NAMESDMP'} if !(defined($names) && -e $names);
	$nodes = $ENV{'NODESDMP'} if !(defined($nodes) && -e $nodes);
	$self->{'dict'} = new Bio::LITE::Taxonomy::NCBI(db => 'NCBI', names => $names, nodes => $nodes);
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
sub GetLineage{
	my($self,$type,$gi) = @_;
	my $taxid;
	return 0 if !$type || !$gi;
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
	my $get = $self->{'dict'};
	my @lineage =  $get->get_taxonomy($taxid);

	if ($lineage[0] eq "") {
		@lineage = gi2lineage($gi);
		sleep 1;
	}
	
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
1;

=head1 LocalTaxonomy

=head2 Constructor

The new() method takes the location of the binary files for gi to taxid nucleotide then protein. Next it takes the location of the names, then nodes files. Returns self

=head2 GetLineage

Takes the sequecne type in the form of a string as close to either nucleotide or protein as wanted. Then the corresponding gi number. 
Returns string of lineage from general to specific seperated by "; ".

=cut
