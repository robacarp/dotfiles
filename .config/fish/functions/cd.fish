function cd --description "Change working directory"
  builtin cd $argv
  emit cwd
end
