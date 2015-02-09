function checkouts
  git reflog | awk 'BEGIN { FS = " (from|to) " }; /checkout/ { if (names[$2]++ == 0) print $2 }'
end
