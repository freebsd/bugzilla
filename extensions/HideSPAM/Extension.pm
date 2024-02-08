package Bugzilla::Extension::HideSPAM;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

our $VERSION = '0.1.0';

sub bug_format_comment {
    my ($self, $args) = @_;
    my $regexes = $args->{regexes};
    my $bug = $args->{bug};
    my $comment = $args->{comment};

    my $user;
    $user = $comment->author if (defined($comment));
    $user = $bug->reporter if (defined($bug) && !defined($user));
    if (defined($user) && ($user->disabledtext =~ /\[spam\]/i)) {
        push(@$regexes, {
            match => qr/.+/is,
            replace => "MARKED AS SPAM",
        });
    }
}

__PACKAGE__->NAME;
