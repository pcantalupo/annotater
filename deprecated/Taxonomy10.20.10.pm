#!/usr/bin/perl -w

# Taxid's of some common organisms (This library doesn't use these but I'm
# keeping this info here for future reference)
# 	Bacteria 2
# 	Archaea 2157
# 	Homo sapiens 9606
# 	Mus musculus 10090
# 	Fungi 4751 (cellular organisms; Eukaryota; Fungi/Metazoa group; Fungi;)

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


# argument: fasta identifier (format: gb|J02400|) or can be a genbank
# accession number.  May not work with all non-genbank accession numbers. 
# For example, it does not work with naked PDB accession numbers like 2FL8
# but OK if it is the full fasta identifier: pdb|2FL8|A

# return value: GI number 
#               undef when argument is NOT TRUE (i.e. '', 0, undef)
#               empty string when no GI is found
#
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


# argument: GI number

# return value: Taxonomy database ID
# return value can be undef if the Taxid of the gi record is empty or if
# there is no TaxId item in the Document summary or if no GI was given when
# subroutine was called
#
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

# argument: Taxonomy database ID
#
# return value: list context: an array containing the lineage information from General to Specific
#               scalar context: elements of the array are joined with '; '
#
#               if the Tax ID is not found, returns "Empty id list - nothing todo"
#               undef if the argument is NOT true (i.e. '', 0, undef)
#
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



# argument: is a string that is delimited by '; ' (i.e. Viruses; dsDNA;
# Parvoviridae).  The lineage string must go from General to Specific with
# the last field being the Species name

# returns value: an array (type, family, species)
#         type   - values are human, mouse, phage, virus, bacteria, fungi, other
#         family - if no family is found family = 'NoFamily'
#
#         undef if the argument is NOT true
# 
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


# function: Get the first 'viridae', 'virus', or 'virales' from the lineage
#           array (General to Specific).  Therefore, we assume that caller
#           has ordered the array from General to Specific.  Also the array
#           should not have a species name as the last element of the array
#           unless the caller really wants to parse that field for a family
#           name
#
# argument: an array
#
# return value: string (family name)
#
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


# argument: array containing lineage information that goes from general to
#           specific (last element must be the species name)
#
# return value: integer (1 it is a phage or 0 it is NOT a phage)
#
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


# argument: string (family name)
#
# return value: 1 if the argument is a Phage family
#               0 if the argument is not a Phage family
#               undef if the argument is not TRUE
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


# argument: string (family name)
#
# return value: string (if family is not found or is "NoFamily", returns
#                      "Unknown")
#
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
1;

=head1 Taxonomy.pm

=head2 accession2gi

argument: genbank accession (format: gb|J02400|), May not work with all non-genbank accession numbers. For example, it does not work with naked PDB accession numbers like 2FL8 but OK if it is the full fasta identifier: pdb|2FL8|A

Return value: GI number OR
               undef when argument is NOT TRUE (i.e. '', 0, undef) OR
               empty string when no GI is found

=head2 gi2taxid

Arguement: GI number
return value: Taxonomy database ID
return value can be undef if the Taxid of the gi record is empty or if
there is no TaxId item in the Document summary or if no GI was given when
subroutine was called

=head2 taxid2lineage

argument: Taxonomy database ID
return value: list context: an array containing the lineage information from General to
               scalar context: elements of the array are joined with '; '

               if the Tax ID is not found, returns "Empty id list - nothing todo"
               undef if the argument is NOT true (i.e. '', 0, undef)

=head2 lineage2tfs

argument: is a string that is delimited by '; ' (i.e. Viruses; dsDNA;
Parvoviridae).  The lineage string must go from General to Specific with
the last field being the Species name

returns value: an array (type, family, species) OR
         type   - values are human, mouse, phage, virus, bacteria, fungi, other OR
         family - if no family is found family = 'NoFamily' OR
         undef if the argument is NOT true.


=cut




