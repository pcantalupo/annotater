#
# Pipaslab module for Taxonomy
#
# Please direct questions and support issues to <pcantalupo@gmail.com>
#
# Maintained Cared by Paul Cantalupo <pcantalupo@gmail.com>
#
# Copyright Paul Cantalupo
#
# You may disrtribute this module under the same terms as perl itself

# POD documentation - main docs before the code (Based on Bio::PrimarySeq)

=head1 NAME

Taxonomy - gets taxonomy information from NCBI (and other stuff too...)

=head1 SYNOPSIS

  use strict;
  use Taxonomy;
  
  # get a GI from an accession
  # accession can be several different formats: J02400, gb|J02400|
  
  my $acc = 'J02400';
  my $gi = acc2gi($acc);
  print $gi, "\n";
  
  # get a Taxid from a GI
  
  my $taxid = gi2taxid($gi);

=head1 DESCRIPTION

Taxonomy module is a set of functions to help the user obtain taxonomy
information from NCBI.  It provides a function to convert an accession
number into a GI number.  Then that GI number can be used to obtain the
Taxid.  With the Taxid, the user is able to get lineage information for that
Taxid (i.e.  Viruses, ssRNA viruses, Virgaviridae, Tobamovirus, PepperMild
Mottle virus).

Taxonomy can also tell if a sequence is Virus, Phage, Bacteria, Human,
Mouse, etc.  Additionally, it knows the Genome type for each virus family.

Taxonomy relies upon NCBI's Eutils for data retrieval so you need to have an
Internet connection for those functions to work.

=head1 FEEDBACK

=head2 Support

Please direct usage questions or bugs to 

I<pcantalupo@gmail.com>

=head1 AUTHOR - Paul Cantalupo

Email pcantalupo@gmail.com

=head1 SUNDRY ITEMS

Taxid's of some common organisms (This library doesn't use these but I'm
keeping this info here for future reference)

=over

=item Bacteria

2

=item Archaea

2157

=item Homo sapiens

9606

=item Mus musculus

10090

=item Fungi

4751 (cellular organisms; Eukaryota; Fungi/Metazoa group; Fungi;)

=back

=head1 SEE ALSO

Other modules that do some similar stuff: Bio::Taxon, Bio::DB::Taxonomy

=head1 TODO

This library should be recoded to use Bio::DB::SoapEUtilities instead of
Bio::DB::EUtilities.  See documentation for Bio::DB::SoapEUtilitiess L<http://www.bioperl.org/> and the
ESoap information (LINK here)  on NCBI's website.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

#
# Let the code begin...


package Taxonomy;
use strict;

use Bio::DB::EUtilities;
use XML::Simple;
use Exporter;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(gi2taxid
                  taxid2lineage
                  accession2gi
                  lineage2tfs
                  get_virus_family
                  is_phage
                  is_phage_family
                  get_genome_type
                  );

# GLOBALS
my $NOFAMILY = "NoFamily";





=head2 accession2gi

 Title    : accession2gi
 Usage    : $gi   = acc2gi('J02400');
 Function : Returns a GI number from an accession number.
 Returns  : A scalar (GI number)
            undef when argument is NOT TRUE (i.e. '', 0, undef)
            empty string when no GI is found
 Args     : an accession number in the following formats:
            J02400     - naked accession
            gb|J02400| - full fasta identifier (gotta be a better name for this)
            
            May not work with all non-genbank accession numbers. For
            example, it does not work with naked PDB accession numbers like
            2FL8 but OK if it is the full fasta identifier: pdb|2FL8|A

=cut


sub accession2gi {
   # example URI that BioPerl sends to efetch for gb|J02400| (i.e. SV40)
   # "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide
   # &retmode=text&id=gb%7CJ02400.1%7C&rettype=gi&tool=BioPerl&email=pcantalupo%40gmail.com"

   my ($acc) = @_; 
   return undef unless ($acc);

   my $factory = Bio::DB::EUtilities->new(-eutil => 'efetch',
                                          -db => 'nucleotide',  # don't need to change this to Protein for protein accessions, it seems to work fine by keeping it set to 'nucleotide'
                                          -id => [ $acc ],
                                          -email => 'pcantalupo@gmail.com',
                                          -rettype => 'gi');
   my $gi = $factory->get_Response->content;

   chomp $gi;
   return $gi;
}   



=head2 gi2taxid

 Title    : gi2taxid
 Usage    : $taxid  = gi2taxid('965480');
 Function : Obtain a Taxid (NCBI Taxonomy identifier) from a GI number
 Returns  : A scalar.  Return value can be undef if the Taxid of the GI
            record is empty or if there is no TaxId item in the Document
            summary or if no GI was given when subroutine was called
 Args     : a GI number

