#!/usr/bin/env perl6

class Zef::ORM::Model::Obj {
  has Str @.savequeue;
  has     $.parent;
  has     %.data;
  has     $.id;

  method assign(Str $key, $val) {
    %.data{$key} = $val;
  }

  method get(Str $key) {
    return %!data{$key};
  }

  method save {
    my Str $tblfix;
    for %.data.keys -> $kk {
      $!parent.dbh.do($tblfix) if ($tblfix = $!parent.checkcol($kk, %.data{$kk})).chars > 0;
    }
    my Str $sql;
    my Str $order;
    if !$.id.defined {
      #new record
      $sql ~= "INSERT INTO {$!parent.table} (" ;
      $sql ~= ($order = %.data.keys.join(', '));
      $sql ~= ") VALUES ({(0..^ %!data.keys.elems).join(',').subst(rx{<[\d]>+},'?',:g)});";
    } else {
      $sql ~= "UPDATE {$!parent.table} SET ";
      $sql ~= ($order = %.data.keys.join('=?, ')) ~ '=?';
      $sql ~= " WHERE ID = ?";
    }
    my $stmt = $!parent.dbh.prepare($sql);
    #hash keys aren't guaranteed order
    my @vals;
    for $order.split(rx{<[,=]>+}) -> $key {
      next if $key.trim eq '?';
      @vals.push( %!data{$key.trim} );
    }
    @vals.push( $!id ) if $!id.defined;
    $stmt.execute(@vals);
    $!id = $!parent.dbh.mysql_insertid if !$!id.defined;
    $stmt.finish;
  }
}

