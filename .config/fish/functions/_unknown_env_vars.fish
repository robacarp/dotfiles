function _unknown_env_vars
  # env vars which should never be shown
  set -l env_var_blacklist \
    JAVA_HOME \
    ASDF_DIR \
    HOME USER LANG LOGNAME PATH PWD \
    PKG_CONFIG_PATH \
    LaunchInstanceID SECURITYSESSIONID SSH_AUTH_SOCK \
    fish_user_paths \
    SHELL SHLVL TERM TERM_PROGRAM TERM_PROGRAM_VERSION TERM_SESSION_ID \
    MAIL SUDO_COMMAND SUDO_GID SUDO_UID SUDO_USER USERNAME \
    TMPDIR XPC_FLAGS XPC_SERVICE_NAME \
    AWS_ACCESS_KEY_ID \
    AWS_DEFAULT_REGION \
    AWS_REGION \
    AWS_SECRET_ACCESS_KEY \
    COLORFGBG \
    COLORTERM \
    ITERM_PROFILE \
    ITERM_SESSION_ID \
    LC_TERMINAL \
    LC_TERMINAL_VERSION \
    EDITOR \
    __CF_USER_TEXT_ENCODING \
    __CFBundleIdentifier


  set -l value_whitelist RAILS_ENV NODE_ENV AWS_VAULT

  set -l env_var_names (printenv | awk -F '=' '{print $1}')

  set -l vars_to_show

  for var in $env_var_names
    if ! contains $var $env_var_blacklist
      set -a vars_to_show $var
    end
  end

  for var in $vars_to_show
    set_color -d grey
    echo -n (echo "$var" | tr '[:upper:]' '[:lower:]')

    if contains $var $value_whitelist
      echo -n "=$$var"
    end

    echo -n ' '
  end

  echo ''

  set_color normal
end
