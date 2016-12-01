function g_fetchdb
	aws s3 cp --region us-west-2 (aws s3 cp s3://gloo-v2-production/latest_db_backup-noevents --region us-west-2 /dev/fd/1 ^ /dev/null | head -n 1) .
end
