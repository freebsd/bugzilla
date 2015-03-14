package Bugzilla::Extension::BFBSD::Helpers;

use strict;
use Bugzilla;
use Bugzilla::User;

use base qw(Exporter);

our @EXPORT = qw(
    no_maintainer get_user ports_product ports_component
    switch_to_automation

    UID_AUTOMATION
    PRODUCT_PORTS
    COMPONENT_PORTS
);

use constant {
    UID_AUTOMATION => "bugzilla\@FreeBSD.org",
    PRODUCT_PORTS => "Ports & Packages",
    COMPONENT_PORTS => "Individual Port(s)"
};

sub ports_product {
    return PRODUCT_PORTS
}

sub ports_component {
    return COMPONENT_PORTS
}

sub no_maintainer {
    my $maintainer = shift();
    if (lc($maintainer) eq "ports\@freebsd.org") {
        return 1;
    }
    return 0;
}

sub get_user {
    my ($name, $enabledonly) = @_;
    my $uid = login_to_id($name);
    if (!$uid) {
        warn("No user found for $name");
        return;
    }
    my $user = new Bugzilla::User($uid);
    if ($enabledonly) {
        if (!$user->is_enabled) {
            warn("Found user $name is not enabled in Bugzilla");
            return;
        }
    }
    return $user;
}

sub switch_to_automation {
    # Switch the user session
    my $autoid = login_to_id(UID_AUTOMATION);
    if (!$autoid) {
        warn("Automation user does not exist");
        return;
    }
    my $curuser = Bugzilla->user;
    Bugzilla->set_user(new Bugzilla::User($autoid));
    return $curuser;
};

1;
