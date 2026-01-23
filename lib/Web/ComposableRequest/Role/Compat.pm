package Web::ComposableRequest::Role::Compat;

use Web::ComposableRequest::Constants qw( FALSE TRUE );
use Web::ComposableRequest::Util      qw( add_config_role );
use Encode                            qw( decode );
use Moo::Role;

requires qw( body_params query_params uri_params );

add_config_role __PACKAGE__.'::Config';

sub remote_address {
   my $self = shift;

   return $self->header($self->_config->x_forward) || $self->address;
}

sub args {
   my $self = shift;

   return $self->uri_params->({ optional => TRUE, scrubber => FALSE });
}

sub body_parameters {
   my $self = shift;

   return $self->body_params->({
      hashref => FALSE, optional => TRUE, scrubber => FALSE
   });
}

sub parameters {
   my ($self, $options) = @_;

   return {
      %{$self->query_parameters($options)}, %{$self->body_parameters($options)}
   };
}

sub query_parameters {
   my $self = shift;

   return $self->query_params->({ optional => TRUE, scrubber => FALSE });
}

use namespace::autoclean;

package Web::ComposableRequest::Role::Compat::Config;

use Unexpected::Types qw( Str );
use Moo::Role;

has 'x_forward' => is => 'ro', isa => Str, default => 'X-Forwarded-For';

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Role::Compat - Provide compatibility methods

=head1 Synopsis

   use Moo;

   extends 'Web::ComposableRequest::Base';
   with    'Web::ComposableRequest::Role::Compat';

=head1 Description

Provide compatibility methods

=head1 Configuration and Environment

Defines no attributes

Defines the following configuration attributes

=over 3

=item C<x_forward>

Header attribute string. If this is set in the header use this IP address
instead of the default one in the request. Defaults to C<X-Forwarded-For>

=back

=head1 Subroutines/Methods

=over 3

=item remote_address

Returns the remote address of the request

=item args

Returns the request URI parameters

=item body_parameters

Returns the body parameters

=item parameters

Returns both body and query parameters

=item query_parameters

Returns the query parameters

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

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2026 Peter Flanigan. All rights reserved

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
