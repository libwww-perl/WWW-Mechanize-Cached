use strict;
use warnings FATAL => 'all';

package WWW::Mechanize::Cached;

use 5.006;

use Moose;
extends 'WWW::Mechanize';

use Carp qw( carp croak );
use Data::Dump qw( dump );
use Storable qw( freeze thaw );

has 'cache'                         => ( is => 'rw', );
has 'is_cached'                     => ( is => 'rw', );
has 'positive_cache'                => ( is => 'rw', );
has 'ref_in_cache_key'              => ( is => 'rw', );
has 'cache_undef_content_length'    => ( is => 'rw', );
has 'cache_zero_content_length'     => ( is => 'rw', );
has 'cache_mismatch_content_length' => ( is => 'rw', );
has '_verbose_dwarn'                => ( is => 'rw', );

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

    my %defaults = (
        ref_in_cache_key              => 0,
        positive_cache                => 1,
        cache_undef_content_length    => 0,
        cache_zero_content_length     => 0,
        cache_mismatch_content_length => 'warn',
        _verbose_dwarn                => 0,
    );

    for my $key ( keys %defaults ) {
        delete $mech_args{$key};
    }

    my $self = $class->SUPER::new( %mech_args );

    if ( !$cache ) {
        local $@;
        if ( eval { require Cache::FileCache; 1 } ) {
          my $cache_params = {
              default_expires_in => "1d",
              namespace          => 'www-mechanize-cached',
          };
          $cache = Cache::FileCache->new( $cache_params );
        } elsif ( eval { require CHI; 1 } ) {
          my $cache_params = {
            driver => 'File',
            expires_in => '1d',
            namespace => 'www-mechanize-cached',
          };
          $cache = CHI->new( %$cache_params );
        } else {
          croak("Could not create a default cache." .
            "Please make sure either CHI or Cache::FileCache are installed or configure manually as appropriate"
          );
        }
    }

    $self->cache( $cache );

    foreach my $arg ( keys %defaults ) {
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

    # decode strips some important headers.
    my $headers = $response->headers->clone;

    my $should_cache = $self->_response_cache_ok( $response, $headers );

    # http://rt.cpan.org/Public/Bug/Display.html?id=42693
    $response->decode();
    delete $response->{handlers};

    $self->cache->set( $req, freeze( $response ) ) if $should_cache;

    return $response;
}

sub _dwarn_filter {
    my ( $ctx, $ref ) = @_;
    return {
        hide_keys => [
            qw( _content cookie content set-cookie handlers cookie_jar cache req res page_stack )
        ]
    };

}

sub _dwarn {
    my $self    = shift;
    my $message = shift;

    return unless my $handler = $self->{onwarn};

    return if $self->quiet;

    if ( $self->_verbose_dwarn ) {
        my $payload = {
            self    => $self,
            message => $message,
            debug   => \@_,
        };
        require Data::Dump;
        return $handler->( Data::Dump::dumpf( $payload, \&_dwarn_filter ) );
    }
    else {
        return $handler->( $message );
    }
}

sub _response_cache_ok {
    my $self     = shift;
    my $response = shift;
    my $headers  = shift;

    return 0 if !$response;
    return 1 if !$self->positive_cache;

    return 0 if $response->code < 200;
    return 0 if $response->code > 301;

    if ( exists $headers->{'client-transfer-encoding'} ) {
        for my $cte ( @{ $headers->{'client-transfer-encoding'} } ) {

            # Transfer-Encoding = chunked means document consistency
            # is independent of Content-Length value,
            # and that Content-Length can be safely ignored.
            # Its not obvious how the lower levels represent a
            # failed chuncked-transfer yet.
            # But its safe to say relying on content-length proves pointless.
            return 1 if $cte eq 'chunked';
        }
    }

    my $size = $headers->{'content-length'};

    if ( not defined $size ) {
        if ( $self->cache_undef_content_length . q{} eq q{warn} ) {
            $self->_dwarn(
                q[Content-Length header was undefined, not caching]
                    . q[ (E=WWW_MECH_CACHED_CONTENTLENGTH_MISSING)],
                $headers
            );
            return 0;
        }
        if ( $self->cache_undef_content_length == 0 ) {
            return 0;
        }
    }

    if ( defined $size and $size == 0 ) {
        if ( $self->cache_zero_content_length . q{} eq q{warn} ) {
            $self->_dwarn(
                q{Content-Length header was 0, not caching}
                    . q{ (E=WWW_MECH_CACHED_CONTENTLENGTH_ZERO)},
                $headers
            );
            return 0;
        }
        if ( $self->cache_zero_content_length == 0 ) {
            return 0;
        }
    }

    if (    defined $size
        and $size != 0
        and $size != length( $response->content ) )
    {
        if ( $self->cache_mismatch_content_length . "" eq "warn" ) {
            $self->_dwarn(
                q{Content-Length header did not match contents actual length, not caching}
                    . q{ (E=WWW_MECH_CACHED_CONTENTLENGTH_MISSMATCH)} );
            return 0;
        }
        if ( $self->cache_mismatch_content_length == 0 ) {
            return 0;
        }
    }

    return 1;
}

