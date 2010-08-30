#!/usr/bin/env perl

# For more info on why these tests are important, see RT #56757 and RT #5705

use strict;
use warnings;
use lib 't';

use Find::Lib;
use Path::Class qw(file);
use Test::More tests => 63;
use TestCache;

BEGIN {
    use_ok( 'WWW::Mechanize::Cached' );
}

my $cache = TestCache->new();
isa_ok( $cache, 'TestCache' );

my $mech = WWW::Mechanize::Cached->new( cache => $cache, autocheck => 1 );
isa_ok( $mech, 'WWW::Mechanize::Cached' );

my @iter = ( 1..10 );
foreach my $i ( @iter ) {
    my $file = file( Find::Lib::base(), 'pages', "$i.html" );
    my $page = "file://" . $file->stringify;
    $mech->get( $page );
    cmp_ok( $mech->content, '==', $i, "page $i has correct content" );
    ok( !$mech->is_cached, "page $i NOT in cache");
}


check_cache( @iter );

diag("reversing page order");

check_cache( reverse @iter );

sub check_cache {
    
    my @pages = @_;
    foreach my $i ( @pages ) {
        my $page = "file://" . Find::Lib::base() . "/pages/$i.html";
        $mech->get( $page );
        cmp_ok( $mech->content, 'eq', 'DUMMY', "page $i has correct content" );
        ok( $mech->is_cached, "page $i IS in cache");
    }    
}

