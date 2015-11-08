package Bugzilla::Extension::Reporting::Graphs;

use strict;
use Bugzilla;
use Bugzilla::Extension::Reporting::Charting;
use Bugzilla::Extension::Reporting::Queries;

use base qw(Exporter);
our @EXPORT = qw(
    total_bugs_over_time total_bugs_per_product_over_time
    total_open_bugs_over_time total_open_bugs_per_product_over_time
    total_open_bugs_per_product_over_time
);

sub total_bugs_over_time {
    my $args = shift();

    my %settings = (
        "title" => "Total number of bugs",
        "x_label" => "Date",
        "y_label" => "Count",
    );

    my ($labels, $datasets) = bugs_over_time();
    my ($name, $url, $create) = get_chart_file($args->{file});

    if ($create != 0) {
        chart_lines($name, $labels, $datasets, %settings);
    }
    return $url;
}

sub total_bugs_per_product_over_time {
    my $args = shift();

    my %settings = (
        "title" => "Total number of bugs per product",
        "x_label" => "Date",
        "y_label" => "Count",
    );

    my ($labels, $datasets) = bugs_over_time_per_product();
    my %products = map { $_ => 1 } @{ $args->{products} };

    # Delete all products not being requested.
    foreach my $key (keys %$datasets) {
        next if exists($products{$key});
        delete $datasets->{$key};
    }

    my ($name, $url, $create) = get_chart_file($args->{file});
    if ($create != 0) {
        chart_lines($name, $labels, $datasets, %settings);
    }
    return $url;
}

sub total_open_bugs_over_time {
    my $args = shift();

    my %settings = (
        "title" => "Total open number of bugs",
        "x_label" => "Date",
        "y_label" => "Count",
    );
    my ($labels, $datasets) = bugs_over_time_per_status();
    delete $datasets->{"Closed"};

    # Melt the datasets - we jut want to have a single one.
    my @data;
    my $ds = { "Open Bugs" => \@data };
    my $cnt = scalar(@$labels) - 1;
    for my $i ( 0..$cnt ) {
        my $c = 0;
        foreach my $k (keys %$datasets) {
            $c += $datasets->{$k}->[$i];
        }
        push(@data, $c);
    }
    my ($name, $url, $create) = get_chart_file($args->{file});
    if ($create != 0) {
        chart_lines($name, $labels, $ds, %settings);
    }
    return $url;
}

sub total_open_bugs_per_product_over_time {
    # TODO
}
