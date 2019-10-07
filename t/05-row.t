use lib 't/lib';
use DXPHelper;
use Test;
use DB::Xoos::Role::Row;

try {
  CATCH { default {
    plan 1;
    ok True, 'Skipping tests, unable to connect to postgres';
    exit 0;
  } }
  die 'no connection' unless get-db.db.query('select 1;').array;
}

plan 1;

state $db = get-db(options => { :dynamic, model-dirs => [ 't/' ]});
subtest {
  my Int $uid = 10000.rand.Int;
  my Int $gid = 10000.rand.Int;
  my $model = $db.model('Customers');
  my (@obj, $obj, $search, $scratch);

  $model.delete({ name => 'hello world' });
  $model.insert({ name => 'hello world' });
  $obj = $model.search({ :name<hello world> }).first;

  ok $obj ~~ DB::Xoos::Role::Row, 'obj ~~ DB::Xoos::Role::Row';
  is $obj.name, 'hello world', 'name is right';
  $obj.name('whateverable');
  is $obj.name, 'whateverable', 'returns dirty column';
  is $model.search({ :name<hello world> }).count, 1, 'not updated in db yet';
  $obj.update;
  is $model.search({ :name<hello world> }).count, 0, 'updated `name` in db';
  is $model.search({ :name<whateverable> }).count, 1, '...and found it with search';
  $model.search({ :name<whateverable> }).delete;
  is $model.search({ :name<whateverable> }).count, 0, 'clean OK';
}, 'OK';
