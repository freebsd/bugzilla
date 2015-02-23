package Bugzilla::Extension::FBSDAutoAssign;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

use Bugzilla::Comment;
use Bugzilla::Field;
use Bugzilla::FlagType;
use Bugzilla::Flag;
use Bugzilla::Mailer;
use Bugzilla::User;

use Bugzilla::Extension::BFBSD::Helpers;

use constant {
    PORTSDIR => "/home/ports",
    INDEX => "INDEX",
    # Bug 196372 - make comments optional
    DOCOMMENT => 0,
    REASSIGN => 1
};

our $VERSION = '0.3.0';

sub install_update_db {
    my ($self, $args) = @_;
    my $dbh = Bugzilla->dbh;

    print("Checking for ports directory... ");
    if (-d PORTSDIR) {
        print("found!\n");
    } else {
        print("NOT FOUND - please create it at " . PORTSDIR . "!\n");
    }

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
        inclusions       => ['0:0'],
        exclusions       => [],
    });
}

sub bug_end_of_create {
    my ($self, $args) = @_;
    my $bug = $args->{'bug'};

    # We only add CCs, if it is a individual port bug
    if ($bug->product ne PRODUCT_PORTS ||
        $bug->component ne COMPONENT_PORTS) {
        return;
    }
    my @foundports = ();

    # Is it a port patch in summary matching ([A-Za-z0-9_-]/[A-Za-z0-9_-])?
    my @res = ($bug->short_desc =~ /(?:^|[:\[\s+])([\w-]+\/[\w-]+)(?:[:\]\s+]|$)/g);
    if (@res && scalar(@res) > 0) {
        # warn("Found ports in summary: @res");
        push(@foundports, @res);
    }

    if (scalar(@foundports) == 0) {
        # Did not find a port in subject
        # Is it a port in the description matching
        #  ([A-Za-z0-9_-]/[A-Za-z0-9_-])?
        my $first = $bug->comments->[0]->body;
        @res = ($first =~ /(?:^|[:,\s+])([\w-]+\/[\w-]+)(?:[:,\s+]|$)/g);
        if (@res && scalar(@res) > 0) {
            # warn("Found ports in description: @res");
            push(@foundports, @res);
        }
    }
    # Remove duplicate entries.
    my %hashed = map{$_, 1} @foundports;
    @foundports = keys(%hashed);

    # Add the maintainers of the affected ports to the CC. If there is
    # only one person, add a feedback request for that person and
    # optionally assign (if it is a committer), otherwise set all into
    # CC.

    my @maintainers = ();
    my @categories = ();
    foreach my $port (@foundports) {
        my $maintainer = _get_maintainer($port);
        if ($maintainer) {
            push(@maintainers, $maintainer);
            push(@categories, $port =~ /^([\w-]+)\/[\w-]+$/g);
        }
    }

    # Remove duplicate entries
    %hashed = map{$_, 1} @maintainers;
    @maintainers = keys(%hashed);
    %hashed = map{$_, 1} @categories;
    @categories = keys(%hashed);

    _update_bug($bug, \@maintainers, \@categories);
}

sub _update_bug {
    my ($bug, $maintainers, $categories) = @_;

    # Switch the user session
    my $autoid = login_to_id(UID_AUTOASSIGN);
    if (!$autoid) {
        warn("AutoAssign user does not exist");
        return;
    }
    my $curuser = Bugzilla->user;
    Bugzilla->set_user(new Bugzilla::User($autoid));

    # Only one maintainer?
    if (scalar(@$maintainers) == 1) {
        my $maintainer = @$maintainers[0];
        if (no_maintainer($maintainer)) {
            Bugzilla->set_user($curuser);
            return;
        }
        my $user = get_user($maintainer);
        if (!$user) {
            # Maintainer not registered or deactivated, send a mail.
            _send_mail_to($maintainer, $bug);
            $bug->add_comment("Maintainer informed via mail");
            Bugzilla->set_user($curuser);
            return;
        }
        if ($curuser->id == $user->id) {
            # Maintainer updates should not ask the user for feedback.
            Bugzilla->set_user($curuser);
            return;
        }

        my $flag_feedback;
        my $flagtypes = Bugzilla::FlagType::match(
            { name => 'maintainer-feedback' });
        if (scalar(@$flagtypes) == 1) {
            $flag_feedback = @{$flagtypes}[0];
        }
        if (!$flag_feedback) {
            warn("maintainer-feedback flag not found");
        } else {
            my (@oldflags, @newflags);
            push(@newflags, { type_id   => $flag_feedback->id,
                              status    => "?",
                              requestee => $user->login
                 });
            $bug->set_flags(\@oldflags, \@newflags);
        }
        if (REASSIGN != 0 && $user->login =~ /\@freebsd\.org$/i) {
            my $name = $user->login;
            $bug->set_assigned_to($user);
            # since we set the maintainer-feedback? flag, the default
            # behaviour of bugzilla is to add the user as CC.
            # We do not need that on reassignments
            $bug->remove_cc($user);
            if (DOCOMMENT != 0) {
                $bug->add_comment("Auto-assigned to maintainer $name");
            }
        } else {
            $bug->add_cc($user);
            if (DOCOMMENT != 0) {
                $bug->add_comment("Maintainer CC'd");
            }
        }
    } else {
        my $someoneccd = 0;
        foreach my $maintainer (@$maintainers) {
            next if no_maintainer($maintainer);

            my $user = get_user($maintainer);
            if ($user) {
                if ($curuser->id != $user->id) {
                    $bug->add_cc($user);
                    $someoneccd = 1;
                }
            } else {
                # User not registered or deactivated, we won't send
                # mails to them.
            }
        }
        if (DOCOMMENT != 0 && $someoneccd == 1) {
            $bug->add_comment("Maintainers CC'd");
        }
    }

    # Deal with special requirements: bug 195253
    #  1) port is positively identified
    #  2) port is in games category
    #  3) port is unmaintained
    #  ==> add games@FreeBSD.org as CC
    if (grep { lc($_) eq "games" } @$categories) {
        if (grep { lc($_) eq "ports\@freebsd.org" } @$maintainers) {
            my $user = get_user("games\@FreeBSD.org");
            if ($user) {
                $bug->add_cc($user);
            }
        }
    }

    # Switch the user session back.
    Bugzilla->set_user($curuser);
}

sub _get_maintainer {
    # we expect _get_maintainer("category/port")
    my $port = shift();
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
        return $maintainer;
    } else {
        warn("Port directory $portdir not found");
    }
    return;
}

sub _send_mail_to {
    my ($maintainer, $bug) = @_;
    my $mail = "
From: bugzilla-noreply\@FreeBSD.org
To: %s
Subject: %s

Dear FreeBSD port maintainer,

the following problem report was just filed in the FreeBSD Bugzilla
system, which needs your attention. You can view the report online at

https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=%d

The report contents are as follows.

%s

";
    my $mailmsg = sprintf(
        $mail,
        $maintainer,
        $bug->short_desc,
        $bug->id,
        $bug->comments->[0]->body
        );
    MessageToMTA($mailmsg, 1);
}
__PACKAGE__->NAME;
