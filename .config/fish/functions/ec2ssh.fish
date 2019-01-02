# Defined in - @ line 2
function ec2ssh
	ssh ubuntu@(aws_ip $argv[1])
end
