package Bugzilla::Extension::HideComponents;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

our $VERSION = '0.1.0';


sub template_before_process {
    my ($self, $args) = @_;
    my ($vars, $file) = @$args{qw(vars file)};

    return if $file ne 'bug/create/create.html.tmpl';
    my $user = Bugzilla->user;
    # Limit noise from mis-classified PRs by non-committer
    # https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=198411
    if (!$user->in_group('freebsd_committe')) {
        $vars->{hide_components} = [
            'Package Infrastructure'
        ];
    }
}

__PACKAGE__->NAME;
