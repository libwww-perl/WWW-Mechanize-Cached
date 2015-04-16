#!/usr/bin/env perl

use strict;
use warnings;

use Test::Fatal;
use Test::More;
use Test::RequiresInternet ( 'www.wikipedia.com' => 80 );
use WWW::Mechanize::Cached;

my $mech = WWW::Mechanize::Cached->new;

is(
    exception {
        $mech->get('http://www.wikipedia.com');
    },
    undef,
    'no exceptions',
);

done_testing();
