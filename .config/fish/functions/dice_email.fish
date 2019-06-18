function dice_email
  set -l dice (dice)
  set -l number (random 1 99)
  echo "$dice$number@$argv[1]"
end
