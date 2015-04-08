package Bugzilla::Extension::Reporting;
use strict;
use base qw(Bugzilla::Extension);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Util;
use Bugzilla::Extension::Reporting::Graphs;

our $VERSION = '0.1.0';

sub get_products {
    my $remove = shift();
    my $products = Bugzilla->user->get_selectable_products();
    my @retval;
    if (defined($remove)) {
        my %rm = map { $_ => 1 } @$remove;
        foreach my $p (@$products) {
            next if exists($rm{$p->name});
            push(@retval, $p->name);
        }
    } else {
        @retval = map($_->name, @$products);
    }
    return \@retval;
}

sub get_reports {
    return [
        {
            title => "Total number of bugs",
            type  => "total_bugs_over_time",
            desc  => "Total number of bugs over time",
            func  => \&total_bugs_over_time,
            args => {
                file => "total_bugs_over_time"
            }
        },
        {
            title => "Number of bugs per product",
            type  => "total_bugs_per_product_over_time",
            desc  => "Total number of bugs per product over time",
            func  => \&total_bugs_per_product_over_time,
            args  => {
                file => "total_bugs_per_product_over_time",
                products => get_products(),
            },
        },
        {
            title => "Number of bugs per product without Ports",
            type  => "total_bugs_per_product_over_time_no_ports",
            desc  => "Total number of bugs per product over time without Ports",
            func  => \&total_bugs_per_product_over_time,
            args  => {
                file => "total_bugs_per_product_over_time_no_ports",
                products => get_products(["Ports & Packages"]),
            },
        },
        {
            title => "Total open number of bugs",
            type  => "total_open_bugs_over_time",
            desc  => "Total open number of bugs over time",
            func  => \&total_open_bugs_over_time,
            args => {
                file => "total_open_bugs_over_time"
            }
        },
        {
            title => "Total open number of bugs per product",
            type  => "total_open_bugs_per_product_over_time",
            desc  => "Total open number of bugs over time per product",
            func  => \&total_open_bugs_per_product_over_time,
            args => {
                file => "total_open_bugs_per_product_over_time"
            }
        },
    ];
}
    # Bars:

    # Number of PRs by category
    # Number of PRs by category without ports

    # Number of PRs by category and status
    # Number of PRs by category and statuswithout ports

sub page_before_template {
    my ($self, $args) = @_;
    my $page = $args->{page_id};
    my $vars = $args->{vars};

    if ($page ne "reporting.html" && $page ne "showreport.html") {
        # Do not do anything, if the currently requested page is not
        # the report page.
        return;
    }
    if ($page eq "showreport.html") {
        show_report($page, $args);
    } elsif ($page eq "reporting.html") {
        show_overview($page, $args);
    }
}

sub show_overview {
    my ($page, $args) = @_;
    my $vars = $args->{vars};
    $vars->{reports} = get_reports();
}

sub show_report {
    my ($page, $args) = @_;
    my $vars = $args->{vars};
    my $cgi = Bugzilla->cgi;

    # Ensure that the GET parameters are valid
    if (!defined($cgi->param("type"))) {
        ThrowUserError("invalid_report_type");
    }
    my $type = $cgi->param("type");

    my @reports = grep($_->{type} eq $type, @{ get_reports() });
    if (scalar(@reports) != 1) {
        ThrowUserError("invalid_report_type");
    }
    my $report = $reports[0];

    my @images;
    $vars->{report} = $report;

    push(@images, { title => $report->{title},
                    url   => $report->{func}($report->{args}) });
    $vars->{images} = \@images;
}

__PACKAGE__->NAME;
