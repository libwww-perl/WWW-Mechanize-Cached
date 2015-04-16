#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;

BEGIN {
    use_ok('WWW::Mechanize::Cached');
}

my $mech = WWW::Mechanize::Cached->new;

$mech->get('http://www.wikipedia.com');