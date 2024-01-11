#!/usr/local/bin/perl -w

use strict;
use warnings;
use lib qw(. lib);

use Bugzilla;
use Bugzilla::Mailer;
use Bugzilla::Constants;
use Bugzilla::Util;
use Email::MIME;

use constant {
    # Consider bugs, for which nothing happened for more than X days
    WAIT => 7
};

my $urlbase = Bugzilla->params->{'urlbase'};

my $MAIL_TXT_HEADER = "To view an individual PR, use:
  ${urlbase}show_bug.cgi?id=(Bug Id).
";

my $MAIL_HTML_HEADER = '<pre style="font-family: monospace;">';

my $MAIL_COMMON = "
The following is a listing of current problems submitted by FreeBSD users,
which need special attention. These represent problem reports covering
all versions including experimental development code and obsolete releases.

Status      |    Bug Id | Description
------------+-----------+---------------------------------------------------
%s
%d problems total for which you should take action.
";

my $MAIL_TXT_FOOTER = "";

my $MAIL_HTML_FOOTER = '</pre>';

my $TBLROW = "%-11s | %9s | %-50.49s\n";
my $TBLROW_HTML = "%-11s | <a href=\"%s\">%9s</a> | <a href=\"%s\">%s</a>\n";

# We're a non-interactive user
Bugzilla->usage_mode(USAGE_MODE_CMDLINE);
# Get the db conection and query the db directly.
my $dbh = Bugzilla->dbh;

my $dnow = $dbh->sql_to_days("NOW()");
my $mfcquery = q{
SELECT DISTINCT
  bugs.bug_id, bugs.short_desc, bugs.bug_status, p.login_name, bugs.assigned_to
FROM
  bugs
  JOIN bug_status bs ON (bs.value = bugs.bug_status AND bs.is_open != 0)
  JOIN flags ON (bugs.bug_id = flags.bug_id AND flags.status = '?')
  JOIN flagtypes ON (flags.type_id = flagtypes.id)
  JOIN profiles p ON (p.userid = bugs.assigned_to AND p.is_enabled = 1)
WHERE
  flagtypes.name IN (?, ?, ?, ?)
  AND } . $dnow . " - " . $dbh->sql_to_days("bugs.delta_ts") . " >= " . WAIT .
" ORDER BY bugs.assigned_to, bugs.bug_status, bugs.bug_id;";

my $openbugs = $dbh->selectall_arrayref(
    $mfcquery,
    undef,
    'merge-quarterly',
    'mfc-stable8',
    'mfc-stable9',
    'mfc-stable10');

my $kwdquery = q{
SELECT DISTINCT
  bugs.bug_id, bugs.short_desc, bugs.bug_status, p.login_name, bugs.assigned_to
FROM
  bugs
  JOIN bug_status bs ON (bs.value = bugs.bug_status AND bs.is_open != 0)
  JOIN keywords ON (keywords.bug_id = bugs.bug_id)
  JOIN keyworddefs ON (keywords.keywordid = keyworddefs.id)
  JOIN profiles p ON (p.userid = bugs.assigned_to AND p.is_enabled = 1)
WHERE
  keyworddefs.name IN (?)
  AND } . $dnow . " - " . $dbh->sql_to_days("bugs.delta_ts") . " >= " . WAIT .
" ORDER BY bugs.assigned_to, bugs.bug_status, bugs.bug_id;";

my $kwdbugs = $dbh->selectall_arrayref(
    $kwdquery,
    undef,
    'patch-ready');
push(@$openbugs, @$kwdbugs);


my $reqquery = "
SELECT DISTINCT
  bugs.bug_id, bugs.short_desc, bugs.bug_status, p.login_name, bugs.assigned_to
FROM
  bugs
  JOIN flags ON (bugs.bug_id = flags.bug_id AND flags.status = '?' AND flags.requestee_id IS NOT NULL)
  JOIN bug_status bs ON (bs.value = bugs.bug_status AND bs.is_open != 0)
  JOIN profiles p ON (p.userid = flags.requestee_id)
WHERE
  bugs.assigned_to != flags.requestee_id";

my $reqbugs = $dbh->selectall_arrayref($reqquery, undef);
push(@$openbugs, @$reqbugs);

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
    my $tblbugs_html = "";
    my $bugcount = scalar(@{$bugs{$mail}});
    foreach my $bug (@{$bugs{$mail}}) {
        my ($id, $desc, $status, $mail__, @assignedto) = @$bug;
        $tblbugs .= sprintf($TBLROW, $status, $id, $desc);
        # we can not use %50s format on HTML-escaped string
        # sut it implicitly
        my $desc_cut = html_quote(substr($desc, 0, 49));
        my $url = "${urlbase}show_bug.cgi?id=$id";
        $tblbugs_html .= sprintf($TBLROW_HTML, $status, $url, $id, $url, $desc_cut);
        $tblbugs_html =~ s/(<a href=".*?">)(\s+)/$2$1/;
    }

    my $body_txt = $MAIL_TXT_HEADER;
    $body_txt .= sprintf($MAIL_COMMON, $tblbugs, $bugcount);
    $body_txt .= $MAIL_TXT_FOOTER;

    my $body_html = $MAIL_HTML_HEADER;
    $body_html .= sprintf($MAIL_COMMON, $tblbugs_html, $bugcount);
    $body_html .= $MAIL_HTML_FOOTER;

    # parts should go from least rich to most rich format
    my @parts = (
        Email::MIME->create(
            attributes => {
                content_type => "text/plain",
                charset => "UTF-8"
            },
            body => $body_txt
        ),
        Email::MIME->create(
            attributes => {
                content_type => "text/html",
                charset => "UTF-8"
            },
            body => $body_html
        ),
    );

    my $mailmsg = Email::MIME->create(
        header_str => [
            From => 'bugzilla-noreply@FreeBSD.org',
            To => [ $mail ],
            Subject => "Problem reports for $mail that need special attention"
        ],
        attributes => {
            content_type => "multipart/alternative"
        },
        parts      => [ @parts ],
    );

    # Send the mail via the bugzilla configuration.
    # print $mailmsg->as_string;
    MessageToMTA($mailmsg, 1);
}
