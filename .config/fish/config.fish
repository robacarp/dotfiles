. ~/.config/aliases

function fish_user_key_bindings
  bind . 'expand-dot-to-parent-directory-path'
  bind \cs 'sudo-my-prompt-yo'
end

function exec_start --on-event fish_preexec -d "Starts the execution clock of a process"
  set -g _exec_start (date +%s)
  set -g _last_cmd $argv[1]
end

function exec_end --on-event fish_postexec -d "Stop the execution clock of a process and set _exec_delta"
  set -g _exec_delta (math (date +%s) - $_exec_start)
  set -e -g _exec_start
end

if test -d $HOME/.rbenv
  set PATH $HOME/.rbenv/shims $PATH
  . (rbenv init -|psub)
end

# Postgres.app CLI tools
if test -d /Applications/Postgres.app/Contents/Versions/latest/bin
  set PATH /Applications/Postgres.app/Contents/Versions/latest/bin $PATH
end

# homedirectory bin folder
if test -d ~/.dotfiles/bin
  set PATH $PATH ~/.dotfiles/bin
end

# homebrew path
if test -d /usr/local/sbin
  set PATH $PATH /usr/local/sbin
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

function cs -d "Change directory then ls contents"
  cd $argv; and ls
end

alias cld="cd (command ls -t | head -n1)"

function _git_hash
  echo -n (git log -1 ^/dev/null | sed -n -e 's/^commit \([a-z0-9]\{8\}\)[a-z0-9]\{32\}/\1/p')
end

function _hostname
  echo (hostname ^&- | cut -d . -f 1)
end

function _env_vars
  if set -q RAILS_ENV
    echo -n $RAILS_ENV
  end

  if set -q RAILS_ENV NODE_ENV
    echo -n " "
  end

  if set -q NODE_ENV
    echo -n $NODE_ENV
  end

  if set -q TEST
    echo -n " "
    echo -n (basename $TEST)
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
  set -l previous_command $status
  set -l stats (gitstatus)
  set -l vars (_env_vars)
  set -l hash (_git_hash)

  set -l dirty (math $stats[3] + $stats[2] + $stats[4])

  # previous command status if nonzero
  if test $previous_command -gt 0
    echo -s -n (set_color -b red) status: " "  $previous_command (set_color normal) " "
  end

  # ! for modified files
  if test $dirty -gt 0
    echo -s -n (set_color red) ! (set_color normal)
  end

  # branch name
  if test $stats[1]
    echo -s -n (set_color cyan) $stats[1] " " (set_color normal)
  end

  # environment vars
  if test $vars
    echo -s -n (set_color purple) " " $vars (set_color normal)
  end

  # colorize extra data only if there was a previous command
  if test -z $_last_cmd
    echo -s -n (set_color grey)
  else
    echo -s -n (set_color black)
  end

  # current sha hash
  if test $hash
    echo -s -n (_git_hash) " "
  end

  echo -s -n (date "+%b-%d %H:%M:%S")

  if test -n '$_exec_delta'
    set _exec_delta 0
  end

  if test "$_exec_delta" -gt 5
    echo -s -n " ∆t=" (decode_time $_exec_delta)
  end

  echo -s -n (set_color normal)

  # prompt line
  echo -s (set_color normal)

  if test $USER = 'root'
    echo -s -n (set_color -o magenta) $USER (set_color normal) @
  end

  echo -s -n (_hostname) " "

  echo -s -n (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
  echo -s -n (_prompt_character) " "
end

function tab -d "Open a new tab and run a command in that tab."
  osascript             -e 'tell application "System Events"' \
                          -e 'tell process "Terminal" to keystroke "t" using command down' \
                        -e 'end'
  osascript             -e 'tell application "Terminal"' \
                          -e 'activate' \
                          -e "do script with command \"cd $PWD\" in window 1" \
                        -e 'end tell'

  for current_arg in $argv
    osascript             -e 'tell application "Terminal"' \
                            -e 'activate' \
                            -e "do script with command \"$current_arg\" in window 1" \
                          -e 'end tell'
  end

end

function workflow -d "Start up my standard rails workflow"
  tab rc
  test -f Guardfile; and tab guard
  tab
  if not contains "!v" $argv
    mvim . 2>/dev/null
  end
  rs
end

function gloo -d "Start up the Gloo vm and related tools"
  cd ~/Sites/gloo/program_creator
  tab rs
  tab rc
  tab "rake QUEUE=\\\* VERBOSE=1 resque:work"
  tab "rake resque:scheduler"
  tab "cd ../bfd/api-analytics" "play run"
  exit
end

function backend -d "Start up the gloo bfd infrastructure"
  cd ~/Sites/gloo/bfd
  tab "redis-server /usr/local/etc/redis.conf"
  tab "elasticsearch -f -D es.config=/usr/local/opt/elasticsearch/config/elasticsearch.yml"
  tab "cd ~/Sites/gloo/kafka-0.7.2-incubating-src" "bin/zookeeper-server-start.sh config/zookeeper.properties"
  tab "cd ~/Sites/gloo/kafka-0.7.2-incubating-src" "bin/kafka-server-start.sh config/server.properties"
  exit
end

function notes -d "show the notes file"
  test -f ~/notes.md; and less ~/notes.md
end

