#!perl

use strict;
use warnings FATAL => 'all';
use Test::More tests => 14;
use Cache::FileCache;
use Devel::SimpleTrace;
use constant URL => 'http://www.google.com';

BEGIN {
    use_ok( 'WWW::Mechanize::Cached' );
}

my $stashpage;
my $secs = time; # Handy string that will be different between runs
my $cache_parms = {
    namespace => "www-mechanize-cached-$secs",
    default_expires_in => "1d",
};

FIRST_CACHE: {
    my $cache = Cache::FileCache->new( $cache_parms );
    isa_ok( $cache, 'Cache::FileCache' );

    my $mech = WWW::Mechanize::Cached->new( autocheck => 0, cache => $cache );
    isa_ok( $mech, 'WWW::Mechanize::Cached' );

    ok( !defined( $mech->is_cached ), "No request status" );

    my $first  = $mech->get( URL )->content;
    SKIP: {
        skip "cannot connect to google", 6 unless $mech->success;
        ok( defined $mech->is_cached, "First request" );
        ok( !$mech->is_cached, "should be NOT cached" );
        $stashpage = $first;
    
        my $second = $mech->get( URL )->content;
        ok( defined $mech->is_cached, "Second request" );
        ok( $mech->is_cached, "should be cached" );
    
        sleep 3; # 3 due to Referer header
        my $third  = $mech->get( URL )->content;
        ok( $mech->is_cached, "Third request should be cached" );
    
        is( $second => $third, "Second and third match" );
    }
}


SECOND_CACHE: {
    my $cache = Cache::FileCache->new( $cache_parms );
    isa_ok( $cache, 'Cache::FileCache' );

    my $mech = WWW::Mechanize::Cached->new( autocheck => 0, cache => $cache );
    isa_ok( $mech, 'WWW::Mechanize::Cached' );

    my $fourth = $mech->get( URL )->content;
    SKIP: {
        skip "cannot connect to google", 2 unless $mech->success;
        is_deeply( [split /\n/, $fourth], [split /\n/, $stashpage], "Fourth request matches..." );
        ok( $mech->is_cached, "... because it's from the same cache" );
    }
}
