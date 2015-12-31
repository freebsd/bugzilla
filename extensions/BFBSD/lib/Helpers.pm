package Bugzilla::Extension::BFBSD::Helpers;

use strict;
use Bugzilla;
use Bugzilla::User;

use base qw(Exporter);

our @EXPORT = qw(
    no_maintainer get_user ports_product ports_component
    switch_to_automation
    get_maintainers_of_bug _get_maintainer

    UID_AUTOMATION
    PRODUCT_PORTS
    COMPONENT_PORTS
    PORTSDIR
    INDEX
    PORT_CAT_LIST
);

use constant {
    UID_AUTOMATION => "bugzilla\@FreeBSD.org",
    PRODUCT_PORTS => "Ports & Packages",
    COMPONENT_PORTS => "Individual Port(s)",

#XXX Mokhi added inorder to avoid duplicated codes :)
    PORTSDIR => "/usr/ports-dev",
    INDEX => "INDEX",
    PORT_CAT_LIST => "accessibility|arabic|archivers|astro|audio|benchmarks|biology|cad|chinese|comms|converters|databases|deskutils|devel|distfiles|dns|editors|emulators|finance|french|ftp|games|german|graphics|hebrew|hungarian|irc|japanese|java|korean|lang|mail|math|misc|multimedia|net|net\-im|net\-mgmt|net\-p2p|news|packages|palm|polish|ports\-mgmt|portuguese|print|russian|science|security|shells|sysutils|textproc|ukrainian|vietnamese|www|x11|x11\-clocks|x11\-drivers|x11\-fm|x11\-fonts|x11\-servers|x11\-themes|x11\-toolkits|x11\-wm",
};

sub ports_product {
    return PRODUCT_PORTS
}

sub ports_component {
    return COMPONENT_PORTS
}

sub no_maintainer {
    my $maintainer = shift();
    if (lc($maintainer) eq "ports\@freebsd.org") {
        return 1;
    }
    return 0;
}

sub get_user {
    my ($name, $enabledonly) = @_;
    my $uid = login_to_id($name);
    if (!$uid) {
        warn("No user found for $name");
        return;
    }
    my $user = new Bugzilla::User($uid);
    if ($enabledonly) {
        if (!$user->is_enabled) {
            warn("Found user $name is not enabled in Bugzilla");
            return;
        }
    }
    return $user;
}

sub switch_to_automation {
    # Switch the user session
    my $autoid = login_to_id(UID_AUTOMATION);
    if (!$autoid) {
        warn("Automation user does not exist");
        return;
    }
    my $curuser = Bugzilla->user;
    Bugzilla->set_user(new Bugzilla::User($autoid));
    return $curuser;
};

#XXX Mokhi added inorder to avoid duplicated codes :)
sub get_maintainers_of_bug {
	my ($bug) = @_;

	my @foundports = ();

	# Is it a port in summary matching ([A-Za-z0-9_-]/[A-Za-z0-9_-])?
	#my @res = ($bug->short_desc =~ /(?:^|[:\[\s+])([\w-]+\/[\w-\.]+)(?:[:\]\s+]|$)/g);
	my @res = ($bug->short_desc =~ /(?:^|\W)((${\(PORT_CAT_LIST)})\/([\w\-\+](\.(?=\w))*)+)(?:$|\b)*/g);
	if (@res && scalar(@res) > 0) {
		# warn("Found ports in summary: @res");
		push(@foundports, @res);
	}

	if (scalar(@foundports) == 0) {
		# Did not find a port in subject
		# Is it a port in the description matching
		#  ([A-Za-z0-9_-]/[A-Za-z0-9_-])?
		my $first = $bug->comments->[0]->body;
		#@res = ($first =~ /(?:^|[:,\s+])([\w-]+\/[\w-\.]+)(?:[:,\s+]|$)/g);
		@res = ($first =~ /(?:^|\W)((${\(PORT_CAT_LIST)})\/([\w\-\+](\.(?=\w))*)+)(?:$|\b)*/g);
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
	foreach my $port (@foundports) {
		my $maintainer = _get_maintainer($port);
		if ($maintainer) {
			push(@maintainers, $maintainer);
		}
	}

	# Remove duplicate entries
	%hashed = map{$_, 1} @maintainers;
	@maintainers = keys(%hashed);

	return @maintainers;
}

#XXX Mokhi added inorder to avoid duplicated codes :)
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


1;
