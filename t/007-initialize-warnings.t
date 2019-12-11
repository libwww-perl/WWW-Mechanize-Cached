use strict;
use warnings FATAL => 'all';

use Test::More;
use WWW::Mechanize::Cached;

BEGIN {
    eval "use Test::Warn";
    plan skip_all => "Test::Warn required for testing initialization warnings"
        if $@;
}

use lib 't';
use TestCache;

my $cache = TestCache->new();
isa_ok( $cache, 'TestCache' );

my $was_warning = $^W;
   $^W          = 1;

my $mech;

warnings_are
    {
        $mech = WWW::Mechanize::Cached->new(
            cache => $cache,
        );
    }
    [ ],
    "No warnings for accepted 'cache' parameter";

for my $boolean_attribute (
    qw(
        is_cached
        positive_cache
        ref_in_cach_key
        _verbose_dwarn
        cache_undef_content_length
        cache_zero_content_length
        cache_mismatch_content_length
    )
) {
    warnings_are
        {
            $mech = WWW::Mechanize::Cached->new(
                $boolean_attribute => 1,
            );
        }
        [ ],
        "No warnings for accepted '$boolean_attribute' parameter";
}

warnings_exist
    {
        $mech = WWW::Mechanize::Cached->new(
            not_my_argument => 1,
        );
    }
    qr/not_my_argument/,
    'Unrecognized arguments passed through to WWW::Mechanize';


# Put this back
$^W = $was_warning;

done_testing();
