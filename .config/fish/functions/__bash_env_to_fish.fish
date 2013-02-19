# https://github.com/nirvdrum/fish_config/blob/master/functions/__bash_env_to_fish.fish
function __bash_env_to_fish
  set -l env_vars_to_skip _ SHLVL PWD

  for v in $argv
    set -l tmp (echo $v|sed -e 'y/=/\n/')

    set name $tmp[1]
    set value $tmp[2]

    if test "PATH" = $name
      set -e PATH
      set -l bash_path (echo $value|sed -e 'y/:/\n/')

      for d in $bash_path
        if /bin/test -d $d
          set -xg PATH $PATH $d
        end
      end
    else
      if not contains $name $env_vars_to_skip
        set -xg $name $value
      end
    end
  end
end

