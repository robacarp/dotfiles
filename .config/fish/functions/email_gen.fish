# Defined in - @ line 2
function email_gen
  set -l uid (uuidgen | tr A-Z a-z | tr -d '-' | cut -c 1-8)
  echo "$argv[1]-$uid@robacarp.com"
end
