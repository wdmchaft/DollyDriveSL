use strict;
use warnings;

use Dancer;

use constant SHARED_SECRET => 'cb9abf74e1de6bc42ab83301b14fb318';
use constant CREATE_SCRIPT => 'sudo ' . $ENV{HOME} . '/preview/create_sparsebundle.pl ';
use constant SHARE_PARENT_GLOB => '/Volumes/DollyStore*/*';

set serializer => 'JSON';
set show_errors => 1;

post '/create_sparsebundle' => sub {
    # TODO: check remote IP
    my $username = params->{username};
    my $secret = params->{secret};
    my $share_name = params->{share_name};
    my $mac_address = params->{mac_address};
    my $host_uuid = params->{host_uuid};
    my $size_kb = params->{share_size};

    # need to check params carefully since they are placed into a sudo/root commandline
    return send_error({ success => JSON::false(), reason => "bad secret" }, 403)
      if !defined $secret || $secret ne SHARED_SECRET;

    return send_error({ success => JSON::false(), reason =>  "bad username ($username)" })
        if !defined $username || $username !~ /^[a-zA-Z0-9]+$/;

    return send_error({ success => JSON::false(), reason =>  "bad mac address ($mac_address)" })
        if !defined $mac_address || $mac_address !~ /^[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}$/;

    return send_error({ success => JSON::false(), reason =>  "bad host uuid ($host_uuid)" })
        if !defined $host_uuid || $host_uuid !~ /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/;

    return send_error({ success => JSON::false(), reason =>  "bad share_name ($share_name)" })
        if !defined $share_name || !$share_name || $share_name =~ /\.\./ || $share_name =~ m!/! || $share_name =~ /'/;

    return send_error({ success => JSON::false(), reason => "bad size ($size_kb)" })
      if !defined $size_kb || !$size_kb;

    my $size = ($size_kb / (1024 * 1024)) . 'g';

    my @share_paths = glob SHARE_PARENT_GLOB . "/$share_name";
    return send_error({ success => JSON::false(), reason => "Couldn't find any directory for share ($share_name)" })
      if !@share_paths;
    return send_error({ success => JSON::false(), reason => "Found more than one directory for share ($share_name)" })
      if @share_paths > 1;
    my $share_path = $share_paths[0];

    return send_error({ success => JSON::false(), reason => "Couldn't find directory for share ($share_name)" })
        if ! $share_path;

    my $sparsebundle_name = "${username}.sparsebundle";

    my $cmd = CREATE_SCRIPT . " --username '$username' --macaddress '$mac_address' --machineuuid '$host_uuid' --size '$size' --filepath '$share_path/$sparsebundle_name'";

    my $ret = system($cmd);

    return send_error({ success => JSON::false(), reason => "Error creating sparse bundle: $ret" })
        if $ret != 0;

    return { success => JSON::true() };
};

dance;
