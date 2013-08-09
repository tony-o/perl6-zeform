#!/usr/bin/env perl6

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
    return $!statement.fetchrow_hashref;
  }
  
}
