package WWW::Mechanize::Cached;

use strict;
use warnings FATAL => 'all';

=head1 Name

WWW::Mechanize::Cached - Cache response to be polite

=head1 Version

Version 1.32

    $Header: /home/cvs/www-mechanize-cached/Cached.pm,v 1.18 2004/04/12 03:21:25 andy Exp $

=cut

use vars qw( $VERSION );
$VERSION = '1.32';

=head1 Synopsis

    use WWW::Mechanize::Cached;

    my $cacher = WWW::Mechanize::Cached->new;
    $cacher->get( $url );

=head1 Description

Uses the L<Cache::Cache> hierarchy to implement a caching Mech. This
lets one perform repeated requests without hammering a server impolitely.

=cut

use base qw( WWW::Mechanize );
use Carp qw( carp croak );
use Storable qw( freeze thaw );

my $cache_key = __PACKAGE__;

=head1 Constructor

=head2 new

Behaves like, and calls, L<WWW::Mechanize>'s C<new> method.  Any parms
passed in get passed to WWW::Mechanize's constructor.

You can pass in a C<< cache => $cache_object >> if you want.  The
I<$cache_object> must have C<get()> and C<set()> methods like the
C<Cache::Cache> family.

The I<cache> parm used to be a set of parms that described how the
cache object was to be initialized, but I think it makes more sense
to have the user initialize the cache however she wants, and then
pass it in.

=cut

sub new {
    my $class = shift;
    my %mech_args = @_;

    my $cache = delete $mech_args{cache};
    if ( $cache ) {
        my $ok = (ref($cache) ne "HASH") && $cache->can("get") && $cache->can("set");
        if ( !$ok ) {
            carp "The cache parm must be an initialized cache object";
            $cache = undef;
        }
    }

    my $self = $class->SUPER::new( %mech_args );

    if ( !$cache ) {
        require Cache::FileCache;
        my $cache_parms = {
            default_expires_in => "1d",
            namespace => 'www-mechanize-cached',
        };
        $cache = Cache::FileCache->new( $cache_parms );
    }

    $self->{$cache_key} = $cache;

    return $self;
}

=head1 Methods

Most methods are provided by L<WWW::Mechanize>. See that module's
documentation for details.

=head2 is_cached()

Returns true if the current page is from the cache, or false if not.
If it returns C<undef>, then you don't have any current request.

=cut

sub is_cached {
    my $self = shift;

    return $self->{_is_cached};
}

sub _make_request {
    my $self = shift;
    my $request = shift;

    my $req = $request->as_string;
    my $cache = $self->{$cache_key};
    my $response= $cache->get( $req );
    if ( $response ) {
        $response = thaw $response;
        $self->{_is_cached} = 1;
    } else {
        $response = $self->SUPER::_make_request( $request, @_ );
        $cache->set( $req, freeze($response) );
        $self->{_is_cached} = 0;
    }

    # An odd line to need.
    $self->{proxy} = {} unless defined $self->{proxy};

    return $response;
}



=head1 Thanks

Iain Truskett for writing this in the first place.

=head1 Oddities

It may sometimes seem as if it's not caching something. And this
may well be true. It uses the HTTP request, in string form, as the key
to the cache entries, so any minor changes will result in a different
key. This is most noticable when following links as L<WWW::Mechanize>
adds a C<Referer> header.

=head1 Bugs, Requests, Comments

Support for this module is provided via the CPAN RT system:

    http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Mechanize-Cached

    bug-www-mechanize-cached@rt.cpan.org

This makes it much easier for me to track things and thus means
your problem is less likely to be neglected.

=head1 Licence and copyright

This module is copyright Iain Truskett and Andy Lester, 2004. All rights
reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.000 or,
at your option, any later version of Perl 5 you may have available.

The full text of the licences can be found in the F<Artistic> and
F<COPYING> files included with this module, or in L<perlartistic> and
L<perlgpl> as supplied with Perl 5.8.1 and later.

=head1 Author

Iain Truskett <spoon@cpan.org>, currently maintained by Andy Lester
<petdance@cpan.org>

=head1 See also

L<perl>, L<WWW::Mechanize>.

=cut

"We miss you, Spoon";
