function _dots_dirty
  # Succeeds when the bare dotfiles repo has uncommitted changes
  test -d $HOME/.dots.git; or return 1
  test -n "$(git --git-dir=$HOME/.dots.git --work-tree=$HOME status --porcelain 2> /dev/null)"
end
