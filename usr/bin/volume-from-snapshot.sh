#!/bin/bash

fail() {
  echo $1
  exit 1
}

source /opt/nitor/ebs-functions.sh
SNAPSHOT_LOOKUP_TAG_KEY=$1
SNAPSHOT_LOOKUP_TAG_VALUE=$2
MOUNT_PATH=$3
SIZE_GB=$4

if [ $# -lt 3 ]; then
  fail "Usage: $0 <tag key> <tag value> <mount path> [<empty volume size in gb>]"
fi

if ! SNAPSHOT_ID=$(find_latest_snapshot $SNAPSHOT_LOOKUP_TAG_KEY $SNAPSHOT_LOOKUP_TAG_VALUE); then
  if ! VOLUME_ID=$(create_empty_volume $SIZE_GB); then
    fail $ERROR
  fi
elif ! VOLUME_ID=$(create_volume $SNAPSHOT_ID); then
  fail $ERROR
fi

aws ec2 create-tags --resources $VOLUME_ID --tags Key=$SNAPSHOT_LOOKUP_TAG_KEY,Value=$SNAPSHOT_LOOKUP_TAG_VALUE

for LETTER in c d e f g h i; do
  if [ ! -e /dev/xvd$LETTER ]; then
    DEVICE=/dev/xvd$LETTER
    break
  fi
done

if [ -z "$DEVICE" ]; then
  fail "Free device not found."
fi

if ! attach_volume $VOLUME_ID $DEVICE; then
  fail $ERROR
fi

delete_on_termination $DEVICE
# set up cron snapshots

# mount volume
mkdir -p $MOUNT_PATH
mount $DEVICE $MOUNT_PATH
