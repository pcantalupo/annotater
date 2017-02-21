#
# Module for Taxonomy methods
#
# Please direct questions and support issues to <pcantalupo@gmail.com>
#
# Maintained by Paul Cantalupo <pcantalupo-at-gmail-dot-com>
#
# Copyright Paul Cantalupo
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

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
Taxid (i.e.  Viruses; ssRNA viruses; Virgaviridae; Tobamovirus; PepperMild
Mottle virus).

Taxonomy can also tell if a sequence is Virus, Phage, Bacteria, Human,
Mouse, etc.  Additionally, it knows the Genome type for each virus family.

Taxonomy relies upon NCBI's Eutils for data retrieval so you need to have an
Internet connection for those functions to work.

=head1 FEEDBACK

=head2 Support

Please direct usage questions or bugs to I<pcantalupo-at-gmail-dot-com>

=head1 AUTHOR - Paul Cantalupo

Email pcantalupo-at-gmail-dot-com

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

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal
methods are usually preceded with a _

=cut

#
# Let the code begin...


package Taxonomy;
use strict;
use warnings;

use Bio::DB::EUtilities;
use XML::Simple;
use Exporter;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(gi2taxid
                  taxid2lineage
                  gi2lineage
                  accession2gi
                  gi2acc
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
 Errors   : When submitting a malformed request (i.e. an invalid accession 
            number like 'XYZ', method will throw an error and exit)

=cut


sub accession2gi {
   # example URI that BioPerl sends to efetch for gb|J02400| (i.e. SV40)
   # "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide
   # &retmode=text&id=gb%7CJ02400.1%7C&rettype=gi&tool=BioPerl&email=pcantalupo%40gmail.com"

   my ($acc) = @_; 
   return unless ($acc);

   my $factory = Bio::DB::EUtilities->new(-eutil => 'efetch',
                                          -db => 'nucleotide',  # don't need to change this to Protein for protein accessions, it seems to work fine by keeping it set to 'nucleotide'
                                          -id => [ $acc ],
                                          -email => 'pcantalupo@gmail.com',
                                          -rettype => 'gi');
   my $gi = $factory->get_Response->content;

   chomp $gi;
   return $gi;
}   


=head2 gi2acc

 Title    : gi2acc
 Usage    : $acc = gi2acc(965480);
 Function : Returns an accession.version from a GI number
 Returns  : A scalar (Acc.Version value)
 Args     : a GI number

=cut

sub gi2acc {
   my ($gi) = @_;
   return unless ($gi);

   my $factory = Bio::DB::EUtilities->new(-eutil => 'efetch',
                                          -db => 'nucleotide',  # don't need to change this to Protein for protein accession, it works ok keeping set to 'nucleotide'
                                          -id => [ $gi ],
                                          -email => 'pcantalupo@gmail.com',
                                          -rettype => 'acc');
   my $acc = $factory->get_Response->content;

   chomp $acc;
   return $acc;
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
   return unless ($gi);
   
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
   }
   return;    # No item called 'TaxID' existed in the XML document or no DocSums in factory
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
   return unless ($id);
   
   my $factory = Bio::DB::EUtilities->new(-eutil => 'efetch',
                                          -db    => 'taxonomy',
                                          -email => 'pcantalupo@gmail.com',
                                          -id    => [ $id ],
                                          );

   my $res = $factory->get_Response->content;
   my $data = XMLin($res);   
   if (!ref($data)) {
      # if a Tax id doesn't exist in the Taxonomy database, the string
      # "<ERROR>Empty id list - nothing todo</ERROR>" is returned and $data
      # becomes "Empty id list - nothing todo". Therefore, just return the 
      # string value of $data back to caller who can deal with it
      return $data;   
   } 

   # Lineage tag in XML has a value that matches structure of the ORGANISM
   # field in Genbank records  (i.e.  Viruses; dsDNA viruses; Polyomaviridae,
   # etc..). If there is no Lineage, the value is a HASH ref that points to an
   # empty hash.
   my $lineage;
   unless (ref $data->{Taxon}->{Lineage}) {
      $lineage = $data->{Taxon}->{Lineage};
   }
   # add the Species to the end of lineage.
   $lineage = ($lineage) ?
               join("; ", $lineage, $data->{Taxon}->{ScientificName} ) :
               $data->{Taxon}->{ScientificName};

   # lineage for Non-A non-B hepatits virus is wrong so we need to change it
   # here
   if ($id == 12440) {
      $lineage = join("; ", "phage", "Inoviridae", "Non-A, non-B hepatitis virus");
   }
   
   return wantarray ? split(/; /, $lineage) : $lineage;
}


