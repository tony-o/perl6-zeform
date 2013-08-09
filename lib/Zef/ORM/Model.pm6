#!/usr/bin/env perl6

use Zef::ORM::Statement;

class Zef::ORM::Model::obj {
  has Str @.savequeue;
  has     $.parent;
  has     %.data;
  has     $.id;
  method assign(Str $key, $val) {
    %.data{$key} = $val;
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



class Zef::ORM::Model {
  has Str                       $.table;
  has Zef::ORM::Model::obj      @.objects;
  has                           $.dbh;
  has                           %.columns;

  method find(Str $where, Array $values? = [ ] ) {
    #init stmt
    my Zef::ORM::Statement $stmt .= new(table => $!table, where => $where, values => $values, dbh => $!dbh);
    return $stmt;
  }

  method create {
    my $obj = Zef::ORM::Model::obj.new( parent => self );
    @!objects.push($obj);
    return $obj;
  }

  method checkcol ( Str $key, $val ) {
    #check col existing
    #say "Checking {$key} in \n {%!columns.perl}";
    my Str  $return   = '';
    my Bool $complete = False;
    if !%.columns{$key}.defined {
      $return ~= "ALTER TABLE {$!table} ADD COLUMN {$key} ";
    }
    #check column type and degrade sequentially
    {
      #int is first choice
      {
        if ( $val ~~ Int || $val ~~ rx{^<[\d]>+$} ?? True !! False ) && ( !%.columns{$key}.defined ) {
          $return  ~= 'INT;';
          $complete = True;
          #keep my definitions up to date
          %.columns{$key}<type> = 'int';
          return $return;
        }
        CATCH { default { } }
      }
      {
        #downgrade to varchar
        if ( 
             $val ~~ Str || 
             $val !~~ rx{^<[\d]>+$} ?? True !! False 
           ) && 
           ( 
             ( 
               %.columns{$key}.defined && 
               ( %.columns{$key}<type> ~~ rx{"varchar"} || 
                 %.columns{$key}<type> ~~ rx{"int"} 
               ) 
             ) || 
             !%.columns{$key}.defined 
           ) {
          return '' if %.columns{$key}.defined && 
                       %.columns{$key}<type> ~~ rx{<[\d]>+} &&
                       $val.chars < +( %.columns{$key}<type> ~~ rx{<[\d]>+} ) &&
                       %.columns{$key}<type> !~~ rx{'int'} ?? True !! False;
          $return  ~= "ALTER TABLE {$!table} CHANGE $key $key " if $return.chars == 0;
          $return  ~= "VARCHAR({$val.chars < 8 ?? 8 !! $val.chars + 1})";
          %.columns{$key}<type> = "varchar({$val.chars < 8 ?? 8 !! $val.chars + 1})";
          $complete = True;
          return $return;
        }
        CATCH { default { } }
      }
      {
        if $val ~~ Buf {
          $return  ~= "BLOB";
          $complete = True;
          return $return;
        }
        CATCH { default { } }
      }
    }
    return '';
  }
  
}

