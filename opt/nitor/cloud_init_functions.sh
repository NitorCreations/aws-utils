#!/bin/bash

set -e
onexit () {
  if [ -x ./fetch-secrets.sh ]; then
    ./fetch-secrets.sh logout
  fi
  aws --region ${CF_AWS__Region} cloudformation signal-resource --stack-name ${CF_AWS__StackName} --logical-resource-id resourceAsg --unique-id $INSTANCE_ID --status $status
}
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
trap onexit EXIT
status=FAILURE
