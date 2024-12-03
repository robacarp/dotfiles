function _unknown_env_vars
  # env vars which should never be shown
  set -l env_var_blacklist \
   SECURITYSESSIONID \
   EDITOR \
   asdf_data_dir \
   ASDF_DIR \
   DISPLAY \
   CR_PAT \
   ERL_AFLAGS \
   EXTENSION_KIT_EXTENSION_TYPE \
   HOME \
   LANG \
   LOGNAME \
   LaunchInstanceID \
   MallocNanoZone \
   MallocSpaceEfficient \
   PATH \
   PWD \
   SHELL \
   SHLVL \
   SSH_AUTH_SOCK \
   TERM \
   TERM_PROGRAM \
   TERM_PROGRAM_VERSION \
   TERM_SESSION_ID \
   TMPDIR \
   USER \
   XPC_FLAGS \
   XPC_SERVICE_NAME \
   __CFBundleIdentifier


  set -l value_whitelist RAILS_ENV NODE_ENV AWS_VAULT MIX_ENV

  set -l env_var_names (printenv | awk -F '=' '{print $1}')

  set -l vars_to_show

  for var in $env_var_names
    if ! contains $var $env_var_blacklist
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
