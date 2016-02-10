#!/bin/bash -e

# Copyright 2016 Nitor Creations Oy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ -z "$1" -o -z "$2" ]; then
  echo "Usage: $0 <domain> <admin-email>"
  exit 1
fi
PATH=/usr/sbin:/usr/bin:/sbin:/bin
NOW=$(date +%s)
TWO_WEEK_SEC=$((14 * 24 * 3600))
MONTH_SEC=$((30 * 24 * 3600))
ENDDATE=$(openssl x509 -in /etc/letsencrypt/live/$1/cert.pem -noout -enddate | cut -d= -f2)
SEC=$(date --date="$ENDDATE" +%s)
TIME_TO_RENEW=$(($SEC - $NOW))
if [ $TIME_TO_RENEW -lt $TWO_WEEK_SEC ]; then
  /opt/letsencrypt/letsencrypt-auto certonly --webroot -w "/var/www/$1" --agree-tos --email "$2" --renew-by-default -d "$1"
fi
