package options;
# command line arguments

use utf8;
use strict;
use warnings;
local $" = ' ';

use database;

my %available = (
    'help|h' => "Display this help and exit right away.",
    'reset|r' => "Reset the database and exit, removing all the history cache and settings."
                . " The database file F<$database::db_path> will be removed.",
    'debug|d+' => "Enable debugging."
                . " Will reset files (i.e. clear cache) when debug options changed from last time.",
    'output|o=s' => "Set default output file for B<current> source.",
    'prefix|p=s' => "Set build file prefix.",
    'no-execute|x' => "Do not execute the built binary.",
    'clean|c+' => "Clean the built."
                . " B<Level 1> cleans all the object files;"
                . " B<Level 2> skips no file;"
                . " B<Level 3> removes the linked binary as well.",
    'lines|n=i' => "Catch error message and show only first n lines.",
    'output-from-trigger|t+' => "Deduce default output filename from triggers (i.e. F<source-file>)."
                . " Repeat I<n> times to use the I<n>th trigger.",
    'show-command|C' => "Show the compiling command and linking command.",
    'show-dirty|D' => "Show which file is dirty. Dirty files are going to be rebuilt.",
    'shared-library|s' => "B<TODO:> Link to shared object/library instead of executable.",
    'project|P' => "B<FIXME:> Not very clear what I should do with this.",
);

sub parse
{
    use Getopt::Long qw(:config gnu_getopt);

    my $opts = {};
    GetOptions($opts, keys %available) or die "\e[0;31mbad options: \e[1;31muse \e[0;33m-h\e[1;31m to show help.\e[0m\n";
    help() if $opts->{help};
    $opts;
}

sub help
{
    my $exit_code = shift || 0;

    my @lines;
    push @lines, "=head1 NAME";
    push @lines, "";
    push @lines, "C<makeless>: config-free C++ build system";
    push @lines, "";
    push @lines, "=head1 SYNOPSIS";
    push @lines, "";
    push @lines, "B<makeless> [I<OPTIONS>] [F<source-file> [...]]";
    push @lines, "";
    push @lines, "B<ml> [I<OPTIONS>] [F<source-file> [...]]";
    push @lines, "";
    push @lines, "=head1 OPTIONS";
    push @lines, "";
    push @lines, "=over";
    push @lines, "";
    for my $k (sort keys %available) {
        my $item = $k;
        for ($item) {
            s{\|}{ | -};
            s{\+$}{, B<multiple leveled>};
            s{=s$}{ I<string>} and s{ \|}{=I<string>$&};
            s{=i$}{ I<integer>} and s{ \|}{=I<integer>$&};
        }
        push @lines, "=item --$item";
        push @lines, "";
        push @lines, $available{$k};
        push @lines, "";
    }
    push @lines, "=back";
    push @lines, "";
    push @lines, "=head1 EXAMPLES";
    push @lines, "";
    push @lines, "=over";
    push @lines, "";
    push @lines, "=item B<ml> F<source.cc>";
    push @lines, "";
    push @lines, "Build F<source.cc> to F</tmp/makeless-build> (default output filename) and execute it.";
    push @lines, "";
    push @lines, "=item B<ml> I<-t> F<source.cc>";
    push @lines, "";
    push @lines, "Build F<source.cc> to F<source> (output filename deduced from the 1st trigger, a.k.a. F<source-file>, i.e. F<source.cc>) and execute it.";
    push @lines, "";
    push @lines, "=item B<ml> I<-x> F<source.cc>";
    push @lines, "";
    push @lines, "Build F<source.cc> to F</tmp/makeless-build> but do not execute it.";
    push @lines, "";
    push @lines, "=item B<ml> I<-tx> F<source.cc>";
    push @lines, "";
    push @lines, "Build F<source.cc> to F<source> but do not execute it.";
    push @lines, "";
    push @lines, "=item B<ml> I<-cccr>";
    push @lines, "";
    push @lines, "Clean everything up. Removes all object files, linked binaries/targets and makeless database F<$database::db_path>.";
    push @lines, "";
    push @lines, "=back";
    push @lines, "";

    use Pod::Text::Color;
    my $p = Pod::Text::Color->new();
    $p->parse_lines(@lines, undef);

    exit $exit_code;
}

