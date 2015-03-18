function gitstatus
  git status --porcelain -b ^ /dev/null | awk '
    BEGIN {
      status["untracked"] = 0
      status["modifications"] = 0
      status["unmerged"] = 0
    }

    $1 ~ /##/ {
      split($2, branch_names, ".")
    }

    $1 ~ /\?\?/       { status["untracked"] ++     }
    $1 ~ /M/          { status["modifications"] ++ }
    $1 ~ /[DAU][DAU]/ { status["unmerged"] ++ }

    END {
      print branch_names[1]
      print status["untracked"]
      print status["modifications"]
      print status["unmerged"]
    }
   '
end
