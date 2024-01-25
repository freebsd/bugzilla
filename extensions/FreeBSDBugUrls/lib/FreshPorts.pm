# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::FreeBSDBugUrls::FreshPorts;

use 5.10.1;
use strict;
use warnings;

use parent qw(Bugzilla::BugUrl);

###############################
####        Methods        ####
###############################

sub should_handle {
    my ($class, $uri) = @_;

    # FreshPorts issues have the form of
    # https://github.com/FreshPorts/freshports/issues/535
    # note: historically this has been accepted due to the github.com rule
    return (lc($uri->authority) eq "github.com"
            && $uri->path =~ m|[^/]+/[^/]+/FreshPorts/freshports/issues/\d+|i) ? 1 : 0;
}

sub _check_value {
    my $class = shift;

    my $uri = $class->SUPER::_check_value(@_);

    my ($path) = $uri->path =~ m|([^/]+/[^/]+/FreshPorts/freshports/issues/\d+)|i;
    $uri = new URI("https://github.com/$path");

    return $uri;
}

1;
