package Bugzilla::Extension::FreeBSDBugUrls;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

our $VERSION = '0.1.0';

use constant MORE_SUB_CLASSES => qw(
    Bugzilla::Extension::FreeBSDBugUrls::BitBucket
    Bugzilla::Extension::FreeBSDBugUrls::Phabricator
    Bugzilla::Extension::FreeBSDBugUrls::NetBSD
    Bugzilla::Extension::FreeBSDBugUrls::GoogleChromium
    Bugzilla::Extension::FreeBSDBugUrls::GoogleIssueTracker
    Bugzilla::Extension::FreeBSDBugUrls::DragonFlyBSD
    Bugzilla::Extension::FreeBSDBugUrls::Gitlabs
);

# We need to update bug_see_also table because both
sub bug_url_sub_classes {
    my ($self, $args) = @_;
    push @{ $args->{sub_classes} }, MORE_SUB_CLASSES;
}

__PACKAGE__->NAME;
