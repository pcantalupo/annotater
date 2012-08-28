#!/usr/bin/perl -w
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
                  is_phage_family
                  get_genome_type
                  );


# GLOBALS

my $NOFAMILY = "NoFamily";




sub accession2gi {
   # here is an example of the URL that this subroutine will send:
   # http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&retmode=text&id=J02400&rettype=gi&tool=BioPerl&email=pcantalupo%40gmail.com

   my ($acc) = $_;

   my $factory = Bio::DB::EUtilities->new(-eutil => 'efetch',
                                          -db => 'nucleotide',
                                          -id => [ $acc ],
                                          -email => 'pcantalupo@gmail.com',
                                          -rettype => 'gi');
   my $gi = $factory->get_Response->content;
   chomp $gi;

   return $gi;
}   


# returns the taxid for given gi and database (default db is nucleotide)
# return value can be undef if the Taxid of the gi record is empty or if
# there is no TaxId item in the Document summary or if no GI was given when
# subroutine was called
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
      
      return undef;
   }
}

# if no lineage is returned (i.e. $data is not a reference), the
# string value of $data is returned 
sub taxid2lineage {
   # here is an example of the URL that this subroutine will send:
   # http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=10633&email=pcantalupo%40gmail.com&retmode=xml
   # taxid = 10633 is SV40
   
   my ($id) = @_;
   
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
      # sometimes $data is not a Hash ref but is a string that starts with "Empty id list"
      return wantarray ? ("data") : $data;   
   } 
   
   foreach my $taxa (@{ $data->{Taxon}->{LineageEx}->{Taxon} } ) {
      # taxa is a hash with three keys ScientificName, TaxId, and Rank
      push (@lineage, $taxa->{ScientificName});
   }
   push (@lineage, $data->{Taxon}->{ScientificName});

   return wantarray ? return @lineage : join("; ", @lineage);
}



# Argument is a string that is delimited by '; ' (i.e. Viruses; dsDNA;
# Parvoviridae).  The lineage string must go from General to Specific with
# the last field being the Species name

# returns
# - type (human, mouse, phage, virus, bacteria, fungi, other)
# - family (viridae
# - species
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
      my $type = "virus";   # default type is 'virus' until we prove that it is a phage
      
      my $family = get_virus_family(@taxa);

      # Check to see if this virus is a Phage
      if (is_phage_family($family)) {
         $type = $PHAGE;
      } elsif ($species =~ /phage/i) {
         # even if it is not a phage family (i.e. NoFamily), it could still
         # be an unclassified phage
         $type = $PHAGE;
      } else {
         foreach (@taxa) {
            if ($_ eq "unclassified phages") {  # this is for those phages that don't have "phage" in their species name (i.e. Geobacillus virus E2)
               $type = $PHAGE;
            }
         }
      }
            
      return ($type, $family, $species);
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


sub get_virus_family {
   # Get the first 'viridae', 'virus', or 'virales' from the lineage array
   # (General to specific).  Therefore, we assume that caller has ordered the
   # array from General to Specific
   
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


# returns 1 if the argument is a Phage family
#         0 if the argument is not a Phage family
#         undef if the argument is not TRUE
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

   my $family = shift;
   return undef unless ($family);
   
   return $vf2genome{$family} if (exists $vf2genome{$family});
   
   return $UNKNOWN;
}








1;
