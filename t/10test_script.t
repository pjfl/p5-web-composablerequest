use t::boilerplate;

use Test::More;
use Unexpected::Types qw( NonEmptySimpleStr );

use_ok 'Web::ComposableRequest';

my $config  = { request_roles => [ 'L10N', 'Session', 'Static' ],
                session_attr  => { theme => [ NonEmptySimpleStr, 'green' ] },
                scrubber      => '[^0-9A-Za-z]' };
my $factory = Web::ComposableRequest->new( config => $config );
my $query   = { mid => 1234 };
my $env     = { HTTP_HOST => 'localhost:5000',
                PATH_INFO => '/Getting-Started',
                'psgix.session' => {},
              };
my $req     = $factory->new_from_simple_request( {}, '', $query, $env );

is $req->config->encoding, 'UTF-8', 'Default encoding';
is $req->config->max_asset_size, 4_194_304, 'Default max asset size';
is $req->config->scrubber, '[^0-9A-Za-z]', 'Non default scrubber';
is $req->config->l10n_domain, 'messages', 'Config attribute from role';
is $req->config->max_sess_time, 3_600, 'Config attribute from another role';
is $req->uri, 'http://localhost:5000/Getting-Started', 'Builds URI';
is $req->query_params->( 'mid' ), 1234, 'Query params';
is $req->loc( 'One [_1] Three', [ 'Two' ] ), "One 'Two' Three", 'Localises';
is $req->session->theme, 'green', 'Default session attribute value';
is $env->{ 'psgix.session' }->{theme}, undef, 'Envirnoment hash value undef';

$req->session->update;

is $env->{ 'psgix.session' }->{theme}, 'green', 'Inserts into envirnoment hash';

$req->session->theme( 'red' ); $req->session->update;

is $env->{ 'psgix.session' }->{theme}, 'red', 'Updates envirnoment hash';

$req = $factory->new_from_simple_request( {}, '', { mode => 'static' }, $env );

is $req->uri, '../en/Getting-Started.html', 'Builds static URI';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
