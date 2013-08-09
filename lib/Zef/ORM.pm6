#!/usr/bin/env perl6

use Zef::ORM::Model;
use DBIish;

class Zef::ORM {
  has Str $.db;
  has Str $.dbtype = 'mysql';
  has $.dbh;

  has $.translator = {
    mysql => {
      information_schema => 'INFORMATION_SCHEMA',
      information_tables => 'tables',
      information_cols   => 'columns',
      info_cols_table    => 'TABLE_NAME',
      info_cols_db       => 'TABLE_SCHEMA',
      col_types          => 'COLUMN_NAME, COLUMN_TYPE, COLUMN_KEY'
    }
  };

  method open(Str :$user, Str :$pass, Str :$host = 'localhost', Int :$port = 3306, Str :$db, Str :$dbtype = 'mysql') {
    $!db     = $db;
    $!dbtype = $dbtype;
    $!dbh    = DBIish.connect($dbtype,
                              :user\   ($user    ),
                              :password($pass    ),
                              :host\   ($host    ),
                              :port\   ($port    ),
                              :database($db      ),
                              PrintError => True                               
                             );
    die 'Could not connect to db' if !$!dbh.defined;
  }

  method close { $!dbh.disconnect; }

  method model(Str $tbl) {
    my $sql = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.tables WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?";
    my $prp = $!dbh.prepare($sql);
    my $exists = False;
    $prp.execute($!db, $tbl);
    while my $d = $prp.fetchrow_array {
      $exists = True;
      last;
    }
    $prp.finish;
    if !$exists {
      $!dbh.do("CREATE TABLE $tbl ( ID INT PRIMARY KEY AUTO_INCREMENT NOT NULL );");
    }
    #read table structure
    $sql  = "SELECT {$!translator{$!dbtype}<col_types>} FROM "
            ~ "{$!translator{$!dbtype}<information_schema>}." 
            ~ "{$!translator{$!dbtype}<information_cols>} WHERE "
            ~ "{$!translator{$!dbtype}<info_cols_table>} = ? AND "
            ~ "{$!translator{$!dbtype}<info_cols_db>} = ?";

    #get columns for Model
    $prp = $!dbh.prepare($sql);
    my %cols;
    $prp.execute($tbl, $!db);

    while $d = $prp.fetchrow_array {
      %cols{$d[0]} = { type => $d[1], key => $d[2] }; 
    };

    $prp.finish;

    #instantiate a new Zef::ORM::Model object
    my Zef::ORM::Model $model = Zef::ORM::Model.new(columns => %cols, table => $tbl, dbh => $!dbh);
    return $model;
  }
}
