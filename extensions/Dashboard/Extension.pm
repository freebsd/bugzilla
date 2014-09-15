package Bugzilla::Extension::Dashboard;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Extension::Dashboard::Util;

our $VERSION = '0.01';

use constant {
    MAXDAYS => 366,
    IDLEDAYS => 30,
    DEFDAYS => 14

};

sub page_before_template {
    my ($self, $args) = @_;
    my $page = $args->{page_id};
    my $vars = $args->{vars};

    if ($page ne "dashboard.html") {
        # Do not do anything, if the currently requested page is not
        # the dashboard.
        return;
    }
    # The dashboard requires a login for proper rights.
    Bugzilla->login(LOGIN_REQUIRED);

    my $cgi = Bugzilla->cgi;
    my $user = Bugzilla->user;
    my $urlbase = Bugzilla->params->{urlbase};
    my $days = DEFDAYS;

    # Ensure that the &days=XX GET parameter is valid
    if (defined($cgi->param("days")) && $cgi->param('days') ne "") {
        $days = $cgi->param("days");
        detaint_natural($days) or ThrowUserError("days_type_number");
    }
    ($days < MAXDAYS) or ThrowUserError("days_max_days");

    # Create some statistics about the total number of open bugs, new bugs
    # within the last XX days and closed bugs for the last XX days.
    my (@tnbugs, @tcbugs);
    my ($tncount, $tocount, $tccount) = (0, 0);
    my $products = [];
    my $productlist = $user->get_selectable_products();
    foreach my $product (@$productlist) {
        my ($ncount, $nbugs) = new_bugs($product, $days);
        my ($ccount, $cbugs) = closed_bugs($product, $days);
        my ($ocount, $obugs) = open_bugs($product),

        $tncount += $ncount;
        $tccount += $ccount;
        $tocount += $ocount;

        push(@tnbugs, @$nbugs);
        push(@tcbugs, @$cbugs);

        push(@$products, {
            "name" => $product->name,
            "id" => $product->id,
            "total" => $ocount,
            "new" => $ncount,
            "nurl" => "$urlbase/buglist.cgi?bug_id=" . join(",", @$nbugs),
            "closed" => $ccount,
            "curl" => "$urlbase/buglist.cgi?bug_id=" . join(",", @$cbugs)
             });
    }
    $vars->{products} = $products;
    $vars->{totals} = {
        "total" => $tocount,
        "new" => $tncount,
        "nurl" => "$urlbase/buglist.cgi?bug_id=" . join(",", @tnbugs),
        "closed" => $tccount,
        "curl" => "$urlbase/buglist.cgi?bug_id=" . join(",", @tcbugs)
    };
    $vars->{days} = $days;
    # Get useful queries
    $vars->{queries} = _predefined_queries($user, $urlbase);
}

sub _predefined_queries {
    my ($user, $urlbase) = @_;
    my ($count, $buglist);
    my $queries = ();

    ($count, $buglist) = missing_feedback(DEFDAYS);
    push(@$queries, {
        "desc" => "Bugs waiting for feedback (flags) for more than " . DEFDAYS . " days",
        "count" =>  $count,
        "url" => "$urlbase/buglist.cgi?bug_id=" . join(",", @$buglist)
         });

    ($count, $buglist) = idle_bugs(IDLEDAYS);
    push(@$queries, {
        "desc" => "Idle bugs, for which nothing happend for more than " . IDLEDAYS . " days",
        "count" =>  $count,
        "url" => "$urlbase/buglist.cgi?bug_id=" . join(",", @$buglist)
         });

    ($count, $buglist) = new_ports_bugs();
    push(@$queries, {
        "desc" => "Ports bugs, that do not have been looked at yet",
        "count" =>  $count,
        "url" => "$urlbase/buglist.cgi?bug_id=" . join(",", @$buglist)
         });

    ($count, $buglist) = commit_ports_bugs();
    push(@$queries, {
        "desc" => "Ports bugs, that are ready to be taken by a committers",
        "count" =>  $count,
        "url" => "$urlbase/buglist.cgi?bug_id=" . join(",", @$buglist)
         });
    return $queries;
}

__PACKAGE__->NAME;
