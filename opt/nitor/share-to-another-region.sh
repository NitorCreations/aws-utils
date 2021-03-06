#!/bin/bash

# Copyright 2016-2017 Nitor Creations Oy
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

set -xe

SOURCE_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}')

if [ -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" ]; then
  echo "Usage: $0 <source-ami-id> <target-region> <target-name> <account> [<account> ...]"
fi
AMI_ID="$1"
shift
REGION="$1"
shift
NAME="$1"
shift
if [ "$SOURCE_REGION" = "$REGION" ]; then
  IMAGE_ID=$AMI_ID
else
  IMAGE_ID=$(aws --region "$REGION" ec2 copy-image --source-region "$SOURCE_REGION" --name "$NAME" --source-image-id "$AMI_ID" | jq -r ".ImageId")
fi
COUNTER=0
WAIT=3
while [  $COUNTER -lt 600 ] && [ "$IMAGE_STATUS" != "available" ]; do
  sleep $WAIT
  IMAGE_STATUS=$(aws --region "$REGION" ec2 describe-images --image-ids "$IMAGE_ID" | jq -r '.Images[0]|.State')
  echo "$(date +%Y-%m-%d-%H:%M:%S) Waiting for $IMAGE_ID to be available - status: $IMAGE_STATUS"
  COUNTER=$(($COUNTER + $WAIT))
done
if [ "$IMAGE_STATUS" != "available" ]; then
  echo "Image copying failed"
  exit 1
else
  echo "$(date +%Y-%m-%d-%H:%M:%S) sharing $IMAGE_ID with $@"
  DIR=$(cd $(dirname $0); pwd -P)
  IDS=$(create-userid-list "$@")
  aws --region "$REGION" ec2 modify-image-attribute --image-id "$IMAGE_ID" --launch-permission "$IDS"
fi
