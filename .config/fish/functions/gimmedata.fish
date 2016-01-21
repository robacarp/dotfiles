function gimmedata
  cd /Users/robert/Sites/database-backups
  aws s3 cp --region us-west-2 (aws s3 cp s3://gloo-v2-production/latest_db_backup-noevents --region us-west-2 /dev/fd/1 ^ /dev/null | head -n 1) .
  psql polymer_development -c "drop schema public cascade; create schema public"
  gunzip --to-stdout (ls -1t *.sql.gz | head -n1)  | sed -e 's/gloo_production/polymer/' | psql polymer_development
  cd -
end
