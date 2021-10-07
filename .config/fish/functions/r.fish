function r \
  --description 'quickly switch to a repository with fzf'

    cd ( \
      find ~/Repositories -maxdepth 2 -mindepth 2 -type d \
      | fzf \
        --height 20% \
        --border \
        --reverse \
        --preview='ls {}' \
        --query=$argv
    )
end
