#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use v5.10.0;
use File::Which;
use Getopt::Long;
use WWW::Mechanize;
use Config::Pit;
use Log::Minimal;

my $eqsl = pit_get("eqsl.cc", require => {
	"username" => "your username on eqsl",
	"password" => "your password on eqsl",
});

my $tqsl = pit_get("lotw.arrl.org", require => {
	"default_location" => "default location",
	"password" => "your password on LoTW"
});

my $coqso = pit_get("coqso.lab.lowreal.net", require => {
	"endpoint" => "endpoint of coqso",
});

# For Mac
$ENV{'PATH'} = "/Applications/tqsl.app/Contents/MacOS:$ENV{'PATH'}";

my $opts = {
	tqsl => which('tqsl'),
	location => $tqsl->{default_location},
	
	eqsl_account  => $eqsl->{username},
	eqsl_password => $eqsl->{password},

	lotw_password => $tqsl->{password},

	coqso_endpoint => $coqso->{endpoint},
};

GetOptions(
	"tqsl=s"   => \$opts->{tqsl},
	"location=s"   => \$opts->{location},
	"verbose"  => \$opts->{verbose},
);

my $adif = '/Users/cho45/Downloads/signalreports-20150101143319.adi'; # shift ;

sub upload_lotw {
	my ($opts, $adif) = @_;
	infof("Upload to LoTW...");
	my @cmd = (
		$opts->{tqsl},
		"--location=@{[ $opts->{location} ]}",
		# "--begindate='2015-01-01'",
		"--nodate",
		"--action=compliant",
		"--password=@{[ $opts->{lotw_password} ]}",
		"--batch",
		"--upload",
		$adif,
	);
	system(@cmd);
	infof("Done LoTW");
}

sub upload_eqsl {
	my ($opts, $adif) = @_;
	infof("Upload to eQSL");
	my $mech = WWW::Mechanize->new;
	$mech->get('http://www.eqsl.cc/qslcard/index.cfm');
	$mech->submit_form(
		with_fields => {
			'Callsign'        => $opts->{eqsl_account},
			'EnteredPassword' => $opts->{eqsl_password},
			'Login'           => 'Go',
		}
	);
	$mech->uri eq 'http://www.eqsl.cc/qslcard/LoginFinish.cfm' or die "failed to login";
	$mech->get('http://www.eqsl.cc/qslcard/enterADIF.cfm');

	$mech->submit_form(
		with_fields => {
			'Filename' => $adif,
			'AsyncMode' => 'TRUE',
		}
	);

	$mech->res->decoded_content =~ /Step #1 - Upload - Finished!/ or die "failed to upload";
	infof("Done eQSL");
}

sub upload_coqso {
	my ($opts, $adif) = @_;
	infof("Upload to COQSO");
	my $mech = WWW::Mechanize->new;
	my $res = $mech->post($opts->{coqso_endpoint},
		Content_Type => 'form-data',
		Content => [
			file => [$adif]
		],
	);
	$res->decoded_content =~ /200/ or die;
	infof("Done COQSO");
}

upload_lotw($opts, $adif);
upload_eqsl($opts, $adif);
upload_coqso($opts, $adif);

