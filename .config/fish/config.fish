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

if status --is-interactive
  source ~/.config/fish/interactive-config.fish
  . ~/.config/aliases
end
