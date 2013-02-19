#
# This is a kludge
#
function rvm -d 'Ruby enVironment Manager'
  # save original environment
  set -l fish_env (env)

  # run rvm and capture the resulting environment
  set -l env_file (mktemp -t rvm)
  bash -c "source ~/.rvm/scripts/rvm; rvm $argv; env > $env_file"
  set -l bash_env (cat $env_file)
  rm -f $env_file

  # get the env values from rvm that were present in fish
  set -l common

  for env in $bash_env
    if not contains $env $fish_env
      set common $common $env
    end
  end

  # write the env values to the current fish session
  __bash_env_to_fish $common
end
