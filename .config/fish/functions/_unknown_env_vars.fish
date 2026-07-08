function _unknown_env_vars
  # env vars which should never be shown
  set -f env_var_blacklist

  # read env vars from blacklist file if it exists
  if test -f "$HOME/.config/fish/env_var_blacklist.txt"
    set -a env_var_blacklist (cat ~/.config/fish/env_var_blacklist.txt)
  end

  if test -f "$HOME/.config/fish/env_var_blacklist.local.txt"
    set -a env_var_blacklist (cat ~/.config/fish/env_var_blacklist.local.txt)
  end

  set -f value_whitelist RAILS_ENV NODE_ENV AWS_VAULT MIX_ENV DISTRICT ATHLETIC_ASSOCIATION

  set -f env_var_names (printenv | sort | awk -F '=' '{print $1}')

  set -f vars_to_show

  for var in $env_var_names
    # don't print any vars which are in the blacklist
    if contains $var $env_var_blacklist

    # don't print any vars which are prefixed with __mise or __wezterm
    else if string match --quiet --regex '^__MISE' $var
    else if string match --quiet --regex '^WEZTERM' $var

    # print everything else
    else
      set -a vars_to_show $var
    end
  end

  set -l sep
  set -l var_count (count $vars_to_show)

  if test $var_count -gt 3
    set sep "\n"
  else
    set sep " "
  end

  for var in $vars_to_show
    echo -n "$var" | tr '[:upper:]' '[:lower:]'

    if contains $var $value_whitelist
      echo -n "=$$var"
      echo -en "$sep"
    else
      echo -en "$sep"
    end
  end

  if test $var_count -gt 0
    echo ''
  end
end
