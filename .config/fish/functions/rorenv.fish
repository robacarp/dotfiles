function rorenv -d "sets the environment mode for rails testing"
  if test 1 -eq (count $argv)
    set -g RAILS_ENV $argv[1]
  else
    if set -q RAILS_ENV
      set -g -e RAILS_ENV
    else
      set -g RAILS_ENV production
    end
  end
end
