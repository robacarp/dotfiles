#!/usr/bin/env perl

#
# A little script which should run in dist perl and
# will symlink my dotfiles into $HOME.
#
# Possible TODO:
# - more cli parameters?
#   - link-source=$HOME
#

use strict;
use warnings;
use 5.10.0;
use Term::ANSIColor;
use File::Basename;
use Cwd 'realpath';
use Env 'HOME';
use Getopt::Std;

our ($opt_d, $opt_r, $opt_h) = (0, 0);
getopts('drh');

$opt_r = !$opt_r;

if ($opt_h) {
  print <<HELP;
Usage $0 [-h] [-dr]
Perform a symlink installation of dotfiles to the current users home directory.

    -d: Dry run. Don't actually link or rename anything, just talk about it.
    -h: Help. Display this help and exit.
    -r: noRename cwd. Prevent the automatic renaming of the script current
        execution directory.

HELP
exit;
}

sub color_say {
  my $temp;
  while (@_) {
     print color (shift @_) if (@_ > 1);
     print shift @_ if (@_);
     print color 'reset';
  }

  print "\n";
}

my $preferred_directory_name = '.dotfiles';

# establish where the script resides and
# where the links are going to be dropped
my $cwd = dirname realpath $0;

my $destination = $HOME;

# rename the working directory into something with a dot prefix
if (basename($cwd) ne $preferred_directory_name) {
  my $new_cwd = dirname($cwd) . '/' . $preferred_directory_name;
  color_say 'green', 'renaming'," $cwd to $new_cwd";

  if ($opt_r && ! $opt_d) {
    rename $cwd, $new_cwd;
    $cwd = $new_cwd;
  }

}

# rename current directory to hide it as a dotfile
rename "$cwd", basename($cwd) . "/.dotfiles";

# everything should be done relative to the script,
# not to the execute location
chdir($cwd);

# read in the excludes file
my $excludes = "";
my $excludes_exist = 1;

open my $exclude_file, "excludes" or $excludes_exist = 0;

if ($excludes_exist) {
  $excludes = join(' ', map {chomp; $_} <$exclude_file>);
}

# fetch a list of the dotfiles in this folder
my @destinations = <.*>;

for my $file (@destinations) {
  # skip . and ..
  next if ($file =~ /^\.{1,2}$/);

  # dont link pipes and fifos and other non-files
  if ( ! (-d $file || -f $file)) {
    color_say 'red', 'not a regular file: ', $file;
    next;
  }

  # check to see if the file was explicitly excluded
  if (index($excludes, $file) > -1) {
    color_say 'cyan', 'skip: ', $file;
    next;
  }

  # check to make sure the file doesn't already exist
  if (-e "$destination/$file") {
    color_say 'yellow', 'exists: ', "$destination/$file";
    next;
  }

  # link it, bro
  color_say 'green', 'link: ', "$destination/$file to $cwd/$file";
  if (! $opt_d) {
    symlink "$cwd/$file", "$destination/$file" or color_say 'red', 'link failed :/';
  }
}

print "\n";
