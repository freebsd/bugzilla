# FreeBSD specific hooks for Bugzilla

package Bugzilla::Extension::BFBSD;

use strict;
use warnings;
use base qw(Bugzilla::Extension);

use Bugzilla::Constants;
use Bugzilla::Extension::BFBSD::Helpers;


our $VERSION = '0.1.0';

sub bug_check_can_change_field {
    my ($self, $args) = @_;
    if ($args->{'field'} eq 'keywords') {
        my $user = Bugzilla->user;
        if (!$user->in_group('editbugs', $args->{'bug'}->product_id)) {
            push($args->{'priv_results'}, PRIVILEGES_REQUIRED_EMPOWERED);
            return;
        }
    }
}

sub auth_verify_methods {
    my ($self, $args) = @_;
    my $mods = $args->{'modules'};
    if (exists $mods->{'FreeBSD'}) {
        $mods->{'FreeBSD'} = 'Bugzilla/Extension/BFBSD/Auth/Verify.pm';
    }
}

sub config_modify_panels {
    my ($self, $args) = @_;
    my $panels = $args->{panels};
    my $auth_params = $panels->{'auth'}->{params};
    my ($verify_class) = grep($_->{name} eq 'user_verify_class', @$auth_params);
    push(@{ $verify_class->{choices} }, 'FreeBSD');
}

sub bug_end_of_create {
    # Bug 196909 - Add freebsd-$arch for arch specific ports tickets
    my ($self, $args) = @_;
    my $bug = $args->{'bug'};

    # We only add CCs, if it is a individual port bug
    if ($bug->product ne PRODUCT_PORTS ||
        $bug->component ne COMPONENT_PORTS) {
        return;
    }
    if ($bug->rep_platform eq "amd64" || $bug->rep_platform eq "i386") {
        # Do nothing.
        return;
    }

    # Switch the user session
    my $autoid = login_to_id(UID_AUTOASSIGN);
    if (!$autoid) {
        warn("AutoAssign user does not exist");
        return;
    }
    my $curuser = Bugzilla->user;
    Bugzilla->set_user(new Bugzilla::User($autoid));
    my $archuser = sprintf("freebsd-%s\@FreeBSD.org",
                           $bug->rep_platform);
    my $user = get_user($archuser);
    if ($user) {
        $bug->add_cc($user);
    };
    Bugzilla->set_user($curuser);
}

__PACKAGE__->NAME;
