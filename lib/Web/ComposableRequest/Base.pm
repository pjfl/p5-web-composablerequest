package Web::ComposableRequest::Base;

use namespace::autoclean;

use HTTP::Body;
use HTTP::Status                      qw( HTTP_EXPECTATION_FAILED
                                          HTTP_INTERNAL_SERVER_ERROR
                                          HTTP_REQUEST_ENTITY_TOO_LARGE );
use Scalar::Util                      qw( weaken );
use Try::Tiny;
use Web::ComposableRequest::Constants qw( EXCEPTION_CLASS NUL TRUE );
use Web::ComposableRequest::Util      qw( decode_array decode_hash first_char
                                          is_arrayref new_uri throw );
use Unexpected::Functions             qw( Unspecified );
use Unexpected::Types                 qw( ArrayRef CodeRef HashRef LoadableClass
                                          NonEmptySimpleStr NonZeroPositiveInt
                                          Object PositiveInt SimpleStr Str
                                          Undef );
use Moo;

# Attribute constructors
my $_build_body = sub {
   my $self = shift; my $content = $self->_content; my $len = length $content;

   my $body = HTTP::Body->new( $self->content_type, $len );

   $body->cleanup( TRUE ); $len or return $body;

   try   { $self->decode_body( $body, $content ) }
   catch { $self->log->( { level => 'error', message => $_ } ) };

   return $body;
};

my $_build__content = sub {
   my $self = shift; my $env = $self->_env; my $log = $self->log; my $content;

   my $cl = $self->content_length  or return NUL;
   my $fh = $env->{ 'psgi.input' } or return NUL;

   try   { $fh->seek( 0, 0 ); $fh->read( $content, $cl, 0 ); $fh->seek( 0, 0 ) }
   catch { $log->( { level => 'error', message => $_ } ); $content = NUL };

   return $content || NUL;
};

my $_build_tunnel_method = sub {
   return $_[ 0 ]->body_params->(  '_method', { optional => TRUE } )
       || $_[ 0 ]->query_params->( '_method', { optional => TRUE } )
       || 'not_found';
};

