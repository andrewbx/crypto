#!/usr/bin/env perl
#--------------------------------------------------------------------------
# Program     : smctool.pl
# Version     : v1.6-STABLE-2023-10-16
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
use feature qw( switch );
no warnings qw( experimental::smartmatch );

$Data::Dumper::Terse     = 1;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Useqq     = 1;
$Data::Dumper::Deparse   = 1;
$Data::Dumper::Quotekeys = 1;
$Data::Dumper::Sortkeys  = 0;

binmode( STDOUT, ":encoding(UTF-8)" );

my $VERSION = "v1.6-STABLE";
my $RELEASE = "smcTOOL $VERSION";
my $GPL_URL = "https://api.gopluslabs.io/api/v1";
my $CGO_URL = "https://api.coingecko.com/api/v3";
my $CAP_URL = "https://api.coincap.io/v2";
my $DEX_URL = "https://api.dexscreener.com/latest/dex";
my $LWP_UA  = "Mozilla/5.0";
my $TIMEOUT = 15;

@ARGV or help();

# Process Command Options.

{
    my ( %args, %opts );

    GetOptions(
        'o|output=s'        => \$opts{output},
        'c|cid=i'           => \$opts{cid},
        'a|address=s'       => \$opts{address},
        'i|api=s'           => \$opts{api},
        'n|no=n'            => \$opts{no},
        's|symbol=s'        => \$opts{symbol},
        'query_api=s'       => \$args{query_api},
        'token_security'    => \$args{token_security},
        'approval_security' => \$args{approval_security},
        'rugpull_detect'    => \$args{rugpull_detect},
        'nft_security'      => \$args{nft_security},
        'address_security'  => \$args{address_security},
        'top_crypto'        => \$args{top_crypto},
        'help'              => \$args{help},
        'version'           => \$args{version}
    ) or help();

    if ( $args{help} ) {
        exit help();
    }

    if ( $args{version} ) {
        exit print("$RELEASE\n");
    }

    if ( $opts{api} and $opts{api} !~ m/^(cgo|gpl|cap|dex)$/i ) {
        print "API endpoint invalid\n";
        exit help();
    }

    if (    $opts{api}
        and $opts{api} =~ m/^(cgo|gpl|cap|dex)$/i
        and !$args{query_api} )
    {
        print "API request expected\n";
        exit help();
    }

    if ( $args{query_api} and $opts{api} ) {
        my $API_URL = q{};
        given ( $opts{api} ) {
            when ("gpl") { $API_URL = $GPL_URL; }
            when ("cgo") { $API_URL = $CGO_URL; }
            when ("cap") { $API_URL = $CAP_URL; }
            when ("dex") { $API_URL = $DEX_URL; }
            default      { $API_URL = $CGO_URL; }
        }
        process_api( \%opts, { api => $API_URL, request => $args{query_api} } );
    }

    if ( $args{token_security} ) {
        process_api( \%opts,
            { api => $GPL_URL, request => q{token_security} } );
    }

    if ( $args{approval_security} ) {
        process_api( \%opts,
            { api => $GPL_URL, request => q{approval_security} } );
    }

    if ( $args{rugpull_detect} ) {
        process_api( \%opts,
            { api => $GPL_URL, request => q{rugpull_detecting} } );
    }

    if ( $args{nft_security} ) {
        process_api( \%opts, { api => $GPL_URL, request => q{nft_security} } );
    }

    if ( $args{address_security} ) {
        process_api( \%opts,
            { api => $GPL_URL, request => q{address_security} } );
    }

    if ( $args{top_crypto} ) {
        query_top_crypto( \%opts,
            { api => $CGO_URL, request => q{top_crypto} } );
    }
}

# Output Help Menu.

