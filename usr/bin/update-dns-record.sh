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

fail() {
  echo $1
  exit 1
}
if [ -z "$1" -o -z "$2" -o -z "$3"]; then
  fail "Usage: $0 zone record.name ip.address"
else
  ZONE_NAME=$1
  NAME=$2
  IP=$3
fi

if ! ZONE_ID=$(aws route53 list-hosted-zones | jq -e -r ".HostedZones[]|select(.Name==\"${ZONE_NAME}\").Id"); then
  fail "Did not find requested zone"
fi
if ! CHANGE_ID=$(aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --cli-input-json "{\"HostedZoneId\":\"$ZONE_ID\",\"ChangeBatch\":
{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$NAME\",
\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"$IP\"}]}}]}}" | jq -e -r ".ChangeInfo.Id"); then
  fail "Failed to upsert DNS record"
fi
COUNT=0
while [ $COUNT -lt 180 ] && [ "$STATUS" != "INSYNC" ]; do
  sleep 1
  STATUS=$(aws route53 get-change --id "$CHANGE_ID" | jq  -r ".ChangeInfo.Status")
  COUNT=$((COUNT + 1))
done
if [ "$STATUS" != "INSYNC" ]; then
  fail "Failed to update private ip into DNS"
fi
