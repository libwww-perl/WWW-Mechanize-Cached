#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
    use_ok('WWW::Mechanize::Cached');
}

my $mech = WWW::Mechanize::Cached->new;

ok( !defined( $mech->is_cached ), "is_cached should default to undef" );

