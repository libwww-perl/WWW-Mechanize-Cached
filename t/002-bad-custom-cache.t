use strict;
use warnings FATAL => 'all';
use lib 't';

use Test::More;

BEGIN {
    eval "use Test::Warn";
    plan skip_all => "Test::Warn required for testing invalid cache parms"
        if $@;
    plan tests => 3;
}

BEGIN {
    use_ok('WWW::Mechanize::Cached');
}

my $mech;

warning_like {
    $mech = WWW::Mechanize::Cached->new(
        cache     => { parm => 73 },
        autocheck => 1
    );
}
qr/cache param/, "Threw the right warning";

isa_ok(
    $mech, "WWW::Mechanize::Cached",
    "Even with a bad cache, still return a valid object"
);
