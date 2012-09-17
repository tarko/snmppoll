#!/usr/bin/perl

# tarko@lanparty.ee
#
# TODO:
# gnuplottable output
# make sleep interval configurable
# rewrite in ruby ;)
#

$| = 1;

use strict;
use Net::SNMP;

my $sysuptime = "1.3.6.1.2.1.1.3.0";
my $ifName = "1.3.6.1.2.1.31.1.1.1.1";
my $ifAlias = "1.3.6.1.2.1.31.1.1.1.18";
my $sysName = "1.3.6.1.2.1.1.5.0";
my $ifInOctets = "1.3.6.1.2.1.31.1.1.1.6";
my $ifOutOctets = "1.3.6.1.2.1.31.1.1.1.10";

my $ifindex;
my $fieldformat = "%-15.15s";

# --------------------------------------------------------------------
# -- init ------------------------------------------------------------
# --------------------------------------------------------------------

if(!defined($ARGV[0]) || !defined($ARGV[1])) {
	print STDERR "usage: grapher.pl <hostname> <community>\n";
	exit -1;
}

my $node = $ARGV[0];
my $community = $ARGV[1];

# --------------------------------------------------------------------
# -- setup and test snmp connectivity --------------------------------
# --------------------------------------------------------------------

(my $session, my $error) = Net::SNMP->session(-hostname => $node, -version => 2, -community => $community, -translate => 0);

# DNS lookup failed
if($error) {
	print STDERR "SNMP session create failure for $node\n";
	exit -1;
}

my $sysname = $session->get_request(varbindlist => [$sysName]);

if(!defined($sysname)) {
	print STDERR "timeout connecting node $node\n";
	exit -1;
}

# --------------------------------------------------------------------
# -- fetch and display all interfaces --------------------------------
# --------------------------------------------------------------------

my $allinterfaces = $session->get_table(baseoid => $ifName);
my $allaliases = $session->get_table(baseoid => $ifAlias);

print STDERR "Interfaces found: \n";

foreach my $oid (sort { &get_ifIndex($a) <=> &get_ifIndex($b) } keys %$allinterfaces) {
	$ifindex = &get_ifIndex($oid);
	printf STDERR "%-5s %-15s %s\n", $ifindex, $$allinterfaces{$oid}, $$allaliases{$ifAlias . "." . $ifindex};
}

# --------------------------------------------------------------------
# -- handle user prompt ----------------------------------------------
# --------------------------------------------------------------------

print STDERR "\nEnter ifindexes to monitor, separated by whitespace: ";
my $userinput = <STDIN>;
chop($userinput);
my @userifs = split(/\s+/, $userinput);

my (@descroids, @ifs);

foreach $ifindex (@userifs) {
	if($$allinterfaces{$ifName . "." . $ifindex}) {
		push(@descroids, $ifName . "." . $ifindex);
		push(@ifs, $ifindex);
	}
}

if(scalar @ifs == 0) {
	print STDERR "No valid ifindexes entered\n";
	exit -1;
}

# --------------------------------------------------------------------
# -- prepare ifName cache and print header --------------------------
# --------------------------------------------------------------------

my $ifnames = $session->get_request(-varbindlist => \@descroids);

print STDERR printtime();

foreach $ifindex (@ifs) {
	printf STDERR $fieldformat, $ifnames->{$ifName . "." . $ifindex} . "-in";
	printf STDERR $fieldformat, $ifnames->{$ifName . "." . $ifindex} . "-out";
}

print STDERR "\n";

# --------------------------------------------------------------------
# -- prepare collector cache -----------------------------------------
# --------------------------------------------------------------------

my @oids;

push(@oids, $sysuptime);

foreach $ifindex (@ifs) {
	push(@oids, "$ifInOctets" . "." . $ifindex);
	push(@oids, "$ifOutOctets" . "." . $ifindex);
}

# --------------------------------------------------------------------
# -- mainloop --------------------------------------------------------
# --------------------------------------------------------------------

# display maximums at exit
$SIG{INT} = \&shutdown;

my ($result, $oldresult, $qtime);
my ($INoctets, $OUToctets, $INoldoctets, $OUToldoctets);
my ($INrate, $OUTrate);
my (%maxIN, %maxOUT);

for(;;) { 

	$result = $session->get_request(-varbindlist => \@oids);

	if(defined($oldresult)) {

		$qtime = ($result->{$sysuptime} - $oldresult->{$sysuptime}) / 100;

		print printtime();

		foreach $ifindex (@ifs) {

			$INoctets = $result->{$ifInOctets . "." . $ifindex};
			$INoldoctets = $oldresult->{$ifInOctets . "." . $ifindex};

			if($INoctets < $INoldoctets) {
				$INrate = "+" . int(((2**64)-$INoldoctets+$INoctets)/$qtime*8);
			} else {
				$INrate = int(($INoctets-$INoldoctets)/$qtime*8);
			}

			$OUToctets = $result->{$ifOutOctets . "." . $ifindex};
			$OUToldoctets = $oldresult->{$ifOutOctets . "." . $ifindex};

			if($OUToctets < $OUToldoctets) {
				$OUTrate = "+" . int(((2**64)-$OUToldoctets+$OUToctets)/$qtime*8);
			} else {
				$OUTrate = int(($OUToctets-$OUToldoctets)/$qtime*8);
			}

			if($INrate > $maxIN{$ifindex}) { $maxIN{$ifindex} = $INrate; }
			if($OUTrate > $maxOUT{$ifindex}) { $maxOUT{$ifindex} = $OUTrate; }

			printf $fieldformat, &thousands($INrate);
			printf $fieldformat, &thousands($OUTrate);
	
		}

		print "\n";
	}

	$oldresult = $result;

	sleep 5;

}

# we should never reach this point :)
$session->close;
exit;

sub shutdown {
	&stats;
	$session->close;
	exit;
}

sub printtime {
	my $ts = time();
	return "$ts ";
}

sub stats {

	print STDERR "\n\nMaximum values recorded:\n";

	foreach $ifindex (@ifs) {
		printf STDERR $fieldformat, $ifnames->{$ifName . "." . $ifindex} . "-in";
		printf STDERR $fieldformat, $ifnames->{$ifName . "." . $ifindex} . "-out";
	}

	print STDERR "\n";

	foreach $ifindex (@ifs) {
		printf STDERR $fieldformat, &thousands($maxIN{$ifindex});
		printf STDERR $fieldformat, &thousands($maxOUT{$ifindex});
	}
	
	print STDERR "\n";
	
}

sub thousands {
	my $num = shift;
	$num =~ s/(?<=\d)(?=(?:\d\d\d)+\b)/ /g;
	return $num;
}

sub get_ifIndex {
	my $oid = shift;
	my @parts = split(/\./, $oid);
	return $parts[-1];
}

