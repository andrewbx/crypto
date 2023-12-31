#!/usr/bin/env perl
#--------------------------------------------------------------------------
# Program     : soltool.pl
# Version     : v1.5-STABLE-2023-12-31
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

our $VERSION = 'v1.5-STABLE';
my $RELEASE = "solTOOL $VERSION";

my $PMP_POOL = 'https://pumpr.xyz/api';
my $PMP_DROP = 'https://pumr-drops-production.up.railway.app';

my $LWP_UA = 'Mozilla/5.0';
my $DEBUG  = 0;
my $EMOJIS
    = "[\x{1f300}-\x{1f5ff}\x{1f900}-\x{1f9ff}\x{1f600}-\x{1f64f}\x{1f680}-\x{1f6ff}\x{2600}-\x{26ff}\x{2700}-\x{27bf}\x{1f1e6}-\x{1f1ff}\x{1f191}-\x{1f251}\x{1f004}\x{1f0cf}\x{1f170}-\x{1f171}\x{1f17e}-\x{1f17f}\x{1f18e}\x{3030}\x{2b50}\x{2b55}\x{2934}-\x{2935}\x{2b05}-\x{2b07}\x{2b1b}-\x{2b1c}\x{3297}\x{3299}\x{303d}\x{00a9}\x{00ae}\x{2122}\x{23f3}\x{24c2}\x{23e9}-\x{23ef}\x{25b6}\x{23f8}-\x{23fa}]";

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
        $opts{output} = defined( $opts{output} ) ? $opts{output} : 'table';
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

    @a = reverse sort { $a->{timeCreated} <=> $b->{timeCreated} } @a;

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
    Readonly::Scalar my $TSOFFSET => 1000;

    print
        "Date Created         Asset            TokenId                                       Total Supply                   LP SOL        LP Burn    Mintable   RugPull    C. Flag    S. Flag    Name\n";
    print
        "------------         -----            -------                                       ------------                   ------        -------    --------   -------    -------    -------    ----\n";

    while ( my ( $i, $item ) = each( @{$results} ) ) {
        my $f_ismintable = colour( { value => $item->{isMintable} } ) || q{};
        my $f_rugpull    = colour( { value => $item->{rugPull} } )    || q{};
        my $f_lpburn     = colour( { value => $item->{lpBurn} } )     || q{};
        my $f_iscreatorflagged
            = colour( { value => $item->{isCreatorFlagged} } ) || q{};
        my $f_issymbolflagged
            = colour( { value => $item->{isSymbolFlagged} } ) || q{};

        my $timestamp = strftime '%Y-%m-%d %H:%M:%S',
            localtime( $item->{timeCreated} / $TSOFFSET );

        $item->{symbol} =~ s/${EMOJIS}//g;
        $item->{symbol} =~ s/^\s+//;

        $item->{name} =~ s/${EMOJIS}//g;
        $item->{name} =~ s/^\s+//;

        printf(
            "%-20s %-16s %-45s %-30s %-12s %7.2f%%    ${f_ismintable} ${f_rugpull} ${f_iscreatorflagged} ${f_issymbolflagged} %-30s\n",
            $timestamp,                uc( $item->{symbol} ),
            $item->{tokenId},          comma( $item->{totalSupply} ),
            $item->{amountOfQuote},    $item->{lpBurn},
            $item->{isMintable},       $item->{rugPull},
            $item->{isCreatorFlagged}, $item->{isSymbolFlagged},
            $item->{name}
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
        $argv->{value} eq q{1}
        ? "\e[1;91m%-10s\e[0m"
        : "\e[1;92m%-10s\e[0m"
    );
}
