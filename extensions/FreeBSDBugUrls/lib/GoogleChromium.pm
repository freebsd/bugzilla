# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::FreeBSDBugUrls::GoogleChromium;

use 5.10.1;
use strict;
use warnings;

use parent qw(Bugzilla::BugUrl);

###############################
####        Methods        ####
###############################

sub should_handle {
    my ($class, $uri) = @_;

    # https://bugs.chromium.org/p/PROJECT/issues/detail?id=8359
    return (lc($uri->authority) eq "bugs.chromium.org"
            && ($uri->path =~ m|^/p/[^/]+/issues/detail$|i
              and $uri->query_param('id') =~ m|^\d+$|
            )) ? 1 : 0;
}

sub _check_value {
    my $class = shift;

    my $uri = $class->SUPER::_check_value(@_);

    return $uri;
}

1;
