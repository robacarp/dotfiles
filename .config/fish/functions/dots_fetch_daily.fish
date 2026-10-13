function dots_fetch_daily
  # Fetches the bare dotfiles repo at most once every 24h. Returns immediately;
  # the fetch runs in a disowned background process.
  set -l stamp ~/.cache/dots-fetch
  test -d $HOME/.dots.git; or return 0

  # Fresh stamp (modified within the last 24h): nothing to do
  test -n "$(find $stamp -mmin -1440 2> /dev/null)"; and return 0

  # Touch first so shells opened at the same time don't all fetch
  mkdir -p (path dirname $stamp)
  touch $stamp

  env GIT_TERMINAL_PROMPT=0 git --git-dir=$HOME/.dots.git fetch --quiet \
    < /dev/null > /dev/null 2>&1 &
  disown
end
