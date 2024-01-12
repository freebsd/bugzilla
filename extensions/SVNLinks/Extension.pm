package Bugzilla::Extension::SVNLinks;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

use constant {
    SVN_PORTS => "https://svnweb.freebsd.org/changeset/ports/",
    SVN_BASE => "https://svnweb.freebsd.org/changeset/base/",
    SVN_DOC => "https://svnweb.freebsd.org/changeset/doc/",
    GIT_PORTS => "https://cgit.freebsd.org/ports/commit/?id=",
    GIT_BASE => "https://cgit.freebsd.org/src/commit/?id=",
    GIT_DOC => "https://cgit.freebsd.org/doc/commit/?id=",
    PHABRIC => "https://reviews.freebsd.org/",
};

our $VERSION = '0.1.0';

sub bug_format_comment {
    my ($self, $args) = @_;
    my $regexes = $args->{regexes};

    push(@$regexes, {
        match => qr/(^|\h+)ports\h+([0-9a-f]{6,40})/im,
        replace => \&_link_git_ports
         });
    push(@$regexes, {
        match => qr/(^|\h+)base\h+([0-9a-f]{6,40})/im,
        replace => \&_link_git_base
         });
    push(@$regexes, {
        match => qr/(^|\h+)doc\h+([0-9a-f]{6,40})/im,
        replace => \&_link_git_doc
         });
    push(@$regexes, {
        match => qr/(^|\h+)ports\h+(?:\#|r)?(\d+)/im,
        replace => \&_link_svn_ports
         });
    push(@$regexes, {
        match => qr/(^|\h+)base\h+(?:\#|r)?(\d+)/im,
        replace => \&_link_svn_base
         });
    push(@$regexes, {
        match => qr/(^|\h+)doc\h+(?:\#|r)?(\d+)/im,
        replace => \&_link_svn_doc
         });
    push(@$regexes, {
        match => qr/(^|\h+)review\h+(D\d+)/im,
        replace => \&_link_phabric
         });
}

sub _link_svn_ports {
    my $pre = $1 || "";
    my $rev = $2 || "";
    my $link = $pre . "<a href=\"" . SVN_PORTS .
        "$rev\" title=\"revision $rev in ports\">ports r$rev</a>";
    return $link;
}

sub _link_svn_base {
    my $pre = $1 || "";
    my $rev = $2 || "";
    my $link = $pre . "<a href=\"" . SVN_BASE .
        "$rev\" title=\"revision $rev in base\">base r$rev</a>";
    return $link;
}

sub _link_svn_doc {
    my $pre = $1 || "";
    my $rev = $2 || "";
    my $link = $pre . "<a href=\"" . SVN_DOC .
        "$rev\" title=\"revision $rev in doc\">doc r$rev</a>";
    return $link;
}

sub _link_git_ports {
    my $pre = $1 || "";
    my $sha1 = $2 || "";
    my $link = $pre . "<a href=\"" . GIT_PORTS .
        "$sha1\" title=\"commit $sha1 in ports\">ports $sha1</a>";
    return $link;
}

sub _link_git_base {
    my $pre = $1 || "";
    my $sha1 = $2 || "";
    my $link = $pre . "<a href=\"" . GIT_BASE .
        "$sha1\" title=\"commit $sha1 in base\">base $sha1</a>";
    return $link;
}

sub _link_git_doc {
    my $pre = $1 || "";
    my $sha1 = $2 || "";
    my $link = $pre . "<a href=\"" . GIT_DOC .
        "$sha1\" title=\"commit $sha1 in doc\">doc $sha1</a>";
    return $link;
}

sub _link_phabric {
    my $pre = $1 || "";
    my $rev = $2 || "";
    my $link = $pre . "<a href=\"" . PHABRIC .
        "$rev\" title=\"Review $rev on reviews.FreeBSD.org\">review $rev</a>";
    return $link;
}

__PACKAGE__->NAME;
