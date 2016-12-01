function g_loaddata
	gunzip --to-stdout (ls -1t scrubbed_db-prod*.sql.gz | head -n1)  | sed -e 's/gloo_production/polymer/' | psql polymer_vanilla
end
