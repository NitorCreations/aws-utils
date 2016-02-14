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

infrapropfile="infra-${GIT_BRANCH##*/}.properties"

source "${infrapropfile}"
[ -e "${image}/${infrapropfile}" ] && source "${image}/${infrapropfile}"

VAR_AMIID="AMIID_${IMAGETYPE}"
AMIID="${!VAR_AMIID}"

# Bake
cd ${image}/image
export APP_HOME APP_USER AWSUTILS_VERSION AWS_KEY_NAME
SSH_USER=$IMAGETYPE
$WORKSPACE/aws-utils/bake-ami.sh $AMIID $IMAGETYPE $SSH_USER ../../fetch-secrets.sh

echo "--------------------- Share to ${SHARE_REGIONS}"
for region in ${SHARE_REGIONS//,/ } ; do
  var_region_accounts=REGION_${region//-/_}_ACCOUNTS
  if [ ! "${!var_region_accounts}" ]; then
    echo "Missing setting '${var_region_accounts}' in ${infrapropfile}"
    exit 1
  fi
  $WORKSPACE/aws-utils/share-to-another-region.sh $(cat $WORKSPACE/ami-id.txt) ${region} $(cat $WORKSPACE/name.txt) ${!var_region_accounts}
done
