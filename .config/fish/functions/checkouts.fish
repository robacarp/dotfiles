function checkouts -d "list recently checked out branches"
  set count 7
  # what is scripting and how do I operand
  if test 1 -lt (count $argv)
  if test '-n' = $argv[1]
    set count $argv[2]
  end
  end

  git reflog | awk 'BEGIN { FS = " (from|to) " };
                    /checkout/ && $2 !~ /^$/ {
                      if (names[$2]++ == 0) print $2
                    }' | head -n $count
end
