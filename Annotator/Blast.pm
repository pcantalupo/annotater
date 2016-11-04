=head1 NAME

TEMPLATE - The great new TEMPLATE!

=head1 VERSION

Version 0.01


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Annotator::Blast;

    my $foo = Annotator::Blast->new();
    ...


=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.


=head1 AUTHOR

Paul Cantalupo, C<< <pcantalupo at gmail.com> >>


=head1 BUGS

Please report any bugs or feature requests to C<bug-template at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TEMPLATE>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TEMPLATE


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



# let the coding begin...

package Annotator::Blast;

use 5.006;
use strict;
use warnings # FATAL => 'all';

our (@SWITCHES, %OK_FIELD, %COLS, $AUTOLOAD);
our $VERSION = '0.01';

use parent qw(Bio::Root::Root);

BEGIN {
  @SWITCHES = qw(BLAST); 
  # Authorize attribute fields
  foreach my $attr ( @SWITCHES ) {  $OK_FIELD{$attr}++;  }

  %COLS = ('qname'   => 0,
            'sname'  => 1,
            'pid'    => 2,
            'hsplen' => 3,
            'mis'    => 4,
            'gap'    => 5,
            'qs'     => 6,
            'qe'     => 7,
            'ss'     => 8,
            'se'     => 9,
            'evalue' => 10,
            'bs'     => 11,
            'qlen'   => 12,
            'slen'   => 13,
            );
}


=head2 function1

Title   : new
Usage   : $ab->new(blast => [ $blast, $blast2 ], -verbose => 1)
              use -verbose (mind the '-') for Bio::Root::Root.pm
Function:
Returns : 
Args    : self

=cut

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);

  my ($attr, $value);
  while (@args) {
    $attr = shift @args;
    $value = shift @args;
    next if ($attr =~ /^-/);
    $self->$attr($value);
  }
  
  foreach my $blast (@{$self->{BLAST}}) {
    next if ($blast eq '-');
    unless ($blast && -e $blast) {
      $self->throw("Specify a proper blast output file with 'blast => \$file'");
    }
  }
    
  return $self;
}


=head2 runfilter

Usage    : $ab->runfilter(qc => 90, pid => 80, evalue => 1e-5, ids => [ foo,bar,... ]);
=cut

sub runfilter {
  my ($self, %args) = @_;

  foreach my $blast (@{$self->{BLAST}}) {
    my $fh;
    if ($blast eq '-') {
      $fh = \*STDIN;
    }
    else {
      open ($fh, "<", $blast);
    }

    while (<$fh>) {
      chomp;
      my @fields = split (/\t/, $_);
      my $queryid = $fields[0];
      
      my $passed = 1;
      foreach (keys %args) {
        if ($_ eq 'evalue') {
          if ($fields[$COLS{$_}] > $args{$_}) {
            $passed = 0;
            last;
          }
        }
        elsif ($_ eq 'pid') {
          if ($fields[$COLS{$_}] < $args{$_}) {
            $passed = 0;
            last;
          }
        }
        elsif ($_ eq 'qc') {
          my $qc = $fields[$COLS{hsplen}]/$fields[$COLS{qlen}]*100;
          if ($qc < $args{$_}) {
            $passed = 0;
            last;
          }
        }
      }
      if ($passed == 1) {
        print $_, "\n" if ($args{STDOUT});
        push (@{$self->{PASSED}{$queryid}}, $_);
      }
      elsif ($args{STDERR}) {
        print STDERR $_, "\n";
      }
    }
  }  
}


=head2

Usage
=cut

sub passfilter {
  my ($self, $id) = @_;
  
  (exists $self->{PASSED}{$id}) ? return 1 : return 0;
}


sub AUTOLOAD {
  my $self = shift;
  my $attr = $AUTOLOAD;
  $attr =~ s/.*:://;
  $attr = uc $attr;
  $self->throw("Unallowed parameter: $attr !") unless $OK_FIELD{$attr};
  $self->{$attr} = shift if @_;
  return $self->{$attr};
}



1;
