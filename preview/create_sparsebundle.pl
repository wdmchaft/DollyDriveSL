#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use Getopt::Long;

my $username = "";
my $size = "";
my $filepath = "";
my $macaddress = "";
my $machineuuid = "";

GetOptions(
	   "username=s" => \$username,
	   "size=s", => \$size,
	   "filepath=s" => \$filepath,
	   "macaddress=s" => \$macaddress,
	   "machineuuid=s" => \$machineuuid,
	  );

die "Need to supply --username ($username) --size ($size) --filepath ($filepath) --macaddress ($macaddress) and --machineuuid ($machineuuid)"
  if !$username || !$size || !$filepath || !$macaddress || !$machineuuid;

# being particularly careful with parameters since this script will be run as root

die "bad username ($username)"
  if $username !~ /^[a-zA-Z0-9]+$/;

die "bad size ($size)"
  if $size !~ /^[0-9]+[gm]$/;

die "filepath ($filepath) exists"
  if -f $filepath || -d $filepath;

die "enclosing directory does not exist for filepath ($filepath)"
  if !dirname($filepath);

die "bad filepath ($filepath)"
  if $filepath =~ /'/;

die "bad mac address ($macaddress)"
  if $macaddress !~ /^[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}$/;

die "bad machine uuid ($machineuuid)"
  if $machineuuid !~ /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/;

my $uid = `/usr/bin/id -u '$username'`;
chomp $uid;

die "id returned unexpected output ($uid) for username ($username)"
  if !$uid || $uid !~ /^\d+$/;

my $ret;

$ret = system("/usr/libexec/StartupItemContext /usr/bin/hdiutil create -size '$size' -type SPARSEBUNDLE -fs HFSX -layout none -uid '$uid' -gid 0 -volname 'Dolly Drive' $filepath");

die "hdiutil failed ($ret)"
  if $ret != 0;

$ret = system("chown -R '$username' '$filepath'");

die "unable to chwon sparsebundle '$filepath' to '$username' : $ret"
    if $ret != 0;

my $plist = <<EOP;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>VerificationDate</key>
        <date>2010-12-28T14:18:07Z</date>
        <key>VerificationExtendedSkip</key>
        <false/>
        <key>VerificationState</key>
        <integer>1</integer>
        <key>com.apple.backupd.BackupMachineAddress</key>
        <string>$macaddress</string>
        <key>com.apple.backupd.HostUUID</key>
        <string>$machineuuid</string>
</dict>
</plist>
EOP

my $plist_path = "$filepath/com.apple.TimeMachine.MachineID.plist";

if (open(my $fh, ">", $plist_path))
  {
    print $fh $plist;
  }
else
  {
    die "Unable to open plist file ($plist_path) : $!";
  }

$ret = system("chown '$username' '$plist_path'");
die "unable to chown '$username' '$plist_path' ($ret)"
  if $ret != 0;

$ret = system("chmod a-w '$filepath'/Info.*");
die "unable to chmod a-w '$filepath'/Info.*"
  if $ret != 0;

exit(0);
