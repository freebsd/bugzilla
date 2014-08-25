package Bugzilla::Extension::AutoAssign;
use strict;
use warnings;
use base qw(Bugzilla::Extension);

use Data::Dumper;

use Bugzilla::Comment;
use Bugzilla::Field;
use Bugzilla::User;

use constant {
    PORTSDIR => "/usr/ports",
    INDEX => "INDEX",
    # Needs to be changed to an internal user
    UID_AUTOASSIGN => "bugzilla\@FreeBSD.org",
    # We want a comment about the automatic action
    AUTOCOMMENT => 1,
    REASSIGN => 1
};

our $VERSION = '0.1.0';

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
        warn("Found ports in summary: @res");
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

    # UNUSED FOR NOW - a different workflow is needed for cf_ports_affected
    #
    # # Sync with the cf_ports_affected list. cf_ports_affected in a
    # # comma-separated list of <cat>/<port> entries.
    # #
    # # Users can't set the field on initial creation, but in case,
    # # the behaviour is changed in bugzilla...
    # my @newlyadded = ();
    # my @affected = split(",", $bug->cf_ports_affected);
    # %hashed = map{$_, 1} @affected;
    # foreach my $port (@foundports) {
    #     if (!exists($hashed{$port})) {
    #         push(@affected, $port);
    #         push(@newlyadded, $port);
    #     }
    # }
    # # Store the new affected port list back to the cf_ field
    # my $field = new Bugzilla::Field({ name => "cf_ports_affected"});
    # if ($field) {
    #     $bug->set_custom_field($field, join(",", @affected));
    # }

    # Add the maintainers of the affected ports to the CC.
    # If there is only one person, assign that person, otherwise
    # set all into CC
    if (REASSIGN == 1 && scalar(@foundports) == 1) {
        my ($maintainer, $user) = _get_maintainer($foundports[0]);
        if (!$user) {
            warn("Could not find maintainer for $foundports[0]");
            return;
        }

        if (Bugzilla->user->id == $user->id) {
            # It's a maintainer update, do not assign to the issuer, but
            # update the status
            _update_status(
                $bug,
                new Bugzilla::Status({ name => "Patch Ready" })
                );
            return;
        } else {
            my $name = $user->login;
            $bug->set_assigned_to($user);
            # TODO: set to feedback, once it's there
            # _update_status(
            #     $bug,
            #     new Bugzilla::Status({ name => "Feedback Required" })
            #     );
            _add_comment($bug, "auto-assigned to maintainer $name");
        }
    } else {
        my $someoneccd = 0;
        foreach my $port (@foundports) {
            my $user = _get_maintainer($port);
            if ($user) {
                $bug->add_cc($user);
                $someoneccd = 1;
            } else {
                warn("Could not find maintainer for '$port'");
            }
        }
        if ($someoneccd == 1) {
            _add_comment($bug, "maintainers CC'd");
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
        warn("configured auto-assign user missing!")
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
        warn("configured auto-assign user missing!")
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
                warn("$port ignored, maintainer is ports\@FreeBSD.org");
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
