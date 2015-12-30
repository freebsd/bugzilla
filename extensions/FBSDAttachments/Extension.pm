package Bugzilla::Extension::FBSDAttachments;

use strict;
use warnings;

use base qw(Bugzilla::Extension);

use Bugzilla::Comment;
use Bugzilla::Field;
use Bugzilla::FlagType;
use Bugzilla::Flag;
use Bugzilla::Mailer;
use Bugzilla::User;
use Bugzilla::Attachment;

use Bugzilla::Extension::BFBSD::Helpers;

our $VERSION = '0.3.0';

sub attachment_process_data {
	my ($self, $args) = @_;
	my $data = $args->{'data'}; # XXX Maybe not needed
	my $attrs = $args->{'attributes'};
	my $dbh = Bugzilla->dbh; # XXX Maybe not needed

	my $bug = $attrs->{'bug'};
	my $attacher = Bugzilla->user;
	my $is_patch = $attrs->{'ispatch'};

	# We only add CCs, if it is a individual port bug
	return if ( (!defined($bug) || !defined($attacher)) || ($bug->product ne PRODUCT_PORTS || $bug->component ne COMPONENT_PORTS) );

	my @maintainers = get_maintainers_of_bug($bug);

	if (defined($is_patch) && $is_patch) {
		my $flag_approval;
		my $flagtypes = Bugzilla::FlagType::match( { name => 'maintainer-approval' } );
		if (scalar(@$flagtypes) == 1) {
			$flag_approval = @{$flagtypes}[0];
		}
		if (!$flag_approval) {
			warn("maintainer-approval flag not found");
		} else {
			my (@oldflags, @newflags);

			#XXX maybe "$_->id == $attacher->id" is better for cmp
			if (grep($_ == $attacher->login, @maintainers)) {
				push(@newflags, { type_id   => $flag_approval->id, status	=> "+", requestee => $attacher->login });
				$bug->set_flags(\@oldflags, \@newflags);
			} else {
				push(@newflags, { type_id   => $flag_approval->id, status	=> "?", requestee => @maintainers });
				$bug->set_flags(\@oldflags, \@newflags);
			}
		}
	}

}

__PACKAGE__->NAME;
