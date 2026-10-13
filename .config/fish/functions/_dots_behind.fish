function _dots_behind
  # Succeeds when the bare dotfiles repo is behind its upstream (as of the last fetch)
  test -d $HOME/.dots.git; or return 1
  set -l behind (git --git-dir=$HOME/.dots.git rev-list --count HEAD..@{u} 2> /dev/null)
  test -n "$behind"; and test $behind -gt 0
end
