eval "$(/opt/homebrew/bin/brew shellenv)"

if [[ -x ~/.local/bin/mise ]]; then
  eval "$(~/.local/bin/mise activate zsh --shims)" # activate mise.jdx.dev
fi