=cut


sub gi2taxid {
   # here is an example of the URL that this subroutine will send:
   # http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=nucleotide&id=965480&email=pcantalupo%40gmail.com&retmode=text
   # example gi 965480 (SV40 J02400) -> taxid = 10633

   my ($gi, $database) = @_;
   return undef unless ($gi);
   
   $database ||= "nucleotide";
 
   my $factory = Bio::DB::EUtilities->new(-eutil => 'esummary',
                                          -email => 'pcantalupo@gmail.com',
                                          -db => $database,
                                          -id => [ $gi ],
                                          );

   # iterate through the individual DocSum objects (one per ID)
   while (my $ds = $factory->next_DocSum) {
      # flattened mode, iterates through all Item objects
      while (my $item = $ds->next_Item('flattened'))  {
         if ($item->get_name eq 'TaxId') {
            return $item->get_content;
         }
      }
            
      return undef;    # No item called 'TaxID' existed in the XML document.
   }
}



=head2 taxid2lineage

 Title    : taxid2lineage
 Usage    : @lineage  = taxid2lineage('10633');
 Function : Returns the lineage of a Taxid
 Returns  : List context: an array containing the lineage information from General to Specific
            Scalar context: elements of the array are joined with '; ' (mind the space)
 
            If the Tax ID is not found, returns "Empty id list - nothing
            todo" and returns undef if the argument is NOT true (i.e.  '',
            0, undef)
 
 Args     : a Taxid (Taxonomy database ID)

=cut


sub taxid2lineage {
   # here is an example of the URL that this subroutine will send (i.e. SV40):
   # http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&
   # id=10633&email=pcantalupo%40gmail.com&retmode=xml 
   
   my ($id) = @_;
   return undef unless ($id);
   
   my $factory = Bio::DB::EUtilities->new(-eutil => 'efetch',
                                          -db    => 'taxonomy',
                                          -email => 'pcantalupo@gmail.com',
                                          -id    => [ $id ],
                                          );

   my $res = $factory->get_Response->content;
   my $data = XMLin($res);

   # build lineage array to match structure of the ORGANISM field in
   # Genbank records (i.e.  Viruses; dsDNA viruses; Polyomaviridae, etc..)
   # and the last element of the array will be the organism name (i.e. 
   # species name)
   my @lineage = ();
   
   if (!ref($data)) {
      # if a Tax id doesn't exist in the Taxonomy database, the string
      # "<ERROR>Empty id list - nothing todo</ERROR>" is returned and $data
      # becomes "Empty id list - nothing todo". Therefore, just return the 
      # string value of $data back to caller who can deal with it
      return $data;   
   } 
   
   foreach my $taxa (@{ $data->{Taxon}->{LineageEx}->{Taxon} } ) {
      # taxa is a hash with three keys ScientificName, TaxId, and Rank
      # I'm only saving the ScientificName but possible extensions to this
      # subroutine would be to return the TaxId and Rank as well.
      push (@lineage, $taxa->{ScientificName});
   }
   
   # add the Species to the end of the Lineage array.
   push (@lineage, $data->{Taxon}->{ScientificName});

   # lineage for Non-A non-B hepatits virus is wrong so we need to change it
   # here
   if ($id == 12440) {
      @lineage = ("Viruses", "Inoviridae", "Non-A, non-B hepatitis virus");
   }
   
   return wantarray ? return @lineage : join("; ", @lineage);
}



=head2 lineage2tfs

 Title    : lineage2tfs
 Usage    : ($type, $family, $species) = lineage2tfs($lineage);
 Function : To determine the Type, Family and Species from a Lineage
 
 Returns  : An array (type, family, species). 'Type' values are human,
            mouse, phage, virus, bacteria, fungi, and other.  If no family
            is found then family = 'NoFamily'.  Returns undef if the
            argument is NOT true
             
 Args     : String that is delimited by '; ' (i.e. Viruses; dsDNA;
            Parvoviridae).  The lineage string must go from General to
            Specific with the last field being the Species name

=cut

