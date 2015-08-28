use t::boilerplate;

use Test::More;
use English           qw( -no_match_vars );
use IO::String;
use Scalar::Util      qw( blessed );
use Unexpected::Types qw( NonEmptySimpleStr );

use_ok 'Web::ComposableRequest::Constants', qw( );
use_ok 'Web::ComposableRequest';
use_ok 'Web::ComposableRequest::Util', qw( bson64id_time );

my $now     = time;
my $config  = {
   max_sess_time => 1,
   prefix        => 'my_app',
   request_roles => [ 'L10N', 'Session', 'Cookie', 'JSON', 'Static' ],
   session_attr  => { theme => [ NonEmptySimpleStr, 'green' ] },
   scrubber      => '[^_~+0-9A-Za-z]' };
my $factory = Web::ComposableRequest->new( config => $config );

is blessed( $factory ), 'Web::ComposableRequest', 'Factory right class';

my $session = { authenticated => 1 };
my $args    = 'arg1/arg2/arg-3';
my $query   = { _method => 'update', key => '123-4', };
my $cookie  = 'my_app_cookie1=key1%7Eval1%2Bkey2%7Eval2; '
            . 'my_app_cookie2=key3%7Eval3%2Bkey4%7Eval4';
my $input   = '{ "_method": "delete", "key": "value-1" }';
my $env     = {
   CONTENT_LENGTH       => length $input,
   CONTENT_TYPE         => 'application/json',
   HTTP_ACCEPT_LANGUAGE => 'en-gb,en;q=0.7,de;q=0.3',
   HTTP_COOKIE          => $cookie,
   HTTP_HOST            => 'localhost:5000',
   PATH_INFO            => '/api',
   QUERY_STRING         => 'key=124-4',
   REMOTE_ADDR          => '127.0.0.1',
   REQUEST_METHOD       => 'POST',
   'psgi.input'         => IO::String->new( $input ),
   'psgix.logger'       => sub { warn $_[ 0 ]->{message}."\n" },
   'psgix.session'      => $session,
};
my $req = $factory->new_from_simple_request( {}, $args, $query, $env );

is $req->_config->encoding, 'UTF-8', 'Default encoding';
is $req->_config->max_asset_size, 4_194_304, 'Default max asset size';
is $req->_config->scrubber, '[^_~+0-9A-Za-z]', 'Non default scrubber';
is $req->_config->l10n_attributes->{domains}->[ 0 ], 'messages',
   'Config attribute from role';
is $req->_config->max_sess_time, 1, 'Config attribute from another role';
is $req->address, '127.0.0.1', 'Remote address';
is $req->base, 'http://localhost:5000/', 'Request base';
is $req->host, 'localhost', 'Client host';
is $req->port, 80, 'Default port';
is $req->method, 'post', 'Request method';
is $req->query, '?key=124-4', 'Request query';
is $req->remote_host, q(), 'Remote host';
is $req->uri, 'http://localhost:5000/api', 'Builds URI';
is $req->has_upload, q(), 'Upload predicate false';
is $req->body_params->( 'key' ), 'value1', 'Body params scrubs unwanted chars';
is $req->body_params->( 'key', { raw => 1 } ), 'value-1', 'Body params raw val';
is join( '/', sort keys   %{ $req->body_params->() } ), '_method/key',
   'Body params as hashref - keys';
is join( '/', sort values %{ $req->body_params->() } ), 'delete/value1',
   'Body params as hashref - values';
is $req->query_params->( 'key' ), 1234, 'Query params scrubs unwanted chars';
is $req->query_params->( 'key', { raw => 1 } ), '123-4', 'Query params raw val';
is join( '/', sort keys   %{ $req->query_params->() } ), '_method/key',
   'Query params as hashref - keys';
is join( '/', sort values %{ $req->query_params->() } ), '1234/update',
   'Query params as hashref - values';
is $req->uri_params->( 2 ), 'arg3', 'URI params scrubs unwanted chars';
is $req->uri_params->( 2, { raw => 1 } ), 'arg-3', 'URI params raw value';
is join( '/', @{ $req->uri_params->( { raw => 1 } ) } ), $args,
   'URI params all args - raw';
