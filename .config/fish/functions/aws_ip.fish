function aws_ip
  aws ec2 describe-instances --filters 'Name=instance-id,Values=i-0b33038d5133264c5' --query "Reservations[0].Instances[0].PublicIpAddress" --output=text
  return $status
end
