#!/bin/bash

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
