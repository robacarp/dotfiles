function repos
    cd ( \
      find ~/Repositories -maxdepth 2 -mindepth 2 -type d \
      | fzf --height 20% --border --reverse --preview='ls {}' \
    )
end
