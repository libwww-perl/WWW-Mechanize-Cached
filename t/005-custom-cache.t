use strict;
use warnings FATAL => 'all';
use lib 't';

use Test::More tests => 4;
use constant URL => 'http://www.google.com';
use TestCache;

BEGIN {
    use_ok( 'WWW::Mechanize::Cached' );
}

my $cache = TestCache->new();
isa_ok( $cache, 'TestCache' );

my $mech = WWW::Mechanize::Cached->new( cache => $cache, autocheck => 0 );
isa_ok( $mech, 'WWW::Mechanize::Cached' );

my $first  = $mech->get( URL );
my $second = $mech->get( URL );
my $third  = $mech->get( URL );

SKIP: {
    skip "cannot connect to google", 1 unless $mech->success;
    is( $third->content, "DUMMY", "Went thru my dummy cache" );
}
