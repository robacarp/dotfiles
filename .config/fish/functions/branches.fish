function branches --description 'list recently checked out branches'
    git branch \
    | fzf \
        --height 20% \
        --border \
        --reverse \
    | xargs git switch
end
