use DB::Xoos::Pg;
unit module DXPHelper;

state $db;
sub get-db(*%_) is export {
  my $dsn = %*ENV<XOOS_TEST> // 'pg://xoos:@127.0.0.1/xoos';
  my $db;
  my $promise = Promise.new;
  await Promise.anyof(
    start { sleep 5; try $promise.break; },
    start {
      $db = DB::Xoos::Pg.new(:prefix(''));
      $db.connect($dsn, |%_);
      $db = Nil unless $db.db.query('select 1 as x').hash<x> == 1;
      try $promise.keep;
    }
  );

  return $db if $promise.status ~~ Kept;
  Nil;
}

