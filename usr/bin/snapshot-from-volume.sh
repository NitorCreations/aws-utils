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
VOLUME_ID=$(aws ec2 describe-volumes --output json --query "Volumes[*].Attachments[*]" | jq -r ".[]|.[]|select(.Device==\"$DEVICE\").VolumeId")

if ! create_snapshot $VOLUME_ID $SNAPSHOT_LOOKUP_TAG_KEY $SNAPSHOT_LOOKUP_TAG_VALUE; then
  fail $ERROR
fi
