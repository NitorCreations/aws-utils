#!/bin/bash

PATH=$PATH:/usr/local/bin:/usr/bin:/bin

source /opt/nitor/ebs-functions.sh

# Usage fail message
fail() {
  echo $1
  exit 1
}

SNAPSHOT_LOOKUP_TAG_KEY=$1
SNAPSHOT_LOOKUP_TAG_VALUE=$2
MOUNT_PATH=$3

DEVICE=$(lsblk | egrep " $MOUNT_PATH\$" | awk '{ print "/dev/"$1 }')
VOLUME_ID=$(aws ec2 describe-volumes --output json --query "Volumes[*].Attachments[*]" | jq -r ".[]|.[]|select(.Device==\"$DEVICE\").InstanceId")

if ! create_snapshot $VOLUME_ID $SNAPSHOT_LOOKUP_TAG_KEY $SNAPSHOT_LOOKUP_TAG_VALUE; then
  fail $ERROR
fi
