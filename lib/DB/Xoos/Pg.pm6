use DB::Pg;
unit class DB::Xoos::Pg;

method get-db(%params, :%options) {
  die 'No connection parameters provided to DB::Xoos::Pg'
    unless %params.elems;

  my $db;
  my %db-opts = |(:%params<db>//{ });
  %db-opts<database> = %params<db>   if %params<db>;
  %db-opts<host>     = %params<host> if %params<host>;
  %db-opts<port>     = %params<port> if %params<port>;
  %db-opts<user>     = %params<user> if %params<user>;
  %db-opts<password> = %params<pass> if %params<pass>;

  my $conninfo = join " ",
    ('dbname=' ~ %db-opts<database>),
    ('host=' ~ %db-opts<host>),
    ('user=' ~ %db-opts<user> if %db-opts<user>.defined),
    ('password=' ~ %db-opts<password> if %db-opts<password>.defined);

  $db = DB::Pg.new(:$conninfo);

  $db;
}
