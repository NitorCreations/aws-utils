#!/bin/bash -xe

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

image="$1" ; shift

source "infra.properties"
[ -e "${image}/infra.properties" ] && source "${image}/infra.properties"
[ -e "${image}/stack-${stack}/infra.properties" ] && source "${image}/stack-${stack}/infra.properties"

VAR_AMIID="AMIID_${IMAGETYPE}"
AMIID="${!VAR_AMIID}"

# Bake
cd ${image}/image
bash -x $WORKSPACE/aws-utils/bake-ami.sh $ami_id
for region in ${SHARE_REGIONS//,/ } ; do
  var_region_accounts=REGION_${region//-/_}_ACCOUNTS
  if [ ! "${!var_region_accounts}" ]; then
    echo "Missing setting '${var_region_accounts}' in infra.properties"
  bash -x $WORKSPACE/aws-utils/share-to-another-region.sh $(cat $WORKSPACE/ami-id.txt) ${region} $(cat $WORKSPACE/name.txt) ${!var_region_accounts}
done
