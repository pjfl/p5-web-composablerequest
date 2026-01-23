package Web::ComposableRequest::Role::Headers;

use Type::Utils qw( class_type );
use HTTP::Headers::Fast;
use Moo::Role;

requires qw( _env );

has 'headers' => is => 'lazy', isa => class_type('HTTP::Headers::Fast'),
   builder => sub {
      my $self = shift;
      my $env  = $self->_env;

      return HTTP::Headers::Fast->new(
         map  { (my $field = $_) =~ s{\A HTTPS?_}{}mx;
                (lc($field) => $env->{$_});
         }
         grep { m{ \A (?:HTTP|CONTENT) }imx } keys %{$env}
      );
   };

sub header {
   my ($self, $name) = @_; return $self->headers->header($name);
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Role::Headers - Returns header attribute values

=head1 Synopsis

   use Moo;

   extends 'Web::ComposableRequest::Base';
   with 'Web::ComposableRequest::Role::Headers';

=head1 Description

Returns header attribute values

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<header>

   $value = $session->header($attribute_name);

Returns the named header attribute value

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo::Role>

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

Peter Flanigan, C<< <lazarus@roxsoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

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
