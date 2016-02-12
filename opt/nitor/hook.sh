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

execute_challenge_op() {
  local OPERATION="$1"
  local DOMAIN="$2"
  local TOKEN_FILENAME="$3"
  local TOKEN_VALUE="$4"
  ZONE=$(find_longest_hosted_zone $DOMAIN)
  ZONE_ID=$(get_zone_id $ZONE)
cat > challenge.json << MARKER
{
  "Changes": [{
    "Action": "$OPERATION",
    "ResourceRecordSet": {
    "Name": "_acme-challenge.$DOMAIN.",
    "Type": "TXT",
    "TTL": 60,
    "ResourceRecords": [
       {"Value": "\"$TOKEN_VALUE\""}
      ]
    }
  }
 ]
}
MARKER
  if ! CHANGE_ID=$(aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://challenge.json | jq -e -r ".ChangeInfo.Id"); then
    echo "$OPERATION failed"
    return 1
  else
    COUNTER=0
    while [ "$COUNTER" -lt 180 ] && [ "$STATUS" != "INSYNC" ]; do
      sleep 1
      STATUS=$(aws route53 get-change --id $CHANGE_ID | jq -r ".ChangeInfo.Status")
      COUNTER=$(($COUNTER + 1))
    done
    if [ "$STATUS" != "INSYNC" ]; then
      echo "Failed to sync $OPERATION change"
      return 1
    fi
    return 0
  fi
}

deploy_challenge() {
  execute_challenge_op "UPSERT" "$@"
}

clean_challenge() {
  execute_challenge_op "DELETE" "$@"
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
  #rm -f $KEYFILE $CERTFILE $CHAINFILE
}
HANDLER=$1; shift; $HANDLER $@
