package Bugzilla::Extension::Reporting::Queries;

use strict;
use Bugzilla;
use base qw(Exporter);
our @EXPORT = qw(
    bugs_over_time bugs_over_time_per_product bugs_per_product
    bugs_per_status_per_product bugs_over_time_per_status
);

sub bugs_over_time {
    my $dbh = Bugzilla->dbh;
    my $query = q{
SELECT   bugs.creation_ts::date AS bdate,
         count(bugs.bug_id) AS amount
FROM     bugs
GROUP BY bdate;
    };
    my $bugs = $dbh->selectall_arrayref($query, undef);
    # The raw data will be
    # bugs = [(date, amount), (date, amount), ...]
    # Transform it into something better as return value:
    #
    #  ( (date, date, date ....),
    #    { bugs => (amount, amount, amount, ...) }
    #  )
    my @xlabels = map($_->[0], @$bugs);
    my $d = 0;
    my @amounts;
    foreach my $e (@$bugs) {
        $d += $e->[1];
        push(@amounts, $d);
    }
    my $dataset = { "Bugs" => \@amounts };
    return (\@xlabels, $dataset);
}

sub bugs_over_time_per_product {
    my $dbh = Bugzilla->dbh;
    my @products = @{ $dbh->selectall_arrayref(qq{
SELECT name FROM products;
}, { Slice => {} }) };
    my $query = q{
SELECT   bugs.creation_ts::date AS bdate,
         products.name AS product,
         count(bugs.bug_id) AS amount
FROM     bugs JOIN products ON (products.id = bugs.product_id)
GROUP BY bdate, products.name;
    };
    my $bugs = $dbh->selectall_arrayref($query, undef);
    # The raw data will be
    # bugs = [(date, product, amount), (date, product, amount), ...]
    # Transform it into something better as return value:
    #
    #  ( (date, date, date ....),
    #    { product => (amount, amount, amount, ...),
    #      product => (amount, ....),
    #    } )
    #
    my @xlabels;
    my $datasets = {};
    my $curvals = {};
    foreach my $p (@products) {
        my @d = ();
        $datasets->{$p->{name}} = \@d;
        $curvals->{$p->{name}} = 0;
    }
    my $offs = 0;
    my $curd = "";
    foreach my $rec (@$bugs) {
        my ($d, $p, $a) = @$rec;
        if ($curd ne $d) {
            foreach my $key (keys %$datasets) {
                my $data = $datasets->{$key};
                while (scalar(@$data) < $offs) {
                    push(@$data, $curvals->{$key});
                }
            }
            $curd = $d;
            push(@xlabels, $d);
            $offs += 1;
        }
        my $dataset = $datasets->{$p};
        $curvals->{$p} += $a;
        push(@$dataset, $curvals->{$p});
    }
    return (\@xlabels, $datasets);
}

sub bugs_per_product {
    my $dbh = Bugzilla->dbh;
    my $query = q{
SELECT   count(bug_id) AS amount, products.name AS product
FROM     bugs JOIN products ON (products.id = bugs.product_id)
GROUP BY products.name;
};
    my $bugs = $dbh->selectall_arrayref($query, undef);
    # The raw data will be
    # bugs = [(product, amount), (product, amount), ...]
    return $bugs;
}

sub bugs_per_status_per_product {
    my $dbh = Bugzilla->dbh;
    my @products = @{ $dbh->selectall_arrayref(qq{
SELECT name FROM products;
}, { Slice => {} }) };
    my $query = q{
SELECT   count(bug_id) AS amount,
         bug_status AS status,
         products.name AS product
FROM     bugs JOIN products ON (products.id = bugs.product_id)
GROUP BY bug_status, products.name
ORDER BY products.name, bug_status;
};
    my $bugs = $dbh->selectall_arrayref($query, undef);
    # The raw data will be
    # bugs = [(amount, status, product), (amount, status, product), ...]
    # The tranformed data will be:
    #
    #   ( (status, status, status, ...),
    #     { product => (val1, val2, val3),
    #       product => (val1, ...) }
    #   )
    #
    my $datasets = {};
    foreach my $p (@products) {
        my @d = map($_->[0], grep($_->[2] eq $p->{name}, @$bugs));
        $datasets->{$p->{name}} = \@d;
    }
    my $prod = $bugs->[0]->[2];
    my @xlabels = map($_->[1], grep($_->[2] eq $prod, @$bugs));
    return (\@xlabels, $datasets);
}

sub bugs_over_time_per_status {
    my $dbh = Bugzilla->dbh;
    my @status = @{ $dbh->selectall_arrayref(qq{
SELECT value FROM bug_status;
}, { Slice => {} }) };
    my $query = q{
SELECT bdate, added, removed, count(bdate) AS amount
FROM   (
  SELECT bugs.creation_ts::date AS bdate, 'New'::varchar(255) AS added, NULL as removed
  FROM bugs
  UNION ALL
  SELECT bug_when::date as bdate, added, removed
  FROM bugs_activity
  WHERE fieldid = (SELECT id FROM fielddefs WHERE name = 'bug_status')
  ) AS data
GROUP BY bdate, added, removed
ORDER BY bdate, added, removed;
};
    my $bugs = $dbh->selectall_arrayref($query, undef);
    my @xlabels;
    my $datasets = {};
    my $curvals = {};
    foreach my $p (@status) {
        my @d = ();
        $datasets->{$p->{value}} = \@d;
        $curvals->{$p->{value}} = 0;
    }
    my $offs = 0;
    my $curd = "";
    foreach my $rec (@$bugs) {
        my ($d, $a, $r, $t) = @$rec;
        if ($curd ne $d) {
            foreach my $key (keys %$datasets) {
                my $data = $datasets->{$key};
                while (scalar(@$data) < $offs) {
                    push(@$data, $curvals->{$key});
                }
            }
            $curd = $d;
            push(@xlabels, $d);
            $offs += 1;
        }
        $curvals->{$a} += $t;
        if (defined($r) && $r ne "") {
            $curvals->{$r} -= $t;
        }
    }
    # Store the last set
    foreach my $key (keys %$datasets) {
        my $data = $datasets->{$key};
        push(@$data, $curvals->{$key});
    }
    return (\@xlabels, $datasets);
}

sub bugs_over_time_per_product_per_status {
    my $dbh = Bugzilla->dbh;
    my @status = @{ $dbh->selectall_arrayref(qq{
SELECT value FROM bug_status;
}, { Slice => {} }) };
    my @products = @{ $dbh->selectall_arrayref(qq{
SELECT id, name FROM products ORDER BY id;
}, undef)};
my $query = q{
SELECT bdate, added, removed, count(bdate) AS amount
FROM   (
  SELECT bugs.creation_ts::date AS bdate, 'New'::varchar(255) AS added, NULL as removed
  FROM bugs WHERE bugs.product_id = ?
  UNION ALL
  SELECT bugs_activity.bug_when::date as bdate, bugs_activity.added, bugs_activity.removed
  FROM bugs_activity JOIN bugs ON (bugs_activity.bug_id = bugs.bug_id AND bugs.product_id = ?)
  WHERE fieldid = (SELECT id FROM fielddefs WHERE name = 'bug_status')
) AS data
GROUP BY bdate, added, removed
ORDER BY bdate, added, removed
};    

    foreach my $rec (@products) {
        my $id = @$rec[0];
        my $name = @$rec[1];
        my $bugs = $dbh->selectall_arrayref($query, undef, $id, $id);
    }
}

1;
