package database;
# hold an instance of raii::db, and provides various query functions.

use utf8;
use strict;
use warnings;
local $" = ' ';

use raii::db;
use settings;
use makeless;
use file;

our $db;
our $db_path = ".makeless.db";

my $defaults = {
    debug => 0, # 0: no; 1: dump database; 2: 1 with base64 digest
    files => {},
    depss => {},
    dirty => {},
    dirty_bin => {},
    targets => {},
    cc => "clang++",
};

sub guard
{
    $db = raii::db->new($db_path);
    &default();
    bless {}, shift;
}

sub DESTROY { undef $db }

sub default
{
    my $db = shift || $database::db;
    my $dvals = shift || $defaults;
    for (keys %$dvals) {
        $db->{$_} = $dvals->{$_} unless exists $db->{$_};
        &default($db->{$_}, $dvals->{$_}) if ref($db->{$_}) eq 'HASH'
    }
    $db;
}

sub reset { $db->reset() }
sub reset_files { $db->{files} = {} }
sub reset_dirty { $db->{dirty} = {} }

sub update_file
{
    my $npath = shift;
    die "is your brain made out of water?" if -d $npath;

    if (-e $npath) {
        my $ss = settings::parse($npath, '+=', qw(lib ccf ldf));
        my $lib = $ss->{lib};
        if (@$lib) {
            push @{$ss->{ccf}}, makeless::pkg_config('cflags', @$lib);
            push @{$ss->{ldf}}, makeless::pkg_config(  'libs', @$lib);
        }
        delete $ss->{lib};

        $db->{files}{$npath} = {
            digest => file::digest($npath),
            modified_time => file::modified_time($npath),
            settings => $ss,
        };
    }
    else { delete $db->{files}{$npath} }
}

sub update_deps
{
    my $npath = shift;
    die "is your brain made out of water?" if -d $npath;
    $db->{depss}{$npath} = _dependencies($npath);
}

sub update_target
{
    my $npath = $_[0];
    my $key = _stringify_objects(@_);
    die "is your brain made out of water?" if -d $npath;

    if (-e $npath) {
        $db->{targets}{$key} = {
            digest => file::digest($npath),
            modified_time => file::modified_time($npath),
            path => $npath,
        };
    }
    else { delete $db->{targets}{$key} }
}

sub target_modified
{
    my $key = _stringify_objects(@_);
    return 1 unless exists $db->{targets}{$key};

    my $target = $db->{targets}{$key};
    return file_modified($target->{path}, $target);
}

sub file_modified
{
    my $npath = shift;
    my $info = shift;

    # file not exist is considered modified
    return 1 unless -e $npath;

    unless ($info) {
        # file is assumed to be modified if not recorded in the db.
        # this is for the "first-time" situation.
        return 1 unless exists $db->{files}{$npath};
        $info = $db->{files}{$npath};
    }

    # definitely not modified if modified_time unchanged.
    my $time = $info->{modified_time} || 0;
    my $ftime = file::modified_time($npath);
    return 0 if $ftime == $time;

    # definitely modified if digest changed.
    # TODO: ignore spaces?
    my $digest = $info->{digest} || '';
    my $fdigest = file::digest($npath);
    return 1 if $fdigest ne $digest;

    # assume not modified.
    # TODO: file content comparison to avoid hash collision?
    #       md5 is pretty good hash function,
    #       so assume collision won't happen for now.
    0;
}

sub mark_dirty
{
    my $npath = shift || return;
    my $pending = shift || {};
    my $dirty = $db->{dirty};

    return $pending if exists $pending->{$npath};
    $pending->{$npath} = undef;

    delete $dirty->{$npath};

    # header
    if (file::is_header($npath)) {
        return unless file_modified($npath);
        update_file($npath);
        $dirty->{$npath} = undef;
        return;
    }

    # source
    if (file_modified($npath)) {
        update_file($npath);
        update_deps($npath);
        $dirty->{$npath} = undef;
    }

    # object
    # TODO: better logic on this?
    my $obj = file::source_to_object($npath);
    if (file_modified($obj)) {
        update_file($obj);
        $dirty->{$npath} = undef;
    }

    # dependencies
    for my $dep (@{$db->{depss}{$npath}}) {
        # header
        mark_dirty($dep, $pending);
        $dirty->{$npath} = undef if exists $dirty->{$dep};

        # source
        my $sources = file::header_to_source($dep);
        mark_dirty($_, $pending) for @$sources;
    }

    $pending;
}

sub build_dirty
{
    my $show_cmd = shift;
    my $nline = shift;
    my $dirty = $db->{dirty};
    for (@_) {
        next unless exists $dirty->{$_};

        # header
        if (file::is_header($_)) {
            delete $dirty->{$_};
            next;
        }

        # source -> object
        my $obj = makeless::compile($show_cmd, $nline, $_);
        update_file($obj);
        delete $dirty->{$_};
    }
}

# fetch dependencies from compiler
sub _dependencies
{
    my $path = shift;
    my $cc = $db->{cc};
    my @args = (@{$db->{basic_flags}}, '-MM', $path);

    use IPC::Open2;
    my $pid = open2(my $out, undef, $cc, @args);
    my @deps;
    for (<$out>) {
        chomp;
        s{\s*\\\s*$}{}g;
        while ($_ =~ m{(\\.|[^\\\s])+}g) {
            my $path = $&;
            $path =~ s{\\(.)}{$1}g;
            push @deps, file::normalize_path($path);
        }
    }
    waitpid $pid, 0;
    die "\e[0;31m$path: \e[1;31mcannot obtain dependencies.\e[0m\n" if $?;
    @deps = @deps[2 .. $#deps];
    return \@deps;
}

sub _stringify_objects
{
    join(' ', map { s{[\\ ]}{\\$&}g; $_ } @_);
}

