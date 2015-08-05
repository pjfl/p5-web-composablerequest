package Web::ComposableRequest::Role::Session;

use namespace::autoclean;

use Digest::MD5                  qw( md5_hex );
use Subclass::Of;
use Web::ComposableRequest::Util qw( request_config_roles );
use Unexpected::Types            qw( LoadableClass Object );
use Moo::Role;

requires qw( config loc loc_default log query_params _env );

request_config_roles __PACKAGE__.'::Config';

my $class_stash = {};

my $_build_session_class = sub {
   my $self         = shift;
   my $base         = $self->config->session_class;
   my $session_attr = $self->config->session_attr;
   my @session_attr = keys %{ $session_attr };

   @session_attr > 0 or return $base;

   my $class = "${base}::".(substr md5_hex( join q(), @session_attr ), 0, 8);

   exists $class_stash->{ $class } and return $class_stash->{ $class };

   my @attrs;

   for my $name (@session_attr) {
      my ($type, $default) = @{ $session_attr->{ $name } };
      my $props            = [ is => 'rw', isa => $type ];

      defined $default and push @{ $props }, 'default', $default;
      push @attrs, $name, $props;
   }

   return $class_stash->{ $class } = subclass_of
      ( $base, -package => $class, -has => [ @attrs ] );
};

has 'session'       => is => 'lazy', isa => Object, builder => sub {
   return $_[ 0 ]->session_class->new
      ( config      => $_[ 0 ]->config,
        log         => $_[ 0 ]->log,
        session     => $_[ 0 ]->_env->{ 'psgix.session' }, ) },
   handles          => [ 'authenticated', 'username' ];

has 'session_class' => is => 'lazy', isa => LoadableClass,
   builder          => $_build_session_class;

package Web::ComposableRequest::Role::Session::Config;

use namespace::autoclean;

use Unexpected::Types qw( ArrayRef HashRef NonEmptySimpleStr
                          NonZeroPositiveInt PositiveInt );
use Moo::Role;

has 'max_messages'  => is => 'ro', isa => NonZeroPositiveInt, default => 3;

has 'max_sess_time' => is => 'ro', isa => PositiveInt, default => 3_600;

has 'session_attr'  => is => 'ro', isa => HashRef[ArrayRef],
   builder          => sub { {} };

has 'session_class' => is => 'ro', isa => NonEmptySimpleStr,
   default          => 'Web::ComposableRequest::Session';

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Role::Session - One-line description of the modules purpose

=head1 Synopsis

   use Web::ComposableRequest::Role::Session;
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
