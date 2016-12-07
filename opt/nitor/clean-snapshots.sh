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

containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}
declare -a TAGS
# Nitor infra tags to clean: amibakery-home confluence-data jenkins-home nexus-data nitor-gw-home
if [ "$#" -eq 0 ]; then
  echo "usage: $0 [tag1 [tag2] ...]"
  exit 1
else
  TAGS=( "$@" )
fi
DATESTAMP_30_DAYS_AGO=$(date -d '30 days ago' +%s)



RESPONSE=$(aws ec2 describe-snapshots --max-items 50 --page-size 50 --owner-ids self --filters Name=status,Values=completed)
NEXT_TOKEN=$(echo "$RESPONSE" | jq -r .NextToken)
while [ -n "$NEXT_TOKEN" ]; do
#  echo "$RESPONSE" | jq .Snapshots
  for SNAP in $(echo "$RESPONSE" | jq -r '.Snapshots[]|"\(.StartTime)~\(.SnapshotId)~\(.Tags[]|.Value)"' 2>/dev/null| sort -u); do
    DATE=$(echo $SNAP | cut -d~ -f1)
    ID=$(echo $SNAP | cut -d~ -f2)
    TAG=$(echo $SNAP | cut -d~ -f3)
    DATESTAMP=$(date -d "$DATE" +%s)
    if containsElement $TAG ${TAGS[@]} && [ "$DATESTAMP_30_DAYS_AGO" -gt "$DATESTAMP" ]; then
      echo DELETING $SNAP
      aws ec2 delete-snapshot --snapshot-id "$ID"
    else
      echo SKIPPING $SNAP
    fi
  done
  RESPONSE=$(aws ec2 describe-snapshots --max-items 50 --page-size 50 --owner-ids self --filters Name=status,Values=completed --starting-token "$NEXT_TOKEN")
  RETRY=0
  while ! echo "$RESPONSE" | jq -e -r .NextToken > /dev/null 2>&1 && [ "$RETRY" -lt 5 ]; do
    RESPONSE=$(aws ec2 describe-snapshots --max-items 50 --page-size 50 --owner-ids self --filters Name=status,Values=completed)
  done
  NEXT_TOKEN=$(echo "$RESPONSE" | jq -r .NextToken)
done
