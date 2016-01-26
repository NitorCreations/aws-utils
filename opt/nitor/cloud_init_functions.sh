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

set -e
: <<'EOF'

For required parameters, see end of this script.

Required template policies - please update all the Ref resource names as necessary!

  rolepolicyAllowCFNSignal:
    Type: AWS::IAM::Policy
    Properties:
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
        - Sid: AllowCFNSignal
          Effect: Allow
          Action: ['cloudformation:SignalResource']
          Resource: '*'
      PolicyName: allowCFNSignal
      Roles:
      - {Ref: roleResource}
  rolepolicyCloudWatch:
    Type: AWS::IAM::Policy
    Properties:
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
        - Effect: Allow
          Action: ['logs:CreateLogGroup', 'logs:CreateLogStream', 'logs:PutLogEvents', 'logs:DescribeLogStreams']
          Resource: ['arn:aws:logs:*:*:*']
      PolicyName: allowCloudWatch
      Roles:
      - {Ref: roleResource}
EOF

onexit_sendlogs () {
  local cloudwatch_log_group="instanceDeployment"
  aws logs create-log-group --log-group-name "${cloudwatch_log_group}" 2>&1 | grep -v ResourceAlreadyExistsException ||:
  aws logs create-log-stream --log-group-name "${cloudwatch_log_group}" --log-stream-name "${CF_AWS__StackName}" 2>&1 | grep -v ResourceAlreadyExistsException ||:
  logSeqId=$(aws logs describe-log-streams --log-group-name "${cloudwatch_log_group}" --log-stream-name "${CF_AWS__StackName}" | jq -r '.logStreams[0].uploadSequenceToken')
  [ "$logSeqId" != "null" ] && logSeqArg=--sequence-token || logSeqId=
  {
    date="$(date "+%F %T")"
    [ "${CF_paramAmiName}" ] && ami="${CF_paramAmiName}" || ami="${CF_paramAmi}"
    # template git commit sha would be nice also
    echo "${date} ${status} ${CF_AWS__StackName} ${ami}"
    cat /var/log/cloud-init-output.log
  } | jq -s -R '[{ timestamp: '`date +%s`'000, message: . }]' \
    | aws logs put-log-events --log-group-name "${cloudwatch_log_group}" --log-stream-name "${CF_AWS__StackName}" --log-events file:///dev/stdin $logSeqArg $logSeqId
}

onexit () {
  set +e
  if [ -x ./fetch-secrets.sh ]; then
    ./fetch-secrets.sh logout
  fi
  onexit_sendlogs
  aws --region ${CF_AWS__Region} cloudformation signal-resource --stack-name ${CF_AWS__StackName} --logical-resource-id resourceAsg --unique-id $INSTANCE_ID --status $status
}

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
trap onexit EXIT
status=FAILURE

if [ ! "${CF_AWS__StackName}" -o ! "${CF_paramAmi}" -o ! "${CF_AWS__Region}" ]; then # CF_paramAmiName may be empty so don't check for it
  echo Missing parameters - need CF_AWS__StackName, CF_paramAmi, CF_paramAmiName, CF_AWS__Region
  exit 1
fi
