use strict;
use warnings FATAL => 'all';
use lib 't';

use Test::More tests => 4;
use constant URL => 'http://www.time.gov/timezone.cgi?Central/d/-6';
use TestCache;

BEGIN {
    use_ok( 'WWW::Mechanize::Cached' );
}

my $cache = TestCache->new();
isa_ok( $cache, 'TestCache' );

my $mech = WWW::Mechanize::Cached->new( cache => $cache, autocheck => 1 );
isa_ok( $mech, 'WWW::Mechanize::Cached' );

my $first  = $mech->get( URL );
my $second = $mech->get( URL );
my $third  = $mech->get( URL );

is( $third->content, "DUMMY", "Went thru my dummy cache" );
