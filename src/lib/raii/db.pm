package raii::db;

use utf8;
use strict;
use warnings;
local $" = ' ';

use Storable qw(fd_retrieve store);
use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Useqq = 1;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys = 1;

my $config_key = '__raii::db::config';

sub new
{
    my $class = shift;
    my $path = shift;

    my $db = _load($path);
    bless($db, $class)->_config({ path => $path });
}

sub DESTROY
{
    my $db = shift;
    return $db->_remove() if $db->_config('reset');
    $db->save();
    print "\n\e[1;37m---- DUMP ----\e[0m\n", $db, "\n" if $db->{debug};
}

sub save
{
    my $db = shift;
    store($db->_curse(), $db->_config('path'));
    $db;
}

sub reset
{
    my $db = shift;
    my $config = $db->_config();
    $config->{reset} = 1;
}

sub reload
{
    my $db = shift;
    my $config = $db->_config();
    %$db = %{ _load($db->_config('path')) };
    $db->_config($config);
}

use overload '""' => \&stringify;
sub stringify
{
    my $db = shift;
    Data::Dumper->Dump([ $db->_curse() ], [ qw(db) ]);
}

sub _load
{
    my $path = shift;
    open my $file, '<', $path or return {};
    fd_retrieve($file);
}

sub _curse
{
    my $db = shift;
    my $cursed = {%$db};
    delete $cursed->{$config_key};
    $cursed;
}

sub _config
{
    my $db = shift;
    my $key = shift;
    if (ref($key) eq 'HASH') {
        $db->{$config_key} = $key;
        return $db;
    }
    return $db->{$config_key}{$key} if $key;
    $db->{$config_key};
}

sub _remove
{
    my $db = shift;
    my $path = $db->_config('path');
    print "\e[0;34mdatabase \e[0;35m$path\e[0;34m is reset.\e[0m\n"
        if unlink $path;
}

