if test -f ~/.local/bin/mise
  ~/.local/bin/mise activate fish --shims | source
end

if status --is-interactive
  source ~/.config/fish/interactive-config.fish
  . ~/.config/aliases
end
