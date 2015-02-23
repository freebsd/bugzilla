package Bugzilla::Extension::Dashboard::Util;

use strict;
use POSIX qw(strftime);
use Bugzilla;
use Bugzilla::Flag;
use Bugzilla::Search;
use base qw(Exporter);

use constant {
    SEC_PER_DAY => 86400
};

our @EXPORT = qw(
    open_bugs new_bugs closed_bugs missing_feedback idle_bugs
    new_ports_bugs commit_ports_bugs mfc_bugs flags_requestee
    flags_setter
);

sub _search {
    my ($criteria, $fields) = @_;

    if (!$fields) {
        $fields = [ "bug_id" ];
    }

    my $search = new Bugzilla::Search(
        "fields"          => $fields,
        "params"          => $criteria,
        "user"            => Bugzilla->user,
        "allow_unlimited" => 1
        );
    my $result = $search->data;
    return ($criteria, scalar(@$result), $result);
}

sub open_bugs {
    my $product = shift();
    my $critonly = shift();

    my %criteria = (
        "bug_status" => "__open__",
    );
    if (defined($product)) {
        $criteria{"product"} = $product->name;
    }
    if ($critonly) {
        return \%criteria;
    } else {
        return _search(\%criteria);
    }
}

sub new_bugs {
    my ($product, $days, $critonly) = @_;

    my $back = time() - ($days * SEC_PER_DAY);
    my $ts = strftime("%Y-%m-%d", localtime($back));

    my %criteria = (
        "bug_status" => "__open__",
        "f1" => "creation_ts",
        "o1" => "greaterthaneq",
        "v1" => $ts
        );
    if (defined($product)) {
        $criteria{"product"} = $product->name;
    }
    if ($critonly) {
        return \%criteria;
    } else {
        return _search(\%criteria);
    }
}

sub closed_bugs {
    my ($product, $days, $critonly) = @_;

    my $back = time() - ($days * 24 * 60 * 60);
    my $ts = strftime("%Y-%m-%d", localtime($back));

    my %criteria = (
        "bug_status" => "__closed__",
        "f1" => "delta_ts",
        "o1" => "greaterthaneq",
        "v1" => $ts
        );
    if (defined($product)) {
        $criteria{"product"} = $product->name;
    }
    if ($critonly) {
        return \%criteria;
    } else {
        return _search(\%criteria);
    }
}

sub missing_feedback {
    my ($days, $critonly) = @_;

    my %criteria = (
        "bug_status" => "__open__",
        "f1" => "flagtypes.name",
        "o1" => "substring",
        "v1" => "?",
        "f2" => "flagtypes.name",
        "o2" => "changedbefore",
        "v2" => "" . $days . "d"
        );
    if ($critonly) {
        return \%criteria;
    } else {
        return _search(\%criteria);
    }
}

sub idle_bugs {
    my ($days, $critonly) = @_;

    my %criteria = (
        "bug_status" => "__open__",
        "f2" => "days_elapsed",
        "o2" => "greaterthan",
        "v2" => "" . $days
        );
    if ($critonly) {
        return \%criteria;
    } else {
        return _search(\%criteria);
    }
}

sub new_ports_bugs {
    my $critonly = shift();

    my %criteria = (
        "bug_status" => "New",
        "email1" => "freebsd-ports-bugs\@FreeBSD.org",
        "emailassigned_to1" => "1",
        "emailtype1" => "exact",
        "product" => "Ports & Packages",
        "f1" => "longdescs.count",
        "o1" => "equals",
        "v1" => "1"
        );
    if ($critonly) {
        return \%criteria;
    } else {
        return _search(\%criteria);
    }
}

sub commit_ports_bugs {
    my $critonly = shift();

    my %criteria = (
        "email1" => "freebsd-ports-bugs\@FreeBSD.org",
        "emailassigned_to1" => "1",
        "emailtype1" => "exact",
        "f1" => "keywords",
        "o1" => "substring",
        "v1" => "patch-ready",
        "product" => "Ports & Packages",
        "bug_status" => "__open__",
        );
    if ($critonly) {
        return \%criteria;
    } else {
        return _search(\%criteria);
    }
}

sub mfc_bugs {
    my $critonly = shift();

    my %criteria = (
        "f1" => "flagtypes.name",
        "o1" => "anywordssubstr",
        "v1" => "mfc-stable8? mfc-stable9? mfc-stable10? merge-quarterly?",
        "bug_status" => "__open__",
        );
    if ($critonly) {
        return \%criteria;
    } else {
        return _search(\%criteria);
    }
}

sub flags_requestee {
    my $critonly = shift();

    my $user = Bugzilla->user;
    my %criteria = (
        "f1" => "requestees.login_name",
        "o1" => "equals",
        "v1" => $user->login,
        "bug_status" => "__open__",
        );
    if ($critonly) {
        return \%criteria;
    }

    # We can't request the login_names, since the SQL query blows up
    # then. Let's do it manually and push all in a simple array.
    my @bugs;
    my $matchedbugs = Bugzilla::Flag->match({
        status => '?',
        requestee_id => $user->id
    });
    my %bugids = map{$_->bug_id, $_} @$matchedbugs;

    # $matchedbugs won't necessarily contain only bugs, which
    # match the user preferences, visibility or bug status,
    # let's sync them with the Bugzilla::Search() result.

    my ($crit, $count, $ids) = _search(
        \%criteria, ["bug_id", "short_desc"]);

    foreach my $id (@$ids) {
        my ($bug_id, $desc) = @$id;
        next if (!$bugids{$bug_id});

        my $flag = $bugids{$bug_id};
        push(@bugs, {
            "id"        => $flag->bug_id,
            "desc"      => $desc,
            "flag"      => $flag->type->name,
            "requester" => $flag->setter->login,
            "requestee" => $flag->requestee ? $flag->requestee->login : '',
             });
    }
    return (\%criteria, scalar(@bugs), \@bugs);
}

sub flags_setter {
    my $critonly = shift();

    my $user = Bugzilla->user;
    my %criteria = (
        "f1" => "setters.login_name",
        "o1" => "equals",
        "v1" => $user->login,
        "bug_status" => "__open__",
        );
    if ($critonly) {
        return \%criteria;
    }

    # We can't request the login_names, since the SQL query blows up
    # then. Let's do it manually and push all in a simple array.
    my @bugs;
    my $matchedbugs = Bugzilla::Flag->match({
        status => '?',
        setter_id => $user->id
    });
    my %bugids = map{$_->bug_id, $_} @$matchedbugs;

    # $matchedbugs won't necessarily contain only bugs, which
    # match the user preferences, visibility or bug status,
    # let's sync them with the Bugzilla::Search() result.

    my ($crit, $count, $ids) = _search(
        \%criteria, ["bug_id", "short_desc"]);
    foreach my $id (@$ids) {
        my ($bug_id, $desc) = @$id;
        next if (!$bugids{$bug_id});

        my $flag = $bugids{$bug_id};
        push(@bugs, {
            "id"        => $flag->bug_id,
            "desc"      => $desc,
            "flag"      => $flag->type->name,
            "requester" => $flag->setter->login,
            "requestee" => $flag->requestee ? $flag->requestee->login : '',
             });
    }
    return (\%criteria, scalar(@bugs), \@bugs);
}
