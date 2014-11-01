package Bugzilla::Extension::SVNLinks;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

use constant {
    SVN_PORTS => "http://svnweb.freebsd.org/changeset/ports/",
    SVN_BASE => "http://svnweb.freebsd.org/changeset/base/",
    SVN_DOC => "http://svnweb.freebsd.org/changeset/doc/",
    PHABRIC => "https://reviews.freebsd.org/",
};

our $VERSION = '0.1.0';

sub bug_format_comment {
    my ($self, $args) = @_;
    my $regexes = $args->{regexes};

    push(@$regexes, {
        match => qr/ports\h*\#?\h*r?(\d+)/i,
        replace => \&_link_ports
         });
    push(@$regexes, {
        match => qr/base\h*\#?\h*r?(\d+)/i,
        replace => \&_link_base
         });
    push(@$regexes, {
        match => qr/doc\h*\#?\h*r?(\d+)/i,
        replace => \&_link_doc
         });
    push(@$regexes, {
        match => qr/review\h*\#?\h*(D\d+)/i,
        replace => \&_link_phabric
         });
}

sub _link_ports {
    my $rev = $1 || "";
    my $link = "<a href=\"" . SVN_PORTS .
        "$rev\" title=\"revision $rev in ports\">ports r$rev</a>";
    return $link;
}

sub _link_base {
    my $rev = $1 || "";
    my $link = "<a href=\"" . SVN_BASE .
        "$rev\" title=\"revision $rev in base\">base r$rev</a>";
    return $link;
}

sub _link_doc {
    my $rev = $1 || "";
    my $link = "<a href=\"" . SVN_DOC .
        "$rev\" title=\"revision $rev in doc\">doc r$rev</a>";
    return $link;
}

sub _link_phabric {
    my $rev = $1 || "";
    my $link = "<a href=\"" . PHABRIC .
        "$rev\" title=\"Review $rev on reviews.FreeBSD.org\">review $rev</a>";
    return $link;
}

__PACKAGE__->NAME;
