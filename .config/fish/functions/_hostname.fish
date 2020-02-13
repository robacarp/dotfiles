function _hostname
  echo (hostname | cut -d . -f 1)
end