is $req->tunnel_method, 'delete', 'Tunnel method from body params';
is $req->uri_for, 'http://localhost:5000/', 'Default uri_for';
is $req->loc( 'One [_1] Three', [ 'Two' ] ), "One 'Two' Three", 'Localises';
is $req->language, 'en', 'Default language';
is $req->get_cookie_hash( 'cookie1' )->{key1}, 'val1', 'Gets cookie value 1';
is $req->get_cookie_hash( 'cookie1' )->{key2}, 'val2', 'Gets cookie value 2';
is $req->get_cookie_hash( 'cookie2' )->{key3}, 'val3', 'Gets cookie value 3';
is $req->get_cookie_hash( 'cookie2' )->{key4}, 'val4', 'Gets cookie value 4';
is $req->session->theme, 'green', 'Default session attribute value';
is $session->{theme}, undef, 'Envirnoment hash value undef';

$req->session->add_status_message( [ 'bite [_1]',  'her'    ] );
$req->session->add_status_message( [ 'bite [_1]', [ 'him' ] ] );
$req->session->add_status_message( [ 'bite any'             ] );

my $params = { arg1 => 'me' };
my $mid    = $req->session->add_status_message( [ 'bite {arg1}', $params ] );

$req->session->update;

ok bson64id_time( $mid ) >= $now, 'BSON id time';
is $session->{theme}, 'green', 'Inserts into envirnoment hash';

$req->session->theme( 'red' ); $req->session->update;

is $session->{theme}, 'red', 'Updates envirnoment hash';

sleep 2; # For the benifit of session timeout
$query = { _method => 'post', locale => 'en', mid => $mid };
$env   = { HTTP_HOST       => 'localhost:5000',
           PATH_INFO       => '/api',
           'psgix.session' => $session,
         };
$req   = $factory->new_from_simple_request( {}, undef, $query, $env );

is $req->tunnel_method, 'post', 'Tunnel method from query params';
is $req->session->collect_status_message( $req ), 'bite me', 'Status message';

like $req->session->collect_status_message( $req ),
   qr{ \Qsession expired\E }mx, 'Session expired';

$req->session->update;
$query = { locale => 'de', mode => 'static' };
$env   = { HTTP_HOST       => 'localhost:5000',
           PATH_INFO       => '/api',
           'psgix.session' => $session,
           'psgix.logger'  => sub { warn $_[ 0 ]->{message}."\n" },
         };
$req   = $factory->new_from_simple_request( {}, '', $query, $env );

is $req->session->collect_status_message( $req ), undef, 'No more messages';
is $req->authenticated, 0, 'Session timed out';
is $req->tunnel_method, 'not_found', 'Tunnel method default';
is $req->uri, '../en/api.html', 'Builds static URI';
is $req->uri_for, '../en/index.html', 'Default static uri_for';

$req = $factory->new_from_simple_request( {}, q() );

is $req->query_params->( 'key', { optional => 1 } ), undef,
   'Query params optional';
is $req->uri_params->( 2, { optional => 1 } ), undef,
   'URI params optional';
is $req->body_params->( 'key', { optional => 1 } ), undef,
   'Body params ';

my $upload = bless {}, 'Upload';

$req = $factory->new_from_simple_request( {}, $upload );

is $req->has_upload, 1, 'Upload predicate true';
is blessed $req->upload, 'Upload', 'Upload object';

is Web::ComposableRequest::Constants->Exception_Class,
   'Web::ComposableRequest::Exception', 'Default exception class';

Web::ComposableRequest::Constants->Exception_Class( 'Unexpected' );

is Web::ComposableRequest::Constants->Exception_Class,
   'Unexpected', 'Non default exception class';

eval { Web::ComposableRequest::Constants->Exception_Class( 'Scalar::Util' ) };

like $EVAL_ERROR, qr{ \Qno throw method\E}mx, 'Invalid exception class';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
