function fish_prompt
  set -l previous_command $status
  set -l stats (_gitstatus)
  set -l hash (_git_hash)

  set -l dirty (math $stats[3] + $stats[2] + $stats[4])

  echo ''

  # List environment variables/values which are atypical, but not when running in vim
  if ! set -q VIM_TERMINAL
    set_color black
    _unknown_env_vars
    set_color normal
  end

  # previous command status if nonzero
  if test $previous_command -gt 0
    set_color -b red
    echo -s -n $previous_command
    set_color normal
    echo -n ' '
  end

  # branch name
  set -l branch (git branch --show-current)
  if test $branch
    set_color cyan
    echo -n -s $branch " "
    set_color normal
  end

  echo -s -n (date "+%b-%d %H:%M:%S") " "

  if test -n "$_last_cmd" -a $CMD_DURATION -gt 200
    echo -n -s '∆t=' (decode_time -m $CMD_DURATION) ' '
  end

  echo

  set_color normal

  # prompt line

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
