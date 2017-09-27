# Defined in - @ line 2
function aws_ip
	aws ec2 describe-instances | jq --exit-status --raw-output '.Reservations[] | select(.Instances[] | select(.InstanceId == "'$argv[1]'")) | .Instances[0] | .PublicIpAddress'
end
