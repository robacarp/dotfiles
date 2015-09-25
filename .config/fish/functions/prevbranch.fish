function -d 'attempt to checkout the most recently checked out branch' prevbranch
  git checkout (checkouts -n 1)
end
