use strict;
use warnings;

use lib '/home/trigger/perl5/lib/perl5/amd64-openbsd';
use lib '/home/trigger/perl5/lib/perl5';

use constant AUTHORIZED_KEYS_PATH => '/home/trigger/.ssh/authorized_keys';
use constant SECRET => 'd1fa091afdffb5f45ddf8eb372bef385';

use File::Copy;
use LockFile::Simple;
use Dancer;

my %server_command_map = (
        'private-beta' => 'nc 10.1.5.115 548',
        'DollyTest01' => 'nc 10.1.5.115 548',
        'Dolly01' => 'nc 10.2.8.170 548',
        'Dolly02' => 'nc 10.2.8.170 548',
        'Dolly09' => 'nc 10.1.5.116 548',
        'Dolly0001' => 'nc 10.2.8.56 548',
        'Dolly0002' => 'nc 10.2.8.56 548',
        'Dolly0003' => 'nc 10.2.8.56 548',
        'Dolly0004' => 'nc 10.2.8.56 548',
        'Dolly0005' => 'nc 10.2.8.56 548',
        'Dolly0006' => 'nc 10.2.8.56 548',
        'Dolly0007' => 'nc 10.2.8.56 548',
        'Dolly0008' => 'nc 10.2.8.56 548',
        'Dolly0009' => 'nc 10.2.8.56 548',
        'Dolly0010' => 'nc 10.2.8.56 548',
        'Dolly0011' => 'nc 10.2.8.56 548',
        'Dolly0012' => 'nc 10.2.8.56 548',
        'Dolly0013' => 'nc 10.2.8.56 548',
        'Dolly0014' => 'nc 10.2.8.56 548',
        'Dolly0015' => 'nc 10.2.8.56 548',
        'Dolly0016' => 'nc 10.2.8.56 548',
        'Dolly0017' => 'nc 10.2.8.56 548',
        'Dolly0018' => 'nc 10.2.8.56 548',
        'Dolly0019' => 'nc 10.2.8.56 548',
        'Dolly0020' => 'nc 10.2.8.56 548',
        'Dolly0021' => 'nc 10.2.8.56 548',
        'Dolly0022' => 'nc 10.2.8.56 548',
        'Dolly0023' => 'nc 10.2.8.56 548',
        'Dolly0024' => 'nc 10.2.8.56 548',
        'Dolly0025' => 'nc 10.2.8.56 548',
        'Dolly0026' => 'nc 10.2.8.56 548',
        'Dolly0027' => 'nc 10.2.8.56 548',
        'Dolly0028' => 'nc 10.2.8.56 548',
        'Dolly0029' => 'nc 10.2.8.56 548',
        'Dolly0030' => 'nc 10.2.8.56 548',
        'Dolly0031' => 'nc 10.2.8.56 548',
        'Dolly0032' => 'nc 10.2.8.56 548',
        'Dolly0033' => 'nc 10.2.8.56 548',
        'Dolly0034' => 'nc 10.2.8.56 548',
        'Dolly0035' => 'nc 10.2.8.56 548',
        'Dolly0036' => 'nc 10.2.8.56 548',
        'Dolly0037' => 'nc 10.2.8.56 548',
        'Dolly0038' => 'nc 10.2.8.56 548',
        'Dolly0039' => 'nc 10.2.8.56 548',
        'Dolly0040' => 'nc 10.2.8.56 548',
        'Dolly0041' => 'nc 10.2.8.56 548',
        'Dolly0042' => 'nc 10.2.8.56 548',
        'Dolly0043' => 'nc 10.2.8.56 548',
        'Dolly0044' => 'nc 10.2.8.56 548',
        'Dolly0045' => 'nc 10.2.8.56 548',
        'Dolly0046' => 'nc 10.2.8.56 548',
        'Dolly0047' => 'nc 10.2.8.56 548',
        'Dolly0048' => 'nc 10.2.8.56 548',
        'Dolly0049' => 'nc 10.2.8.56 548',
        'Dolly0050' => 'nc 10.2.8.56 548',
        'Dolly0051' => 'nc 10.2.8.56 548',
        'Dolly0052' => 'nc 10.2.8.56 548',
        'Dolly0053' => 'nc 10.2.8.56 548',
        'Dolly0054' => 'nc 10.2.8.56 548',
        'Dolly0055' => 'nc 10.2.8.56 548',
        'Dolly0056' => 'nc 10.2.8.56 548',
        'Dolly0057' => 'nc 10.2.8.56 548',
        'Dolly0058' => 'nc 10.2.8.56 548',
        'Dolly0059' => 'nc 10.2.8.56 548',
        'Dolly0060' => 'nc 10.2.8.56 548',
        'Dolly0061' => 'nc 10.2.8.56 548',
        'Dolly0062' => 'nc 10.2.8.56 548',
        'Dolly0063' => 'nc 10.2.8.56 548',
        'Dolly0064' => 'nc 10.2.8.56 548',
        'Dolly0065' => 'nc 10.2.8.56 548',
        'Dolly0066' => 'nc 10.2.8.56 548',
        'Dolly0067' => 'nc 10.2.8.56 548',
        'Dolly0068' => 'nc 10.2.8.56 548',
        'Dolly0069' => 'nc 10.2.8.56 548',
        'Dolly0070' => 'nc 10.2.8.56 548',
        'Dolly0071' => 'nc 10.2.8.56 548',
        'Dolly0072' => 'nc 10.2.8.56 548',
        'Dolly0073' => 'nc 10.2.8.56 548',
        'Dolly0074' => 'nc 10.2.8.56 548',
        'Dolly0075' => 'nc 10.2.8.56 548',
        'Dolly0076' => 'nc 10.2.8.56 548',
        'Dolly0077' => 'nc 10.2.8.56 548',
        'Dolly0078' => 'nc 10.2.8.56 548',
        'Dolly0079' => 'nc 10.2.8.56 548',
        'Dolly0080' => 'nc 10.2.8.56 548',
        'Dolly0081' => 'nc 10.2.8.56 548',
        'Dolly0082' => 'nc 10.2.8.56 548',
        'Dolly0083' => 'nc 10.2.8.56 548',
        'Dolly0084' => 'nc 10.2.8.56 548',
        'Dolly0085' => 'nc 10.2.8.56 548',
        'Dolly0086' => 'nc 10.2.8.56 548',
        'Dolly0087' => 'nc 10.2.8.56 548',
        'Dolly0088' => 'nc 10.2.8.56 548',
        'Dolly0089' => 'nc 10.2.8.56 548',
        'Dolly0090' => 'nc 10.2.8.56 548',
        'Dolly0091' => 'nc 10.2.8.56 548',
        'Dolly0092' => 'nc 10.2.8.56 548',
        'Dolly0093' => 'nc 10.2.8.56 548',
        'Dolly0094' => 'nc 10.2.8.56 548',
        'Dolly0095' => 'nc 10.2.8.56 548',
        'Dolly0096' => 'nc 10.2.8.56 548',
        'Dolly0097' => 'nc 10.2.8.56 548',
        'Dolly0098' => 'nc 10.2.8.56 548',
        'Dolly0099' => 'nc 10.2.8.56 548',
        'Dolly0100' => 'nc 10.2.8.56 548',
        'Dolly0101' => 'nc 10.2.8.56 548',
        'Dolly0102' => 'nc 10.2.8.56 548',
        'Dolly0103' => 'nc 10.2.8.56 548',
        'Dolly0104' => 'nc 10.2.8.56 548',
        'Dolly0105' => 'nc 10.2.8.56 548',
        'Dolly0106' => 'nc 10.2.8.56 548',
        'Dolly0107' => 'nc 10.2.8.56 548',
        'Dolly0108' => 'nc 10.2.8.56 548',
        'Dolly0109' => 'nc 10.2.8.56 548',
        'Dolly0110' => 'nc 10.2.8.56 548',
        'Dolly0111' => 'nc 10.2.8.56 548',
        'Dolly0112' => 'nc 10.2.8.56 548',
        'Dolly0113' => 'nc 10.2.8.56 548',
        'Dolly0114' => 'nc 10.2.8.56 548',
        'Dolly0115' => 'nc 10.2.8.56 548',
        'Dolly0116' => 'nc 10.2.8.56 548',
        'Dolly0117' => 'nc 10.2.8.56 548',
        'Dolly0118' => 'nc 10.2.8.56 548',
        'Dolly0119' => 'nc 10.2.8.56 548',
        'Dolly0120' => 'nc 10.2.8.56 548',
        'Dolly0121' => 'nc 10.2.8.56 548',
        'Dolly0122' => 'nc 10.2.8.56 548',
        'Dolly0123' => 'nc 10.2.8.56 548',
        'Dolly0124' => 'nc 10.2.8.56 548',
        'Dolly0125' => 'nc 10.2.8.56 548',
        'Dolly0126' => 'nc 10.2.8.56 548',
        'Dolly0127' => 'nc 10.2.8.56 548',
        'Dolly0128' => 'nc 10.2.8.56 548',
        'Dolly0129' => 'nc 10.2.8.56 548',
        'Dolly0130' => 'nc 10.2.8.56 548',
        'Dolly0131' => 'nc 10.2.8.56 548',
        'Dolly0132' => 'nc 10.2.8.56 548',
);

