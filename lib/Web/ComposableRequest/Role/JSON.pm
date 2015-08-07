package Web::ComposableRequest::Role::JSON;

use namespace::autoclean;

use Encode                            qw( decode );
use JSON::MaybeXS                     qw( );
use Web::ComposableRequest::Constants qw( FALSE );
use Unexpected::Types                 qw( Object );
use Moo::Role;

requires qw( content_type _config );

has '_json' => is => 'lazy', isa => Object,
   builder  => sub { JSON::MaybeXS->new( utf8 => FALSE ) };

around 'decode_body' => sub {
   my ($orig, $self, $body, $content) = @_;

   $self->content_type eq 'application/json'
      or return $orig->( $self, $body, $content );

   $body->{param} = $self->_json->decode
      ( decode( $self->_config->encoding, $content ) );

   return;
};

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Role::JSON - One-line description of the modules purpose

=head1 Synopsis

   use Web::ComposableRequest::Role::JSON;
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
