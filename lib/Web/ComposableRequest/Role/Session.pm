package Web::ComposableRequest::Role::Session;

use namespace::autoclean;

use Digest::MD5                  qw( md5_hex );
use Subclass::Of;
use Web::ComposableRequest::Util qw( add_config_role );
use Unexpected::Types            qw( LoadableClass Object );
use Moo::Role;

requires qw( loc loc_default query_params _config _env _log );

add_config_role __PACKAGE__.'::Config';

my $class_stash = {};

my $_build_session_class = sub {
   my $self         = shift;
   my $base         = $self->_config->session_class;
   my $session_attr = $self->_config->session_attr;
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
      ( config      => $_[ 0 ]->_config,
        log         => $_[ 0 ]->_log,
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

Web::ComposableRequest::Role::Session - Adds a session object to the request

=head1 Synopsis

   package Your::Request::Class;

   use Moo;

   extends 'Web::ComposableRequest::Base';
   with    'Web::ComposableRequest::Role::Session';

=head1 Description

Adds a session object to the request. The L</session_attr> list defines
attributes (name, type, and default) which are dynamically added to the
session class

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<session>

Stores the user preferences. An instance of L</session_class>

=item C<session_class>

Defaults to L<Web::ComposableRequest::Session>

=back

Defines the following configuration attributes

=over 3

=item C<max_messages>

A non zero positive integer which defaults to 3. The maximum number of messages
to keep in the queue

=item C<max_sess_time>

A positive integer that defaults to 3600 seconds (one hour). The maximum amount
of time a session can be idle before re-authentication is required. Setting
this to zero disables the feature

=item C<session_attr>

A hash reference of array references. Defaults to an empty hash. The keys
are the session attribute names, the arrays are tuples containing a type
and a default value

=item C<session_class>

A non empty simple string which defaults to L<Web::ComposableRequest::Session>.
The name of the session base class

=back

=head1 Subroutines/Methods

Defines no methods

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Digest::MD5>

=item L<Subclass::Of>

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