=head2 gi2lineage

 Title    : gi2lineage
 Usage    : $lineage  = gi2lineage('965480');
 Function : Returns the lineage of a GI. Acts as a wrapper around gi2taxid
            and taxid2lineage
 Returns  : List context: an array containing the lineage information from General to Specific
            Scalar context: elements of the array are joined with '; ' (mind the space)

            If cannot get Taxid or Lineage, returns "".
            If argument to subroutine is NOT true (i.e. '', 0, undef), returns undef
             
 Args     : a GI number
 
=cut


sub gi2lineage {
   my ($gi) = @_;
   return unless ($gi);

   my @lineage = ();
   
   my $taxid;
   do {
      undef $@;
      eval { $taxid = gi2taxid($gi); };   # gi2taxid from this module
   } while ($@);
   
   unless (defined $taxid) {
      print STDERR $_, "\tError: No Taxid found\n";
      return "";
   }
   
   do {
      undef $@;
      eval { @lineage = taxid2lineage($taxid); };   # taxid2lineage from this module
   } while ($@);

   if ($lineage[0] =~ /^Empty id list|Error occurred/) {
      chomp $lineage[0];
      print STDERR "gi2lineage: Problem getting lineage for taxid $taxid: $lineage[0]\n";
      return "";
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
   return unless ($lineage);

   my @taxa = split (/; /, $lineage);   
   my $species     = $taxa[-1];

   # Improperly classified agents list
   my %bad = ( "Non-A, non-B hepatitis virus" =>
                     [ "phage", "Inoviridae", "Non-A, non-B hepatitis virus" ],
               "Helicobacter pylori GAMchJs117Ai" =>
                     [ "phage", "Microviridae", "Enterobacteria phage phiX174" ],
               "Helicobacter pylori GAMchJs114i" =>
                     [ "phage", "Microviridae", "Enterobacteria phage phiX174" ],
            );

   if (exists $bad{$species}) {
      return @{$bad{$species}};
   }

   # Check for Virus or Phage
   if ($taxa[0] =~ /Viruses/i || $taxa[0] =~ /Viroids/i) {
      my $PHAGE = "phage";
      my $type = "virus";   # default to virus unless we prove it is a phage

      $type = $PHAGE if is_phage(@taxa);
      
      return ($type, 
               get_virus_family(@taxa[0..$#taxa-1]),
               $species);
   }  

   # Check for Bacteria/Archaea
   if ($taxa[1] eq "Bacteria") {
      return ("bacteria", $NOFAMILY, $species);
   } elsif ($taxa[1] eq "Archaea") {
      return ("archaea", $NOFAMILY, $species);
   }
     
   # Check for Human and Fungi
   # 1. check for human
   if ($species =~ /Homo sapiens/i) {
      return ("human", $NOFAMILY, $species);
   }
   
   # 2. check for fungi
   foreach my $taxa (@taxa) {
      if ($taxa eq "Fungi") {
         return ("fungi", $NOFAMILY, $species);
      }
   }
         
   # Return 'other' type for the 'Other', and 'Unclassified'
   # kingdoms plus the subset of Eukaryota that are not Human or Fungi
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

 Title    : is_phage
 Usage    : $isphage = is_phage(@lineage)
 Function : To determine if the lineage of organism is a phage or not.
 Returns  : An integer - 1 it is a phage or 0 it is NOT a phage
 Args     : Array containing lineage information that goes from general to
            specific (last element must be the species name)

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

 Title    : is_phage_family
 Usage    : $isphagefamily = is_phage_family($familyname)
 Function : Determines if the string argument is a phage family or not.
 Returns  : An integer - 1 if the argument is a phage family or 0 if not.
 Args     : A string (virus family name)

=cut

sub is_phage_family {
   my $family = shift;   
   return unless ($family);

   my @PHAGEFAMS = qw/  Ampullaviridae
                        Bicaudaviridae
                        Caudovirales
                        Clavaviridae
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
                        Pleolipoviridae
                        Podoviridae
                        Rudiviridae
                        Siphoviridae
                        Sphaerolipoviridae
                        Tectiviridae
                        Turriviridae/;


   foreach (@PHAGEFAMS) {
      return 1 if ($_ eq ucfirst $family);
   }
   return 0;
}


=head2 get_genome_type

 Title    : get_genome_type
 Usage    : $genometype = get_genome_type("Adenoviridae")
 Function : Obtain the genome type of the argument
 Returns  : A string - if family is not found or is "NoFamily", returns "Unknown"
 Args     : A string (virus family name)
 
=cut

sub get_genome_type {
   my $family = shift;
   return unless ($family);

   my $UNKNOWN = "Unknown";

   my %vf2genome = (
                  # unknown
                  NoFamily => 'Unknown',
                  Satellites => 'Unknown',
                
                  # ssDNA
                  Anelloviridae 	=> 'ssDNA,circular,nonsegmented',
                  Circoviridae 		=> 'ssDNA,circular,nonsegmented',
                  Geminiviridae 	=> 'ssDNA,circular,both',
                  Inoviridae 		=> 'ssDNA,circular,nonsegmented',
                  Microviridae 		=> 'ssDNA,linear,nonsegmented',
                  Nanoviridae 		=> 'ssDNA,circular,nonsegmented',
                  Parvoviridae		=> 'ssDNA,linear,nonsegmented',

                  # dsDNA
                  Adenoviridae 		=> 'dsDNA,linear,nonsegmented',
                  Alloherpesviridae 	=> 'dsDNA,linear,nonsegmented',
                  Ascoviridae 		=> 'dsDNA,circular,nonsegmented',
                  Asfarviridae 		=> 'dsDNA,linear,nonsegmented',
                  Baculoviridae 	=> 'dsDNA,circular,nonsegmented',
                  Bicaudaviridae 	=> 'dsDNA,circular,nonsegmented',
                  Caudovirales		=> 'dsDNA,linear,nonsegmented',
                  Caulimoviridae 	=> 'dsDNA,circular,nonsegmented',
                  Corticoviridae 	=> 'dsDNA,circular,nonsegmented',
                  Fuselloviridae 	=> 'dsDNA,circular,nonsegmented',
                  Globuloviridae 	=> 'dsDNA,linear,nonsegmented',
                  Guttaviridae   	=> 'dsDNA,circular,nonsegmented',
                  Herpesviridae 	=> 'dsDNA,linear,nonsegmented',
                  Hepadnaviridae        => 'dsDNA,circular,nonsegmented',
                  Hytrosaviridae        => 'dsDNA,circular,nonsegmented',
                  Iridoviridae 		=> 'dsDNA,linear,nonsegmented',
                  Lipothrixviridae 	=> 'dsDNA,linear,nonsegmented',
                  Marseilleviridae      => 'dsDNA,circular,nonsegmented',
                  Mimiviridae 		=> 'dsDNA,linear,nonsegmented',
                  Myoviridae 		=> 'dsDNA,linear,nonsegmented',
                  Nimaviridae 		=> 'dsDNA,circular,nonsegmented',
                  Nudiviridae           => 'dsDNA,circular,nonsegmented',
                  Nudivirus 		=> 'dsDNA,circular,nonsegmented',
                  Papillomaviridae 	=> 'dsDNA,circular,nonsegmented',
                  Phycodnaviridae 	=> 'dsDNA,linear,nonsegmented',
                  Plasmaviridae 	=> 'dsDNA,circular,nonsegmented',
                  Podoviridae 		=> 'dsDNA,linear,nonsegmented',
                  Polydnaviridae 	=> 'dsDNA,circular,segmented',
                  Polyomaviridae 	=> 'dsDNA,circular,nonsegmented',
                  Poxviridae 		=> 'dsDNA,linear,nonsegmented',
                  Rudiviridae 		=> 'dsDNA,linear,nonsegmented',
                  Siphoviridae 		=> 'dsDNA,linear,nonsegmented',
                  Sphaerolipoviridae =>'dsDNA,linear/circular,nonsegmented',
                  Tectiviridae 		=> 'dsDNA,linear,nonsegmented',
                  Turriviridae 		=> 'dsDNA,linear,nonsegmented',

                  # dsRNA
                  Cystoviridae 		=> 'dsRNA,linear,segmented',
                  Partitiviridae 	=> 'dsRNA,linear,segmented',
                  Picobirnaviridae 	=> 'dsRNA,linear,segmented',
                  Reoviridae		=> 'dsRNA,linear,segmented',
                  Totiviridae 		=> 'dsRNA,linear,nonsegmented',

                  # ssRNA(+)
                  Alphaflexiviridae 	=> 'ssRNA(+),linear,nonsegmented',
                  Astroviridae 		=> 'ssRNA(+),linear,nonsegmented',
                  Bacillariornaviridae 	=> 'ssRNA(+),linear,nonsegmented',
                  Betaflexiviridae 	=> 'ssRNA(+),linear,nonsegmented',
                  Bromoviridae 		=> 'ssRNA(+),linear,segmented',
                  Caliciviridae 	=> 'ssRNA(+),linear,nonsegmented',
                  Closteroviridae 	=> 'ssRNA(+),linear,nonsegmented',
                  Dicistroviridae 	=> 'ssRNA(+),linear,nonsegmented',
                  Flaviviridae 		=> 'ssRNA(+),linear,nonsegmented',    
                  Hepeviridae 		=> 'ssRNA(+),linear,nonsegmented',                
                  Iflaviridae 		=> 'ssRNA(+),linear,nonsegmented',
                  Labyrnaviridae 	=> 'ssRNA(+),linear,nonsegmented',
                  Leviviridae 		=> 'ssRNA(+),linear,nonsegmented',
                  Luteoviridae		=> 'ssRNA(+),linear,nonsegmented',
                  Marnaviridae 		=> 'ssRNA(+),linear,nonsegmented',
                  Nodaviridae 		=> 'ssRNA(+),linear,segmented',
                  Ourmiavirus 		=> 'ssRNA(+),linear,segmented',
                  Picornavirales 	=> 'ssRNA(+),linear,nonsegmented',
                  Picornaviridae 	=> 'ssRNA(+),linear,nonsegmented',
                  Potyviridae 		=> 'ssRNA(+),linear,nonsegmented',
                  Retroviridae 		=> 'ssRNA(+),linear,nonsegmented',
                  Secoviridae 		=> 'ssRNA(+),linear,segmented',
                  Sobemovirus 		=> 'ssRNA(+),linear,nonsegmented',
                  Tetraviridae		=> 'ssRNA(+),linear,nonsegmented',
                  Tobamovirus 		=> 'ssRNA(+),linear,nonsegmented',
                  Tombusviridae 	=> 'ssRNA(+),linear,nonsegmented',
                  Tymoviridae 		=> 'ssRNA(+),linear,nonsegmented',
                  Umbravirus 		=> 'ssRNA(+),linear,nonsegmented',
                  Virgaviridae		=> 'ssRNA(+),linear,nonsegmented',
                  
                  # ssRNA(-)
                  Arenaviridae		=> 'ssRNA(-),linear,segmented',
                  Bornaviridae 		=> 'ssRNA(-),linear,nonsegmented',
                  Bunyaviridae 		=> 'ssRNA(-),linear,segmented',
                  Filoviridae		=> 'ssRNA(-),linear,nonsegmented',
                  Orthomyxoviridae	=> 'ssRNA(-),linear,segmented',
                  Rhabdoviridae 	=> 'ssRNA(-),linear,nonsegmented',
                  Paramyxoviridae	=> 'ssRNA(-),linear,nonsegmented',
               );

   
   return $vf2genome{$family} if (exists $vf2genome{$family});
   
   return $UNKNOWN;
}


=head1 Internal methods

There are internal methods to Taxonomy

=cut

=head2 _foo


=cut


1;




