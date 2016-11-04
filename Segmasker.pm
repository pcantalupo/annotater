package Segmasker;

use 5.006;
use strict;
use warnings # FATAL => 'all';
use Bio::SeqIO;
use File::Temp qw/tempfile/;

=head1 NAME

Segmasker - Run segmasker

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Segmasker

    my $foo = Segmasker->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {
  my ($class, @args) = @_;
  my $self = {};
  $self->{program} = 'segmasker';
  bless $self, $class;
  return $self;
}


=head2 run

=cut

sub run {
  my ($self, $seq) = @_;
    
  if (-e $seq) {   # is $seq a file?
    $self->{seqfile} = $seq;
  }
  else {           # $seq is not a file to write a temp file containing this protein sequence
    my ($fh, $filename) = tempfile("tempXXXXXX", SUFFIX => ".fa", DIR => '.');
    $self->{fh} = $fh;
    $self->{seqfile} = $filename;
  
    chomp $seq;  
    my $protein_seq = ">$filename\n$seq\n";
    print {$fh} $protein_seq;
    close $fh;
  }
  
  # get length of the protein sequence
  my $seqio = Bio::SeqIO->new(-file => $self->{seqfile});
  my $mm = $seqio->next_seq();
  $self->{length} = $mm->length();
  $self->{id} = $mm->primary_id();

  # run segmasker  
  my $command = $self->{program} . " -in " . $self->{seqfile} . " -infmt fasta";
  $self->{result} = `$command`;
  
  # process results
  my $masked_ranges;
  my $nmasked = 0;
  while ($self->{result} =~ /((\d+) - (\d+))/gm) {
    $nmasked += ($3-$2+1);
    push (@$masked_ranges, $1);
  }
  return $self->{id}, $nmasked/$self->{length} * 100, $nmasked, $self->{length}, $masked_ranges;
}

=head2 DESTROY

=cut

sub DESTROY {
  my $self = shift;
  if ($self->{fh}) {
    close $self->{fh};
    unlink $self->{seqfile};
  }
}



=head1 AUTHOR

Paul Cantalupo, C<< <pcantalupo at gmail.com> >>

=head1 BUGS


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Segmasker


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Paul Cantalupo.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Segmasker
