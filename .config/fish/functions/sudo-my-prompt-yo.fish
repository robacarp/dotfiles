function sudo-my-prompt-yo
  set -l cmd (commandline)
  commandline --replace "sudo $cmd"
end
