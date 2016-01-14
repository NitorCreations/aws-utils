#!/bin/bash

if [ -z "$1" -o -z "$2" ]; then
  echo "Usage: $0 <conf-file> <domain>"
fi
generate-dummy-certs.sh $2
sed -i "s/%domain%/$2/g" $1
if which systemctl > /dev/null; then
  systemctl enable httpd
  systemctl start httpd
else
  rm /etc/init/apache2.override
  service apache2 start
fi
/opt/letsencrypt/letsencrypt-auto certonly --agree-tos --webroot --renew-by-default -w /var/www/$1 -d $1
