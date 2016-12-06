function g_loaddata
  set source (ls -1t ~/Documents/Programs/gloo/database_dumps/scrubbed_db-prod*.sql.gz | head -n1) 
  echo inserting $source
  psql -c 'drop database polymer_vanilla'
  psql -c 'create database polymer_vanilla'
  gunzip --to-stdout $source | sed -e 's/gloo_production/polymer/' | psql polymer_vanilla > /dev/null
end
