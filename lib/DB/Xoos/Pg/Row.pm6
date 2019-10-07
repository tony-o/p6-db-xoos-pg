unit role DB::Xoos::Pg::Row;

multi submethod BUILD(:$model, :%field-data, :%field-changes?, :$is-dirty = True, :$db) { callsame; }

method update {
  my @keys = self.columns.grep({ $_.value<is-primary-key> || $_.value<auto-increment> });
  my %filter;
  warn "creating new row, define a primary key for {self.^name}"
    unless @keys.elems;
  @keys.map({ my $value = self.field-changes{$_.key}//self.field-data{$_.key}; %filter{$_.key} = $value if $value; });
  if %filter.keys.elems != @keys.elems || Any ~~ self.field-data{@keys.grep({ $_.value<is-primary-key> })[0].key} {
    #create
    my %field-data = self.columns.map({
      my $x = $_.key;
      $x => (self.field-changes{$x}//self.field-data{$x}//Nil)
        if @keys.grep({ $_.key ne $x && $_.value<auto-increment>//True }) && self.field-changes{$x}//self.field-data{$x}
    });
    try {
      CATCH {
        if $_.^can('native-message') && $_.native-message ~~ m:i{'unique constraint failed'} {
          my $anon = self.^name ~~ m{'<anon|'};
          die "Primary key constraint violated: (" ~
            @keys.map({ "{$_.key} => '{%filter{$_.key}}'" }).join(', ') ~
            ") in {$anon ?? (self.model.^name.subst(/'Model'/, 'Row') ~ ' (anon)') !! self.^name}";
        }
        .rethrow;
      };
      my $new-id = self.model.insert(%field-data);
      my $key    = @keys.grep({ $_.value<auto-increment>//False })[0].key // Nil;
      my %params = self.columns.grep({
        $_.value<unique> && !$_.value<is-primary-key>
      }).map({ .key => self.get-column(.key) });

      if %params.keys {
        $new-id = self.model.search(%params).first.as-hash{$key};
      }
      self.field-data{$key} = $new-id
        if $key && $new-id;
    };
  } elsif self.model.search(%filter).count == 1 {
    #update
    return unless self.field-changes.keys.elems;
    self.model.search(%filter).update(self.field-changes);
  }
  #TODO refresh self.field-data
  for self.field-changes -> $f {
    self.field-data{$f.key} = $f.value
      if !(@keys.grep({ $_.key eq $f.key })[0].value<auto-incrememt>//False);
  }
  self.field-changes = ();
  self.is-dirty(False);
}
