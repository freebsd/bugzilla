package Bugzilla::Extension::SVNLinks;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

use constant {
    SVN_PORTS => "http://svnweb.freebsd.org/changeset/ports/",
    SVN_BASE => "http://svnweb.freebsd.org/changeset/base/",
    SVN_DOC => "http://svnweb.freebsd.org/changeset/doc/",
};

our $VERSION = '0.1.0';

sub bug_format_comment {
    my ($self, $args) = @_;
    my $regexes = $args->{regexes};

    push(@$regexes, {
        match => qr/ports\s*\#?\s*r?(\d+)/i,
        replace => \&_link_ports
         });
    push(@$regexes, {
        match => qr/base\s*\#?\s*r?(\d+)/i,
        replace => \&_link_base
         });
    push(@$regexes, {
        match => qr/doc\s*\#?\s*r?(\d+)/i,
        replace => \&_link_doc
         });
}

sub _link_ports {
    my $rev = $1 || "";
    my $link = "<a href=\"" . SVN_PORTS .
        "$rev\" title=\"revision $rev in ports\">ports r$rev</a>";
}

sub _link_base {
    my $rev = $1 || "";
    my $link = "<a href=\"" . SVN_BASE .
        "$rev\" title=\"revision $rev in base\">base r$rev</a>";
}

sub _link_doc {
    my $rev = $1 || "";
    my $link = "<a href=\"" . SVN_DOC .
        "$rev\" title=\"revision $rev in doc\">doc r$rev</a>";
}

__PACKAGE__->NAME;
