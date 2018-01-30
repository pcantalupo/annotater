=head1 NAME

TEMPLATE - The great new TEMPLATE!

=head1 VERSION

Version 0.01


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Annotator::Report;

    my $foo = Annotator::Report->new();
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

package Annotator::Report;

use 5.006;
use strict;
use warnings; # FATAL => 'all';
use List::Util qw/min/;
use File::Temp qw/tempfile/;
use File::Spec;

our (@SWITCHES, %OK_FIELD, %COLS, $AUTOLOAD);
our $TEMP_ENTROPYFH = "temp_fh";
our $TEMP_ENTROPYFILE = "temp_file";
our $VERSION = '0.01';

use parent qw(Bio::Root::Root);

BEGIN {
  @SWITCHES = qw(REPORT NOTAX HEADER REFSEQS);
  # Authorize attribute fields
  foreach my $attr ( @SWITCHES ) {  $OK_FIELD{$attr}++;  }

  %COLS = ('seqID'    => 1,
            'seq'       => 2,
            'seqLength' => 3,
            'pid'       => 4,
            'coverage'  => 5,
            'e'         => 6,
            'accession' => 7,
            'desc'	=> 8,
            'type'	=> 9,
            'family'	=> 10,
            'species'	=> 11,
            'genome'	=> 12,
            'algorithm'	=> 13,
            'db'	=> 14,
            'qstart'	=> 15,
            'qend'	=> 16,
            'sstart'	=> 17,
            'ssend'	=> 18,
            );
}


=head2 function1

Title   : new
Usage   : $ar->new(report => $reportfile, -verbose => 1)
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

  unless ($self->{REPORT} && -e $self->{REPORT}) {
    $self->throw("Specify a proper report file with 'report => \$file'");
  }

  # check if header row is present in report file
  open (my $in, "<", $self->{REPORT});
  my $fl = <$in>;
  if ($fl =~ /\bseqID\b/) {
    $self->{HEADER} = 1;
  }
  close ($in);

  return $self;
}


=head2 run_entropy

=cut

sub run_entropy {
  my ($self, @args) = @_;

  my ($attr, $value);
  while (@args) {
    $attr = shift @args;
    $value = shift @args;
    $self->$attr($value);
  }

  my $error = 0;
  if (exists $self->{REFSEQS}) {
    foreach my $db (keys %{$self->{REFSEQS}}) {
      if (!-e $self->{REFSEQS}{$db}) {
        $error = 1;
        last;
      }
      $self->{REFSEQS}{$db} = File::Spec->canonpath( $self->{REFSEQS}{$db} ) # clean up path for Cygwin
    }
  }
  else {
    $error = 1;
  }
  $self->throw("Reference sequence file(s) (refseqs => {db => \$file, ...}) was not specified during method call or file(s) do not exist") if ($error);

  my ($fh, $filename) = tempfile();
  #print "temp file is $filename\n";
  my $header = ''; $header = '-h' if ($self->{HEADER});
  my @f_option;
  foreach my $db (keys %{$self->{REFSEQS}}) {
    push (@f_option, "-f $db=" . $self->{REFSEQS}{$db});
  }
  my $command = "blastentropy.pl $header @f_option $self->{REPORT} > $filename";
  if ($self->verbose) {
    print $command, "\n";
  }
  `$command`;
  ($self->{$TEMP_ENTROPYFH}, $self->{$TEMP_ENTROPYFILE}) = ($fh, $filename);
  return $self->{$TEMP_ENTROPYFILE};
}


=head2 pass_filters
# Run pass_entropy and remove_baculo_artifact
#
# Does not return the report header
=cut

sub pass_filters {
  my ($self, %args) = @_;

  unless ($self->{TEMP_ENTROPYFILE} || exists $args{use_report} ) {
    $self->run_entropy(%args);
  }

  my $fh;
  if (exists $args{use_report}) {
    open ($fh, "<", $self->{REPORT});    # Report file has entropy values
  }
  else {
    open ($fh, "<", $self->{$TEMP_ENTROPYFILE});
  }

  my $passed = $self->pass_entropy( use_report => 1 );

  $passed = $self->remove_baculo_artifact( report => $passed );

  return $passed;
}


=head2 remove_baculo_artifact

# default is to return every row except to label baculovirus hits as
# unannotated if the only baculo hits in the sample is to one subject
# description
#
# does not expect report header nor returns report header
#
# Unimplemented:
#    I should add ability to remove these rows entirely

=cut

sub remove_baculo_artifact {
  my ($self, %args) = @_;

  my %baculo;
  foreach my $row ( @{ $args{report} } ) {
    my @fields = split ("\t", $row);
    if ($fields[9] eq 'Baculoviridae') {
      $baculo{$fields[7]}++;   # index 7 is the 'Subject description'
    }
  }

  # If there is only one Baculo subject description, change Baculo rows to unannotated.
  if (keys %baculo == 1) {
    foreach my $row ( @{ $args{report} } ) {
      my @fields = split ("\t", $row);
      if ($fields[9] eq 'Baculoviridae') {
        my $pid_col = 3;  my $ssend_col = 17;
        for (my $i = $pid_col; $i <= $ssend_col; $i++) {
          $fields[$i] = "";
        }
      }
      $row = join ("\t", @fields);
    }
  }

  return $args{report};
}



=head2 pass_entropy

=cut

# default is to retun every row of a Report file except that if a sequence does not
# pass the entropy cutoffs, the PID field to the SSEND field are set to the empty string.
# This essentially makes the sequence an unannotated sequence.
#
# If you do not want the default behavior, pass a hash argument with 'remove => 1'
#
# Does not return the report header
sub pass_entropy {
  my ($self, %args) = @_;

  unless ($self->{TEMP_ENTROPYFILE} || exists $args{use_report} ) {
    $self->run_entropy(%args);
  }

  my $fh;
  if (exists $args{use_report}) {
    open ($fh, "<", $self->{REPORT});    # Report file has entropy values
  }
  else {
    open ($fh, "<", $self->{$TEMP_ENTROPYFILE});
  }

  my $toReturn;
  my $ENT_MIN = 65; my $LC_MAX  = 50;
  while (<$fh>) {
    chomp;
    next if ($. == 1 && $self->{HEADER});
    my @fields = split (/\t/, $_);

    my @query_ent = ($fields[-4], $fields[-3]);
    my $shsp_ent = $fields[-2];
    my $shsp_lc  = $fields[-1];
    if (
            (    # unassigned sequence does not have a Qhsp_ent ($query_ent[1])
              $query_ent[0] > $ENT_MIN && $query_ent[1] == -1
            )
        ||
            (    # for all hits that are not unassigned
              min(@query_ent) > $ENT_MIN
              && ($shsp_ent == -1 || $shsp_ent > $ENT_MIN)
              && $shsp_lc < $LC_MAX
            )
        )
    {
      push(@$toReturn, $_);
    }
    else {
      unless (exists $args{remove}) {
        my $pid_col = 3;   my $ssend_col = 17;
        for (my $i = $pid_col; $i <= $ssend_col; $i++) {
          $fields[$i] = "";
        }
        push(@$toReturn, join("\t",@fields));
      }
    }
  }
  close ($fh);
  return $toReturn;
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


=head2 DESTROY

=cut

sub DESTROY {
  my $self = shift;
  my $fh = $self->{$TEMP_ENTROPYFH};
  close $fh;
  unlink $self->{$TEMP_ENTROPYFILE};
}



1;
