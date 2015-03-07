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
        _block_and_delete($args);
    }
}

sub _get_bugs {
    my $spamuser = shift();

    my %criteria = (
        "email1"         => $spamuser->login,
        "emailreporter1" => "1",
        "emailtype1"     => "exact",
    );
    my $fields = [ "bug_id", "product", "component", "short_desc" ];
    my $search = new Bugzilla::Search(
        "fields"          => $fields,
        "params"          => \%criteria,
        "user"            => Bugzilla->user,
        "allow_unlimited" => 1
    );
    return $search->data;
}

sub _search_user {
    my $args = shift();
    my $vars = $args->{vars};
    my $cgi = Bugzilla->cgi;

    warn("YADDDA22321321321");
    if (!defined($cgi->param("user")) || $cgi->param("user") eq "") {
        # No user
        return;
    }
    # Search for a user
    my $spamuser = get_user($cgi->param("user"));
    if (!$spamuser) {
        warn("YADDDA111111");
        ThrowUserError("invalid_user", { user_login => $cgi->param("user") });
    }

    warn("YADDDA");
    $vars->{bugs} = _get_bugs($spamuser);
}

sub _block_and_delete {
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

    # Search all bugs from that user and delete them. If no backup
    # directory is specified, we won't save any bug.
    my $folder = Bugzilla->params->{spam_backupfolder};
    my $datadir = bz_locations()->{"datadir"};
    my $backups = "$datadir/$folder";
    my $wantbackup = 1;
    if (!defined($folder) || $folder eq "") {
        $wantbackup = 0;
    } else {
        mkdir($backups, 0770);
        # adjust the permissions, if the directory already exits
        chmod(0770, $backups);
    }

    my @buglist;
    if ($input->{action} eq "Block and Delete") {
        my $bugs = _get_bugs($spamuser);
        $vars->{bugs} = $bugs;
        my @todelete;
        foreach my $bug (@$bugs) {
            # Check, if we can properly access all bugs.
            my $del = new Bugzilla::Bug($bug->[0]);
            if ($del->{error}) {
                Bugzilla->set_user($curuser);
                ThrowCodeError("bug_error", { bug => $del });
            }
            push(@todelete, $del);
        }
        if ($wantbackup == 1) {
            # Save all bugs before we delete them. If one
            # cannot be saved properly, we will error out without
            # having deleted only a part.
            foreach my $bug (@todelete) {
                my $id = $bug->bug_id;
                open(my $FH, '>', "$backups/spam_bug_$id");
                _dump_bug($bug, $FH);
                close($FH);
            }
        }
        foreach my $bug (@todelete) {
            push(@buglist, {
                id   => $bug->bug_id,
                desc => $bug->short_desc
            });
            $bug->remove_from_db();
        }
    }

    # Block the user
    if ($input->{action} eq "Block and Delete" ||
        $input->{action} eq "Block User") {
        $spamuser->set_disabledtext(Bugzilla->params->{spam_disable_text});
        $spamuser->update();
    }

    _send_info($curuser->login, $spamuser->login, \@buglist);
    Bugzilla->set_user($curuser);
}

sub _pretty {
    my $v = shift();
    return "NULL" unless defined $v; # empty (null) values
    return $v if ($v =~ /^[0-9]+\.?[0-9]+$/); # int or numeric
    return "''" if $v eq ''; # empty strings
    return Bugzilla->dbh->quote($v); # timestamps, strings, etc.
}

sub _dump {
    my ($bug, $file, $table, $query) = @_;
    my $data = Bugzilla->dbh->selectall_arrayref($query, undef, $bug->bug_id);
    foreach my $rec (@$data) {
        print($file "INSERT INTO $table VALUES(\n");
        print($file "  " . join(",", map { _pretty($_) } @$rec) . "\n");
        print($file ");\n");
    }
}

sub _dump_bug {
    my ($bug, $file) = @_;

    print($file "BEGIN;\n");

    _dump($bug, $file, "bugs", qq{
        SELECT * from bugs WHERE bug_id = ?;
    });
    _dump_attachments($bug, $file);

    _dump($bug, $file, "bug_group_map", qq{
        SELECT * from bug_group_map WHERE bug_id = ?;
    });
    _dump($bug, $file, "bug_see_also", qq{
        SELECT * from bug_see_also WHERE bug_id = ?;
    });
    _dump($bug, $file, "bug_tag", qq{
        SELECT * from bug_tag WHERE bug_id = ?;
    });
    _dump($bug, $file, "bugs_activity", qq{
        SELECT * from bugs_activity WHERE bug_id = ?;
    });
    _dump($bug, $file, "bugs_fulltext", qq{
        SELECT * from bugs_fulltext WHERE bug_id = ?;
    });
    _dump($bug, $file, "cc", qq{
        SELECT * from cc WHERE bug_id = ?;
    });
    _dump($bug, $file, "dependencies", qq{
        SELECT * from dependencies WHERE blocked = ?;
    });
    _dump($bug, $file, "dependencies", qq{
        SELECT * from dependencies WHERE dependson = ?;
    });
    _dump($bug, $file, "duplicates", qq{
        SELECT * from duplicates WHERE dupe = ?;
    });
    _dump($bug, $file, "duplicates", qq{
        SELECT * from duplicates WHERE dupe_of = ?;
    });
    _dump($bug, $file, "flags", qq{
        SELECT * from flags WHERE bug_id = ?;
    });
    _dump($bug, $file, "keywords", qq{
        SELECT * from keywords WHERE bug_id = ?;
    });
    _dump($bug, $file, "longdescs", qq{
        SELECT * from longdescs WHERE bug_id = ?;
    });

    print($file "COMMIT;\n");
}

sub _dump_attachments {
    my ($bug, $file) = @_;
    my $dbh = Bugzilla->dbh;
    my $attach = $dbh->selectall_arrayref(qq{
        SELECT * FROM attachments WHERE bug_id = ?;
    }, undef, $bug->bug_id);
    foreach my $value (@$attach) {
        my $id = @$value[0];

        print($file "INSERT INTO attachments VALUES(\n");
        print($file "  " . join(",", map { _pretty($_) } @$value) . "\n");
        print($file ");\n");

        my $data = $dbh->selectall_arrayref(qq{
            SELECT id, encode(thedata, 'base64') FROM attach_data WHERE id = ?;
        }, undef, $id);
        foreach my $rec (@$data) {
            my $id = @$rec[0];
            my $val = @$rec[1];
            print($file "INSERT INTO attach_data VALUES(\n");
            print($file "  $id, decode('$val', 'base64')");
            print($file ");\n");
        }
    }
}

sub _send_info {
    my ($who, $spamuser, $buglist) = @_;
    my $mail = "
From: bugzilla-noreply\@FreeBSD.org
To: %s
Subject: Spammer blocked on %s

Dear administrators,

user %s blocked the potential spammer
%s on %s.
";
    if (scalar(@$buglist) > 0) {
        $mail .= "
The following bugs were deleted:

    Bug Id | Description
-----------+--------------------------------------------------------------
";
        my $TBLROW = "%10s | %-60.59s\n";
        foreach my $bug (@$buglist) {
            $mail .= sprintf($TBLROW, $bug->{id}, $bug->{desc});
        }
        $mail .= "\n";
    } else {
        $mail .= "
No bugs were deleted.
";
    }

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
        Bugzilla->params->{urlbase}
    );
    MessageToMTA($mailmsg, 1);
}

__PACKAGE__->NAME;
