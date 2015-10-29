function ips
 ifconfig | awk '$2 ~ /([0-9.]{7,15})/ && $2 !~ /^127/ { print $2 }'
end
