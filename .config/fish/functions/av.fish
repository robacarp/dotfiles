function av
  echo "# aws-vault profile=$AWS_PROFILE"
  aws-vault exec "$AWS_PROFILE" -- $argv
end
