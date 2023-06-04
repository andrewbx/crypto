#!/usr/bin/env perl
#--------------------------------------------------------------------------
# Program     : smctool.pl
# Version     : v1.0-STABLE-2023-06-04
# Description : Check Blockchain Smart Contract Health
# Syntax      : smctool.pl <option>
# Author      : Andrew (andrew@devnull.uk)
#--------------------------------------------------------------------------

use strict;
use warnings;
use JSON qw(encode_json decode_json);
use LWP::UserAgent;
use MIME::Base64;
use Getopt::Long qw/:config no_ignore_case/;
use Data::Dumper;
use POSIX;

$Data::Dumper::Terse     = 1;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Useqq     = 1;
$Data::Dumper::Deparse   = 1;
$Data::Dumper::Quotekeys = 1;
$Data::Dumper::Sortkeys  = 0;

binmode( STDOUT, ":encoding(UTF-8)" );

my $VERSION = "v1.0-STABLE";
my $RELEASE = "smcTOOL $VERSION";
my $API_URL = "https://api.gopluslabs.io/api/v1";

@ARGV or help();

# Process Command Options.

{
    my ( %args, %opts );

    GetOptions(
        'o|output=s'        => \$opts{output},
        'c|cid=i'           => \$opts{cid},
        'a|address=s'       => \$opts{address},
        'token_security'    => \$args{token_security},
        'approval_security' => \$args{approval_security},
        'rugpull_detect'    => \$args{rugpull_detect},
        'nft_security'      => \$args{nft_security},
        'address_security'  => \$args{address_security},
        'help'              => \$args{help},
        'version'           => \$args{version}
    ) or help();

    if ( $args{help} ) {
        exit help();
    }

    if ( $args{version} ) {
        exit print("$RELEASE\n");
    }

    if ( $args{token_security} ) {
        process_api( \%opts, { request => q{token_security} } );
    }

    if ( $args{approval_security} ) {
        process_api( \%opts, { request => q{approval_security} } );
    }

    if ( $args{rugpull_detect} ) {
        process_api( \%opts, { request => q{rugpull_detecting} } );
    }

    if ( $args{nft_security} ) {
        process_api( \%opts, { request => q{nft_security} } );
    }

    if ( $args{address_security} ) {
        process_api( \%opts, { request => q{address_security} } );
    }
}

# Output Help Menu.

sub help {
    $0 =~ s{.*/}{};
    printf( "
\033[1m$RELEASE\033[0m - Retrieve blockchain smart contract information.

\033[1mUsage:\033[0m
  --token_security	-c|--cid -a|--address	<List smart contract attributes>
  --approval_security	-c|--cid -a|--address	<List attributes to identify malicious behaviour>
  --rugpull_detect	-c|--cid -a|--address	<List attributes to identify rug pull behaviour>
  --nft_security	-c|--cid -a|--address	<List attributes configured for NFT's>
  --address_security	-c|--cid -a|--address	<Check for malicious address>

\033[1mOptions:\033[0m
  -o|output	<json|dumper>		Output format for API Query. (Default=json)
  -c|cid	<chain id>		Blockchain ID.
  -a|address	<blockhain address>	Smart Contract or Holder address.
  --help				Print this help information.
  --version				Print version.

\033[1mReferences:\033[0m

API Documentation - https://docs.gopluslabs.io/reference/

" );

    exit;
}

# Setup the API Query.

sub process_api {
    my ( $opts, $argv ) = @_;

    if ( !$opts->{cid} or !$opts->{address} ) {
        print "Blockchain ID and Smart Contract address expected\n";
        exit help();
    }

    my $env = query_api( $API_URL, qq{$argv->{request}/$opts->{cid}?contract_addresses=$opts->{address}}
    );

    if ( $env->{result} ) {
        output_api( $opts->{output}, $env );
    }
    else {
        print "\nNo results found.\n";
        exit;
    }
}

# Run API Query through LWP.

sub query_api {
    my ( $url, $argv ) = @_;

    my $ua = LWP::UserAgent->new(
        ssl_opts      => { verify_hostname => 0, SSL_verify_mode => 0x00 },
        show_progress => 0
    );

    my $res = $ua->get( "$url/$argv", );

    unless ( $res->is_success ) {
        exit;
    }

    my $json = decode_json( $res->decoded_content() );
    return $json;
}

# Output API Results.
# Formats: JSON/Dumper

sub output_api {
    my ( $output, $results ) = @_;

    if ( defined($output) and lc($output) eq q{json} ) {
        print Dumper($results);
    }
    else {
        my $json = JSON->new;
        print $json->pretty->encode($results);
    }
}
