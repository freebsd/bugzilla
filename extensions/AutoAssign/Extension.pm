package Bugzilla::Extension::AutoAssign;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

use Data::Dumper;

use Bugzilla::Comment;
use Bugzilla::Field;
use Bugzilla::FlagType;
use Bugzilla::Flag;
use Bugzilla::User;

use constant {
    PORTSDIR => "/usr/ports",
    INDEX => "INDEX",
    # Needs to be changed to an internal user
    UID_AUTOASSIGN => "bugmeister\@FreeBSD.org",
    # We want a comment about the automatic action
    AUTOCOMMENT => 1,
    REASSIGN => 1
};

our $VERSION = '0.1.0';

sub install_update_db {
    my ($self, $args) = @_;
    my $dbh = Bugzilla->dbh;

    if (@{ Bugzilla::FlagType::match({ name => 'maintainer-feedback' }) }) {
        return;
    }

    print("Creating maintainer-feedback flag ...\n");

    my $flagtype = Bugzilla::FlagType->create({
        name        => 'maintainer-feedback',
        description => "Set this flag, if you want to request information from the maintainer",
        target_type => 'bug',
        cc_list     => '',
        sortkey     => 1,
        is_active   => 1,
        is_requestable   => 1,
        is_requesteeble  => 1,
        is_multiplicable => 0,
        request_group    => '',
        grant_group      => '',
        inclusions       => [],
        exclusions       => ['0:0'],
    });
}

sub bug_end_of_create {
    my ($self, $args) = @_;
    my $bug = $args->{'bug'};

    # We only add CCs, if it is a individual port bug
    #my $product = ;
    #my $component = ;
    if ($bug->product ne "Ports Tree" ||
        $bug->component ne "Individual Port(s)") {
        return;
    }
    my @foundports = ();

    # Is it a port patch in summary matching ([A-Za-z0-9_-]/[A-Za-z0-9_-])?
    my @res = ($bug->short_desc =~ /([\w-]+\/[\w-]+)/g);
    if (@res && scalar(@res) > 0) {
        # warn("Found ports in summary: @res");
        push(@foundports, @res);
    }
    # Remove duplicate entries.
    my %hashed = map{$_, 1} @foundports;
    @foundports = keys(%hashed);

    if (scalar(@foundports) == 0) {
        # Did not find a port in subject
        # Is it a port in the description matching
        #  ([A-Za-z0-9_-]/[A-Za-z0-9_-])?
        my $first = $bug->comments->[0]->body;
        @res = ($first =~ /([\w-]+\/[\w-]+)/g);
        if (@res && scalar(@res) > 0) {
            warn("Found ports in description: @res");
            push(@foundports, @res);
        }
    }
    # Remove duplicate entries.
    %hashed = map{$_, 1} @foundports;
    @foundports = keys(%hashed);

    my $flag_feedback;
    my $flagtypes = Bugzilla::FlagType::match(
        { name => 'maintainer-feedback' });
    if (scalar(@$flagtypes) == 1) {
        $flag_feedback = @{$flagtypes}[0];
    }

    # Add the maintainers of the affected ports to the CC. If there is only
    # one person, add a feedback request for that person and optionally assign
    # (if it is a committer), otherwise set all into CC.
    if (scalar(@foundports) == 1) {
        my ($maintainer, $user) = _get_maintainer($foundports[0]);
        if (!$user) {
            # warn("Could not find maintainer for $foundports[0]");
            return;
        }
        if (!$user->is_enabled) {
            # warn("Found maintainer is not enabled in Bugzilla");
            return;
        }
        if (Bugzilla->user->id == $user->id) {
            # Maintainer updates should not ask the user for feedback.
            return;
        }

        if (!$flag_feedback) {
            # warn("maintainer-feedback flag not found");
        } else {
            my (@oldflags, @newflags);
            push(@newflags, { type_id   => $flag_feedback->id,
                              status    => "?",
                              requestee => $user->login
                 });
            $bug->set_flags(\@oldflags, \@newflags);
        }
        if (REASSIGN != 0 && $user->login =~ /\@freebsd\.org$/i) {
            # It's a FreeBSD committer
            $bug->set_assigned_to($user);
            _add_comment($bug, "Auto-assigned to maintainer $user->login");
        } else {
            $bug->add_cc($user);
            _add_comment($bug, "Maintainer CC'd");
        }

    } else {
        my $someoneccd = 0;
        foreach my $port (@foundports) {
            my $user = _get_maintainer($port);
            if ($user) {
                $bug->add_cc($user);
                $someoneccd = 1;
            } else {
                # warn("Could not find maintainer for '$port'");
            }
        }
        if ($someoneccd == 1) {
            _add_comment($bug, "Maintainers CC'd");
        }
    }
}

sub _add_comment {
    my ($bug, $comment) = @_;
    if (AUTOCOMMENT == 0) {
        return;
    }
    my $autoid = login_to_id(UID_AUTOASSIGN);
    # Do not set a comment, if the user does not exist.
    if ($autoid) {
        my $curuser = Bugzilla->user;
        Bugzilla->set_user(new Bugzilla::User($autoid));
        $bug->add_comment($comment);
        Bugzilla->set_user($curuser);
    } else {
        # warn("configured auto-assign user missing!")
    }
}

sub _update_status {
    my ($bug, $status) = @_;
    my $autoid = login_to_id(UID_AUTOASSIGN);
    if ($autoid) {
        my $curuser = Bugzilla->user;
        Bugzilla->set_user(new Bugzilla::User($autoid));
        $bug->set_bug_status($status);
        Bugzilla->set_user($curuser);
    } else {
        # warn("configured auto-assign user missing!")
    }
}

sub _get_maintainer {
    # we expect _get_maintainer("category/port")
    my $port = shift;
    my $portdir = "" . PORTSDIR . "/$port";
    # Does it exist and is a directory?
    if (-d $portdir) {
        # temporarily manipulate path to allow the exec
        # to access all necessary tools
        my $oldenv = $ENV{PATH};
        $ENV{PATH} .= "/usr/bin:/usr/local/bin:/usr/local/sbin";
        my $maintainer = `PORTSDIR=@{[PORTSDIR]} make -C $portdir -V MAINTAINER`;
        $ENV{PATH} = $oldenv;
        chomp($maintainer);
        if ($maintainer) {
            # Do not bother ports@FreeBSD.org
            if (lc($maintainer) eq "ports\@freebsd.org") {
                # warn("$port ignored, maintainer is ports\@FreeBSD.org");
                return;
            }
            my $uid = login_to_id($maintainer);
            if ($uid) {
                return ($maintainer, new Bugzilla::User($uid));
            }
        }
    }
    return;
}

__PACKAGE__->NAME;
