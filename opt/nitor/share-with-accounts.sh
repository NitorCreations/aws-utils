#!/bin/bash

if [ -z "$1" -o -z "$2" ]; then
  echo "usage: $0 ami-id account-id [account-id ...]"
  exit 1
fi
AMI_ID=$1
shift
DIR=$(cd $(dirname $0); pwd -P)
IDS=$($DIR/create-userid-list.py "$@")
aws ec2 modify-image-attribute --image-id $AMI_ID --launch-permission "$IDS"
