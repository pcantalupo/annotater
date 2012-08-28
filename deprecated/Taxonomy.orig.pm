#!/usr/bin/perl -w
package Taxonomy;

use strict;
use Bio::DB::EUtilities;
use XML::Simple;
use Exporter;
our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(gi2taxid taxid2classification accession2gi);


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

# if no classification is returned (i.e. $data is not a reference), the
# string value of $data is returned 
sub taxid2classification {
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

   # build classification array to match structure of the ORGANISM field in
   # Genbank records (i.e.  Viruses; dsDNA viruses; Polyomaviridae, etc..)
   # and the last element of the array will be the organism name (i.e. 
   # species name)
   my @classification =();
   
   if (!ref($data)) {
      # sometimes $data is not a Hash ref but is a string that starts with "Empty id list"
      return wantarray ? ("data") : $data;   
   } 
   
   foreach my $taxa (@{ $data->{Taxon}->{LineageEx}->{Taxon} } ) {
      # taxa is a hash with three keys ScientificName, TaxId, and Rank
      push (@classification, $taxa->{ScientificName});
   }
   push (@classification, $data->{Taxon}->{ScientificName});

   return wantarray ? return @classification : join("; ", @classification);
}

1;

