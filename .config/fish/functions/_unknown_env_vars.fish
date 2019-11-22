function _unknown_env_vars
  # env vars which should never be shown
  set -l env_var_blacklist "ASDF_DIR" "HOME" "LANG" "LOGNAME" "LaunchInstanceID" "PATH" "PKG_CONFIG_PATH" "PWD" "SECURITYSESSIONID" "SHELL" "SHLVL" "SSH_AUTH_SOCK" "TERM" "TERM_PROGRAM" "TERM_PROGRAM_VERSION" "TERM_SESSION_ID" "TMPDIR" "USER" "XPC_FLAGS" "XPC_SERVICE_NAME"

  set -l env_var_names (printenv | awk -F '=' '{print $1}')

  set -l vars_to_show

  for var in $env_var_names
    if ! contains $var $env_var_blacklist
      set -a vars_to_show $var
    end
  end

  for var in $vars_to_show
    echo -s (set_color -d grey) "$var" (set_color black) "$$var"
  end

  echo -n (set_color normal)
end
