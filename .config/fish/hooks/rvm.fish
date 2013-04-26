#!/usr/bin/env fish

function __check_rvm_at_cwd --on-event cwd
  # Source a .rvmrc file in a directory after changing to it, if it exists.
  # To disable this fature, set rvm_project_rvmrc=0 in $HOME/.rvmrc

  if test "$rvm_project_rvmrc" != 0
    set -l cwd $PWD

    while true

      # if cwd is any of '' $home '/'
      if contains $cwd "" $HOME "/"
        rvm default 1>/dev/null 2>&1
        break

      else
        if test -s "$cwd/.rvmrc" -o -s "$cwd/.ruby-version"
          rvm rvmrc load "$cwd"
          break
        else
          set cwd (dirname "$cwd")
        end
      end

    end

  end
end
