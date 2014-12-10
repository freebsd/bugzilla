# FreeBSD specific hooks for Bugzilla

package Bugzilla::Extension::BFBSD;

use strict;
use warnings;
use Bugzilla::Constants;

use base qw(Bugzilla::Extension);

use constant {
};

our $VERSION = '0.1.0';

sub bug_check_can_change_field {
    my ($self, $args) = @_;
    if ($args->{'field'} eq 'keywords') {
        my $user = Bugzilla->user;
        if (!$user->in_group('freebsd_committer', $args->{'bug'}->product_id)) {
            push($args->{'priv_results'}, PRIVILEGES_REQUIRED_EMPOWERED);
            return;
        }
    }
}

__PACKAGE__->NAME;
