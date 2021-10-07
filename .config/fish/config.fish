. ~/.config/aliases

#set PATH /Users/robert/Documents/repositories/crystal-lang/crystal/bin $PATH

function fish_user_key_bindings
  bind . 'expand-dot-to-parent-directory-path'
  bind \cs 'sudo-my-prompt-yo'
end

function exec_start --on-event fish_preexec -d "Keep track of the last command string"
  set -g _last_cmd $argv[1]
end

# to enable on a machine, set -U _long_command_finished_notification true
function auto_alert --on-event fish_postexec -d "Check the execution delta and send an alert on long running commands"
  set -l exit_code $status

  if test "$_long_command_finished_notification" != true
    return
  end

  if test $CMD_DURATION -gt 12000
    set -l first_word (string split -m 1 " " "$argv[1]")[1]
    set -l formatted_time (decode_time -m $CMD_DURATION)
    alert -m "$first_word command finished ($formatted_time)" -s $exit_code
  end
end

# integrate with pyenv
if test -f /usr/local/bin/pyenv
  if status --is-interactive
    source (pyenv init -|psub)
  end
end

# homedirectory bin folder
if test -d ~/.dotfiles/bin
  set PATH $PATH ~/.dotfiles/bin
end

# homebrew path
if test -d /usr/local/sbin
  set PATH $PATH /usr/local/sbin
end

set -l uname (uname -a | sed -e 'y/ /\n/')
if contains "Linux" $uname
  #echo "system: linux"
  alias ls="command ls -la --color=auto"
  alias ll="command ls -l --color=auto"
else if contains "Darwin" $uname
  #echo "system: darwin"
  alias ls="command ls -la -G"
  alias ll="command ls -l -G"
else
  echo "could not detect operating system"
end

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

fish_add_path ~/bin
source /opt/homebrew/opt/asdf/libexec/asdf.fish
fish_add_path /opt/homebrew/bin
fish_add_path /opt/homebrew/sbin
