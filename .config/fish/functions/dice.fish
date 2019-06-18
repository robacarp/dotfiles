function dice
  set -l word_list (curl -s https://robacarp.io/dice.json)
  set -l color (echo "$word_list" | jq -r .colors[] | shuf -n 1)
  set -l adjective (echo "$word_list" | jq -r .adjectives[] | shuf -n 1)
  set -l animal (echo "$word_list" | jq -r .nouns[] | shuf -n 1)

  echo "$adjective-$color-$animal"
end
