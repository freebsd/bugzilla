#!/usr/local/bin/perl -w

use strict;
use warnings;
use Bugzilla;
use Bugzilla::Bug;
use Bugzilla::Constants;

my $count = $#ARGV + 1;
if ($count < 1) {
    print("usage: delete_bug.pl id1 id2 id3 ...\n");
    exit 1;
}

foreach my $id (@ARGV) {
    if ($id !~ /^\d+$/) {
        print("Argument '$id' is not a number\n");
        exit 1;
    }
}

foreach my $id (@ARGV) {
    print("Deleting bug $id...\n");
    my $bug = new Bugzilla::Bug($id);
    if ($bug->{error}) {
        my $err = $bug->{error};
        print("Error: $err\n");
    } else {
        $bug->remove_from_db();
    }
}
