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

set -xe

if [ -z "$1" -o -z "$2" ]; then
  echo "usage: $0 ami-id account-id [account-id ...]"
  exit 1
fi
AMI_ID=$1
shift
DIR=$(cd $(dirname $0); pwd -P)
IDS=$($DIR/create-userid-list.py "$@")
aws ec2 modify-image-attribute --image-id $AMI_ID --launch-permission "$IDS"
