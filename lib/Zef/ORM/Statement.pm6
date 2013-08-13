#!/usr/bin/env perl6

use Zef::ORM::Model::Obj;

class Zef::ORM::Statement {
  has Bool $.built = False;
  has Str  $.table;
  has Str  $.where;
  has Str  $.stmt;
  has Str  @.values;
  has      $.dbh;
  has      $statement;

  method build {
    $!stmt  = "SELECT * FROM $!table $!where"; 
    return self;
  }

  method exec (@values? = @.values) {
    @!values = @values;
    self.build;
    $!statement = $!dbh.prepare($!stmt);
    $!statement.execute( @!values );
  }

  method finish {
    $!statement.finish;
  }

  method next {
    my $hash = $!statement.fetchrow_hashref;
    return $hash if !$hash;
    my $obj  = Zef::ORM::Model::Obj.new( id => $hash<ID> );
    for $hash.keys -> $k {
      $obj.assign($k, $hash{$k});
    }
    return $obj;
  }
  
}
