#!/bin/bash

# Set aws-cli region to the region of the current instance
set_region() {
  REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}')
  aws configure set default.region $REGION
}

# Find the latest snapshot with a tag key and value
# Usage: find_latest_snapshot tag_key tag_value
find_latest_snapshot() {
  set_region
  local SNAPSHOT_LOOKUP_TAG_KEY=$1
  local SNAPSHOT_LOOKUP_TAG_VALUE=$2
  local SNAPSHOT_ID=$(aws ec2 describe-snapshots --filter 'Name=tag:'$SNAPSHOT_LOOKUP_TAG_KEY',Values='$SNAPSHOT_LOOKUP_TAG_VALUE | jq -r '.[]|max_by(.StartTime)|.SnapshotId')
  local SNAPSHOT_STATUS=$(aws ec2 describe-snapshots --snapshot-ids $SNAPSHOT_ID | jq -r '.[]|.[]|.State')
  local COUNTER=0
  while [  $COUNTER -lt 180 ] && [ "$SNAPSHOT_STATUS" != "completed" ]; do
   sleep 1
   SNAPSHOT_STATUS=$(aws ec2 describe-snapshots --snapshot-ids $SNAPSHOT_ID | jq -r '.[]|.[]|.State')
   COUNTER=$(($COUNTER+1))
  done
  if [ $COUNTER -eq 180 ]; then
    ERROR="Latest data volume snapshot not in completed state!"
    return 1
  else
    echo "$SNAPSHOT_ID"
    return 0
  fi
}

# Create new volume from snapshot
# Usage: create_volume snapshot-id
create_volume() {
  local SNAPSHOT_ID=$1
  local AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
  local VOLUME_ID=$(aws ec2 create-volume --snapshot-id $SNAPSHOT_ID --availability-zone $AVAILABILITY_ZONE --volume-type gp2 | jq -r '.VolumeId')
  local VOLUME_STATUS=$(aws ec2 describe-volumes --volume-ids $VOLUME_ID | jq -r '.Volumes[].State')
  local COUNTER=0
  while [  $COUNTER -lt 180 ] && [ "$VOLUME_STATUS" != "available" ]; do
    sleep 1
    VOLUME_STATUS=$(aws ec2 describe-volumes --volume-ids $VOLUME_ID | jq -r '.Volumes[].State')
    COUNTER=$(($COUNTER+1))
  done
  if [ $COUNTER -eq 180 ]; then
    ERROR="Volume creation failed!"
    return 1
  else
    echo "$VOLUME_ID"
    return 0
  fi
}

# Attach volume
# Usage: attach_volume volume-id
attach_volume() {
  local VOLUME_ID=$1
  local DEVICE_PATH=$2
  local INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  local VOLUME_ATTACHMENT_STATUS=$(aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device $DEVICE_PATH | jq -r '.State')
  local COUNTER=0
  while [  $COUNTER -lt 180 ] && [ "$VOLUME_ATTACHMENT_STATUS" != "attached" ]; do
    sleep 1
    VOLUME_ATTACHMENT_STATUS=$(aws ec2 describe-volumes --volume-ids $VOLUME_ID | jq -r '.Volumes[].Attachments[].State')
    COUNTER=$(($COUNTER+1))
  done
  if [ $COUNTER -eq 180 ]; then
    ERROR="Volume attachment failed!"
    return 1
  else
    return 0
  fi
}

# Set volume to be deleted on instance termination. Snapshots will remain.
# Usage: delete_on_termination device-path
delete_on_termination() {
  local INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  local DEVICE_PATH=$1
  aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --block-device-mappings "[{\"DeviceName\": \"$DEVICE_PATH\",\"Ebs\":{\"DeleteOnTermination\":true}}]"
}

# Create snapshot from volume and tag it so it can be found by e.g. find_latest_snapshot
# For data consistency, it may be a good idea to unmount the volume first.
# Usage: create_snapshot volume_id tag_key tag_value
create_snapshot() {
  local VOLUME_ID=$1
  local TAG_KEY=$2
  local TAG_VALUE=$3
  local SNAPSHOT_ID=$(aws ec2 create-snapshot --volume-id $VOLUME_ID | jq -r '.SnapshotId')
  if [ "$SNAPSHOT_ID" != "" ]; then
    echo $SNAPSHOT_ID
  else
    ERROR="Snapshot creation failed!"
    return 1
  fi

  if ! $(aws ec2 create-tags --resources $SNAPSHOT_ID --tags Key=$TAG_KEY,Value=$TAG_VALUE Key=Name,Value=$TAG_VALUE); then
    ERROR="Tagging snapshot failed!"
    return 1
  fi
}

# Delete old snapshots tagged with a specific key/value. Keep a number of latest snapshots.
# Usage: delete_old_snapshots tag_key tag_value number_to_keep
delete_old_snapshots() {
  local SNAPSHOT_LOOKUP_TAG_KEY=$1
  local SNAPSHOT_LOOKUP_TAG_VALUE=$2
  local KEEP=$3
  local TO_DELETE
  if ! TO_DELETE=$(aws ec2 describe-snapshots --filter 'Name=tag:'$SNAPSHOT_LOOKUP_TAG_KEY',Values='$SNAPSHOT_LOOKUP_TAG_VALUE | jq -r '.[]|sort_by(.StartTime)|reverse|.['$KEEP':]|.[]|.SnapshotId'); then
    ERROR="Lookup for snapshots failed!"
    return 1
  fi
  local ERRORS=0
  for i in $TO_DELETE;
  do
    aws ec2 delete-snapshot --snapshot-id $i
    ERRORS=$(($ERRORS+$?))
  done
  return $ERRORS
}
