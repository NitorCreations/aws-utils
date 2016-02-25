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

if [ -z "$1" ]; then
  echo "usage: $0 <domain-name>"
  exit 1
fi
DOMAIN="$1"
RENEW_DAYS="30"
if [ -z "$CERT_DIR" ]; then
  CERT_DIR=/etc/certs
fi

CERT=$CERT_DIR/$DOMAIN.crt

renew_cert() {
  local DOMAIN="$1"
  letsencrypt.sh --cron --hook /opt/nitor/hook.sh --challenge dns-01 --domain "$DOMAIN"
}

if /opt/nitor/fetch-secrets.sh get 444 $CERT; then
  VALID="$(openssl x509 -enddate -noout -in "$CERT" | cut -d= -f2- )"
  echo "Valid: $VALID"
  if ! openssl x509 -checkend $((RENEW_DAYS * 86400)) -noout -in "$CERT"; then
    renew_cert $DOMAIN
  fi
else
  renew_cert $DOMAIN
fi
