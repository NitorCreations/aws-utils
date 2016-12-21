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

onexit () {
  echo -----------------------------------------------------------------
  set +e
  if [ -x /opt/nitor/fetch-secrets.sh ]; then
    /opt/nitor/fetch-secrets.sh logout
  fi
  signal-cf-status $status
  kill $LOG_TAILER
}

trap onexit EXIT
status=FAILURE
logs-to-cloudwatch /var/log/cloud-init-output.log &
LOG_TAILER=$!

[ "${INSTANCE_ID}" ] || INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
