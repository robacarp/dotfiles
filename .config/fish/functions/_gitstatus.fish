function _gitstatus
  git status --porcelain -b 2> /dev/null | awk '
    BEGIN {
      status["untracked"] = 0
      status["modifications"] = 0
      status["unmerged"] = 0
    }

    $1 ~ /##/ {
      branch_name = $2
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
