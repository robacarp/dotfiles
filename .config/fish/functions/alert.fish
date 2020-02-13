function alert
  argparse --name alert 'm/message=' 't/timeout=' 's/status=' -- $argv or return
  open -g "hammerspoon://task_completed?message=$_flag_message&timeout=$_flag_timeout&status=$_flag_status"
end
