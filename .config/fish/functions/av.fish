function av
  echo "# aws-vault AWS_PROFILE=$AWS_PROFILE" 1>&2
  aws-vault exec "$AWS_PROFILE" -- $argv
end
