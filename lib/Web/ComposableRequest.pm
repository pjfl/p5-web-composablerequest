package Web::ComposableRequest;

use 5.010001;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 5 $ =~ /\d+/gmx );

use Scalar::Util                      qw( blessed );
use Web::ComposableRequest::Base;
use Web::ComposableRequest::Config;
use Web::ComposableRequest::Constants qw( NUL );
use Web::ComposableRequest::Util      qw( deref is_hashref
                                          request_config_roles trim );
use Unexpected::Types                 qw( HashRef NonEmptySimpleStr
                                          Object Undef );
use Moo::Role ();
use Moo;

my $_build_config_class = sub {
   my $base  = __PACKAGE__.'::Config';
   my @roles = request_config_roles; @roles > 0 or return $base;

   return Moo::Role->create_class_with_roles( $base, @roles );
};

my $_build_request_class = sub {
   my $self  = shift;
   my $base  = __PACKAGE__.'::Base';
   my $conf  = $self->config_attr or return $base;
   my $class = deref( $conf, 'request_class' ) // $base;
   my @roles = @{ deref( $conf, 'request_roles' ) // [] };

   @roles > 0 or return $class;

   @roles = map { (substr $_, 0, 1 eq '+')
                ?  substr $_, 1 : __PACKAGE__."::Role::${_}" } @roles;

   return Moo::Role->create_class_with_roles( $class, @roles );
};

has 'config'        => is => 'lazy', isa => Object, builder => sub {
   $_[ 0 ]->config_class->new( $_[ 0 ]->config_attr ) }, init_arg => undef;

has 'config_attr'   => is => 'ro',   isa => HashRef | Object | Undef,
   builder          => sub {},  init_arg => 'config';

has 'config_class'  => is => 'lazy', isa => NonEmptySimpleStr,
   builder          => $_build_config_class;

has 'request_class' => is => 'lazy', isa => NonEmptySimpleStr,
   builder          => $_build_request_class;

sub new_from_simple_request {
   my ($self, $opts, @args) = @_; my $attr = { %{ $opts // {} } };

   my $request_class = $self->request_class; # Trigger role application

   $attr->{config} = $self->config; # Composed after request_class
   $attr->{env   } = (is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{params} = (is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args  } = (defined $args[ 0 ] && blessed $args[ 0 ])
                   ? [ $args[ 0 ] ] # Upload object
                   : [ split m{ / }mx, trim $args[ 0 ] || NUL ];

   return $request_class->new( $attr );
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest - Composable request class for web frameworks

=head1 Synopsis

   use Web::ComposableRequest;

   # List the roles to be applied to the request object base class
   my $config  = {
      prefix        => 'my_app',
      request_roles => [ 'L10N', 'Session', 'Cookie', 'JSON', 'Static' ], };

   # Construct a request object factory
   my $factory = Web::ComposableRequest->new( config => $config );

   # Request data provided by the web framework
   my $args    = 'arg1/arg2/arg_3';
   my $query   = { mid => '123_4' };
   my $cookie  = 'my_app_cookie1=key1%7Eval1%2Bkey2%7Eval2; '
               . 'my_app_cookie2=key3%7Eval3%2Bkey4%7Eval4';
   my $input   = '{ "key": "value_1" }';
   my $env     = { CONTENT_LENGTH  => 20,
                   CONTENT_TYPE    => 'application/json',
                   HTTP_COOKIE     => $cookie,
                   HTTP_HOST       => 'localhost:5000',
                   PATH_INFO       => '/Getting-Started',
                   'psgi.input'    => IO::String->new( $input ),
                   'psgix.session' => {},
                 };

   # Construct a new request object
   my $req     = $factory->new_from_simple_request( {}, $args, $query, $env );

=head1 Description

Composes a request class from a base class plus a selection of applied roles

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<config>

A configuration object created by passing the L</config_attr> to the constructor
of the L</config_class>

=item C<config_attr>

Either a hash reference or an object reference or undefined. Overrides the
hard coded configuration class defaults

=item C<config_class>

A non empty simple string which is the name of the base configuration class

=item C<request_class>

A non empty simple string which is the name of the base request class

=back

=head1 Subroutines/Methods

=head2 C<new_from_simple_request>

   my $req = $factory->new_from_simple_request( $opts, $args, $query, $env );

Returns a request object representing the passed parameters. The C<$opts>
hash reference is used to directly set attributes in the request object.
The C<$args> parameter is either a string of arguments after the path in the
URI or an upload object reference. The C<$query> hash reference are the keys
and values of the URI query parameters, and the C<$env> hash reference is the
Plack environment

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<CGI::Simple>

=item L<Class::Inspector>

=item L<Exporter::Tiny>

=item L<HTTP::Body>

=item L<HTTP::Message>

=item L<JSON::MaybeXS>

=item L<Moo>

=item L<Subclass::Of>

=item L<Try::Tiny>

=item L<URI>

=item L<Unexpected>

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
# coding: utf-8
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
