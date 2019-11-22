function asgssh
  # ARG: asg name

  set -l instance_id (
    aws autoscaling \
      describe-auto-scaling-groups \
      --auto-scaling-group-names=$argv[1] \
      --query='AutoScalingGroups[0].Instances[0].InstanceId' \
      --output=text
  )

  echo "Found an instance: $instance_id"

  ec2ssh $instance_id
end
