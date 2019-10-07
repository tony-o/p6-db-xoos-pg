use DB::Xoos::Role::Searchable;
use DB::Xoos::Pg::Row;
unit role DB::Xoos::Pg::Searchable does DB::Xoos::Role::Searchable;

has $!iter;
has $!ident = '`';
has $!quote = '"';
has %!query;
has %!filter;
has %!option;

multi submethod BUILD (:%!filter, :%!option) {
  self.row.WHAT.^add_role(DB::Xoos::Pg::Row);
}

multi method search(%filters, %options?) {
  my (%option, %filter);
  if (%!filter//{}).keys {
    %filter = |%!filter, %filters;
  } else {
    %filter = %filters;
  }
  if (%!option//{}).keys && %options {
    %option = |%!option, %options;
  } elsif %options {
    %option = %options;
  }
  my $clone = self.clone;
  $clone!set-filter(%filter);
  $clone!set-option(%option);
  $clone;
}

method all(%filter?) {
  return self.search(%filter).all if %filter;
  die 'Must be able to .db' unless self.^can('db');
  my $sql  = self.sql;
  my @rows  = self.db.query($sql<sql>, |$sql<params>).hashes;
  my @rtv;
  for @rows -> $row {
    my $new-model;
    try {
      CATCH { default {
        warn $_;
        @rtv.push: $row;
      } }
      @rtv.push: self.row.new(:field-data($row), :!is-dirty, :db(self.db), :model(self));
      @rtv[*-1] does DB::Xoos::Pg::Row;
    }
  }
  @rtv;
}

method !iterate(Bool :$next = False) {
  my $row;
  if $next && $!iter {
    return Nil if $!iter<i> >= $!iter<s>.elems;
    $row = $!iter<s>[$!iter<i>++];
    $row = self.row.new(:field-data($row), :!is-dirty, :db(self.db), :model(self), :field-changes({}));
    $row does DB::Xoos::Pg::Row;
    return $row;
  }
  my $sql = self.sql;
  $!iter  = { i => 0, s => self.db.db.cursor($sql<sql>, |$sql<params>, :hash) };
  self!iterate(:next);
}

