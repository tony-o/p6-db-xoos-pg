use lib 't/lib';
use DXPHelper;
use Test;

try {
  CATCH { default {
    plan 1;
    ok True, 'Skipping tests, unable to connect to postgres';
    exit 0;
  } }
  die 'no connection' unless get-db.db.query('select 1;').array;
}

plan 1;

subtest {
  lives-ok {
    get-db;
  }, 'Can connect to local test db';
}, 'OK';
