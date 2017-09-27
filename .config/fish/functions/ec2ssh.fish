# Defined in - @ line 2
function ec2ssh
	ssh ec2-user@(aws_ip $argv[1])
end
