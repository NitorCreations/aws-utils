#!/bin/bash -e

if [ -z "$1" ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi
NOW=$(date +%s)
TWO_WEEK_SEC=$((14 * 24 * 3600))
MONTH_SEC=$((30 * 24 * 3600))
ENDDATE=$(openssl x509 -in /etc/letsencrypt/live/$1/cert.pem -noout -enddate | cut -d= -f2)
SEC=$(date --date="$ENDDATE" +%s)
TIME_TO_RENEW=$(($SEC - $NOW))
if [ $TIME_TO_RENEW -lt $TWO_WEEK_SEC ]; then
  /opt/letsencrypt/letsencrypt-auto certonly --agree-tos --webroot --renew-by-default -w /var/www/$1 -d $1
fi
