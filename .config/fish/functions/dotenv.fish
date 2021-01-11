# from https://github.com/JoshAshby/dots/blob/8844b6c9b33ded0432e9c9c2f65cf894728afa20/.config/fish/functions/dotenv.fish
function dotenv --description 'Load environment variables from .env file'
  set -l envfile ".env"
  if [ (count $argv) -gt 0 ]
    set envfile $argv[1]
  end

  if test -e $envfile
    for line in (cat $envfile)
      set -xg (echo $line | cut -d = -f 1) (echo $line | cut -d = -f 2-)
    end
  end
end
