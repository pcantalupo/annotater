package Program;
use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromString);
sub new{
	my $class = shift;
	my $self;
	my $options = shift;
	my %mm;
	my $r = GetOptionsFromString($options,\%mm,qw(exec=s));
	$self = \%mm;
	bless $self,$class;
	print $self->{'exec'},$/;
	return $self;
}
sub run{
	my $self = shift;
	print $self->{'exec'},$/;	
}
sub PrintParams{
	my $self = shift;
	foreach my $k (keys %{$self}){
		print join "\t", $k, $self->{$k},$/;	
	}	
}
1;

=cut

Contains the run and filter calls for all programs

=cut