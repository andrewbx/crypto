#!/usr/bin/env perl
#--------------------------------------------------------------------------
# Program     : soltool.pl
# Version     : v1.3-STABLE-2023-12-30
# Description : Check Solana Contract & Pools Health
# Syntax      : soltool.pl <option>
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

our $VERSION = 'v1.3-STABLE';
my $RELEASE = "solTOOL $VERSION";

my $PMP_POOL = 'https://pumpr.xyz/api';
my $PMP_DROP = 'https://pumr-drops-production.up.railway.app';

my $LWP_UA = 'Mozilla/5.0';
my $DEBUG  = 0;

@ARGV or help();

# Process Command Options.

{
    my ( %args, %opts );

    GetOptions(
        'o|output=s'   => \$opts{output},
        'm|mintable=i' => \$opts{mintable},
        'r|rugpull=i'  => \$opts{rugpull},
        'c|creator=i'  => \$opts{creator},
        's|symbol=i'   => \$opts{symbol},
        'l|lp=i'       => \$opts{lp},
        'drops'        => \$args{drops},
        'pools'        => \$args{pools},
        'debug'        => \$args{debug},
        'help'         => \$args{help},
        'version'      => \$args{version}
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

    if ( $args{drops} ) {
        process_api(
            \%opts,
            {   api     => $PMP_DROP,
                request => 'drops'
            }
        );
    }

    if ( $args{pools} ) {
        process_api(
            \%opts,
            {   api     => $PMP_POOL,
                request => 'getPools'
            }
        );
    }
}

# Output Help Menu.

sub help {
    printf( "
\033[1m$RELEASE\033[0m - Retrieve solana smart contract information.

\033[1mUsage:\033[0m
  --drops                       List new drops
  --pools   <-r|-m|-c|-s|-l>    List new liquidity pools

\033[1mOptions:\033[0m
  -o|output    <json|dumper>    Output format for API Query (Default=json)
  -r|rugpull   <1|0>            List pools with rugpull flag set/unset
  -m|mintable  <1|0>            List pools with mintable flag set/unset
  -c|creator   <1|0>            List pools with creator flag set/unset
  -s|symbol    <1|0>            List pools with symbol flag set/unset
  -l|lp        <no>             List pools with liquidity pool size > value
  --debug                       Enable verbose mode
  --help                        Print this help information
  --version                     Print version

" );

    exit;
}

# Setup the API Query.

sub process_api {
    my ( $opts, $argv ) = @_;

    my $env = query_api( $argv->{api}, "$argv->{request}" );

    push( my @a, @{ $env->{pools} } );

    if ( defined( $opts->{rugpull} ) ) {
        @a = grep { defined and ( $_->{rugPull} ) eq $opts->{rugpull} } @a;
    }

    if ( defined( $opts->{mintable} ) ) {
        @a = grep { defined and ( $_->{isMintable} ) eq $opts->{mintable} }
            @a;
    }

    if ( defined( $opts->{creator} ) ) {
        @a = grep {
            defined
                and ( $_->{isCreatorFlagged} ) eq $opts->{creator}
        } @a;
    }

    if ( defined( $opts->{symbol} ) ) {
        @a = grep { defined and ( $_->{isSymbolFlagged} ) eq $opts->{symbol} }
            @a;
    }

    if ( defined( $opts->{lp} ) ) {
        @a = grep { defined and int( $_->{lpBurn} ) >= int( $opts->{lp} ) }
            @a;
    }

    $env = \@a;

    if ( length($env) > 0 ) {
        output_api( $opts->{output}, $env );
    }
    else {
        print "\nNo results found.\n";
    }

    return;
}

sub process_table {
    my ($results) = @_;

    print
        "Date Created         Asset            TokenId                                       Total Supply                   LP Burn(%)   Mintable   RugPull    C. Flag    S. Flag    Name\n";
    print
        "------------         -----            -------                                       ------------                   ---------    --------   -------    -------    -------    ----\n";

    while ( my ( $i, $item ) = each( @{$results} ) ) {
        $item->{symbol} =~ s/^\s+//;

        my $f_isMintable = colour( { value => $item->{isMintable} } ) || q{};
        my $f_rugPull    = colour( { value => $item->{rugPull} } )    || q{};
        my $f_lpBurn     = colour( { value => $item->{lpBurn} } )     || q{};
        my $f_isCreatorFlagged
            = colour( { value => $item->{isCreatorFlagged} } ) || q{};
        my $f_isSymbolFlagged
            = colour( { value => $item->{isSymbolFlagged} } ) || q{};

        my $timestamp = strftime '%Y-%m-%d %H:%M:%S',
            ( localtime $item->{timeCreated} / 1000 );

        printf(
            "%-20s %-16s %-45s %-30s %-12.2f ${f_isMintable} ${f_rugPull} ${f_isCreatorFlagged} ${f_isSymbolFlagged} %-30s\n",
            $timestamp,               uc( $item->{symbol} ),
            $item->{tokenId},         comma( $item->{totalSupply} ),
            floor( $item->{lpBurn} ), $item->{isMintable},
            $item->{rugPull},         $item->{isCreatorFlagged},
            $item->{isSymbolFlagged}, $item->{name}
        );
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
        timeout       => $TIMEOUT,
        max_redirect  => 3
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
    elsif ( defined($output) and lc($output) eq 'table' ) {
        process_table($results);
    }
    else {
        my $json = JSON->new;
        print $json->pretty->encode($results);
    }

    return;
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
        $argv->{value} eq 1
        ? "\e[1;91m%-10s\e[0m"
        : "\e[1;92m%-10s\e[0m"
    );
}