sub _cache_ok {

    my $self     = shift;
    my $response = shift;

    return 0 if !$response;
    return 1 if !$self->positive_cache;

    return 0 if $response->code < 200;
    return 0 if $response->code > 301;

    return 1;
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

"We miss you, Spoon";    ## no critic

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
    $mech->get("http://www.wikipedia.org");


=head1 DESCRIPTION

Uses the L<Cache::Cache> hierarchy by default to implement a caching Mech. This
lets one perform repeated requests without hammering a server impolitely.
Please note that L<Cache::Cache> has been superceded by L<CHI>, but the default
has not been changed here for reasons of backwards compatibility.  For this
reason, you are encouraged to provide your own L<CHI> caching object to
override the default.

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
    $mech->get("http://www.wikipedia.org");


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

=head2 cache_undef_content_length( 0 | 'warn' | 1 )

This is configuration option which adjusts how caching behaviour performs when
the Content-Length header is not specified by the server.

Default behaviour is 0, which is not to cache.

Setting this value to 1, will cache pages even if the Content-Length header is
missing, which was the default behaviour prior to the addition of this feature.

And thirdly, you can set the value to the string 'warn', to warn if this
scenario occurs, and then not cache it.

=head2 cache_zero_content_length( 0 | 'warn' | 1 )

This is configuration option which adjusts how caching behaviour performs when
the Content-Length header is equal to 0.

Default behaviour is 0, which is not to cache.

Setting this value to 1, will cache pages even if the Content-Length header is
0, which was the default behaviour prior to the addition of this feature.

And thirdly, you can set the value to the string 'warn', to warn if this
scenario occurs, and then not cache it.

=head2 cache_mismatch_content_length( 0 | 'warn' | 1 )

This is configuration option which adjusts how caching behaviour performs when
the Content-Length header differs from the length of the content itself. ( Which
usually indicates a transmission error )

Setting this value to 0, will silenly not cache pages with a Content-Length
mismatch.

Setting this value to 1, will cache pages even if the Content-Length header
conflicts with the content length, which was the default behaviour prior to the
addition of this feature.

And thirdly, you can set the value to the string 'warn', to warn if this
scenario occurs, and then not cache it. ( This is the default behaviour )

=head1 UPGRADING FROM 1.40 OR EARLIER

Caching behaviour has changed since 1.40, and this may result in pages that were
previously cached start failing to cache, and in some cases, emit warnings.

To return to the 1.40 behaviour:

    $mech->cache_undef_content_length(1);  # Default is 0
    $mech->cache_zero_content_length(1);   # Default is 0
    $mech->cache_mismatch_content_length(1); # Default is 'warn'

=head1 THANKS

Iain Truskett for writing this in the first place.
Andy Lester for graciously handing over maintainership.
Kent Fredric for adding content length handling.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Mechanize::Cached

=over

=item * Search CPAN

L<https://metacpan.org/module/WWW::Mechanize::Cached>

=back

=head1 SEE ALSO

L<WWW::Mechanize>, L<WWW::Mechanize::Cached::GZip>.

=cut
