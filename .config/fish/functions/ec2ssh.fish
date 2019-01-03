function ec2ssh
  argparse --name ec2ssh 'u/user=' -- $argv
  or return

  set -l user

  if test "$_flag_user" != ""
    set user "$_flag_user"
  else
    set user ubuntu
  end

  set -l ip_address (aws_ip $argv[1])
  echo "# connecting to $user@$ip_address ..."

  ssh $user@$ip_address
end
