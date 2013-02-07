. .config/aliases

function tab -d "Open a new tab and run a command in that tab."
  osascript             -e 'tell application "System Events"' \
                          -e 'tell process "Terminal" to keystroke "t" using command down' \
                        -e 'end'
  osascript             -e 'tell application "Terminal"' \
                          -e 'activate' \
                          -e "do script with command \"cd $PWD; $argv\" in window 1" \
                        -e 'end tell'
end

function workflow -d "Start up my standard rails workflow"
  tab rc
  tab guard
  rs
end

function notes -d "show the notes file"
  less ~/notes.md
end
