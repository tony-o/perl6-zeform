#!/usr/bin/env perl6

use lib './lib';
use Zef::ORM;

my Zef::ORM $o = Zef::ORM.new;

$o.open(:user('zef'), :pass('zef'), :db('test'));

my $tbl = $o.model('pkgs');

my $type1 = $tbl.create;
my $type2 = $tbl.create;
$type2.assign('intfield', 'x' x (1 + 4.rand) );
$type1.assign('intfield', rand);
$type1.save;
$type2.save;

my $result = $tbl.find('WHERE ID = ? OR ID = ? '); 

$result.exec( [$type1.id, $type2.id] );
my $data;
while ( $data = $result.next ) {
  say "{$data.get(<ID>)}\t{$data.get(<intfield>)}";
}
$result.finish;


$o.close;
