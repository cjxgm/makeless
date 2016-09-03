package settings;
# magic comment in source code and headers that can alter the
# flags of compiler and/or linker

use utf8;
use strict;
use warnings;
local $" = ' ';

sub parse
{
    my ($path, $symbol, @keys) = @_;
    my %result = map { $_ => [] } @keys;

    open my $file, '<', $path or die "\e[0;31m$path: \e[1;31mfailed to read settings: \e[0;31m$!\e[0m\n";
    for (<$file>) {
        next unless m{//\s+ml:(\w+)\s*\Q$symbol\E\s*(.*)};

        die "\e[0;31m$path: \e[1;31msetting \e[0;33m$1\e[1;31m is not one of (\e[0;33m"
            . join(' ', @keys)
            . "\e[1;31m).\e[0m\n"
            unless exists $result{$1};

        @{$result{$1}} = @{_split_escaped($2)};
    }
    \%result;
}

sub merge
{
    my ($dst, $src) = @_;

    if (defined $src) { @{$dst->{$_}}{@{$src->{$_}}} = undef for keys %$src }
    else { $_ = [ _array_from_set($_) ] for values %$dst }
    $dst;
}

sub _split_escaped
{
    local $_ = shift;
    local @_;
    push @_, $& while $_ =~ m{(\\.|[^\\\s])+}g;
    s{\\(.)}{$1}g for @_;
    \@_;
}

sub _array_from_set
{
    sort keys %{$_[0]};
}

