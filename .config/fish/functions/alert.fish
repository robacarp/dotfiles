# Defined in - @ line 2
function alert
  argparse --name alert 'm/message=' 't/timeout=' -- $argv or return
  open -g "hammerspoon://task_completed?message=$_flag_message&timeout=$_flag_timeout"
end
