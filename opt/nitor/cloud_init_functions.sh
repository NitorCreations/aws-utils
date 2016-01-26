#!/bin/bash

set -e

onexit_sendlogs () {
  : <<'EOF'
  Required policy in template - please update the Ref on the last line if necessary:

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
