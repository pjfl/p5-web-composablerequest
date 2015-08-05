package Web::ComposableRequest::Config;

use namespace::autoclean;

use Class::Inspector;
use Unexpected::Types            qw( NonEmptySimpleStr PositiveInt Str );
use Web::ComposableRequest::Util qw( deref is_member );
use Moo;

my $_list_attr_of = sub {
   my $class = shift; my @except = qw( BUILDARGS BUILD DOES does new );

   return map  { $_->[1] }
          grep { $_->[0] ne 'Moo::Object' and not is_member $_->[1], @except }
          map  { m{ \A (.+) \:\: ([^:]+) \z }mx; [ $1, $2 ] }
              @{ Class::Inspector->methods( $class, 'full', 'public' ) };
};

# Public attributes
has 'encoding'       => is => 'ro', isa => NonEmptySimpleStr,
   default           => 'UTF-8';

has 'max_asset_size' => is => 'ro', isa => PositiveInt,
   default           => 4_194_304;

has 'scrubber'       => is => 'ro', isa => Str,
   default           => '[^ +\-\./0-9@A-Z\\_a-z~]';

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, $config) = @_; my $attr = {}; $config or return $attr;

   for my $k ($_list_attr_of->( $self )) {
       my $v = deref $config, $k; defined $v and $attr->{ $k } = $v;
   }

   return $attr;
};

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Config - One-line description of the modules purpose

=head1 Synopsis

   use Web::ComposableRequest::Config;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Web-ComposableRequest.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
