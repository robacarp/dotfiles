# ported from / inspired by https://github.com/thcipriani/dotfiles/blob/3c2d75bc31865d97b36723351f9a8e1722a17d1b/bash_prompt#L97

function decode_time -d "Converts a unix timestamp delta into d:hh:mm:ss"
  set -l seconds $argv[1]
  set -l days (math $seconds / 86400)
  set -l hours (math "$seconds / 3600 % 24")
  set -l minutes (math "$seconds / 60 % 60")
  set -l seconds (math "$seconds % 60")

  set -l sent_days 0
  set -l sent_hours 0
  set -l sent_minutes 0
  set -l printable ''


  if test $days -gt 0
    set printable $printable{$days}d
    set sent_days 1
  end

  if test $hours -gt 0 -o $sent_days -gt 0
    test $sent_days -gt 0; and set printable $printable{' '}
    set printable $printable{$hours}h
    set sent_hours 1
  end

  if test $minutes -gt 0 -o $sent_hours -gt 0
    test $sent_hours -gt 0; and set printable $printable{' '}
    set printable $printable{$minutes}m
    set sent_minutes 1
  end

  test $sent_minutes -gt 0; and set printable $printable{' '}
  echo $printable{$seconds}s
end