sub update_authorized_keys {
	my ($nc_string, $key, $email) = @_;

	my @in;
	{
		open (my $fh, AUTHORIZED_KEYS_PATH)
			or return "ERROR: $!";

		@in = <$fh>;
	}

	chomp @in;

	my $entry = "command=\"$nc_string\",no-X11-forwarding,no-agent-forwarding,no-port-forwarding $key";
	chomp $entry;

	my @user_key = grep { / $email$/ } @in;

	if (@user_key == 1 && $user_key[0] eq $entry)
	{
		return "OK";
	}

	warn "replacing key for $email" if (@user_key == 1);
	warn "removing multiple keys for $email" if (@user_key > 1);
	warn "inserting new key for $email" if (!@user_key);

	my @out = grep { ! / $email$/ } @in;

	push @out, $entry;

	my $tempfile = AUTHORIZED_KEYS_PATH . ".$$";

	{
		open (my $fh, "> $tempfile")
			or return "ERROR: $!";

		print $fh "$_\n" for @out;

		close($fh)
			or return "ERROR: $!";
	}

	copy(AUTHORIZED_KEYS_PATH, AUTHORIZED_KEYS_PATH . ".bak.$$")
		or return "ERROR: $!";

	rename($tempfile, AUTHORIZED_KEYS_PATH)
		or return "ERROR: $!";

	return "OK";
}

post '/register_key' => sub {
	my $share_name = params->{advn};
	my $key = params->{key};
	my $email = params->{email};
	my $nc_string = $server_command_map{$share_name};
	my $secret = params->{secret};

	if (!$nc_string)
	{
		return "ERROR: no nc entry for advn '$share_name'";
	}

	if (!$key || !$email || $secret ne SECRET)
	{
		return "ERROR: param error";
	}

    my $lockmgr = LockFile::Simple->make(
        autoclean => 1,
        delay => 1,
        max => 5,
        hold => 10,
        stale => 1,
        warn => 0,
    );

    my $lock = $lockmgr->lock(AUTHORIZED_KEYS_PATH);

    my $ret;
    if ($lock)
    {
        $ret = eval { update_authorized_keys($nc_string, $key, $email) };
        $ret = $@ if $@;
        $lock->release;
    }
    else
    {
        $ret = "Unable to lock keys file";
    }
    
	return $ret;
};

dance;


