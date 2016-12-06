function g_load_encrypted_db
  set encrypted_dump (ls -1t  ~/Documents/Programs/gloo/database_dumps/*.sql.gz.aes | head -n1)
  echo Loading decrypted $encrypted_dump
  openssl aes-256-cbc -d -salt -k "$GLOO_DECRYPT" -in   | gunzip --to-stdout | sed -e 's/gloo_production/polymer/' | psql polymer_vanilla > /dev/null
end
