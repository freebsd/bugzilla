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
        if (!$user->in_group('editbugs', $args->{'bug'}->product_id)) {
            push($args->{'priv_results'}, PRIVILEGES_REQUIRED_EMPOWERED);
            return;
        }
    }
}

sub auth_verify_methods {
    my ($self, $args) = @_;
    my $mods = $args->{'modules'};
    if (exists $mods->{'FreeBSD'}) {
	$mods->{'FreeBSD'} = 'Bugzilla/Extension/BFBSD/Auth/Verify.pm';
    }
}

sub config_modify_panels {
    my ($self, $args) = @_;
    my $panels = $args->{panels};
    my $auth_params = $panels->{'auth'}->{params};
    my ($verify_class) = grep($_->{name} eq 'user_verify_class', @$auth_params);
    push(@{ $verify_class->{choices} }, 'FreeBSD');
}

__PACKAGE__->NAME;
