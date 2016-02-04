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

image="$1" ; shift
stack="$1" ; shift
AMI_ID="$1" ; shift
imagejob="$1" ; shift

source "infra.properties"
[ -e "${image}/infra.properties" ] && source "${image}/infra.properties"
[ -e "${image}/stack-${stack}/infra.properties" ] && source "${image}/stack-${stack}/infra.properties"

if [ ! "$AMI_ID" ]; then
  AMI_ID="$(curl -fs "http://localhost:8080/job/${imagejob}/lastSuccessfulBuild/artifact/ami-id.txt")"
  if [ ! "$AMI_ID" ]; then
    echo "AMI_ID job parameter not defined and value could not be determined from parent bake job - aborting"
    exit 1
  fi
  echo "Using AMI_ID $AMI_ID from last successful bake"
else
  echo "Using AMI_ID $AMI_ID given as job parameter"
fi

aws-utils/cloudformation-update-stack.py "${stack}" "${image}/stack-${stack}/template.yaml" $AMI_ID
