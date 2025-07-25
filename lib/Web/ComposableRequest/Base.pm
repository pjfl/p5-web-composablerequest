package Web::ComposableRequest::Base;

use HTTP::Status                      qw( HTTP_EXPECTATION_FAILED
                                          HTTP_INTERNAL_SERVER_ERROR
                                          HTTP_REQUEST_ENTITY_TOO_LARGE );
use Web::ComposableRequest::Constants qw( EXCEPTION_CLASS NUL TRUE );
use Unexpected::Types                 qw( ArrayRef CodeRef HashRef LoadableClass
                                          NonEmptySimpleStr NonZeroPositiveInt
                                          Object PositiveInt SimpleStr Str
                                          Undef );
use Scalar::Util                      qw( weaken );
use Web::ComposableRequest::Util      qw( decode_array decode_hash first_char
                                          is_arrayref is_hashref new_uri
                                          throw );
use Unexpected::Functions             qw( Unspecified );
use HTTP::Body;
use Try::Tiny;
use Moo;

# Public attributes
has 'address' =>
   is      => 'lazy',
   isa     => SimpleStr,
   default => sub { $_[0]->_env->{'REMOTE_ADDR'} // NUL };

has 'base' =>
   is       => 'lazy',
   isa      => Object,
   init_arg => undef,
   default  => sub { new_uri $_[0]->scheme, $_[0]->_base };

has 'body' => is => 'lazy', isa => Object, default => sub {
   my $self    = shift;
   my $content = $self->_content;
   my $len     = length $content;
   my $body    = HTTP::Body->new($self->content_type, $len);

   $body->cleanup(TRUE);
   $body->tmpdir($self->_config->tempdir);

   return $body unless $len;

   try   { $self->_decode_body($body, $content) }
   catch {
      # uncoverable subroutine
      # uncoverable statement
      $self->_log->({ level => 'error', message => $_ });
   };

   return $body;
};

has 'content_length' => is => 'lazy', isa => PositiveInt,
   default           => sub { $_[0]->_env->{ 'CONTENT_LENGTH' } // 0 };

has 'content_type' => is => 'lazy', isa => SimpleStr,
   default         => sub { $_[0]->_env->{ 'CONTENT_TYPE' } // NUL };

has 'host' => is => 'lazy', isa => NonEmptySimpleStr,
   default => sub { (split m{ : }mx, $_[0]->hostport)[0] };

has 'hostport' => is => 'lazy', isa => NonEmptySimpleStr,
   default     => sub { $_[0]->_env->{ 'HTTP_HOST' } // 'localhost' };

has 'method' => is => 'lazy', isa => SimpleStr,
   default   => sub { lc( $_[0]->_env->{ 'REQUEST_METHOD' } // NUL )};

has 'path' => is => 'lazy', isa => SimpleStr, default => sub {
   my $v = $_[0]->_env->{'PATH_INFO'} // '/';

   $v =~ s{ \A / }{}mx; $v =~ s{ \? .* \z }{}mx;

   return $v;
};

has 'port' => is => 'lazy', isa => NonZeroPositiveInt,
   default => sub { $_[0]->_env->{ 'SERVER_PORT' } // 80 };

has 'protocol' => is => 'lazy', isa => NonEmptySimpleStr,
   default     => sub { $_[0]->_env->{ 'SERVER_PROTOCOL' } };

has 'query' => is => 'lazy', isa => Str, default => sub {
   my $v = $_[0]->_env->{'QUERY_STRING'};

   return $v ? "?${v}" : NUL;
};

has 'referer' => is => 'lazy', isa => Str,
   default    => sub { $_[0]->_env->{ 'HTTP_REFERER' } // NUL };

has 'remote_host' => is => 'lazy', isa => SimpleStr,
   default        => sub { $_[0]->_env->{ 'REMOTE_HOST' } // NUL };

has 'scheme' => is => 'lazy', isa => NonEmptySimpleStr,
   default   => sub { $_[0]->_env->{ 'psgi.url_scheme' } // 'http' };

has 'script' => is => 'lazy', isa => SimpleStr, default => sub {
   my $v = $_[0]->_env->{'SCRIPT_NAME'} // '/';

   $v =~ s{ / \z }{}gmx;

   return $v;
};

has 'tunnel_method'  => is => 'lazy', isa => NonEmptySimpleStr, default => sub {
   return $_[0]->body_params->(  '_method', { optional => TRUE } )
       || $_[0]->query_params->( '_method', { optional => TRUE } )
       || 'not_found';
};

has 'upload' => is => 'lazy', isa => Object | Undef, predicate => TRUE;

has 'uri' => is => 'lazy', isa => Object, builder => '_build_uri';

# Private attributes
has '_args' =>
   is       => 'ro',
   isa      => ArrayRef,
   init_arg => 'args',
   default  => sub { [] };

has '_base' =>
   is      => 'lazy',
   isa     => NonEmptySimpleStr,
   builder => '_build__base';

has '_config' =>
   is       => 'ro',
   isa      => Object,
   init_arg => 'config',
   required => TRUE;

has '_content' => is => 'lazy', isa => Str, default => sub {
   my $self    = shift;
   my $cl      = $self->content_length or return NUL;
   my $fh      = $self->_env->{ 'psgi.input' } or return NUL;
   my $content = NUL;

   try {
      $fh->seek( 0, 0 ) if $fh->can( 'seek' );
      $fh->read( $content, $cl, 0 );
      $fh->seek( 0, 0 ) if $fh->can( 'seek' );
   }
   catch {
      # uncoverable subroutine
      # uncoverable statement
      $self->_log->( { level => 'error', message => $_ } );
   };

   return $content;
};

has '_env' => is => 'ro', isa => HashRef, init_arg => 'env', required => TRUE;

has '_log'  =>
   is       => 'lazy',
   isa      => CodeRef,
   init_arg => 'log',
   default  => sub { $_[0]->_env->{'psgix.logger'} // sub {} };

has '_params' =>
   is       => 'ro',
   isa      => HashRef,
   init_arg => 'params',
   default  => sub { {} };

# Construction
sub BUILD {
   my $self = shift;
   my $enc  = $self->_config->encoding;

   decode_array $enc, $self->_args;
   decode_hash  $enc, $self->_params;

   return;
}

# Public methods
sub body_params {
   my $self = shift; weaken( $self );

   my $params = $self->body->param;

   weaken($params) if ref $params;

   return sub {
      return $self->_get_scrubbed_param(
         $params, (defined $_[0] && !is_hashref $_[0])
            ? @_ : (-1, { hashref => TRUE, %{ $_[0] // {} } })
      );
   };
}

sub query_params {
   my $self = shift; weaken( $self );

   my $params = $self->_params; weaken( $params );

   return sub {
      return $self->_get_scrubbed_param(
         $params, (defined $_[0] && !is_hashref $_[0])
            ? @_ : (-1, { hashref => TRUE, %{ $_[0] // {} } })
      );
   };
}

sub uri_for {
   my ($self, $path, @args) = @_;

   $path //= NUL;

   my $base = $self->_base;
   my @query_params = ();
   my $uri_params = [];

   if (is_arrayref $args[0]) {
      $uri_params = shift @args;
      @query_params = @args;
   }
   elsif (is_hashref $args[0]) {
      $uri_params   =    $args[0]->{uri_params  } // [];
      @query_params = @{ $args[0]->{query_params} // [] };

      $base = $args[0]->{base} if $args[0]->{base};
   }

   $path = $base.$path if first_char $path ne '/';

   if ($uri_params->[0]) {
      if ($path =~ m{ \* }mx) {
         for my $arg (grep { defined and length } @{$uri_params}) {
            if ($path =~ m{ \* }mx) { $path =~ s{ \* }{$arg}mx }
            else { $path = "${path}/${arg}" }
         }
      }
      else {
         $path = join '/', $path, grep { defined and length } @{$uri_params};
      }
   }

   my $uri = new_uri $self->scheme, $path;

   $uri->query_form(@query_params) if $query_params[0];

   return $uri;
}

sub uri_params {
   my $self = shift; weaken( $self );

   my $params = $self->_args; weaken( $params );

   return sub {
      return $self->_get_scrubbed_param(
         $params, (defined $_[0] && !is_hashref $_[0])
         ? @_ : (-1, { %{ $_[0] // {} }, multiple => TRUE })
      );
   };
}

# Private functions
my $_defined_or_throw = sub {
   my ($k, $v, $opts) = @_;

   return $v if $opts->{optional};

   $k = "arg[${k}]" if $k =~ m{ \A \d+ \z }mx;

   throw 'Parameter [_1] undefined value', [ $k ],
      level => 6, rv => HTTP_EXPECTATION_FAILED unless defined $v;

   return $v;
};

my $_get_last_value = sub {
   my ($k, $v, $opts) = @_; return $_defined_or_throw->( $k, $v->[-1], $opts );
};

my $_get_value_or_values = sub {
   my ($params, $name, $opts) = @_;

   throw Unspecified, [ 'name' ], level => 5, rv => HTTP_INTERNAL_SERVER_ERROR
      unless defined $name;

   my $v = (is_arrayref $params and $name eq '-1') ? [ @{ $params } ]
         : (is_arrayref $params                  ) ? $params->[ $name ]
         : (                        $name eq '-1') ? { %{ $params } }
                                                   : $params->{ $name };

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
   my ($name, $v, $opts) = @_;

   my $pattern = $opts->{scrubber};

   $v =~ s{ $pattern }{}gmx if $pattern and defined $v;

   $name = "arg[${name}]" if $name =~ m{ \A [\-]? \d+ \z }mx;

   my $len = defined $v ? length $v : 0;

   throw Unspecified, [ $name ], level => 4, rv => HTTP_EXPECTATION_FAILED
      unless $opts->{optional} or $opts->{allow_null} or $len;

   throw 'Parameter [_1] size [_2] too big', [ $name, $len ], level => 4,
      rv => HTTP_REQUEST_ENTITY_TOO_LARGE if $len > $opts->{max_length};

   return $v;
};

my $_scrub_hash = sub {
   my ($params, $opts) = @_;

   my $hash = $_get_defined_value->( $params, -1, $opts );
   my @keys = keys %{ $hash };

   for my $k (@keys) {
      my $v = delete $hash->{ $k };

      $hash->{ $_scrub_value->( 'key', $k, $opts ) }
         = (is_arrayref $v && $opts->{multiple}) ?
            [ map { $_scrub_value->( $k, $_, $opts ) } @{ $v } ]
         : (is_arrayref $v) ? $_get_last_value->( $k, $v, $opts )
         : $_scrub_value->( $k, $v, $opts );
   }

   return $hash;
};

# Private methods
sub _build__base {
   return $_[0]->scheme . '://' . $_[0]->hostport . $_[0]->script . '/';
}

sub _build_uri {
   return new_uri $_[0]->scheme, $_[0]->_base . $_[0]->path . $_[0]->query;
}

sub _decode_body {
   my ($self, $body, $content) = @_;

   $body->add( $content );
   decode_hash $self->_config->encoding, $body->param;

   return;
}

sub _get_scrubbed_param {
   my ($self, $params, $name, $opts) = @_;

   $opts = { %{ $opts // {} } };
   $opts->{max_length} //= $self->_config->max_asset_size;
   $opts->{scrubber} //= $self->_config->scrubber;

   return $_scrub_hash->( $params, $opts ) if $opts->{hashref};

   if ($opts->{multiple}) {
      return [ map { $opts->{raw} ? $_ : $_scrub_value->( $name, $_, $opts ) }
                  @{ $_get_defined_values->( $params, $name, $opts ) } ];
   }

   my $v = $_get_defined_value->( $params, $name, $opts );

   return $opts->{raw} ? $v : $_scrub_value->( $name, $v, $opts );
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::ComposableRequest::Base - Request class core attributes and methods

=head1 Synopsis

   package Web::ComposableRequest;

   use Web::ComposableRequest::Util qw( merge_attributes );
   use Unexpected::Types            qw( NonEmptySimpleStr );

   my $_build_request_class = sub {
      my $self  = shift;
      my $base  = __PACKAGE__.'::Base';
      my $conf  = $self->config_attr or return $base;
      my $attr  = {};

      merge_attributes $attr, $conf, [ 'request_class', 'request_roles' ];

      my $class = $attr->{request_class} // $base;
      my @roles = $attr->{request_roles} // [];

      @roles > 0 or return $class;

      @roles = map { (substr $_, 0, 1 eq '+')
                   ?  substr $_, 1 : __PACKAGE__."::Role::${_}" } @roles;

      return Moo::Role->create_class_with_roles( $class, @roles );
   };

   has 'request_class' => is => 'lazy', isa => NonEmptySimpleStr,
      default          => $_build_request_class;

=head1 Description

Request class core attributes and methods

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<address>

A simple string the C<REMOTE_ADDR> attribute from the Plack environment

=item C<base>

A L<URI> object reference that points to the application base

=item C<body>

An L<HTTP::Body> object constructed from the current request

=item C<content_length>

Length in bytes of the not yet decoded body content

=item C<content_type>

Mime type of the body content

=item C<host>

A non empty simple string which is the hostname in the request. The value of
L</hostport> but without the port number

=item C<hostport>

The hostname and port number in the request

=item C<method>

The HTTP request method. Lower cased

=item C<path>

Taken from the request path, this should be the same as the
C<mount_point> configuration attribute

=item C<port>

A non zero positive integer that default to 80. The default server port

=item C<protocol>

A non empty simple string. The protocol used by the request e.g. C<HTTP/2.0>

=item C<query>

The query parameters from the current request. A simple string beginning with
C<?>

=item C<referer>

The C<HTTP_REFERER> attribute from the Plack environment

=item C<remote_host>

The C<REMOTE_HOST> attribute from the Plack environment

=item C<scheme>

The HTTP protocol used in the request. Defaults to C<http>

=item C<script>

The request path

=item C<tunnel_method>

The C<_method> attribute from the body of a post or from the query parameters
in the event of a get request

=item C<upload>

The upload object if one was supplied in the request. Undefined otherwise

=item C<uri>

The URI of the current request. Does not include the query parameters

=item C<_args>

An array reference of the arguments supplied with the URI

=item C<_base>

A non empty simple string which is the base of the requested URI

=item C<_config>

The configuration object reference. Required

=item C<_content>

A decoded string of characters representing the body of the request

=item C<_env>

A hash reference, the L<Plack> request environment

=item C<_log>

The logger code reference. Defaults to the one supplied by the Plack
environment

=item C<_params>

A hash reference of query parameters supplied with the request URI

=back

=head1 Subroutines/Methods

=head2 C<BUILD>

Decodes the URI and query parameters

=head2 C<body_params>

   $code_ref = $req->body_params; $value = $code_ref->( 'key', $opts );

Returns a code reference which when called with a body parameter name returns
the body parameter value after first scrubbing it of "dodgy" characters. Throws
if the value is undefined or tainted

=head2 C<has_upload>

   $bool = $req->has_upload;

Return true if the request contains an upload, false otherwise

=head2 C<query_params>

   $code_ref = $req->query_params; $value = $code_ref->( 'key', $opts );

Returns a code reference which when called with a query parameter name returns
the query parameter value after first scrubbing it of "dodgy" characters. Throws
if the value is undefined or tainted

=head2 C<uri_for>

   $uri_obj = $req->uri_for( $partial_uri_path, $args, $query_params );

Prefixes C<$partial_uri_path> with the base of the current request. Returns
an absolute URI

=head2 C<uri_params>

   $code_ref = $req->uri_params; $value = $code_ref->( $index, $opts );

Returns a code reference which when called with an integer index returns
the uri parameter value after first scrubbing it of "dodgy" characters. Throws
if the value is undefined or tainted

If the index is C<-1> and the option C<multiple> is true, returns an array
reference of all the uri parameters

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<HTTP::Body>

=item L<HTTP::Status>

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

Copyright (c) 2017 Peter Flanigan. All rights reserved

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