method first(%filter?) {
  return self.search(%filter).first if %filter;
  die unless self.^can('table-name');
  return self!iterate;
}
method insert(%data) {
  die unless self.^can('table-name');
  my $sql = self.sql(:type<insert>, :update(%data));
  my $r = self.db.query($sql<sql>, |$sql<params>);
  Nil;
}
method next(%filter?) {
  return self.search(%filter).first if %filter;
  die unless self.^can('table-name');
  return self!iterate(:next);
}
method count(%filter?) {
  return self.search(%filter).count if %filter;
  die 'Must be able to .db' unless self.^can('db');
  my $sql = self.sql(:field-override('count(*) cnt'));
  self.db.query($sql<sql>, |$sql<params>)\
    .hash<cnt> // 0;
  
}
method update(%values, %filter?) {
  return self.search(%filter).update(%values)
    if %filter;
  die 'Please connect to a database first'
    unless self.^can('db');
  my $sql = self.sql(:type<update>, :update(%values));
  self.db.query($sql<sql>, |$sql<params>) // 0;
}
method delete(%filter?) {
  return self.search(%filter).delete if %filter;
  die unless self.^can('table-name');
  my $sql = self.sql(:type<delete>);
  my $r = self.db.query($sql<sql>, |$sql<params>);
  Nil;
}
method sql($page-start?, $page-size?, :$field-override = Nil, :$type = 'select', :%update?) {
  my (@*params, $sql);
  given $type.lc {
    when 'update' {
      $sql ~= 'UPDATE ';
      $sql ~= self.table-name//'dummy';
      $sql ~= self!gen-update-values(%update);
      $sql ~= self!gen-filters(key-table => self.table-name) if %!filter;
    }
    when 'select' {
      $sql ~= 'SELECT ';
      $sql ~= self!gen-field-sels~' ' unless $field-override;
      $sql ~= "$field-override " if $field-override;
      $sql ~= 'FROM ' ~ (self.table-name//'dummy') ~ ' as self';
      $sql ~= self!gen-joins;
      $sql ~= self!gen-filters if %!filter;
      $sql ~= self!gen-order unless $field-override;
    }
    when 'delete' {
      $sql ~= 'DELETE FROM ';
      $sql ~= self.table-name//'dummy';
      $sql ~= self!gen-filters(key-table => self.table-name) if %!filter;
    }
    when 'insert' {
      $sql ~= 'INSERT INTO ';
      $sql ~= self!gen-id(self.table-name);
      $sql ~= ' ('~self!gen-field-ins(%update)~') ';
      $sql ~= 'VALUES ('~(1..@*params.elems).map({ '$' ~ $_ }).join(', ') ~ ')';
    }
  };
  { sql => $sql, params => @*params };
}

method !gen-field-sels {
  %!option<fields>.defined && %!option<fields>.keys
    ?? %!option<fields>.map({ self!gen-id($_) }).join(', ')
    !! '*';
}

method !gen-filters(:$key-table = 'self') {
  ' WHERE ' ~ self!gen-pairs(%!filter, 'AND', True, :$key-table);
}

method !gen-field-ins(%fields) {
  my @cols;
  for %fields -> $col {
    my ($key, $val) = $col.kv;
    @cols.push(self!gen-id($key));
    @*params.push($val);
  }
  @cols.join(', ');
}

method !set-filter(%filter) { %!filter = %filter; }
method !set-option(%option) { %!option = %option; }
method !gen-id($value, :$table?) {
  my @s = $value.split('.');
  @s.prepend($table)
    if $table.defined && $table ne '' && @s.elems == 1;
  "\"{@s.join('"."')}\"";
}

method !gen-update-values(%values) {
  ' SET '~%values.keys.map({ self!gen-quote($_, :table('')) ~ ' = '~self!gen-quote(%values{$_})}).join(', ');
}

method !gen-pairs($kv, $type = 'AND', $force-placeholder = False, :$key-table?, :$val-table?) {
  my @pairs;
  if $kv ~~ Pair {
    my ($eq, $val, $skp);
    if $kv.key ~~ Str && $kv.key eq ('-or'|'-and') {
      @pairs.push: self!gen-pairs($kv.value, $kv.key.uc.substr(1), $force-placeholder, :$key-table, :$val-table)~' )';
      $eq := 'andor';
    } elsif $kv.value ~~ Hash {
      $eq  := $kv.value.keys[0] eq '-raw' ?? $kv.value.values[0] !! $kv.value.keys[0];
      $val := $kv.value.keys[0] eq '-raw' ?? '' !! $kv.value.values[0];
      $skp = $kv.value.keys[0] eq '-raw';
    } elsif $kv.value ~~ Block && $kv.value.().elems == 2 {
      $eq  := $kv.value.()[0] eq '-raw' ?? $kv.value.()[1] !! $kv.value.()[0];
      $val := $kv.value.()[0] eq '-raw' ?? '' !! $kv.value.()[1];
      $skp = $kv.value.()[0] eq '-raw';
    } elsif $kv.value ~~ Array {
      my @arg;
      for @($kv.value) -> $x {
        @arg.push( self!gen-quote($x, $force-placeholder) );
      }
      $eq  := 'in';
      @pairs.push: self!gen-id($kv.key, :table($key-table))~" $eq ("~@arg.join(', ')~")";
    } else {
      $eq  := '=';
      $val := $kv.value
    }
    @pairs.push: self!gen-id($kv.key, :table($key-table))~" $eq "~ ($skp ?? '' !! self!gen-quote($val, $force-placeholder, :table($val-table)))
      if $eq ne ('andor'|'in');
  } elsif $kv ~~ Hash {
    for %($kv).pairs -> $x {
      @pairs.push: '( '~self!gen-pairs($x.key eq ('-or'|'-and') ?? $x.value !! $x, $x.key eq ('-or'|'-and') ?? $x.key.uc.substr(1) !! $type, $force-placeholder, :$key-table, :$val-table)~' )';
    }
  } elsif $kv ~~ Array {
    my $arg;
    for @($kv) -> $x {
      $arg = $x.WHAT ~~ List ?? $x.pairs[0].value !! $x;
      @pairs.push: '( '~self!gen-pairs($arg, $type, $force-placeholder, :$key-table, :$val-table)~' )';
    }
  }
  @pairs.join(" $type ");
}

method !gen-join-str(Hash() $attr where { $_<table>.defined && $_<on>.defined }) {
  my $join = ' ';
  $join ~= $attr<type> ?? $attr<type> !! 'left outer';
  $join ~= ' join ';
  $join ~= self!gen-id($attr<table>);
  $join ~= ' as '~$attr<as> if $attr<as>.defined;
  $join ~= ' on ';
  $join ~= self!gen-pairs($attr<on>, :key-table($attr<as>//$attr<table>), :val-table<self>);
  $join;
}

method !gen-joins {
  return '' unless %!option<join>;
  my $join = '';
  if %!option<join> ~~ Array {
    $join = [~] self!gen-join-str($_)
      for %!option<join>.values;
  } else {
    $join ~= self!gen-join-str(%!option<join>);
  }
}

method !gen-quote(\val, $force = False, :$table) {
  if !$force && val =:= try val."{val.^name}"() {
    return self!gen-id(val, :$table);
  } else {
    @*params.push: val;
    return '$' ~ @*params.elems;
  }
}
method !gen-order {
  my @pairs;
  if %!option<order-by>.defined {
    for @(%!option<order-by>) -> $order {
      @pairs.push(
        $order ~~ Pair
          ?? $order.key ~ ' ' ~ $order.value.uc
          !! "$order ASC"
      );
    }
  }
  @pairs.elems == 0 ?? '' !! ' ORDER BY ' ~ join(', ', @pairs);
}
