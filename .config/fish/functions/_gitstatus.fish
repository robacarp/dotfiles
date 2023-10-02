function _gitstatus
  git status --porcelain -b 2> /dev/null | awk '
    BEGIN {
      status["untracked"] = 0
      status["modifications"] = 0
      status["unmerged"] = 0
    }

    $1 ~ /##/ {
      if (index($0, "No commits yet on") > 0) {
        branch_name = "⁞"
        next
      }

      branch_name = substr($0, 4)
      dots = index(branch_name, "...")
      if (dots > 0) branch_name = substr(branch_name, 0, dots - 1)
    }

    $1 ~ /\?\?/       { status["untracked"] ++     }
    $1 ~ /M/          { status["modifications"] ++ }
    $1 ~ /[DAU][DAU]/ { status["unmerged"] ++ }

    END {
      print branch_name
      print status["untracked"]
      print status["modifications"]
      print status["unmerged"]
    }
   '
end
