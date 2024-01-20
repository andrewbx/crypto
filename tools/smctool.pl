#!/usr/bin/env perl
#--------------------------------------------------------------------------
# Program     : smctool.pl
# Version     : v1.20-STABLE-2024-01-20
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
use Readonly;
no warnings qw( experimental::smartmatch );

$Data::Dumper::Terse     = 1;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Useqq     = 1;
$Data::Dumper::Deparse   = 1;
$Data::Dumper::Quotekeys = 1;
$Data::Dumper::Sortkeys  = 0;

binmode( STDOUT, ':encoding(UTF-8)' );

our $VERSION = 'v1.20-STABLE';
my $RELEASE = "smcTOOL $VERSION";

my $GPL_URL = 'https://api.gopluslabs.io/api/v1';
my $CGO_URL = 'https://api.coingecko.com/api/v3';
my $CAP_URL = 'https://api.coincap.io/v2';
my $DEX_URL = 'https://api.dexscreener.com/latest/dex';
my $LWP_UA  = 'Mozilla/5.0';
my $DEBUG   = 0;

@ARGV or help();

# Process Command Options.

{
    my ( %args, %opts );

    GetOptions(
        'o|output=s'        => \$opts{output},
        'c|cid=i'           => \$opts{cid},
        'a|address=s'       => \$opts{address},
        'i|api=s'           => \$opts{api},
        'm|mcap=i'          => \$opts{mcap},
        'n|no=n'            => \$opts{no},
        's|symbol=s'        => \$opts{symbol},
        'p|percent=i'       => \$opts{percent},
        't|ticker=s'        => \$opts{ticker},
        'query_api=s'       => \$args{query_api},
        'token_security'    => \$args{token_security},
        'approval_security' => \$args{approval_security},
        'rugpull_detect'    => \$args{rugpull_detect},
        'nft_security'      => \$args{nft_security},
        'address_security'  => \$args{address_security},
        'top_crypto'        => \$args{top_crypto},
        'debug'             => \$args{debug},
        'help'              => \$args{help},
        'version'           => \$args{version}
    ) or help();

    if ( $args{debug} ) {
        $DEBUG = 1;
    }

    if ( $args{help} ) {
        exit help();
    }

    if ( $args{version} ) {
        print "$RELEASE\n";
        exit;
    }

    if ( $opts{api} and $opts{api} !~ m/^cgo|gpl|cap|dex$/i ) {
        print "API endpoint invalid\n";
        exit help();
    }

    if (    $opts{api}
        and $opts{api} =~ m/^cgo|gpl|cap|dex$/i
        and not $args{query_api} )
    {
        print "API request expected\n";
        exit help();
    }

    if ( $args{query_api} and $opts{api} ) {
        my $API_URL = q{};
        given ( $opts{api} ) {
            when ('gpl') { $API_URL = $GPL_URL; }
            when ('cgo') { $API_URL = $CGO_URL; }
            when ('cap') { $API_URL = $CAP_URL; }
            when ('dex') { $API_URL = $DEX_URL; }
            default      { $API_URL = $CGO_URL; }
        }
        process_api(
            \%opts,
            {   api     => $API_URL,
                request => $args{query_api}
            }
        );
    }

    if ( $args{token_security} ) {
        process_api(
            \%opts,
            {   api     => $GPL_URL,
                request => 'token_security'
            }
        );
    }

    if ( $args{approval_security} ) {
        process_api(
            \%opts,
            {   api     => $GPL_URL,
                request => 'approval_security'
            }
        );
    }

    if ( $args{rugpull_detect} ) {
        process_api(
            \%opts,
            {   api     => $GPL_URL,
                request => 'rugpull_detecting'
            }
        );
    }

    if ( $args{nft_security} ) {
        process_api(
            \%opts,
            {   api     => $GPL_URL,
                request => 'nft_security'
            }
        );
    }

    if ( $args{address_security} ) {
        process_api(
            \%opts,
            {   api     => $GPL_URL,
                request => 'address_security'
            }
        );
    }

    if ( $args{top_crypto} ) {
        get_top_crypto(
            \%opts,
            {   api     => $CGO_URL,
                request => 'top_crypto'
            }
        );
    }
}

# Output Help Menu.

