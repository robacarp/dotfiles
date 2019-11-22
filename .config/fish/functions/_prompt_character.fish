function _prompt_character
  switch $USER
  case root
    echo '#'
  case '*'
    echo '>'
  end
end
