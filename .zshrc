export PATH="$HOME/.local/bin:$PATH"

if [[ -x ~/.local/bin/mise && -z "$CLAUDECODE" ]]; then
  eval "$(~/.local/bin/mise activate zsh)"
fi
