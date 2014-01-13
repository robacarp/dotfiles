#!/usr/bin/env perl

use strict;
use warnings;
use 5.10.0;
use Term::ANSIColor;
use File::Basename;
use Cwd 'realpath';
use Env 'HOME';

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
  rename $cwd, $new_cwd;
  $cwd = $new_cwd;
}

# rename current directory to hide it as a dotfile
rename "$cwd", basename($cwd) . "/.dotfiles";

# everything should be done relative to the script,
# not to the execute location
chdir($cwd);

my $excludes = "";
my $no_excludes = 0;

open EXCLUDES, "excludes" or $no_excludes = 1;

if (! $no_excludes) {
  while (<EXCLUDES>) {
    chomp;
    $excludes = "$excludes $_";
  }
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
  symlink "$cwd/$file", "$destination/$file" or color_say 'red', 'link failed :/';
}

print "\n\n";