sub lineage2tfs {
   my $lineage = shift;  
   return undef unless ($lineage);
   
   my @taxa = split (/; /, $lineage);
   
   # check for Human or Mouse first
   my $species = pop @taxa;
   if ($species =~ /Homo sapiens/i) {
      return ("human", $NOFAMILY, $species);
   } elsif ($species =~ /Mus musculus/i) {
      return ("mouse", $NOFAMILY, $species);
   }   
   
   
   # second, check for Virus or Phage
   if ($taxa[0] eq "Viruses") {
      my $PHAGE = "phage";
      my $type = "virus";   # default to virus unless we prove it is a phage

      $type = $PHAGE if is_phage(@taxa, $species);

      # need to pass entire lineage (including species) to is_phage()
      return ($type, 
               get_virus_family(@taxa),
               $species);
   }  
   

   # third, check for Bacteria or Fungi
   foreach my $taxa (@taxa) {
      if ($taxa eq "Bacteria" || $taxa eq "Archaea") {
         return ("bacteria", $NOFAMILY, $species);
      } elsif ($taxa eq "Fungi") {
         return ("fungi", $NOFAMILY, $species);
      }
   }
   
   
   # lastly, return an 'other' type
   return ("other", $NOFAMILY, $species);
}



=head2 get_virus_family

 Title    : get_virus_family
 Usage    : $virusfamily = get_virus_family(@lineage);
 Function : Get the first 'viridae', 'virus', or 'virales' from the lineage
            array (General to Specific).
 Returns  : A string (family name)  
 Args     : An ordered array from General to Specific.  Also the array
            should not have a species name as the last element of the array
            unless the caller really wants to parse that field for a family
            name

=cut

sub get_virus_family {
   
   my @taxa = @_;
   
   my $viridae = '';
   my $virus   = '';
   my $virales = '';
   my $satellite = '';
   foreach (@taxa) {
      if (/viridae$/i) {
         $viridae = $_ unless $viridae;
      }
      if (/virus$/i) {
         $virus = $_ unless $virus;
      }
      if (/virales$/i) {
         $virales = $_ unless $virales;
      }
      if (/satellites/i) {
         $satellite = $_ unless $satellite;
      }
   }

   $viridae =~ s/^(unclassified\s+|unassigned\s+)//;
   return $viridae || $virales || $virus || $satellite || $NOFAMILY;
}


=head2 is_phage

To be done...

# argument: array containing lineage information that goes from general to
#           specific (last element must be the species name)
#
# return value: integer (1 it is a phage or 0 it is NOT a phage)
#

=cut

sub is_phage {
   my @taxa = @_;
   
   my $species = pop @taxa;
   
   # check known phage families first
   if (is_phage_family( get_virus_family(@taxa) )) {
      return 1;
   } elsif ($species =~ /phage/i) {
      # will catch phages that are "NoFamily" and have 'phage' in their species name
      return 1;
   } else {
      foreach (@taxa) {
         if ($_ eq "unclassified phages") {  # this is for those phages that don't have "phage" in their species name (i.e. Geobacillus virus E2)
            return 1;
         }
      }
   }
   
   return 0;
}


=head2 is_phage_family

To be done...

# argument: string (family name)
#
# return value: 1 if the argument is a Phage family
#               0 if the argument is not a Phage family
#               undef if the argument is not TRUE

=cut

sub is_phage_family {
   my @PHAGEFAMS = qw/Bicaudaviridae
                        Caudovirales
                        Corticoviridae
                        Cystoviridae
                        Fuselloviridae
                        Globuloviridae
                        Guttaviridae
                        Inoviridae
                        Leviviridae
                        Lipothrixviridae
                        Microviridae
                        Myoviridae
                        Plasmaviridae
                        Podoviridae
                        Rudiviridae
                        Siphoviridae
                        Tectiviridae/;

   my $family = shift;   
   return undef unless ($family);

   foreach (@PHAGEFAMS) {
      return 1 if ($_ eq ucfirst $family);
   }
   return 0;
}


=head2 get_genome_type

To be done...
# argument: string (family name)
#
# return value: string (if family is not found or is "NoFamily", returns
#                      "Unknown")
#

=cut

