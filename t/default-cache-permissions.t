use strict;
use warnings;

use Path::Tiny ();
use Test::More;
use Test::Needs qw( Cache::FileCache );

my $tmp;

BEGIN {
    if ( $^O =~ /MSWin/ ) {
        plan skip_all => 'POSIX mode bits required';
    }
    $tmp = Path::Tiny->tempdir;
    $ENV{XDG_CACHE_HOME} = "$tmp";
}

use WWW::Mechanize::Cached;

my $mech = WWW::Mechanize::Cached->new;
$mech->cache->set( 'k', 'v' );

my $dirs_checked = 0;
$tmp->visit(
    sub {
        my $path = shift;
        return unless $path->is_dir;
        return if "$path" eq "$tmp";
        $dirs_checked++;
        my $mode = ( stat $path )[2] & 07777;
        is(
            $mode & 077,
            0,
            sprintf( '%s has no group/world bits (mode=%04o)', $path, $mode ),
        );
    },
    { recurse => 1 },
);

ok(
    $dirs_checked,
    'walked at least one cache directory under XDG_CACHE_HOME'
);

done_testing;
