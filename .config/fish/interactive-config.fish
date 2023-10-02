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

# integrate with pyenv
if test -f /usr/local/bin/pyenv
  source (pyenv init -|psub)
end

if test -d ~/.asdf
  # source ~/.asdf/asdf.fish
  fish_add_path ~/.asdf/shims ~/.asdf/bin
  source ~/.asdf/asdf.fish
end

if test -d /opt/homebrew/bin
  fish_add_path -g /opt/homebrew/bin
end

if test -d /opt/homebrew/sbin
  fish_add_path -g /opt/homebrew/sbin
end

if test -d ~/bin
  fish_add_path -g ~/bin
end

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

