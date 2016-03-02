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
ORIG_STACK_NAME="$1" ; shift
AMI_ID="$1"
shift ||:
imagejob="$1"
shift ||:

# by default, prefix stack name with branch name, to avoid accidentally using same names in different branches - override in infra-<branch>.properties to your liking. STACK_NAME and ORIG_STACK_NAME can be assumed to exist.
STACK_NAME="${GIT_BRANCH##*/}-${ORIG_STACK_NAME}"

infrapropfile="infra-${GIT_BRANCH##*/}.properties"

REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}')

source "${infrapropfile}"
[ -e "${image}/${infrapropfile}" ] && source "${image}/${infrapropfile}"
[ -e "${image}/stack-${ORIG_STACK_NAME}/${infrapropfile}" ] && source "${image}/stack-${ORIG_STACK_NAME}/${infrapropfile}"

if [ ! "$AMI_ID" ] && has_ami_parameter; then
  JOB=$(echo $imagejob | sed 's/\W/_/g' | tr '[:upper:]' '[:lower:]')
  AMI_ID="$(aws ec2 describe-images --region=$REGION --owners=self | jq -r ".Images[] | .Name + \"=\" + .ImageId" | grep "^${JOB}_[0-9][0-9][0-9][0-9]=" | sort | tail -1 | cut -d= -f 2)"
  if [ ! "$AMI_ID" ]; then
    echo "AMI_ID job parameter not defined and value could not be determined from parent bake job - aborting"
    exit 1
  fi
  echo "Using AMI_ID $AMI_ID from last successful bake"
else
  echo "Using AMI_ID $AMI_ID given as job parameter"
fi

export $(set | egrep -o '^param[a-zA-Z0-9_]+=' | tr -d '=') # export any param* variable defined in the infra-<branch>.properties files
export paramAmi=$AMI_ID

aws-utils/cloudformation-update-stack.py "${STACK_NAME}" "${image}/stack-${ORIG_STACK_NAME}/template.yaml" "$REGION"
