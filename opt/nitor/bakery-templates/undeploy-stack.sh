#!/bin/bash

# Copyright 2016-2017 Nitor Creations Oy
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

image="$1" ; shift
stackName="$1" ; shift

source aws-utils/source_infra_properties.sh "$image" "$stackName"

#If assume-deploy-role.sh is on the path, run it to assume the appropriate role for deployment
if which assume-deploy-role.sh > /dev/null && [ -z "$AWS_SESSION_TOKEN" ]; then
  eval $(assume-deploy-role.sh)
fi

# Delete will faul if S3 buckets have data - so delete those...
for BUCKET in $(aws --region $REGION cloudformation list-stack-resources --stack-name ${STACK_NAME} \
 | jq -r '.StackResourceSummaries[] | select(.ResourceType=="AWS::S3::Bucket")|.PhysicalResourceId'); do
   aws s3 rm s3://$BUCKET --recursive
done

cf-delete-stack "${STACK_NAME}" "$REGION"
