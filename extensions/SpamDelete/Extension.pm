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

use Date::Parse;
use experimental 'smartmatch';

our $VERSION = '0.1.0';
my @WHITELIST = qw(
    github.com
    bugs.freebsd.org
    freebsd.org
    forums.freebsd.org
    git.freebsd.org
    cgit.freebsd.org
    reviews.freebsd.org
    lists.freebsd.org
    bugs.freebsd.org
    docs.freebsd.org
    www.freebsd.org
    wiki.freebsd.org
    svn.freebsd.org
    security.freebsd.org
    svnweb.freebsd.org
    download.freebsd.org
    gnu.org
    www.gnu.org
    bitbucket.org
    bz-attachments.freebsd.org
);

sub is_white_listed {
    my $url = shift;
    $url = lc($url);
    $url =~ s@^https?://([^/]*).*@$1@;
    return ($url ~~ @WHITELIST);
}

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

    if ($page ne "searchspam.html" && $page ne "deletespam.html" && $page ne "listsuspects.html") {
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
    } elsif ($page eq "listsuspects.html") {
        _list_suspects($args);
    } elsif ($page eq "deletespam.html") {
        _block($args);
    }
}

sub _get_comments_with_link {
    my $dbh = Bugzilla->dbh;
    my $input = Bugzilla->input_params;

    my $only_suspects = 0;
    my $time_limit = "(bug_when > NOW() - INTERVAL '2 weeks')";
    my @bind;
    if (defined($input->{year})) {
        if ($input->{year} =~ m/^(\d+)$/) {
            push @bind, $1;
            $time_limit = "(bug_when > NOW() - INTERVAL '7 years')";
            $time_limit = "(EXTRACT(YEAR from bug_when) = ?)";
            $only_suspects = 1;
        }
    }
    my $sth = $dbh->prepare("
        SELECT bug_id, comment_id, who, login_name, bug_when, thetext
        FROM longdescs JOIN profiles ON (userid = who)
        WHERE $time_limit 
            AND (thetext ilike '%http://%' or thetext ilike '%https://%')
            AND NOT (login_name ilike '%\@freebsd.org')
            AND (disabledtext = '')
    ");
    $sth->execute(@bind);

    my $age_sth = $dbh->prepare("
        SELECT profiles_when
        FROM profiles_activity WHERE fieldid=30 and who=? LIMIT 1
    ");

    my @comments;
    my %registered;
    while (my($bug, $comment, $who, $login, $when, $text) = $sth->fetchrow_array) {
        my @links;
        while ($text =~ m@(https?://.*?)(?:\h|$)@mig) {
            push @links, $1;
        }
        @links = grep { not is_white_listed($_) } @links;
        next unless(@links);
        if (!defined($registered{$who})) {
            $registered{$who} = '';
            $age_sth->execute($who);
            if (my ($activity_when) = $age_sth->fetchrow_array) {
                $registered{$who} = $activity_when;
            }
        }
        my $age = 'Unknown';
        my $suspect = 0;
        if ($registered{$who} ne '') {
            my $time_reg = str2time($registered{$who});
            my $time_comment = str2time($when);
            my $diff = $time_comment - $time_reg;
            if ($diff < 3600) {
                $age = int($diff/60);
                $age .= ' minutes';
                $suspect = 1;
            }
            elsif ($diff < 3600*24) {
                $age = int($diff/3600);
                $age .= ' hours';
                $suspect = 1;
            }
            elsif ($diff < 3600*24*7) {
                $age = int($diff/(3600*24));
                $age .= ' days';
            }
            else {
                $age = int($diff/(3600*24*7));
                $age .= ' weeks';
            }
        }
        next if ($only_suspects and not $suspect);
        my $entry = {
            'bug' => $bug,
            'when' => $when,
            'who' => $login,
            'registered' => $registered{$who},
            'age' => $age,
            'suspect' => $suspect,
            'links' => \@links
        };
        push @comments, $entry;
    }

    return [ sort { $b->{when} cmp $a->{when} } @comments ];
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

sub _list_suspects {
    my $args = shift();
    my $vars = $args->{vars};
    my $cgi = Bugzilla->cgi;

    $vars->{comments} = _get_comments_with_link();
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
    my $mail = "
From: bugzilla-noreply\@FreeBSD.org
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
