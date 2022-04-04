function fish_prompt
  set -l previous_command $status
  set -l stats (_gitstatus)
  set -l hash (_git_hash)

  set -l dirty (math $stats[3] + $stats[2] + $stats[4])

  # List environment variables/values which are atypical, but not when running in vim
  if ! set -q VIM_TERMINAL
    _unknown_env_vars
  end

  # previous command status if nonzero
  if test $previous_command -gt 0
    set_color -b red
    echo -s -n $previous_command
    set_color normal
    echo -n ' '
  end

  # branch name
  if test $stats[1]
    set_color cyan
    echo -n -s $stats[1] " "
    set_color normal
  end

  # colorize extra data only if there was a previous command
  if test -z $_last_cmd
    set_color grey
  else
    set_color black
  end

  # current sha hash
  if test $hash
    echo -s -n (_git_hash) " "
  end

  echo -s -n (date "+%b-%d %H:%M:%S") " "

  if test -n $_last_cmd
    echo -n -s '∆t=' (decode_time -m $CMD_DURATION) ' '
  end

  echo -s -n (set_color normal)

  # prompt line
  echo -s (set_color normal)

  if test $USER = 'root'
    set_color -o magenta
    echo -s -n $USER
    set_color normal
    echo -s -n '@'
  end

  echo -s -n (_hostname) " "

  set_color $fish_color_cwd
  echo -n (prompt_pwd)
  set_color normal

  echo -s -n (_prompt_character) " "
end
