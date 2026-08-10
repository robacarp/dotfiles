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
  set -l branch (git branch --show-current 2> /dev/null)
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

  # jjt workspace: nearest ancestor of $PWD with its own .jj is the
  # workspace root. Only look when JJT_REPO_ROOT is set (i.e. we're inside
  # a jjt-spawned subshell) so plain jj repos outside jjt don't match.
  set -l jjt_ws
  if set -q JJT_REPO_ROOT
    set -l dir $PWD
    while test "$dir" != /
      if test -d $dir/.jj
        set jjt_ws $dir
        break
      end
      set dir (path dirname $dir)
    end
  end

  if test -n "$jjt_ws"
    set_color red
    echo -s -n '[' (path basename $jjt_ws) ']'
    set_color normal
    echo
  end

  # prompt line

  if test $USER = 'root'
    set_color -o magenta
    echo -s -n $USER
    set_color normal
    echo -s -n '@'
  end

  echo -s -n (_hostname) " "

  set_color $fish_color_cwd
  if test -n "$jjt_ws"
    set -l subpath (string replace -- $jjt_ws '' $PWD)
    echo -n (prompt_pwd "$JJT_REPO_ROOT$subpath")
  else
    echo -n (prompt_pwd)
  end
  set_color normal

  echo -s -n (_prompt_character) " "
end
