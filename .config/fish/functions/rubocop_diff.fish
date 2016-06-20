function rubocop_diff
  set -l git_branch (git status --porcelain -b ^ /dev/null | awk '
      $1 ~ /##/ {
        split($2, branch_names, ".")
        print branch_names[1]
      }
  ')

  set -l delta (git diff origin/mainline...origin/$git_branch --name-only | grep '.rb$')
  if [ ! -z "$delta" ]
    bundle exec rubocop $delta
  end
end
