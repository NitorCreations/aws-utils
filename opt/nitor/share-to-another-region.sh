#!/bin/bash

if [ -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" ]; then
  echo "Usage: $0 <ami-id> <region> <name> <account> [<account> ...]"
fi
AMI_ID=$1
shift
REGION=$1
shift
NAME=$1
shift
IMAGE_ID=$(aws --region "$REGION" ec2 copy-image --source-region eu-west-1 --name "$NAME" --source-image-id "$AMI_ID" | jq -r ".ImageId")
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
  IDS=$($DIR/create-userid-list.py "$@")
  aws --region "$REGION" ec2 modify-image-attribute --image-id "$IMAGE_ID" --launch-permission "$IDS"
fi
