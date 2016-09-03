package entry;

use utf8;
use strict;
use warnings;
local $" = ' ';

use options;
use database;
use makeless;
use file;

# COMMON ABBREVIATIONS
#
# npath    normalized path
# db       database instance
#

sub entry
{
    my $options = options::parse();
    my $db_guard = database->guard();
    my $db = $database::db;

    # clean up
    makeless::clean($options->{clean}) if $options->{clean};

    # process options
    if ($options->{reset}) {
        database::reset();
        exit;
    }
    my $opt_debug = $options->{debug} || 0;
    if ($db->{debug} != $opt_debug) {
        database::reset_files();
        $db->{debug} = $opt_debug;
    }
    exit if $options->{clean};

    # process input files
    my @files;
    if (@ARGV) {
        @files = map { file::normalize_path($_) } @ARGV;
        $db->{triggers} = \@files;
    }
    die "\e[0;31mno triggers: \e[1;31msource-file is required on first run.\e[0m\n"
        unless exists $db->{triggers};

    # setup default prefix
    $db->{prefix} = $options->{prefix} if $options->{prefix};
    unless ($db->{prefix}) {
        my $prefix = "/tmp/build";
        $prefix .= ".tmp" while -e $prefix && not -d $prefix;
        $db->{prefix} = $prefix;
    }
    file::mkdir_or_die($db->{prefix});
    $db->{prefix} = file::normalize_path($db->{prefix});

    # setup output path
    my $default_output = '/tmp/makeless-build';
    if (defined $options->{"output-from-trigger"}) {
        my $t = $options->{"output-from-trigger"} - 1;
        my $triggers = $db->{triggers};
        my $nt = $#$triggers;
        die "\e[0;31m$t > $nt: \e[1;31mno enough triggers.\e[0m\n" if $t > $nt;
        my $p = file::source_to_binary($triggers->[$t]);
        die "WTF?" unless $p;
        $default_output = $p;
    }
    my $output = file::normalize_path($options->{output} || $default_output);
    $output .= '.bin' while -d $output;

    makeless::build($output,
        $options->{'no-execute'},
        $options->{'show-command'},
        $options->{'show-dirty'},
        $options->{'lines'} || 0);
}