sub get_genome_type {
   my $UNKNOWN = "Unknown";

   my %vf2genome = (Adenoviridae => 'dsDNA,linear,nonsegmented',
                  Alloherpesviridae => 'dsDNA,linear,nonsegmented',
                  Alphaflexiviridae => 'ssRNA(+),linear,nonsegmented',
                  Anelloviridae => 'ssDNA,circular,nonsegmented',
                  Ascoviridae => 'dsDNA,circular,nonsegmented',
                  Asfarviridae => 'dsDNA,linear,nonsegmented',
                  Astroviridae => 'ssRNA(+),linear,nonsegmented',
                  Bacillariornaviridae => 'ssRNA(+),linear,nonsegmented',
                  Baculoviridae => 'dsDNA,circular,nonsegmented',
                  Betaflexiviridae => 'ssRNA(+),linear,nonsegmented',
                  Bicaudaviridae => 'dsDNA,circular,nonsegmented',
                  Bromoviridae => 'ssRNA(+),linear,segmented',
                  Bunyaviridae => 'ssRNA(-),linear,segmented',
                  Caliciviridae => 'ssRNA(+),linear,nonsegmented',
                  Caudovirales => 'dsDNA,linear,nonsegmented',
                  Circoviridae => 'ssDNA,circular,nonsegmented',
                  Closteroviridae => 'ssRNA(+),linear,nonsegmented',
                  Corticoviridae => 'dsDNA,circular,nonsegmented',
                  Cystoviridae => 'dsRNA,linear,segmented',
                  Dicistroviridae => 'ssRNA(+),linear,nonsegmented',
                  Fuselloviridae => 'dsDNA,circular,nonsegmented',
                  Geminiviridae => 'ssDNA,circular,both',
                  Globuloviridae => 'dsDNA,linear,nonsegmented',
                  Guttaviridae => 'dsDNA,circular,nonsegmented',
                  Hepeviridae => 'ssRNA(+),linear,nonsegmented',
                  Herpesviridae => 'dsDNA,linear,nonsegmented',
                  Iflaviridae => 'ssRNA(+),linear,nonsegmented',
                  Inoviridae => 'ssDNA,circular,nonsegmented',
                  Iridoviridae => 'dsDNA,linear,nonsegmented',
                  Labyrnaviridae => 'ssRNA(+),linear,nonsegmented',
                  Leviviridae => 'ssRNA(+),linear,nonsegmented',
                  Lipothrixviridae => 'dsDNA,linear,nonsegmented',
                  Luteoviridae => 'ssRNA(+),linear,nonsegmented',
                  Marnaviridae => 'ssRNA(+),linear,nonsegmented',
                  Microviridae => 'ssDNA,linear,nonsegmented',
                  Mimiviridae => 'dsDNA,linear,nonsegmented',
                  Myoviridae => 'dsDNA,linear,nonsegmented',
                  Nanoviridae => 'ssDNA,circular,nonsegmented',
                  Nimaviridae => 'dsDNA,circular,nonsegmented',
                  Nodaviridae => 'ssRNA(+),linear,segmented',
                  NoFamily => 'Unknown',
                  Nudivirus => 'dsDNA,circular,nonsegmented',
                  Ourmiavirus => 'ssRNA(+),linear,segmented',
                  Papillomaviridae => 'dsDNA,circular,nonsegmented',
                  Partitiviridae => 'dsRNA,linear,segmented',
                  Parvoviridae => 'ssDNA,linear,nonsegmented',
                  Phycodnaviridae => 'dsDNA,linear,nonsegmented',
                  Picobirnaviridae => 'dsRNA,linear,segmented',
                  Picornavirales => 'ssRNA(+),linear,nonsegmented',
                  Picornaviridae => 'ssRNA(+),linear,nonsegmented',
                  Plasmaviridae => 'dsDNA,circular,nonsegmented',
                  Podoviridae => 'dsDNA,linear,nonsegmented',
                  Polyomaviridae => 'dsDNA,circular,nonsegmented',
                  Potyviridae => 'ssRNA(+),linear,nonsegmented',
                  Poxviridae => 'dsDNA,linear,nonsegmented',
                  Retroviridae => 'ssRNA(+),linear,nonsegmented',
                  Rudiviridae => 'dsDNA,linear,nonsegmented',
                  Satellites => 'Unknown',
                  Secoviridae => 'ssRNA(+),linear,segmented',
                  Siphoviridae => 'dsDNA,linear,nonsegmented',
                  Sobemovirus => 'ssRNA(+),linear,nonsegmented',
                  Tectiviridae => 'dsDNA,linear,nonsegmented',
                  Tetraviridae => 'ssRNA(+),linear,nonsegmented',
                  Tobamovirus => 'ssRNA(+),linear,nonsegmented',
                  Tombusviridae => 'ssRNA(+),linear,nonsegmented',
                  Totiviridae => 'dsRNA,linear,nonsegmented',
                  Tymoviridae => 'ssRNA(+),linear,nonsegmented',
                  Umbravirus => 'ssRNA(+),linear,nonsegmented',
                  Virgaviridae => 'ssRNA(+),linear,nonsegmented',
               );

   my $family = shift @_;
   return undef unless ($family);
   
   return $vf2genome{$family} if (exists $vf2genome{$family});
   
   return $UNKNOWN;
}


=head1 Internal methods

There are internal methods to Taxonomy

=cut

=head2 _foo


=cut


1;