sub help {
    printf( "
\033[1m$RELEASE\033[0m - Retrieve blockchain smart contract information.

\033[1mUsage:\033[0m
  --token_security     <-c|--cid -a|--address>  List smart contract attributes
  --approval_security  <-c|--cid -a|--address>  List attributes to identify malicious behaviour
  --rugpull_detect     <-c|--cid -a|--address>  List attributes to identify rug pull behaviour
  --nft_security       <-c|--cid -a|--address>  List attributes configured for NFTs
  --address_security   <-c|--cid -a|--address>  Check for malicious address
  --top_crypto         <-n|--num -s|--symbol>   Get top cryptoassets by market cap
  --query_api          <request>                Run an API query against an endpoint

\033[1mOptions:\033[0m
  -o|output   <json|dumper>         Output format for API Query (Default=json)
  -c|cid      <chain id>            Blockchain ID
  -a|address  <blockhain address>   Smart Contract or Holder address
  -i|api      <cgo|gpl|cap|dex>     API Endpoint (gpl=GoPlusLabs, cgo=Coin Gecko, cap=Coin Cap, dex=DEX Screener)
  -m|mcap     <1|0>                 Show market cap summary (1=yes, 0=no)
  -n|num      <items>               Number of items to display for top cryptoassets
  -s|symbol   <currency>            Denonimated currency
  -t|ticker   <ticker>              Crypto ticker symbol
  -p|percent  <24hr percentage>     Filter results by percentage value
  --debug                           Enable verbose mode
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

    if ( not $opts->{cid} or not $opts->{address} ) {
        print "Blockchain ID and Smart Contract address expected\n";
        exit help();
    }

    $opts->{address} = lc( $opts->{address} );
    my $env = query_api( $argv->{api},
        "$argv->{request}/$opts->{cid}?contract_addresses=$opts->{address}" );

    if ( $env->{result} ) {
        $argv->{request} eq 'token_security'
            ? output_api( $opts->{output},
            $env->{result}->{ $opts->{address} } )
            : output_api( $opts->{output}, $env->{result} );
    }
    else {
        print "\nNo results found.\n";
    }

    return;
}

# Run API Query through LWP.

sub query_api {
    my ( $url, $argv ) = @_;
    Readonly::Scalar my $TIMEOUT => 15;

    my $ua = LWP::UserAgent->new(
        agent             => $LWP_UA,
        protocols_allowed => ['https'],
        ssl_opts          => {
            verify_hostname => 0,
            SSL_verify_mode => 0
        },
        show_progress => $DEBUG,
        timeout       => $TIMEOUT
    );

    my $r = $ua->get(
        "$url/$argv",
        'Accept'        => '*/*',
        'Cache-Control' => 'no-cache',
    );

    if ( not $r->is_success ) {
        die 'Error with API query: ' . $r->status_line;
    }

    return decode_json( $r->decoded_content() );
}

# Output API Results.
# Formats: JSON/Dumper

sub output_api {
    my ( $output, $results ) = @_;

    if ( defined($output) and lc($output) eq 'dumper' ) {
        print Dumper($results);
    }
    else {
        my $json = JSON->new;
        print $json->pretty->encode($results);
    }

    return;
}

# Get top cryptoassets by market cap.

sub get_top_crypto {
    my ( $opts, $argv ) = @_;

    if ( $argv->{request} ne 'top_crypto' ) {
        return;
    }

    my $symbol = 'usd';
    my $order  = 'market_cap_desc';
    Readonly::Scalar my $ITEMS  => 10;
    Readonly::Scalar my $OFFSET => 0.01;
    Readonly::Scalar my $MAXRPP => 250;
    Readonly::Scalar my $SLEEP  => 1;

    if ( not $opts->{no} ) {
        $opts->{no} = $ITEMS;
    }

    if ( not $opts->{symbol} ) {
        $opts->{symbol} = $symbol;
    }

    my $env      = q{};
    my $per_page = $opts->{no};
    my $delay    = 0;

    if ( $opts->{no} > $MAXRPP ) {
        $per_page = $MAXRPP;
        $delay    = $SLEEP;
    }

    my $page_count = $opts->{no} / $per_page;
    my $remainder  = $opts->{no} % $per_page ? $page_count++ : $page_count;

    my @a = ();

    for my $i ( 1 .. $page_count ) {
        local $a = query_api( $argv->{api},
                  "coins/markets?vs_currency=$opts->{symbol}&order=$order"
                . "&per_page=$per_page&page=$i&sparkline=false"
                . '&price_change_percentage=1h%2C24h%2C7d' );
        if ( $DEBUG or $page_count > 1 ) {
            printf( "[+] Parsing results page %d/%d (delay=%ds)\n",
                $i, $page_count, $delay );
        }
        push( @a, @{$a} );
        sleep $delay;
    }

    if ( defined( $opts->{ticker} ) ) {
        @a = grep {
            defined
                and lc( $_->{symbol} ) eq ( lc( $opts->{ticker} ) )
        } @a;
    }

    if ( defined( $opts->{percent} ) ) {
        @a = grep {
            defined
                and $_->{price_change_percentage_24h_in_currency}
                >= int( $opts->{percent} )
        } @a;
    }

    $env = \@a;

    if ( length($env) <= 1 ) {
        return;
    }

    if ( defined( $opts->{output} ) ) {
        output_api( $opts->{output}, \@{$env} );
        return;
    }

    if ( $opts->{mcap} ) {
        print_mcap_summary($opts);
    }

    my $localtime = localtime();

    if ( defined( $opts->{percent} ) ) {
        printf(
            "\nTop %d Cryptoassets (by 24hr percentage >= %s%%) in %s ($localtime)\n\n",
            $opts->{no},
            int( $opts->{percent} ),
            uc( $opts->{symbol} )
        );
    }
    elsif ( defined( $opts->{ticker} ) ) {
        printf(
            "\nCryptoasset search for %s in %s ($localtime)\n\n",
            uc( $opts->{ticker} ),
            uc( $opts->{symbol} )
        );
    }
    else {
        printf(
            "\nTop %d Cryptoassets (by market cap) in %s ($localtime)\n\n",
            $opts->{no}, uc( $opts->{symbol} ) );
    }

    print
        "No     Asset      Price          Market Cap           Circ Supply              Total Supply             1hr C(%)    24hr C(%)   7d C(%)     ATH            ATH C(%)\n";
    print
        "--     -----      -----          ----------           -----------              ------------             --------    ---------   -------     ---            --------\n";

    while ( my ( $i, $item ) = each( @{$env} ) ) {
        return
            if ( $i >= $opts->{no} );

        $i++;

        my $m_cap    = $item->{market_cap}         || 0;
        my $c_supply = $item->{circulating_supply} || 0;
        my $t_supply = $item->{total_supply}       || 0;

        my $c_ath   = $item->{ath}                   || 0;
        my $p_ath_c = $item->{ath_change_percentage} || 0;

        my $p_1hr  = $item->{price_change_percentage_1h_in_currency}  || 0;
        my $p_24hr = $item->{price_change_percentage_24h_in_currency} || 0;
        my $p_7d   = $item->{price_change_percentage_7d_in_currency}  || 0;

        my $c_price = $item->{current_price} || 0;

        my $f_price = $c_price < $OFFSET ? '%-14.6f' : '%-14.2f';
        my $f_ath   = $c_ath < $OFFSET   ? '%-14.6f' : '%-14.2f';

        my $f_1hr   = colour( { value => $p_1hr } )   || q{};
        my $f_24hr  = colour( { value => $p_24hr } )  || q{};
        my $f_7d    = colour( { value => $p_7d } )    || q{};
        my $f_ath_c = colour( { value => $p_ath_c } ) || q{};

        printf(
            "%-6d %-10s ${f_price} %-20s %-24s %-24s ${f_1hr} ${f_24hr} ${f_7d} ${f_ath} ${f_ath_c}\n",
            $item->{market_cap_rank},
            uc( $item->{symbol} ),
            $c_price,
            comma( int($m_cap) )    || q{N/A},
            comma( int($c_supply) ) || q{N/A},
            comma( int($t_supply) ) || q{N/A},
            $p_1hr,
            $p_24hr,
            $p_7d,
            $c_ath,
            $p_ath_c
        );
    }

    return;
}

# Print market cap summary.

sub print_mcap_summary {
    my ($argv) = @_;

    return
        if ( not $argv );

    my ( $tmc, $btc_mc, $btc_d ) = get_mcap_summary(
        {   id     => 'bitcoin',
            symbol => $argv->{symbol},
            api    => $CGO_URL
        }
    );

    if ( length($tmc) > 1 ) {
        printf(
            "Total Market Cap (%s): %s\n",
            uc( $argv->{symbol} ),
            comma($tmc)
        );
        printf(
            "Bitcoin Market Cap (%s): %s\n",
            uc( $argv->{symbol} ),
            comma($btc_mc)
        );
        printf(
            "Altcoin Market Cap (%s): %s\n",
            uc( $argv->{symbol} ),
            comma( $tmc - $btc_mc )
        );
        printf( "Bitcoin Dominance : \e[1;97m%.3f%%\e[0m\n", $btc_d );
    }

    return;
}

# Get market cap summary.

sub get_mcap_summary {
    my ($argv) = @_;

    return 0
        if ( not $argv );

    my $symbol         = lc( $argv->{symbol} );
    my $btc_market_cap = get_mc(
        { api => $argv->{api}, id => $argv->{id}, symbol => $symbol } );
    my $total_market_cap
        = get_tmc( { api => $argv->{api}, symbol => $symbol } );

    return ( floor($total_market_cap),
        floor($btc_market_cap),
        get_cd( { cmc => $btc_market_cap, tmc => $total_market_cap } ) );
}

# Get total market cap.

sub get_tmc {
    my ($argv) = @_;

    return 0
        if ( not $argv );

    my $symbol = lc( $argv->{symbol} );
    my $tmc    = query_api( $argv->{api}, 'global' );

    return ( $tmc->{data}->{total_market_cap}->{$symbol} );
}

# Get market cap.

sub get_mc {
    my ($argv) = @_;

    return 0
        if ( not $argv );

    my $symbol = lc( $argv->{symbol} );
    my $mc     = query_api( $argv->{api}, "coins/$argv->{id}" );

    return ( $mc->{market_data}->{market_cap}->{$symbol} );
}

# Get coin dominance.

sub get_cd {
    my ($argv) = @_;

    return 0
        if ( not $argv );

    return ( $argv->{cmc} / $argv->{tmc} );
}

# Add formatting to price.

sub comma {
    my ($argv) = @_;

    return 0
        if ( not $argv );

    return (
        scalar
            reverse( reverse($argv) =~ s/(\d\d\d)(?=\d)(?!\d*[.])/$1,/gr ) );
}

# Price highlighting.

sub colour {
    my ($argv) = @_;

    return
        if ( not $argv );

    return (
        $argv->{value} < 0
        ? "\e[1;91m%-11.2f\e[0m"
        : "\e[1;92m%-11.2f\e[0m"
    );
}
