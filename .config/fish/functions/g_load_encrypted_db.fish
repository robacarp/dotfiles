function g_decryptdb
  openssl aes-256-cbc -d -salt -k "$GLOO_DECRYPT" -in (ls -1t *.sql.gz.aes | head -n1)  | gunzip --to-stdout | sed -e 's/gloo_production/polymer/' | psql polymer_vanilla
end
