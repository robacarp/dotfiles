function dice_email
  set -l adjectives acceptable beloved cheeky durable energetic fire-breathing guilty hostile illogical jobless kosher light macho negative oval peppy queenly random safe teeny upbeat valued waterproof young zealous
  set -l colors red green blue purple grey pink white yellow orange black teal golden silver navy-blue jet-black blonde brunette
  set -l animals aardvark beaver chicken dragonfly elk eel fox gorilla hippo jaguar kangaroo llama mouse newt otter pigeon pug rat sheep squid turtle wolf yak zebra

  set -l adjective $adjectives[(random 1 (count $adjectives))]
  set -l color $colors[(random 1 (count $colors))]
  set -l animal $animals[(random 1 (count $animals))]

  set -l number (random 1 99)
  echo "$adjective-$color-$animal$number@$argv[1]"
end
