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

# integrate with pyenv
if test -f /usr/local/bin/pyenv
  source (pyenv init -|psub)
end

if test -d ~/.asdf
  # source ~/.asdf/asdf.fish
  fish_add_path ~/.asdf/shims ~/.asdf/bin
  source ~/.asdf/lib/asdf.fish
end

if test -d /opt/homebrew/bin
  fish_add_path -g /opt/homebrew/bin
end

if test -d /opt/homebrew/sbin
  fish_add_path -g /opt/homebrew/sbin
end

if test -d ~/bin
  fish_add_path -g ~/bin
end
