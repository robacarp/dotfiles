. .config/aliases

set uname=uname -a
if test $uname =~ "^Linux"
  echo "detected linux"
  alias ls="\ls -la --color=auto"
  alias ll="\ls -l --color=auto"
else if test $uname =~ "^Darwin"
  echo "detected darwin"
  alias ls="\ls -la -G"
  alias ll="\ls -l -G"
else
  echo "could not detect operating system"
end

function cs -d "Change directory then ls contents"
  cd $argv; and ls
end

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
  test -f Guardfile; and tab guard
  tab
  mvim . 2>/dev/null
  rs
end

function notes -d "show the notes file"
  test -f ~/notes.md; and less ~/notes.md
end

function keyme
  echo "NO STOPIT IT DOESNT WORK"
#
# For use when resuming remote screen session to re-sync
# ssh agent, and thus keys push through the new ssh session
# and make them available to shells running inside of screen
#
# Run before connecting to screen to dump env vars to a file,
# then resume or extend screen session and run again to
# import those env vars to the current environment.
#
  if test $TERM =~ "screen"
    echo -n "Importing ssh agent - "
    if test -f $HOME/.ssh/envs
      . $HOME/.ssh/envs
      echo "Success!"
    else
      echo "No envs file found."
    end
  else
    echo -n "Exporting ssh agent - "
      # Courtesy of http://www.deadman.org/sshscreen.php
      set SSHVARS "SSH_CLIENT SSH_TTY SSH_AUTH_SOCK SSH_CONNECTION DISPLAY"
      echo > ~/.ssh/envs
      for x in $SSHVARS
          echo $x=\$$x | sed 's/=/="/
                              s/$/"/
                              s/^/export /' \
                              >> ~/.ssh/envs
      end

      echo "Success!"
  end
end
