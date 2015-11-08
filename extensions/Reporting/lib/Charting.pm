package Bugzilla::Extension::Reporting::Charting;

use strict;
use Bugzilla;
use Bugzilla::Constants;

use Chart::Bars;
use Chart::Lines;
use File::Basename;
use POSIX qw(strftime);

use base qw(Exporter);
our @EXPORT = qw(
    get_chart_file chart_lines chart_bars
);

use constant COLORMAP => {
    "dataset0" => [173, 35, 35],
    "dataset1" => [42, 75, 215],
    "dataset2" => [129, 38, 192],
    "dataset3" => [41, 208, 208],
    "dataset4" => [255, 146, 51],
    "dataset5" => [29, 105, 20],
    "dataset6" => [233, 222, 187],
    "dataset7" => [157, 175, 255],
    "dataset8" => [129, 74, 25],
    "dataset9" => [0,0,0]
};

use constant LINE_SETTINGS => (
    "grey_background" => "false",
    "y_grid_lines" => "true",
    "x_grid_lines" => "false",
    "brush_size" => 4,
    "x_ticks" => "vertical",
    "precision" => 0
);

use constant BAR_SETTINGS => (
    "grey_background" => "false",
    "y_grid_lines" => "true",
    "x_grid_lines" => "true",
    "brush_size" => 4,
    "x_ticks" => "vertical",
    "precision" => 0
);

use constant {
    WIDTH  => 1000,
    HEIGHT => 700,
    TICKS  => 20,
};

sub get_chart_file {
    my $filename = shift();
    my $date = strftime('%Y-%m-%d', localtime());
    my $graphdir = bz_locations()->{"graphsdir"};
    my $imgfile = join("/", $graphdir, "$filename-$date.png");

    my $graphurl = basename($graphdir);
    my $imgurl = join("/", $graphurl, "$filename-$date.png");

    my $recreate = 1;
    if (-e $imgfile) {
        # For debugging purposes: change to 1
        $recreate = 0;
    }
    return ($imgfile, $imgurl, $recreate);
}

# Expects the following arguments:
#   - a filename to store the graph to.
#   - an arrayref containing the x-axis labels: (label1, label2, ...)
#   - a hashref containing the datasets:
#
#       { "datasetname 1" => (value1, value2, ....),
#         "datasetname 1" => (value1, value2, ....), ... }
#
#     the values of the hashref must be lists matching the size of the
#     x-axis labels
#   - a hash containing the settings for Chart::Lines (see its
#     chart->set() documentation)
sub chart_lines {
    my ($filename, $xlabels, $datasets, %settings) = @_;

    my $chart = Chart::Lines->new(WIDTH, HEIGHT);
    $chart->set("colors", COLORMAP);
    my %s = (%settings, LINE_SETTINGS);
    $chart->set(%s);
    my $num = 0;

    # Calculate the resolution
    if (scalar(@$xlabels) > TICKS) {
        my $skipx = int((scalar(@$xlabels) + TICKS - 1) / TICKS);
        $chart->set("skip_x_ticks" => $skipx);
    }
    my @dslabels;
    my @ds;
    foreach my $k (keys %$datasets) {
        push(@dslabels, $k);
        push(@ds, $datasets->{$k});
    }
    $chart->set("legend_labels", \@dslabels);
    my @mref = ($xlabels, @ds);
    $chart->png($filename, \@mref);
}

# Expects the following arguments:
#   - a filename to store the graph to.
#   - an arrayref containing the x-axis labels: (label1, label2, ...)
#   - a hashref containing the datasets:
#
#       { "datasetname 1" => (value1, value2, ....),
#         "datasetname 1" => (value1, value2, ....), ... }
#
#     the values of the hashref must be lists matching the size of the
#     x-axis labels
#   - a hash containing the settings for Chart::Bars (see its
#     chart->set() documentation)
sub chart_bars {
    my ($filename, $xlabels, $datasets, %settings) = @_;

    my $chart = Chart::Bars->new(WIDTH, HEIGHT);
    $chart->set(%settings);
    $chart->set("colors", COLORMAP);
    my $num = 0;

    my @legends;
    my @data;
    foreach my $k (keys %$datasets) {
        push(@legends, $k);
        push(@data, $datasets->{$k});
    }
    $chart->set("legend_labels", \@legends);
    my @mref = ($xlabels, @data);
    $chart->png($filename, \@mref);
}

1;
