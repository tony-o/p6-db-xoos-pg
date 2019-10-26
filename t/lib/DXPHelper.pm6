use DB::Xoos;
unit module DXPHelper;

state $db;
sub get-db(*%_) is export {
  my $dsn = %*ENV<XOOS_TEST> // 'pg://xoos:@127.0.0.1/xoos';
  my $promise = Promise.new;
  await Promise.anyof(
    start { sleep 5; try $promise.break; },
    start {
      CATCH { default { warn $_; } }
      $db = DB::Xoos.new(:$dsn, options => { prefix => '', :dynamic } );
      $db = Nil unless $db.db.query('select 1 as x').hash<x> == 1;
      try $promise.keep;
    }
  );

  return $db if $promise.status ~~ Kept;
  Nil;
}

