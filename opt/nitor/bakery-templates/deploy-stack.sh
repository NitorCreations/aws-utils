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

has_ami_parameter() {
  aws-utils/yaml_to_json.py "${image}/stack-${ORIG_STACK_NAME}/template.yaml" | jq -e .Parameters.paramAmi > /dev/null
}

image="$1" ; shift
stackName="$1" ; shift
AMI_ID="$1"
shift ||:
imagejob="$1"
shift ||:

source aws-utils/source_infra_properties.sh "$image" "$stackName"

if [ ! "$AMI_ID" ] && has_ami_parameter; then
  if [ "$imagejob" ]; then
    JOB=$(echo $imagejob | sed 's/\W/_/g' | tr '[:upper:]' '[:lower:]')
    AMI_ID="$(aws ec2 describe-images --region=$REGION --filters "Name=name,Values=${JOB}*" | jq -r ".Images[] | .Name + \"=\" + .ImageId" | grep "^${JOB}_[0-9][0-9][0-9][0-9]=" | sort | tail -1 | cut -d= -f 2)"
    if [ ! "$AMI_ID" ]; then
      echo "AMI_ID job parameter not defined and value could not be determined from parent bake job - aborting"
      exit 1
    fi
  else
    echo "AMI_ID job parameter not defined and no bake job name given - aborting"
    exit 1
  fi
  echo "Using AMI_ID $AMI_ID from last successful bake"
else
  echo "Using AMI_ID $AMI_ID given as job parameter"
fi

export $(set | egrep -o '^param[a-zA-Z0-9_]+=' | tr -d '=') # export any param* variable defined in the infra-<branch>.properties files
export paramAmi=$AMI_ID

#If assume-deploy-role.sh is on the path, run it to assume the appropriate role for deployment
if which assume-deploy-role.sh > /dev/null; then
  eval $(assume-deploy-role.sh)
fi

aws-utils/cloudformation-update-stack.py "${STACK_NAME}" "${image}/stack-${ORIG_STACK_NAME}/template.yaml" "$REGION"
