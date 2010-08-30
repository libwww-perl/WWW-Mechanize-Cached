use warnings FATAL => 'all';

package WWW::Mechanize::Cached;

use Moose;
extends 'WWW::Mechanize';
use Carp qw( carp croak );
use Data::Dump qw( dump );
use Storable qw( freeze thaw );

has 'cache'            => ( is => 'rw', );
has 'is_cached'        => ( is => 'rw', );
has 'positive_cache'   => ( is => 'rw', );
has 'ref_in_cache_key' => ( is => 'rw', );

# ABSTRACT: Cache response to be polite

=head1 SYNOPSIS

    use WWW::Mechanize::Cached;

    my $cacher = WWW::Mechanize::Cached->new;
    $cacher->get( $url );

    # or, with your own Cache object
    use CHI;
    use WWW::Mechanize::Cached;
    
    my $cache = CHI->new(
        driver   => 'File',
        root_dir => '/tmp/mech-example'
    );
    
    my $mech = WWW::Mechanize::Cached->new( cache => $cache );
    $mech->get("http://www.google.com");
    

=head1 DESCRIPTION

Uses the L<Cache::Cache> hierarchy to implement a caching Mech. This lets one
perform repeated requests without hammering a server impolitely.

Repository: L<http://github.com/oalders/www-mechanize-cached/tree/master>

=head1 CONSTRUCTOR

=head2 new

Behaves like, and calls, L<WWW::Mechanize>'s C<new> method. Any params, other
than those explicitly listed here are passed directly to WWW::Mechanize's
constructor.

You may pass in a C<< cache => $cache_object >> if you wish. The
I<$cache_object> must have C<get()> and C<set()> methods like the
C<Cache::Cache> family.

The default Cache object is set up with the following params:

    my $cache_params = {
        default_expires_in => "1d", namespace => 'www-mechanize-cached',
    };
    
    $cache = Cache::FileCache->new( $cache_params );
    
    
This should be fine if you only want to use a disk-based cache, you only want
to cache results for 1 day and you're not in a shared hosting environment.
If any of this presents a problem for you, you should pass in your own Cache
object.  These defaults will remain unchanged in order to maintain backwards
compatibility.  

For example, you may want to try something like this:

    use WWW::Mechanize::Cached;
    use CHI;
    
    my $cache = CHI->new(
        driver   => 'File',
        root_dir => '/tmp/mech-example'
    );
    
    my $mech = WWW::Mechanize::Cached->new( cache => $cache );
    $mech->get("http://www.google.com");


=head1 METHODS

Most methods are provided by L<WWW::Mechanize>. See that module's
documentation for details.

=head2 cache( $cache_object )

Requires an caching object which has a get() and a set() method. Using the CHI
module to create your cache is the recommended way. See new() for examples.

=head2 is_cached()

Returns true if the current page is from the cache, or false if not. If it
returns C<undef>, then you don't have any current request.

=head2 positive_cache( 0|1 )

As of v1.36 positive caching is enabled by default. Up to this point,
this module had employed a negative cache, which means it cached 404
responses, temporary redirects etc. In most cases, this is not what you want,
so the default behaviour now better reflects this. You can revert to the
negative cache quite easily:

    # cache everything (404s, all 300s etc)
    $mech->positive_cache( 0 );
    
=head2 ref_in_cache_key( 0|1 )

Allow the referring URL to be used when creating the cache key.  This is off
by default.  In almost all cases, you will not want to enable this, but it is
available to you for reasons of backwards compatibility and giving you enough
rope to hang yourself.  

Previous to v1.36 the following was in the "BUGS AND LIMITATIONS" section:

    It may sometimes seem as if it's not caching something. And this may well
    be true. It uses the HTTP request, in string form, as the key to the cache
    entries, so any minor changes will result in a different key. This is most
    noticable when following links as L<WWW::Mechanize> adds a C<Referer>
    header.

See RT #56757 for a detailed example of the bugs this functionality can
trigger.

=head1 THANKS

Iain Truskett for writing this in the first place.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Mechanize::Cached

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Mechanize-Cached>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Mechanize-Cached>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Mechanize-Cached>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Mechanize-Cached>

=back

=head1 PAST AUTHORS

Iain Truskett <spoon@cpan.org>

Maintained from 2004 - July 2009 by Andy Lester <petdance@cpan.org>

=head1 SEE ALSO

L<WWW::Mechanize>.

=cut

sub new {
    my $class     = shift;
    my %mech_args = @_;

    my $cache = delete $mech_args{cache};
    if ( $cache ) {
        my $ok 
            = ( ref( $cache ) ne "HASH" )
            && $cache->can( "get" )
            && $cache->can( "set" );
        if ( !$ok ) {
            carp "The cache param must be an initialized cache object";
            $cache = undef;
        }
    }

    my %cached_args = %mech_args;
    
    delete $mech_args{ref_in_cache_key};
    delete $mech_args{positive_cache};

    my $self = $class->SUPER::new( %mech_args );

    if ( !$cache ) {
        require Cache::FileCache;
        my $cache_params = {
            default_expires_in => "1d",
            namespace          => 'www-mechanize-cached',
        };
        $cache = Cache::FileCache->new( $cache_params );
    }

    $self->cache( $cache );
    
    my %defaults = (
        ref_in_cache_key => 0,
        positive_cache => 1,
    );
    
    foreach my $arg ('ref_in_cache_key', 'positive_cache' ) {
        if ( exists $cached_args{$arg} ) {
            $self->$arg( $cached_args{$arg} );
        }
        else {
            $self->$arg( $defaults{$arg} );
        }
    }
    $self->is_cached( undef );

    return $self;
}

sub _make_request {
    
    my $self    = shift;
    my $request = shift;
    my $req     = $request;

    $self->is_cached( 0 );

    # An odd line to need.
    # No idea what purpose this serves?  OALDERS
    $self->{proxy} = {} unless defined $self->{proxy};

    # RT #56757
    if ( !$self->ref_in_cache_key ) {
        my $clone = $request->clone;
        $clone->header( Referer => undef );
        $req = $clone->as_string;
    }

    my $response = $self->cache->get( $req );
    if ( $response ) {
        $response = thaw( $response );
    }

    if ( $self->_cache_ok( $response ) ) {
        $self->is_cached( 1 );
        return $response;
    }

    $response = $self->SUPER::_make_request( $request, @_ );

    # http://rt.cpan.org/Public/Bug/Display.html?id=42693
    $response->decode();
    delete $response->{handlers};

    if ( $self->_cache_ok( $response ) ) {
        $self->cache->set( $req, freeze( $response ) );
    }

    return $response;
}

sub _cache_ok {

    my $self     = shift;
    my $response = shift;

    return 0 if !$response;
    return 1 if !$self->positive_cache;

    if ( ( $response->code >= 200 && $response->code < 300 )
        || $response->code == 301 )
    {
        return 1;
    }
    return 0;

}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

"We miss you, Spoon";    ## no critic

