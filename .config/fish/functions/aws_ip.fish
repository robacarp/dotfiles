function aws_ip
  aws ec2 describe-instances --filters "Name=instance-id,Values=$argv[1]" --query "Reservations[0].Instances[0].PublicIpAddress" --output=text
  return $status
end
