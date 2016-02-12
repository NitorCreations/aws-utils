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

find_longest_hosted_zone() {
  local DOMAIN="$1"
  for ZONE in $(aws route53 list-hosted-zones | jq -r '.HostedZones[].Name'); do
    if [[ "$DOMAIN." =~ ${ZONE//./\\.}$ ]]; then
      echo ${#ZONE} $ZONE
    fi
  done | sort -n | tail -1 | cut -d" " -f2-
}
get_zone_id() {
  local ZONE="$1"
  aws route53 list-hosted-zones | jq -r ".HostedZones[]|select(.Name==\"$ZONE\").Id"
}

deploy_challenge() {
  local DOMAIN="$1"
  local TOKEN_FILENAME="$2"
  local TOKEN_VALUE="$3"
  ZONE=$(find_longest_hosted_zone $DOMAIN)
  ZONE_ID=$(get_zone_id $ZONE)
  aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "{
    \"Changes\": [
      {\"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
          \"Name\": \"_acme-challenge.$DOMAIN.\",
          \"Type\": \"TXT\",
          \"TTL\": 60,
          \"ResourceRecords\": [
            {\"Value\": \"$TOKEN_VALUE\"}
          ]
        }
      }
    ]
  }"
}

clean_challenge() {
  local DOMAIN="$1"
  local TOKEN_FILENAME="$2"
  local TOKEN_VALUE="$3"
  ZONE=$(find_longest_hosted_zone $DOMAIN)
  ZONE_ID=$(get_zone_id $ZONE)
  set -x
  aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "{
    \"Changes\": [
      {\"Action\": \"DELETE\",
      \"ResourceRecordSet\": {
          \"Name\": \"_acme-challenge.$DOMAIN.\",
          \"Type\": \"TXT\",
          \"TTL\": 60,
          \"ResourceRecords\": [
            {\"Value\": \"$TOKEN_VALUE\"}
          ]
        }
      }
    ]
  }"
}

deploy_cert() {
  local DOMAIN="$1"
  local KEYFILE="$2"
  local CERTFILE="$3"
  local CHAINFILE="$4"
  s3-role-download.sh nitor-infra-secure webmaster.pwd - | lastpass-login.sh webmaster@nitorcreations.com -
  lpass edit --non-interactive --notes Shared-Certs/$DOMAIN.crt < $CERTFILE
  lpass edit --non-interactive --notes Shared-Certs/$DOMAIN.key.clear < $KEYFILE
  lpass edit --non-interactive --notes Shared-Certs/$DOMAIN.chain < $CHAINFILE
  rm -f $KEYFILE $CERTFILE $CHAINFILE
}

HANDLER=$1; shift; $HANDLER $@
