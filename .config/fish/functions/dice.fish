function dice
  curl -s https://robacarp.com/new_dice.json \
  | jq --raw-output --exit-status .chosen[0].assembled
end
