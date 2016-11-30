function ssh_key_copy -d "Copy public key to server"
  set file yolo
  if test -f ~/.ssh/id_rsa.pub
    set file ~/.ssh/id_rsa.pub
  else if test -f ~/.ssh/id_ecdsa.pub
    set file ~/.ssh/id_ecdsa.pub
  end

  echo $file
  cat $file | ssh $argv 'sh -c "mkdir -p .ssh; cat >> .ssh/authorized_keys && echo public key copied"'
end
