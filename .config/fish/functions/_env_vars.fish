function _env_vars
  set -l values_to_show 'RAILS_ENV' 'NODE_ENV' 'AWS_VAULT'

  # collect the variables to show in a list rather than echoing them each to prevent a leading space
  set -l display

  for var in $values_to_show
    if set -q $var
      set -a display $$var
    end
  end

  echo -n $display
end
