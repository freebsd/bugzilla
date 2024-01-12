package Bugzilla::Extension::SpamDelete;

use strict;
use warnings;
use base qw(Bugzilla::Extension);

use Bugzilla;
use Bugzilla::Bug;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Mailer;
use Bugzilla::Search;
use Bugzilla::User;
use Bugzilla::Util;
use Bugzilla::Extension::BFBSD::Helpers;

our $VERSION = '0.1.0';

sub install_update_db {
    my ($self, $args) = @_;
    my $dbh = Bugzilla->dbh;
    #
}

sub config_add_panels {
    my ($self, $args) = @_;
    my $modules = $args->{panel_modules};
    $modules->{SpamDelete} = "Bugzilla::Extension::SpamDelete::Config";
}

sub page_before_template {
    my ($self, $args) = @_;
    my $page = $args->{page_id};

    if ($page ne "searchspam.html" && $page ne "deletespam.html") {
        return;
    }

    Bugzilla->login(LOGIN_REQUIRED);
    if (!Bugzilla->user->in_group(Bugzilla->params->{spam_delete_group})) {
        ThrowUserError("auth_failure", {
            group  => Bugzilla->params->{spam_delete_group},
            action => "access",
            object => "administrative_pages",
        });
    }
    if ($page eq "searchspam.html") {
        _search_user($args);
    } elsif ($page eq "deletespam.html") {
        _block($args);
    }
}

sub _get_bugs {
    my $spamuser = shift();

    my %criteria = (
        "v1"           => $spamuser->login,
        "f1"           => "commenter",
        "o1"           => "equals",
        "query_format" => "advanced",
    );
    my $fields = [ "bug_id", "product", "component", "reporter", "short_desc" ];
    my $search = new Bugzilla::Search(
        "fields"          => $fields,
        "params"          => \%criteria,
        "user"            => Bugzilla->user,
        "allow_unlimited" => 1,
        "order"           => ['bugs.bug_id desc']
    );
    return $search->data;
}

sub _search_user {
    my $args = shift();
    my $vars = $args->{vars};
    my $cgi = Bugzilla->cgi;

    if (!defined($cgi->param("user")) || $cgi->param("user") eq "") {
        # No user
        return;
    }
    # Search for a user
    my $spamuser = get_user($cgi->param("user"));
    if (!$spamuser) {
        ThrowUserError("invalid_user", { user_login => $cgi->param("user") });
    }

    $vars->{bugs} = _get_bugs($spamuser);
}

sub _block {
    my $args = shift();
    my $vars = $args->{vars};
    my $input = Bugzilla->input_params;

    if (!defined($input->{user}) || $input->{user} eq "") {
        ThrowUserError("invalid_user", { user_login => $input->{user} });
    }

    my $curuser = switch_to_automation();
    return if !defined($curuser);

    # Search for a user
    my $spamuser = get_user($input->{user});
    if (!$spamuser) {
        Bugzilla->set_user($curuser);
        ThrowUserError("invalid_user", { user_login => $input->{user} });
    }
    if ($spamuser->in_group(Bugzilla->params->{spam_delete_group})) {
        # Users of the spam deletion group can't be deleted.
        Bugzilla->set_user($curuser);
        ThrowUserError("invalid_user", { user_login => $input->{user} });
    }

    $vars->{spamuser} = $spamuser->login;

    # Block the user
    if ($input->{action} eq "Block User") {
        $spamuser->set_disabledtext('[SPAM] ' . Bugzilla->params->{spam_disable_text});
        $spamuser->update();
    }

    _send_info($curuser->login, $spamuser->login);
    Bugzilla->set_user($curuser);
}

sub _send_info {
    my ($who, $spamuser) = @_;
    my $mail = "From: bugzilla-noreply\@FreeBSD.org
To: %s
Subject: Spammer blocked on %s

Dear administrators,

User %s blocked the potential spammer
%s on %s.

User's PRs/comments:
%spage.cgi?id=searchspam.html&action=search&user=%s
";

    my $to = Bugzilla->params->{maintainer};
    my @contacts = split(",", Bugzilla->params->{spam_contacts});
    foreach my $c (@contacts) {
        $c =~ s/^\s+|\s+$//g;
        $to .= ",$c";
    }

    my $mailmsg = sprintf(
        $mail,
        $to,
        Bugzilla->params->{urlbase},
        $who,
        $spamuser,
        Bugzilla->params->{urlbase},
        Bugzilla->params->{urlbase},
        url_quote($spamuser),
    );

    MessageToMTA($mailmsg, 1);
}

__PACKAGE__->NAME;
