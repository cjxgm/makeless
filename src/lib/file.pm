package file;
# filesystem and file path related functions

use utf8;
use strict;
use warnings;
local $" = ' ';

sub modified_time
{
    my $npath = shift;
    (stat $npath)[9];
}

sub digest
{
    my $npath = shift;
    if ($database::db->{debug} > 1) {
        use Digest::file qw(digest_file_base64);
        digest_file_base64($npath, "MD5");
    }
    else {
        use Digest::file qw(digest_file);
        digest_file($npath, "MD5");
    }
}

sub mkdir
{
    my ($path) = @_;

    use File::Path qw(make_path);
    make_path($path, { error => \my $err });
    return $path unless @$err;
    undef;
}

sub mkdir_or_die
{
    my ($path) = @_;
    file::mkdir($path) or die "\e[0;31m$path \e[1;31mfailed to mkdir for prefix: \e[0;31m$!\e[0m\n";
}

# Normalize a relative path to another relative path (relative to cwd)
# and a absolute path to another absolute path
# that is consistent enough for comparison and
# identifting the same file (can be used as hash keys).
#
# EXAMPLES:
#   ./a/b/../c/ => a/c
#   ../a/b/../../../c => ../../c
#   ../makeless/a => a              # if cwd is     called "makeless"
#   ../makeless/a => ../makeless/a  # if cwd is NOT called "makeless"
#
# This function does physically walking in the filesystem
# and expands symbolic links.
#
# return undef if file not exist.
sub normalize_path
{
    my $path = shift;

    my $rpath = real_path($path);
    return undef unless defined $rpath;
    return $rpath if $path =~ m{^/};

    use File::Spec::Functions qw(abs2rel);
    abs2rel($rpath);
}

sub real_path
{
    use Cwd qw(abs_path);
    abs_path(shift);
}

sub source_to_object
{
    use File::Basename qw(dirname);

    my $path = shift;
    return undef unless $path =~ s{\.cc$}{.o};
    $path = "$database::db->{prefix}/$path";
    file::mkdir_or_die(dirname($path));
    normalize_path($path);
}

sub source_to_binary
{
    my $path = shift;
    return undef unless $path =~ s{\.cc$}{};
    $path;
}

sub is_header
{
    my $path = shift;
    return undef unless $path =~ m{\.(hh|inl)$};
    $path;
}

sub is_object
{
    my $path = shift;
    return undef unless $path =~ m{\.o$};
    $path;
}

sub header_to_source
{
    my $path = shift;
    return undef unless $path =~ s{\.(hh|inl)$}{.cc};
    return undef unless -e $path;
    $path;
}

sub remove
{
    my ($path) = @_;
    die "TODO: remove empty dir" if -d $path;
    unlink $path;
}

sub remove_or_die
{
    my ($path) = @_;
    file::remove($path) or die "\e[0;31m$path: \e[1;31mfailed to remove \e[0;31m$!\e[0m\n";
}

