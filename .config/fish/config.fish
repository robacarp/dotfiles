. ~/.config/aliases

# Tie RVM into the PATH
if test -d ~/.rvm/bin
  . ~/.config/fish/hooks/rvm.fish
  . ~/.config/fish/library/rvm.fish
  set PATH ~/.rvm/bin $PATH
  rvm current >&-
end

# Postgres.app CLI tools
if test -d /Applications/Postgres.app
  set PATH /Applications/Postgres.app/Contents/MacOS/bin $PATH
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

if status --is-login
  set PATH $PATH ~/.rvm/gems/ruby-1.9.3-p362/bin ~/.rvm/gems/ruby-1.9.3-p362@global/bin ~/.rvm/rubies/ruby-1.9.3-p362/bin ~/.rvm/bin /usr/local/heroku/bin ~/.rvm/bin
end

function cs -d "Change directory then ls contents"
  cd $argv; and ls
end

function _git_bang_if_dirty
  if git status -s --ignore-submodules=dirty ^&- >&-
    echo -n !
  end
end

function _git_branch_name
  echo -n (git symbolic-ref HEAD ^/dev/null | sed -e 's|^refs/heads/||')
end

function _git_hash
  echo -n (git log -1 ^/dev/null | sed -n -e 's/^commit \([a-z0-9]\{8\}\)[a-z0-9]\{32\}/\1/p')
end

function _hostname
  echo (hostname ^&- | cut -d . -f 1)
end

function _rvm_prompt
  if test -d ~/.rvm/bin
    rvm-prompt v g
  end
end

function _prompt_character
  switch $USER
  case root
    echo '#'
  case '*'
    echo '>'
  end
end

function fish_prompt
  echo -s -n (set_color yellow) (_rvm_prompt) (set_color normal)
  echo -s -n (set_color red) (_git_bang_if_dirty) (set_color normal)

  echo -s -n (set_color cyan) (_git_branch_name) (set_color normal)

  echo -s    (set_color black) (_git_hash) " " (date "+%b-%d %H:%M:%S") (set_color normal)

  echo -s -n  $USER @ (_hostname) " "
  echo -s -n (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
  echo -s -n (_prompt_character) " "
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

function gloo -d "Start up the Gloo vm and related tools"
  cd ~/Sites/gloo/vagrant
  tab vagrant ssh
  tab vagrant ssh
  tab vagrant ssh
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