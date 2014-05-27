#
# For use when resuming remote screen session to re-sync
# ssh agent, and thus keys push through the new ssh session
# and make them available to shells running inside of screen
#
# Run before connecting to screen to dump env vars to a file,
# then resume or extend screen session and run again to
# import those env vars to the current environment.
#
keyme() {
  if [[ $TERM =~ "screen" ]]; then
    echo -n "Importing ssh agent - "
    if [ -s $HOME/.ssh/envs ]; then
      . $HOME/.ssh/envs
      echo "Success!"
    else
      echo "No envs file found."
    fi
  else
    echo -n "Exporting ssh agent - "
      # Courtesy of http://www.deadman.org/sshscreen.php
      SSHVARS="SSH_CLIENT SSH_TTY SSH_AUTH_SOCK SSH_CONNECTION DISPLAY"

      for x in ${SSHVARS} ; do
          (eval echo $x=\$$x) | sed  's/=/="/
                                      s/$/"/
                                      s/^/export /'
      done 1>$HOME/.ssh/envs

      echo "Success!"
  fi
}
