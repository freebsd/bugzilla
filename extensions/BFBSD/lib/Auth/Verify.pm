package Bugzilla::Extension::BFBSD::Auth::Verify;

use strict;
use warnings;
use base qw(Bugzilla::Auth::Verify);
use Bugzilla::Auth::Verify::LDAP;
use Bugzilla::Constants;

our @ISA = qw(Bugzilla::Auth::Verify::LDAP);

sub check_credentials {
    my ($self, $params) = @_;

    $params = Bugzilla::Auth::Verify::LDAP::check_credentials($self, $params);
    if ($params->{failure}) {
        return $params;
    }
    $params->{bz_username} = $params->{username} . '@freebsd.org';
    return $params;
}

1;

