use DB::Xoos::Result;
use DB::Xoos::SQL;
use DB::Xoos::RowInflator;
unit role DB::Xoos::Pg::Result does DB::Xoos::Result does DB::Xoos::SQL[{ :identifier<`>, :value<">, :placeholder<$> }] does DB::Xoos::RowInflator;

has $!iter;

method search(%filter?, %options?) {
  my $clone = self.^mro[1].new(
    :driver(self.driver),
    :db(self.db),
    :dbo(self.dbo),
    :columns(self.columns),
    :relations(self.?'relations'()//[]),
  );
  $clone.set-inflate(self.inflate);
  $clone.set-options( %( self.options , %options ) );
  $clone.set-filter( %( self.filter, %filter ) );
  $clone;
}

method all(%filter?, %options?) {
  return self.search(%filter, %options).all
    if %filter.keys || %options.keys;
  my $sql = self.sql-select(self.filter, self.options);
  my @results = self.db.query($sql<sql>, |$sql<params>).hashes.map({
    next unless $_;
    (self.?inflate()//True) && Any !~~ self.?row()
      ?? self.inflate($_)
      !! $_
  });

  @results;
}

method !iterate(Bool :$next = False) {
  my $row;
  if $next && $!iter {
    return Nil if $!iter<i> >= $!iter<s>.elems;
    $row = $!iter<s>[$!iter<i>++];
    $row = self.inflate($row) if self.?inflate;
    return $row;
  }
  my $sql = self.sql-select(self.filter, self.options);
  $!iter = {
    i => 0,
    s => self.db.db.cursor($sql<sql>, |$sql<params>, :hash);
  }
  self!iterate(:next);
}

method first(%filter?, %options?) {
  return self.search(%filter, %options).first
    if %filter.keys || %options.keys;
  self!iterate;
}

method next(%filter?, %options?) {
  return self.search(%filter, %options).next
    if %filter.keys || %options.keys;
  self!iterate(:next);
}

method count(%filter?, %options?) {
  return self.search(%filter, %options).count
    if %filter.keys || %options.keys;
  my $sql = self.sql-count(self.filter);
  self.db.query($sql<sql>, |$sql<params>).hash<cnt>;
}

method update(%values) {
  my $sql = self.sql-update(self.filter, self.options, %values);
  self.db.query($sql<sql>, |$sql<params>);  
}

method delete(%filter?, %options?) {
  return self.search(%filter, %options).delete
    if %filter.keys || %options.keys;
  my $sql = self.sql-delete(self.filter, self.options);
  self.db.query($sql<sql>, |$sql<params>);  
}

method insert(%values) {
  my $sql = self.sql-insert(%values);
  self.db.query($sql<sql>, |$sql<params>);
  self.db.query('select LASTVAL() as nid;').hash<nid>;
}
