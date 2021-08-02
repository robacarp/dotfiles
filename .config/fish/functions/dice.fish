function dice
  curl -s https://robacarp.io/new_dice.json \
  | jq --raw-output --exit-status .chosen[0].assembled
end
