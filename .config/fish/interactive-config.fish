if test -f /usr/local/bin/pyenv
  source (pyenv init -|psub)
end

if test -d ~/.asdf
  source ~/.asdf/asdf.fish
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

abbr --add ave "aws-vault exec --duration=4h"
abbr --add tpl "terraform plan -out=.plan.out"
abbr --add tao "terraform apply .plan.out"
