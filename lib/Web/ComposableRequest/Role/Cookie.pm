package Web::ComposableRequest::Role::Cookie;

use namespace::autoclean;

use CGI::Simple::Cookie;
use Unexpected::Types            qw( HashRef );
use Web::ComposableRequest::Util qw( request_config_roles );
use Moo::Role;

requires qw( config _env );

request_config_roles __PACKAGE__.'::Config';

my $_decode = sub {
   my ($cookies, $prefix, $attr_name) = @_; my $name = "${prefix}_${attr_name}";

   my $attr = {}; ($attr_name and exists $cookies->{ $name }) or return $attr;

   for (split m{ \+ }mx, $cookies->{ $name }->value) {
      my ($k, $v) = split m{ ~ }mx, $_; $k and $attr->{ $k } = $v;
   }

   return $attr;
};

has 'cookies' => is => 'lazy', isa => HashRef, builder => sub {
   my %h = CGI::Simple::Cookie->parse( $_[ 0 ]->_env->{ 'HTTP_COOKIE' } ); \%h;
};

sub get_cookie_hash {
   return $_decode->( $_[ 0 ]->cookies, $_[ 0 ]->config->prefix, $_[ 1 ] );
};

package Web::ComposableRequest::Role::Cookie::Config;

use namespace::autoclean;

use Unexpected::Types                 qw( NonEmptySimpleStr );
use Web::ComposableRequest::Constants qw( TRUE );
use Moo::Role;

has 'prefix' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Role::Cookie - One-line description of the modules purpose

=head1 Synopsis

   use Web::ComposableRequest::Role::Cookie;
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
