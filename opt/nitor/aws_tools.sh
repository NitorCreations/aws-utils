#!/bin/bash -e

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

source "$(dirname "${BASH_SOURCE[0]}")/common_tools.sh"

# Required parameters: CF_AWS__Region, INSTANCE_ID
# Optional parameters: CF_paramEipAllocationId
# Required template policies: ec2:AssociateAddress
aws_ec2_associate_address () {
  check_parameters CF_AWS__Region INSTANCE_ID
  if [ ! "$CF_paramEipAllocationId" ]; then
    echo "IP address not associated -- Elastic IP allocation id not configured"
  elif ! aws --region "${CF_AWS__Region}" ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "${CF_paramEipAllocationId}" --allow-reassociation; then
    echo "IP address association failed!"
    exit 1
  fi
}

# Required parameters: CF_AWS__Region, CF_AWS__StackName
aws_install_metadata_files () {
  check_parameters CF_AWS__StackName CF_AWS__Region
  cfn-init -v --stack "${CF_AWS__StackName}" --resource resourceLc --region "${CF_AWS__Region}"
}

update_aws_utils () {
  if [ "${CF_paramAwsUtilsVersion}" ]; then
    echo "Updating aws-utils to version ${CF_paramAwsUtilsVersion}"
    UTILS_VERSION=${CF_paramAwsUtilsVersion}-ubuntu
    wget -O - https://github.com/NitorCreations/aws-utils/archive/\$UTILS_VERSION.tar.gz | tar -xzf - --strip 1 -C /
  fi
}
