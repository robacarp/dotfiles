function ssh-ignore-key --description 'SSH: remove ssh foreign key entry from ~/.ssh/known_hosts and then ssh to that host'
  ssh-keygen -R "$argv[1]" ; and ssh "$argv[1]"
end
