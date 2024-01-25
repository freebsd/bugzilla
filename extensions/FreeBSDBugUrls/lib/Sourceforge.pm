# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::FreeBSDBugUrls::Sourceforge;

use 5.10.1;
use strict;
use warnings;

use parent qw(Bugzilla::BugUrl);

###############################
####        Methods        ####
###############################

sub should_handle {
    my ($class, $uri) = @_;

    # Sourceforge issues have the form of
    # https://sourceforge.net/p/<project>/bugs/<number>/
    return (lc($uri->authority) eq "sourceforge.net"
            && $uri->path =~ m|[^/]+/[^/]+/bugs/\d+|i) ? 1 : 0;
}

sub _check_value {
    my $class = shift;

    my $uri = $class->SUPER::_check_value(@_);

    my ($path) = $uri->path =~ m|([^/]+/[^/]+/bugs/\d+)|i;
    $uri = new URI("https://sourceforge.net/$path");

    return $uri;
}

1;
