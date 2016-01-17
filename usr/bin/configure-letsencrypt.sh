#!/bin/bash

if [ -z "$1" -o -z "$2" -o -z "$3" ]; then
  echo "Usage: $0 <conf-file> <domain> <email>"
fi

sed -i "s/%domain%/$2/g" $1
mkdir -p /var/www/$2
restorecon -Rv /var/www
/opt/letsencrypt/letsencrypt-auto certonly --email $3 --agree-tos --renew-by-default --standalone -d $2
if which systemctl > /dev/null; then
  systemctl enable httpd
  systemctl start httpd
else
  rm /etc/init/apache2.override
  service apache2 start
fi
