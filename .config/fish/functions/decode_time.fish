# ported from / inspired by https://github.com/thcipriani/dotfiles/blob/3c2d75bc31865d97b36723351f9a8e1722a17d1b/bash_prompt#L97

function decode_time -d "Converts a unix timestamp delta into d:hh:mm:ss"
  argparse --name decode_time 'm' -- $argv or return

  set -l milliseconds 0
  set -l seconds $argv[1]

  if test $_flag_m # if using milliseconds
    set milliseconds (math -s0 $argv[1] % 1000)
    set seconds (math -s0 $argv[1] / 1000)
  end

  set -l days (math -s0 $seconds / 86400)
  set -l hours (math -s0 $seconds / 3600 % 24)
  set -l minutes (math -s0 $seconds / 60 % 60)

  set seconds (math -s0 $seconds % 60)

  set -l printable

  if test $days -gt 0
    set -a printable {$days}d
  end

  if test $hours -gt 0 -o -n "$printable"
    set -a printable {$hours}h
  end

  if test $minutes -gt 0 -o -n "$printable"
    set -a printable {$minutes}m
  end

  set -a printable {$seconds}s

  if test $_flag_m
    set -a printable {$milliseconds}ms
  end

  echo $printable
end