# Public attributes
has 'address'        => is => 'lazy', isa => SimpleStr,
   builder           => sub { $_[ 0 ]->_env->{ 'REMOTE_ADDR' } // NUL };

has 'base'           => is => 'lazy', isa => Object,
   builder           => sub { new_uri $_[ 0 ]->_base, $_[ 0 ]->scheme },
   init_arg          => undef;

has 'body'           => is => 'lazy', isa => Object, builder => $_build_body;

has 'content_length' => is => 'lazy', isa => PositiveInt,
   builder           => sub { $_[ 0 ]->_env->{ 'CONTENT_LENGTH' } // 0 };

has 'content_type'   => is => 'lazy', isa => SimpleStr,
   builder           => sub { $_[ 0 ]->_env->{ 'CONTENT_TYPE' } // NUL };

has 'host'           => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { (split m{ : }mx, $_[ 0 ]->hostport)[ 0 ] };

has 'hostport'       => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { $_[ 0 ]->_env->{ 'HTTP_HOST' } // 'localhost' };

has 'log'            => is => 'lazy', isa => CodeRef,
   builder           => sub { $_[ 0 ]->_env->{ 'psgix.logger' } // sub {} };

has 'method'         => is => 'lazy', isa => SimpleStr,
   builder           => sub { lc( $_[ 0 ]->_env->{ 'REQUEST_METHOD' } // NUL )};

has 'path'           => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v             =  $_[ 0 ]->_env->{ 'PATH_INFO' } // '/';
      $v             =~ s{ \A / }{}mx; $v =~ s{ \? .* \z }{}mx; $v };

has 'port'           => is => 'lazy', isa => NonZeroPositiveInt,
   builder           => sub { $_[ 0 ]->_env->{ 'SERVER_PORT' } // 80 };

has 'query'          => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v             =  $_[ 0 ]->_env->{ 'QUERY_STRING' }; $v ? "?${v}" : NUL };

has 'remote_host'    => is => 'lazy', isa => SimpleStr,
   builder           => sub { $_[ 0 ]->_env->{ 'REMOTE_HOST' } // NUL };

has 'scheme'         => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { $_[ 0 ]->_env->{ 'psgi.url_scheme' } // 'http' };

has 'script'         => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v             =  $_[ 0 ]->_env->{ 'SCRIPT_NAME' } // '/';
      $v             =~ s{ / \z }{}gmx; $v };

has 'tunnel_method'  => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => $_build_tunnel_method;

has 'uri'            => is => 'lazy', isa => Object, builder => sub {
   new_uri $_[ 0 ]->_base.$_[ 0 ]->path, $_[ 0 ]->scheme };

# Private attributes
has '_args'    => is => 'ro',   isa => ArrayRef,
   builder     => sub { [] }, init_arg => 'args';

has '_base'    => is => 'lazy', isa => NonEmptySimpleStr, builder => sub {
   $_[ 0 ]->scheme.'://'.$_[ 0 ]->hostport.$_[ 0 ]->script.'/' };

has '_config'  => is => 'ro',   isa => Object,
   required    => TRUE, init_arg => 'config';

has '_content' => is => 'lazy', isa => Str,
   builder     => $_build__content;

has '_env'     => is => 'ro',   isa => HashRef,
   builder     => sub { {} }, init_arg => 'env';

has '_params'  => is => 'ro',   isa => HashRef,
   builder     => sub { {} }, init_arg => 'params';

# Construction
sub BUILD {
   my $self = shift; my $enc = $self->_config->encoding;

   decode_array $enc, $self->_args; decode_hash $enc, $self->_params;

   return;
}

# Private functions
my $_defined_or_throw = sub {
   my ($k, $v, $opts) = @_; $k =~ m{ \A \d+ \z }mx and $k = "arg[${k}]";

   $opts->{optional} or defined $v
      or throw 'Parameter [_1] undefined value', [ $k ],
               level => 6, rv => HTTP_EXPECTATION_FAILED;

   return $v;
};

my $_get_last_value = sub {
   my ($k, $v, $opts) = @_; return $_defined_or_throw->( $k, $v->[-1], $opts );
};

my $_get_value_or_values = sub {
   my ($params, $name, $opts) = @_;

   defined $name or throw Unspecified, [ 'name' ],
                          level => 5, rv => HTTP_INTERNAL_SERVER_ERROR;

   my $v = (is_arrayref $params) ? $params->[ $name ] : $params->{ $name };

   return $_defined_or_throw->( $name, $v, $opts );
};

my $_get_defined_value = sub {
   my ($params, $name, $opts) = @_;

   my $v = $_get_value_or_values->( $params, $name, $opts );

   return (is_arrayref $v) ? $_get_last_value->( $name, $v, $opts ) : $v;
};

my $_get_defined_values = sub {
   my ($params, $name, $opts) = @_;

   my $v = $_get_value_or_values->( $params, $name, $opts );

   return (is_arrayref $v) ? $v : [ $v ];
};

my $_scrub_value = sub {
   my ($name, $v, $opts) = @_; my $pattern = $opts->{scrubber}; my $len;

   $pattern and defined $v and $v =~ s{ $pattern }{}gmx;

   $opts->{optional} or $opts->{allow_null} or $len = length $v
      or  throw Unspecified, [ $name ], level => 4,
                rv => HTTP_EXPECTATION_FAILED;

   $name =~ m{ \A \d+ \z }mx and $name = "arg[${name}]";

   $len and $len > $opts->{max_length}
      and throw 'Parameter [_1] size [_2] too big', [ $name, $len ], level => 4,
                rv => HTTP_REQUEST_ENTITY_TOO_LARGE;
   return $v;
};

my $_get_scrubbed_param = sub {
   my ($self, $params, $name, $opts) = @_; $opts = { %{ $opts // {} } };

   $opts->{max_length} //= $self->_config->max_asset_size;
   $opts->{scrubber  } //= $self->_config->scrubber;
   $opts->{multiple  } and return
      [ map { $opts->{raw} ? $_ : $_scrub_value->( $name, $_, $opts ) }
           @{ $_get_defined_values->( $params, $name, $opts ) } ];

   my $v = $_get_defined_value->( $params, $name, $opts );

   return $opts->{raw} ? $v : $_scrub_value->( $name, $v, $opts );
};

# Public methods
sub body_params {
   my $self = shift; weaken( $self );

   my $params = $self->body->param; weaken( $params );

   return sub { $_get_scrubbed_param->( $self, $params, @_ ) };
}

sub decode_body {
   my ($self, $body, $content) = @_; $body->add( $content );

   decode_hash $self->_config->encoding, $body->param;

   return;
}

sub query_params {
   my $self = shift; weaken( $self );

   my $params = $self->_params; weaken( $params );

   return sub { $_get_scrubbed_param->( $self, $params, @_ ) };
}

sub uri_for {
   my ($self, $path, $args, @query_params) = @_; $path //= NUL;

   $args and defined $args->[ 0 ] and $path = join '/', $path, @{ $args };

   first_char $path ne '/' and $path = $self->_base.$path;

   my $uri = new_uri $path, $self->scheme;

   $query_params[ 0 ] and $uri->query_form( @query_params );

   return $uri;
}

sub uri_params {
   my $self = shift; weaken( $self );

   my $params = $self->_args; weaken( $params );

   return sub { $_get_scrubbed_param->( $self, $params, @_ ) };
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Base - One-line description of the modules purpose

=head1 Synopsis

   use Web::ComposableRequest::Base;
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
