function masterify
  set current_branch (git symbolic-ref HEAD | sed -e 's|^refs/heads/||')

  git checkout master
  git pull
  git checkout $current_branch
end
