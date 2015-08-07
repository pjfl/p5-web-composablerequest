package Web::ComposableRequest::Role::Static;

use namespace::autoclean;

use Web::ComposableRequest::Constants qw( NUL TRUE );
use Web::ComposableRequest::Util      qw( first_char new_uri );
use Moo::Role;

requires qw( locale path query_params scheme _base );

around '_build__base' => sub {
   my ($orig, $self) = @_; $self->mode eq 'static' or return $orig->( $self );

   return '../' x scalar split m{ / }mx, $self->path;
};

around '_build_uri' => sub {
   my ($orig, $self) = @_; $self->mode eq 'static' or return $orig->( $self );

   my $path = $self->_base.$self->locale.'/'.$self->path.'.html';

   return new_uri $path, $self->scheme;
};

around 'uri_for' => sub {
   my ($orig, $self, $path, $args, @query_params) = @_; $path //= NUL;

   ($self->mode eq 'static' and '/' ne substr $path, -1, 1)
      or return $orig->( $self, $path, $args, @query_params );

   $args and defined $args->[ 0 ] and $path = join '/', $path, @{ $args };
   $path or $path = 'index'; $path = $self->_base.$self->locale."/${path}.html";

   my $uri = new_uri $path, $self->scheme;

   $query_params[ 0 ] and $uri->query_form( @query_params );

   return $uri;
};

sub mode {
   return $_[ 0 ]->query_params->( 'mode', { optional => TRUE } ) // 'online';
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Role::Static - One-line description of the modules purpose

=head1 Synopsis

   use Web::ComposableRequest::Role::Static;
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
