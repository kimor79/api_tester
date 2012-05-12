#!/usr/bin/perl
#
# This script is meant to run a test suite against an API built on api_producer.
# It does NOT do any setup of resources. All systems (database, webserver, etc)
# must be working first. This is just the functional test of the actual API.

use strict;
use warnings;

##
## Modules
##

use File::Basename;
use Getopt::Long;
use HTTP::Request;
use JSON::DWIW;
use LWP::UserAgent;
use Test::Deep;
use Test::More;

##
## Variables
##

Getopt::Long::Configure('bundling');

my $PROGNAME = basename($0);
my $REVISION = '1';

my $JSON;
our $TESTS;
my $TOTAL = 0;
my $UA;
our $UNIQUE = $PROGNAME . $$ . time();

##
## Subroutines
##

sub init {
# Purpose: Get command line opts, set things up, etc
# Inputs: None
# Output: None
# Return: None
# Exits: Possibly

	my $help;
	my $tests_file;

	my $result = GetOptions(
		'c|testsfile=s' => \$tests_file,
		'h|help|?' => \$help,
	) || BAIL_OUT(usage());

	BAIL_OUT(usage()) if($help);

	if(!$tests_file) {
		BAIL_OUT(usage());
	}

	note('Unique string is ' . $UNIQUE);

	$JSON = JSON::DWIW->new();
	$UA = LWP::UserAgent->new('agent' => $UNIQUE);

	parse_tests_file($tests_file);

	return;
}

sub parse_tests_file {
# Purpose: Parse the tests file and add to $TESTS
# Inputs: Tests file
# Outputs: Error if any
# Return: None
# Exits: Yes

	my $file = shift;

	my $return = do($file);

	if($@) {
		BAIL_OUT('Unable to parse ' . $file . ': ' . $@);
	}

	if(!defined($return)) {
		BAIL_OUT('Unable to parse ' . $file . ': ' . $!);
	}

	if(!$return) {
		BAIL_OUT('Unable to parse ' . $file);
	}
}

sub usage {
# Purpose: Print a usage statement
# Inputs: None
# Output: None
# Return: usage statement
# Exits: No

	my $usage = 'Usage: ' . $PROGNAME . ' [OPTIONS]' . "\n";
	$usage .= <<USAGE;

Options:
 -c file	The test spec file.
 -h		This help statement.
 -v		Increase verbosity. May be used multiple times.
USAGE

	return $usage;
}

##
## Main
##

init();

foreach my $test (@{$TESTS}) {
	my $requests = scalar(@{$test->{'request'}});
	my $responses = scalar(@{$test->{'response'}});

	$TOTAL += $requests * 5;

	next unless(is($requests, $responses,
		$test->{'description'} . ': requests != responses'));

	my $cur = 0;
	foreach my $request (@{$test->{'request'}}) {
		my $err;
		my $expected = $test->{'request'}->[$cur];
		my $got;
		my $json;
		my $req = HTTP::Request->new('POST' => $test->{'uri'});
		my $response;

		if($request->{'json'}) {
			($json, $err)  = $JSON->to_json($request->{'json'});
			unless(ok(!defined($err), $test->{'description'} .
					': request -> JSON')) {
				diag($err);
				$cur++;
				next;
			}

			$req->header('Content-Type' => 'application/json');
			$req->content($json);
		}

		$response = $UA->request($req);
		unless(ok(($response->is_success()), $test->{'description'} .
				': HTTP 2xx')) {
			diag($response->status_line());
			$cur++;
			next;
		}

		($got, $err) = $JSON->from_json($response->decoded_content());
		unless(ok(!defined($err), $test->{'description'} .
				': JSON response -> perl')) {
			diag($err);
			$cur++;
			next;
		}

		unless(cmp_deeply($got, $expected->{'body'},
				$test->{'description'} . ': body')) {
			$cur++;
			next;
		}

		$cur++;
	}
}

exit(done_testing($TOTAL));