sub help {
    $0 =~ s{.*/}{};
    printf( "
\033[1m$RELEASE\033[0m - Retrieve blockchain smart contract information.

\033[1mUsage:\033[0m
  --token_security     <-c|--cid -a|--address>  List smart contract attributes
  --approval_security  <-c|--cid -a|--address>  List attributes to identify malicious behaviour
  --rugpull_detect     <-c|--cid -a|--address>  List attributes to identify rug pull behaviour
  --nft_security       <-c|--cid -a|--address>  List attributes configured for NFTs
  --address_security   <-c|--cid -a|--address>  Check for malicious address
  --top_crypto         <-n|--no> -s|--symbol>   Get top cryptoassets by market cap
  --query_api          <request>                Run an API query against an endpoint

\033[1mOptions:\033[0m
  -o|output   <json|dumper>         Output format for API Query (Default=json)
  -c|cid      <chain id>            Blockchain ID
  -a|address  <blockhain address>   Smart Contract or Holder address
  -i|api      <cgo|gpl|cap|dex>     API Endpoint (gpl=GoPlusLabs, cgo=Coin Gecko, cap=Coin Cap, dex=DEX Screener)
  -n|no       <items>               Number of items to display for top cryptoassets
  -s|symbol   <ticker>              Currency symbol
  --help                            Print this help information
  --version                         Print version

\033[1mReferences:\033[0m

GoPlusLabs API Documentation   - https://docs.gopluslabs.io/reference/
Coin Gecko API Documentation   - https://www.coingecko.com/en/api/documentation
Coin Cap API Documentation     - https://docs.coincap.io/
DEX Screener API Documentation - https://docs.dexscreener.com/api/reference

" );

    exit;
}

# Setup the API Query.

sub process_api {
    my ( $opts, $argv ) = @_;

    if ( $opts->{api} ) {
        my $env = query_api( $argv->{api}, $argv->{request} );
        if ( length($env) > 0 ) {
            output_api( $opts->{output}, $env );
        }
        return;
    }

    if ( !$opts->{cid} or !$opts->{address} ) {
        print "Blockchain ID and Smart Contract address expected\n";
        exit help();
    }

    $opts->{address} = lc( $opts->{address} );
    my $env = query_api( $argv->{api},
        "$argv->{request}/$opts->{cid}?contract_addresses=$opts->{address}" );

    if ( $env->{result} ) {
        $argv->{request} eq q{token_security}
          ? output_api( $opts->{output}, $env->{result}->{ $opts->{address} } )
          : output_api( $opts->{output}, $env->{result} );
    }
    else {
        print "\nNo results found.\n";
        return;
    }
}

# Run API Query through LWP.

sub query_api {
    my ( $url, $argv ) = @_;

    my $ua = LWP::UserAgent->new(
        agent             => $LWP_UA,
        protocols_allowed => ['https'],
        ssl_opts          => { verify_hostname => 0, SSL_verify_mode => 0 },
        show_progress     => 1,
        timeout           => $TIMEOUT
    );

    my $r = $ua->get(
        "$url/$argv",
        "Accept"        => "*/*",
        "Cache-Control" => "no-cache",
    );

    unless ( $r->is_success ) {
        die "Error with API query: " . $r->status_line;
    }

    return decode_json( $r->decoded_content() );
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

# Get top cryptoassets by market cap.

sub query_top_crypto {
    my ( $opts, $argv ) = @_;

    if ( $argv->{request} eq q{top_crypto} ) {
        my $symbol = q{usd};
        my $order  = q{market_cap_desc};
        my $items  = 10;

        if ( !$opts->{no} ) {
            $opts->{no} = $items;
        }

        if ( !$opts->{symbol} ) {
            $opts->{symbol} = $symbol;
        }

        my $env = query_api( $argv->{api},
                "coins/markets?vs_currency=$opts->{symbol}&order=$order"
              . "&per_page=$opts->{no}&page=1&sparkline=false" );

        if ( length($env) > 0 ) {
            printf( "\nTop %d Cryptoassets (by market cap) in %s\n\n",
                $opts->{no}, uc( $opts->{symbol} ) );
            printf(
                "Asset      Price          Market Cap           24hr Change\n");
            printf(
                "-----      -----          ----------           -----------\n");

            foreach my $item (@$env) {
                my $f = $item->{current_price} < 0.1 ? q{.6f} : q{.2f};
                printf(
                    "%-10s %-14${f} %-20s %.2f%%\n",
                    uc( $item->{symbol} ),
                    $item->{current_price},
                    scalar reverse(
                        reverse( $item->{market_cap} ) =~
                          s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/gr
                    ),
                    $item->{price_change_percentage_24h}
                );
            }
        }
    }
}
