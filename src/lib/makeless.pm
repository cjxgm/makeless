package makeless;
# everything about directing a build.
# build, compile, link, and execute.

use utf8;
use strict;
use warnings;
local $" = ' ';

use database;
use settings;
use file;

sub build
{
    my ($output, $no_exec, $show_cmd, $show_dirty, $nline) = @_;
    my $triggers = $database::db->{triggers};
    my $dirty = $database::db->{dirty};
    my $dirty_bin = $database::db->{dirty_bin};

    my @basic_flags;
    my @tmp_triggers;
    my $cmd;
    {
        my $ss = settings::parse($triggers->[0], '=', qw(std opt run trg inc));

        my $nstd = @{$ss->{std}};
        die "\e[0;31m$nstd > 1: \e[1;31mthere can only be at most one standard.\e[0m\n"
            if $nstd > 1;
        my $std = $ss->{std}[0];
        $std = 'c++14' unless defined $std;

        my $nopt = @{$ss->{opt}};
        die "\e[0;31m$nopt > 1: \e[1;31mthere can only be at most one optimizing level.\e[0m\n"
            if $nopt > 1;
        my $opt = $ss->{opt}[0];
        $opt = '3' unless defined $opt;

        @tmp_triggers = map { file::normalize_path($_) } @{$ss->{trg}};
        @basic_flags = (
            "-fcolor-diagnostics",
            "-std=$std",
            "-O$opt",
            map { ("-isystem", $_) } @{$ss->{inc}},
        );
        $database::db->{basic_flags} = \@basic_flags;

        $cmd = join(' ', @{$ss->{run}}) || "\$bin";
    }

    my $merge_array = sub { sort keys %{{ map { $_ => undef } @_ }} };

    # find all dirty files
    # dirty status of all sources and headers
    my %pending;
    @pending{keys %{database::mark_dirty($_, \%pending)}} = ()
        for $merge_array->(@$triggers, @tmp_triggers);
    my @files = sort keys %pending;
    my $bin_dirty = %$dirty;

    {
        my $ss = {};
        settings::merge($ss, $database::db->{files}{$_}{settings}) for @files;
        settings::merge($ss);
        $database::db->{cc_flags} = [@basic_flags, @{$ss->{ccf}}, "-xc++"];
        $database::db->{ld_flags} = [@basic_flags, @{$ss->{ldf}}];  # TODO is -std=??? needed in linker flags?
    }

    # rebuild them
    if ($show_dirty) {
        print "\e[0;35mdirty: \e[1;35m$_\e[0m\n" for (sort keys %$dirty);
    }
    database::build_dirty($show_cmd, $nline, @files);

    # dirty status of the binary
    my @objects = grep defined, map { file::source_to_object($_) } @files;
    my $key = database::_stringify_objects($output, @objects);
    $dirty_bin->{$key} = undef if $bin_dirty;
    $dirty_bin->{$key} = undef if database::target_modified($output, @objects);

    # linking
    if ($show_dirty) {
        print "\e[0;35mdirty binary: \e[1;35m$_\e[0m\n" for (sort keys %$dirty_bin);
    }
    if (exists $dirty_bin->{$key}) {
        &link($show_cmd, $nline, $output, @objects);
        database::update_target($output, @objects);
        delete $dirty_bin->{$key};
    }

    return if $no_exec;
    makeless::execute($cmd, $output);
}

sub compile
{
    my ($show_cmd, $nline, $path) = @_;
    my $cc = $database::db->{cc};
    my $obj = file::source_to_object($path);
    my @args = (@{$database::db->{cc_flags}}, '-c', '-o', $obj, $path);

    print "\e[0;32mcompiling \e[1;35m$path\e[0m...\n";
    print "\e[0;35m", join(' ', $cc, @args), "\e[0m\n" if $show_cmd;
    spawn_limiting_stderr($nline, $cc, @args) and die "\e[0;31m$path: \e[1;31mfailed to compile.\e[0m\n";
    $obj;
}

sub link
{
    my $show_cmd = shift;
    my $nline = shift;
    my $output = shift;
    my $cc = $database::db->{cc};
    my @args = (@{$database::db->{ld_flags}}, '-o', $output, @_);

    print "\e[0;32mlinking \e[1;35m$output \e[0;32mfrom \e[0;35m", join(' ', @_), "\e[0m...\n";
    print "\e[0;35m", join(' ', $cc, @args), "\e[0m\n" if $show_cmd;
    spawn_limiting_stderr($nline, $cc, @args) and die "\e[0;31m$output: \e[1;31mfailed to link.\e[0m\n";
    $output;
}

sub execute
{
    my ($cmd, $path) = @_;
    my $rpath = file::real_path($path);

    print "\e[0;32mrunning \e[1;35m$path\e[0;32m by \e[0;35m$cmd\e[0m...\n";
    $ENV{bin} = $rpath;
    $ENV{src} = join(' ', @{$database::db->{triggers}});
    system $cmd;

    die "\e[0;31m$path: \e[1;31mfailed to execute: \e[0;31m$!\e[0m\n" if $? == -1;
    die "\e[0;31m$path: \e[1;31mdied with signal \e[0m[\e[1;31m"
        . ($? & 0b0111_1111) . "\e[0m]"
        . ($? & 0b1000_0000 ? " \e[0;33mcoredumped" : '') . "\e[0m\n"
        if $? & 0b0111_1111;
    print "\e[0;34mprogram \e[1;35m$path \e[0;34mreturned \e[0m[\e[1;31m", $? >> 8, "\e[0m]\n";
}

sub pkg_config
{
    my ($type, @libs) = @_;
    my @args = ("--$type", @libs);
    my @flags;

    use IPC::Open2;
    my $pid = open2(my $out, undef, 'pkg-config', @args);
    for (<$out>) {
        chomp;
        while ($_ =~ m{(\\.|[^\\\s])+}g) {
            my $flag = $&;
            $flag =~ s{\\(.)}{$1}g;
            push @flags, $flag;
        }
    }
    waitpid $pid, 0;
    die "\e[0;31m@_: \e[1;31mfailed to process library for $type.\e[0m\n" if $?;

    @flags;
}

sub clean
{
    my ($level) = @_;

    # clean objects
    for my $path (sort keys %{$database::db->{files}}) {
        next unless file::is_object($path);

        if ($level < 2 && database::file_modified($path)) {
            print "\e[0;35mskipping \e[1;35m$path\e[0m...\n";
            next;
        }

        if (-e $path) {
            print "\e[0;32mremoving \e[1;35m$path\e[0m...\n";
            file::remove_or_die($path);
        }
        database::update_file($path);
    }

    return if $level < 3;

    # clean targets
    for (sort keys %{$database::db->{targets}}) {
        my $path = $database::db->{targets}{$_}{path};
        if (-e $path) {
            print "\e[0;32mremoving \e[1;35m$path\e[0m...\n";
            file::remove_or_die($path);
        }
        delete $database::db->{targets}{$_};
    }
}

# same as "system", but limit the stderr to at most $nline lines
sub spawn_limiting_stderr
{
    my ($nline, @cmd) = @_;
    return system(@cmd) unless $nline > 0;

    use IPC::Open3;
    use Symbol qw(gensym);

    my $out = gensym();
    my $pid = open3(undef, undef, $out, @cmd);
    for (<$out>) {
        last unless $nline--;
        print STDERR;
    }
    waitpid $pid, 0;
    $?;
}

