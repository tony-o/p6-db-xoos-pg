use lib 't/lib';
use DXPHelper;
use Test;

state $db;
my $cwd = $*CWD;
try {
  CATCH { default {
    plan 1;
    ok True, 'Skipping tests, unable to connect to postgres';
    exit 0;
  } }
  $*CWD = 't'.IO;
  $db = get-db(options => { :dynamic, model-dirs => [ 't/' ]});
  $*CWD = $cwd;
  die 'no connection' unless $db.db.query('select 1;').array;
}

plan 1;

subtest {
  is $db.loaded-models.sort, qw<Customers Orders>, 'added customers and orders tables';
  is $db.model('Customers').columns.map({ .key }).sort, qw<id name>, 'customer has proper columns';
  is $db.model('Customers').relations.map({ .key }).sort, qw<orders>, 'customer has proper relations';
  is $db.model('Orders').columns.map({ .key }).sort, qw<customer id value>, 'orders has proper columns';
  is $db.model('Orders').relations.map({ .key }).sort, qw<customers>, 'orders has proper relations';
  is $db.model('Customers').^name.split('+{')[0], 'Model::Customers', 'merged dynamic load with model level methods';
  is $db.model('Orders').^name.split('+{')[0], 'DB::Xoos::Model::Orders', 'Orders has anonymous model';
  is $db.model('Customers').merged-method, 'success', 'Can call methods on merged model';
  ok $db.model('Customers').^can('search'), 'Merged .^can ::Searchable';
  ok $db.model('Orders').^can('search'), 'Anon .^can ::Searchable';
}, 'OK';
