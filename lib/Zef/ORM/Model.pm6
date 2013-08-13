#!/usr/bin/env perl6

use Zef::ORM::Statement;
use Zef::ORM::Model::Obj; 

class Zef::ORM::Model {
  has Str                       $.table;
  has Zef::ORM::Model::Obj      @.objects;
  has                           $.dbh;
  has                           %.columns;

  method find(Str $where, Array $values? = [ ] ) {
    #init stmt
    my Zef::ORM::Statement $stmt .= new(table => $!table, where => $where, values => $values, dbh => $!dbh);
    return $stmt;
  }

  method create {
    my $obj = Zef::ORM::Model::Obj.new( parent => self );
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

