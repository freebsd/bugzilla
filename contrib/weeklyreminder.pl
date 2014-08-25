#!/usr/local/bin/perl -w

use strict;
use warnings;

use Bugzilla;
use Bugzilla::Mailer;
use Bugzilla::Constants;
use Email::MIME;

my $MAIL = "
From: bz-noreply\@FreeBSD.org
To: %s
Subject: Current problem reports assigned to %s

To view an individual PR, use:
  https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=(number).

To view all PRs that are current assigned to you, use:
  https://bugs.freebsd.org/bugzilla/buglist.cgi?assigned_to=%s&resolution=---.

The following is a listing of current problems submitted by FreeBSD users.
These represent problem reports covering all versions including
experimental development code and obsolete releases.

Status          |    Bug Id | Description
----------------+-----------+-------------------------------------------------
%s
%d problems total.
";

my $TBLROW = "%-15s | %9s | %-48.47s\n";

# We're a non-interactive user
Bugzilla->usage_mode(USAGE_MODE_CMDLINE);
# Get the db conection and query the db directly.
my $dbh = Bugzilla->dbh;

my $openbugs = $dbh->selectall_arrayref(
    "SELECT
       bugs.bug_id, bugs.short_desc, bugs.bug_status, p.login_name
     FROM
       bugs
       JOIN bug_status bs ON (bs.value = bugs.bug_status AND bs.is_open != 0)
       JOIN profiles p ON (p.userid = bugs.assigned_to AND p.is_enabled = 1)
     ORDER BY
       bugs.assigned_to, bugs.bug_status, bugs.bug_id;"
);
# If there are no bugs (hah!), exit gracefully
if (scalar(@$openbugs) == 0) {
    exit 0;
}

# Create a hash table based on the assigned logins (email):
# bugs{email} = [list of bugs].
my %bugs;
foreach my $bug (@$openbugs) {
    my ($id, $desc, $status, $mail) = @$bug;
    if (!defined($bugs{$mail})) {
        $bugs{$mail} = [];
    }
    push(@{$bugs{$mail}}, $bug);
}

foreach my $mail (keys %bugs) {
    # Prep mail content
    my $tblbugs = "";
    my $bugcount = scalar(@{$bugs{$mail}});
    foreach my $bug (@{$bugs{$mail}}) {
        my ($id, $desc, $status, $mail__) = @$bug;
        $tblbugs .= sprintf($TBLROW, $status, $id, $desc);
    }
    my $mailmsg = sprintf(
        $MAIL,
        $mail, # To
        $mail, # Subject
        $mail, # bugzilla link
        $tblbugs,
        $bugcount
        );
    # Send the mail via the bugzilla configuration now.
    #MessageToMTA($mailmsg, 1);
    print($mailmsg);
}
