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
ORIG_STACK_NAME="$1" ; shift

# by default, prefix stack name with branch name, to avoid accidentally using same names in different branches - override in infra-<branch>.properties to your liking. STACK_NAME and ORIG_STACK_NAME can be assumed to exist.
STACK_NAME="${GIT_BRANCH##*/}-${ORIG_STACK_NAME}"

infrapropfile="infra-${GIT_BRANCH##*/}.properties"

source "${infrapropfile}"
[ -e "${image}/${infrapropfile}" ] && source "${image}/${infrapropfile}"
[ -e "${image}/stack-${ORIG_STACK_NAME}/${infrapropfile}" ] && source "${image}/stack-${ORIG_STACK_NAME}/${infrapropfile}"

#export $(set | egrep -o '^param[a-zA-Z0-9_]+=' | tr -d '=') # export any param* variable defined in the infra-<branch>.properties files
#export paramAmi=$AMI_ID

aws-utils/cloudformation-delete-stack.py "${STACK_NAME}"
