use t::boilerplate;

use Test::More;
use IO::String;
use Unexpected::Types qw( NonEmptySimpleStr );

use_ok 'Web::ComposableRequest';

my $config  = {
   prefix        => 'my_app',
   request_roles => [ 'L10N', 'Session', 'Cookie', 'JSON', 'Static' ],
   session_attr  => { theme => [ NonEmptySimpleStr, 'green' ] },
   scrubber      => '[^0-9A-Za-z]' };
my $factory = Web::ComposableRequest->new( config => $config );
my $args    = 'arg1/arg2/arg_3';
my $query   = { _method => 'delete', mid => '123_4' };
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
my $req     = $factory->new_from_simple_request( {}, $args, $query, $env );

is $req->_config->encoding, 'UTF-8', 'Default encoding';
is $req->_config->max_asset_size, 4_194_304, 'Default max asset size';
is $req->_config->scrubber, '[^0-9A-Za-z]', 'Non default scrubber';
is $req->_config->l10n_domain, 'messages', 'Config attribute from role';
is $req->_config->max_sess_time, 3_600, 'Config attribute from another role';
is $req->uri, 'http://localhost:5000/Getting-Started', 'Builds URI';
is $req->query_params->( 'mid' ), 1234, 'Query params scrubs unwanted chars';
is $req->query_params->( 'mid', { raw => 1 } ), '123_4', 'Query params raw val';
is $req->uri_params->( 2 ), 'arg3', 'URI params scrubs unwanted chars';
is $req->uri_params->( 2, { raw => 1 } ), 'arg_3', 'URI params raw value';
is $req->body_params->( 'key' ), 'value1', 'Body params scrubs unwanted chars';
is $req->body_params->( 'key', { raw => 1 } ), 'value_1', 'Body params raw val';
is $req->tunnel_method, 'delete', 'Tunnel method from query params';
is $req->loc( 'One [_1] Three', [ 'Two' ] ), "One 'Two' Three", 'Localises';
is $req->session->theme, 'green', 'Default session attribute value';
is $env->{ 'psgix.session' }->{theme}, undef, 'Envirnoment hash value undef';

$req->session->update;

is $env->{ 'psgix.session' }->{theme}, 'green', 'Inserts into envirnoment hash';

$req->session->theme( 'red' ); $req->session->update;

is $env->{ 'psgix.session' }->{theme}, 'red', 'Updates envirnoment hash';
is $req->get_cookie_hash( 'cookie1' )->{key1}, 'val1', 'Gets cookie value 1';
is $req->get_cookie_hash( 'cookie1' )->{key2}, 'val2', 'Gets cookie value 2';
is $req->get_cookie_hash( 'cookie2' )->{key3}, 'val3', 'Gets cookie value 3';
is $req->get_cookie_hash( 'cookie2' )->{key4}, 'val4', 'Gets cookie value 4';
is $req->uri_for, 'http://localhost:5000/', 'Default uri_for';

$env = { HTTP_HOST       => 'localhost:5000',
         PATH_INFO       => '/Getting-Started',
         'psgix.session' => {},
       };
$req = $factory->new_from_simple_request( {}, '', { mode => 'static' }, $env );

is $req->uri, '../en/Getting-Started.html', 'Builds static URI';
is $req->uri_for, '../en/index.html', 'Default static uri_for';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
