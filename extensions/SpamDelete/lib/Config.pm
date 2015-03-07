package Bugzilla::Extension::SpamDelete::Config;

use strict;
use warnings;

use Bugzilla::Config::Common;
use Bugzilla::Group;

our $sortkey = 5000;

sub get_param_list {
    my ($class) = @_;

    my @param_list = (
        {
            name    => "spam_backupfolder",
            type    => "t",
            default => "spam",
        },
        {
            name    => "spam_contacts",
            type    => "t",
            default => "",
            checker => \&check_email,
        },
        {
            name    => "spam_delete_group",
            type    => "s",
            choices => \&_get_groups,
            default => 'admin',
            checker => \&check_group
        },
        {
            name    => "spam_disable_text",
            type    => "l",
            default =>
                "This account has been disabled as a " .
                "result of creating spam."
        },
    );
    return @param_list;
}

sub _get_groups {
    my @groups = map {$_->name} Bugzilla::Group->get_all;
    unshift(@groups, '');
    return \@groups;
}

1;
