# FreeBSD specific hooks for Bugzilla

package Bugzilla::Extension::BFBSD;

use strict;
use warnings;
use base qw(Bugzilla::Extension);

use Bugzilla::Constants;
use Bugzilla::Keyword;
use Bugzilla::User;
use Bugzilla::Extension::BFBSD::Helpers;

our $VERSION = '0.1.0';

sub install_update_db {
    my ($self, $args) = @_;
    my $dbh = Bugzilla->dbh;

    my $kwd = new Bugzilla::Keyword({ name => "patch" });
    if (!$kwd) {
        print("Creating 'patch' keyword ...\n");
        $kwd = Bugzilla::Keyword->create({
            name => "patch",
            description => "Contains a patch relevant to resolving the issue. May require testing, review or both.",
        });
    }
    $kwd = new Bugzilla::Keyword({ name => "regression" });
    if (!$kwd) {
        print("Creating 'regression' keyword ...\n");
        $kwd = Bugzilla::Keyword->create({
            name => "regression",
            description => "Describes an issue where a feature has stopped functioning as intended, and that previous worked.",
        });
    }
}

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

    # Switch the user session
    my $autoid = login_to_id(UID_AUTOASSIGN);
    if (!$autoid) {
        warn("AutoAssign user does not exist");
        return;
    }
    my $curuser = Bugzilla->user;
    Bugzilla->set_user(new Bugzilla::User($autoid));

    # Bug 197683 - add some keywords automatically
    # Check, if patch or regression is set in the topic.
    if ($bug->short_desc =~ /\[patch\]|patch:/i) {
        $bug->modify_keywords("patch", "add")
    }
    if ($bug->short_desc =~ /\[regression\]|regression:/i) {
        $bug->modify_keywords("regression", "add")
    }

    # Bug 196909 - add $arch CCs for ports bugs with
    # platform != (amd64, i386)
    # We only add CCs, if it is an individual port bug
    if ($bug->product eq PRODUCT_PORTS &&
        $bug->component eq COMPONENT_PORTS) {
        if ($bug->rep_platform ne "amd64" &&
            $bug->rep_platform ne "i386" &&
            $bug->rep_platform ne "Any") {

            my $archuser = sprintf("freebsd-%s\@FreeBSD.org",
                                   $bug->rep_platform);
            my $user = get_user($archuser);
            if ($user) {
                $bug->add_cc($user);
            };
        }
    }
    Bugzilla->set_user($curuser);
}

__PACKAGE__->NAME;
