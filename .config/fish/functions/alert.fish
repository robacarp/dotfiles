function alert
  argparse --name alert 'm/message=' 't/timeout=' 's/status=' -- $argv or return
  set -l formatted_message (echo $_flag_message |  sed -e 's/ /%20/g')
  open -g "hammerspoon://task_completed?message=$formatted_message&timeout=$_flag_timeout&status=$_flag_status"
end
