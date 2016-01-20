#!/bin/bash
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
