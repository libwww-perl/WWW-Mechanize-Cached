package WWW::Mechanize::Cached;

use strict;
use warnings FATAL => 'all';

use vars qw( $VERSION );
$VERSION = '1.35';

use base qw( WWW::Mechanize );
use Carp qw( carp croak );
use Storable qw( freeze thaw );

my $cache_key = __PACKAGE__;

=head1 NAME

WWW::Mechanize::Cached - Cache response to be polite

=head1 VERSION

Version 1.35

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

Uses the L<Cache::Cache> hierarchy to implement a caching Mech. This
lets one perform repeated requests without hammering a server impolitely.

Repository: L<http://github.com/oalders/www-mechanize-cached/tree/master>

=head1 CONSTRUCTOR

=head2 new

Behaves like, and calls, L<WWW::Mechanize>'s C<new> method.  Any params,
other than those explicitly listed here are passed directly to
WWW::Mechanize's constructor.

You may pass in a C<< cache => $cache_object >> if you wish.  The
I<$cache_object> must have C<get()> and C<set()> methods like the
C<Cache::Cache> family.

The default Cache object is set up with the following params:

    my $cache_params = {
        default_expires_in => "1d",
        namespace => 'www-mechanize-cached',
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

=head2 is_cached()

Returns true if the current page is from the cache, or false if not.
If it returns C<undef>, then you don't have any current request.

=head1 THANKS

Iain Truskett for writing this in the first place.

=head1 BUGS AND LIMITATIONS

It may sometimes seem as if it's not caching something. And this
may well be true. It uses the HTTP request, in string form, as the key
to the cache entries, so any minor changes will result in a different
key. This is most noticable when following links as L<WWW::Mechanize>
adds a C<Referer> header.

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


=head1 LICENSE AND COPYRIGHT

This module is copyright Iain Truskett and Andy Lester, 2004. All rights
reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.000 or,
at your option, any later version of Perl 5 you may have available.

=head1 AUTHOR

Iain Truskett <spoon@cpan.org>

Maintained from 2004 - July 2009 by Andy Lester <petdance@cpan.org>

Currently maintained by Olaf Alders <olaf@wundercounter.com>

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
            carp "The cache parm must be an initialized cache object";
            $cache = undef;
        }
    }

    my $self = $class->SUPER::new( %mech_args );

    if ( !$cache ) {
        require Cache::FileCache;
        my $cache_params = {
            default_expires_in => "1d",
            namespace          => 'www-mechanize-cached',
        };
        $cache = Cache::FileCache->new( $cache_params );
    }

    $self->{$cache_key} = $cache;

    return $self;
}

sub is_cached {
    my $self = shift;

    return $self->{_is_cached};
}

sub _make_request {
    my $self    = shift;
    my $request = shift;

    my $req      = $request->as_string;
    my $cache    = $self->{$cache_key};
    my $response = $cache->get( $req );
    if ( $response ) {
        $response = thaw $response;
        $self->{_is_cached} = 1;
    }
    else {
        $response = $self->SUPER::_make_request( $request, @_ );

        # http://rt.cpan.org/Public/Bug/Display.html?id=42693
        $response->decode();
        delete $response->{handlers};

        $cache->set( $req, freeze( $response ) );
        $self->{_is_cached} = 0;
    }

    # An odd line to need.
    $self->{proxy} = {} unless defined $self->{proxy};

    return $response;
}

"We miss you, Spoon";    ## no critic
