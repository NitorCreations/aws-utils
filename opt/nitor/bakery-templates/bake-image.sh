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

source aws-utils/source_infra_properties.sh "$image" ""

cd ${image}/image

VAR_AMI="AMIID_${IMAGETYPE}"
AMI="${!VAR_AMI}"

SSH_USER=$IMAGETYPE
FETCH_SECRETS=../../fetch-secrets.sh

DIR=$(cd $(dirname $0)/..; pwd -P)
TSTAMP=$(date +%Y%m%d%H%M%S)
cleanup() {
  eval $(ssh-agent -k)
}

if [ -z "$AWS_KEY_NAME" ]; then
  AWS_KEY_NAME=nitor-intra
fi
eval $(ssh-agent)
if [ -r "$HOME/.ssh/$AWS_KEY_NAME" ]; then
  ssh-add "$HOME/.ssh/$AWS_KEY_NAME"
elif [ -r "$HOME/.ssh/$AWS_KEY_NAME.pem" ]; then
  ssh-add "$HOME/.ssh/$AWS_KEY_NAME.pem"
elif [ -r "$HOME/.ssh/$AWS_KEY_NAME.rsa" ]; then
  ssh-add "$HOME/.ssh/$AWS_KEY_NAME.rsa"
else
  echo "Failed to find ssh private key"
  cleanup
  exit 1
fi
if [ -z "$AWSUTILS_VERSION" ]; then
  AWSUTILS_VERSION=0.58
fi
if [ -z "$BUILD_NUMBER" ]; then
  BUILD_NUMBER=$TSTAMP
else
  BUILD_NUMBER=$(printf "%04d\n" $BUILD_NUMBER)
fi
if [ -z "$WORKSPACE" ]; then
  WORKSPACE=$DIR
fi
if [ -z "$JOB_NAME" ]; then
  JOB_NAME="bake-$(basename $(cd ..; pwd))"
fi
if ! [ -r ./pre_install.sh ]; then
  echo -e "#!/bin/bash\n\nexit 0" > ./pre_install.sh
fi
if ! [ -r ./post_install.sh ]; then
  echo -e "#!/bin/bash\n\nexit 0" > ./post_install.sh
fi
touch ./packages.txt
PACKAGES="$($DIR/list-file-to-json.py packages ./packages.txt)"
if [ "$IMAGETYPE" = "ubuntu" ]; then
  touch ./repos.txt ./keys.txt
  REPOS="$($DIR/list-file-to-json.py repos ./repos.txt)"
  KEYS="$($DIR/list-file-to-json.py keys ./keys.txt)"
  extra_args=( -e "$REPOS" -e "$KEYS" )
else
  extra_args=( -e '{"repos": []}' -e '{"keys": []}' )
fi

JOB=$(echo $JOB_NAME | sed 's/\W/_/g' | tr '[:upper:]' '[:lower:]')
[ "${REGION}" ]
NAME="${JOB}_$BUILD_NUMBER"
AMI_TAG="$NAME"
echo "$AMI_TAG" > $WORKSPACE/ami-tag.txt
echo "$NAME" > $WORKSPACE/name.txt

ANSIBLE_FORCE_COLOR=true
ANSIBLE_HOST_KEY_CHECKING=false
export ANSIBLE_FORCE_COLOR ANSIBLE_HOST_KEY_CHECKING
rm -f ami.properties ||:
if python -u $(which ansible-playbook) -vvvv --flush-cache -i $DIR/inventory $DIR/bake-ami.yml \
  -e tools_version=$AWSUTILS_VERSION -e ami_tag=$AMI_TAG -e ami_id_file=$WORKSPACE/ami-id.txt \
  -e job_name=$JOB -e aws_key_name=$AWS_KEY_NAME -e app_user=$APP_USER \
  -e app_home=$APP_HOME -e build_number=$BUILD_NUMBER -e "$PACKAGES" \
  "${extra_args[@]}" -e root_ami=$AMI -e tstamp=$TSTAMP \
  -e aws_region=$REGION -e ansible_ssh_user=$SSH_USER \
  -e workdir="$(pwd -P)" -e fetch_secrets=$FETCH_SECRETS \
  -e subnet_id=$SUBNET -e sg_id=$SECURITY_GROUP; then

  echo "AMI_ID=$(cat $WORKSPACE/ami-id.txt)" > $WORKSPACE/ami.properties
  echo "NAME=$(cat $WORKSPACE/name.txt)" >> $WORKSPACE/ami.properties
  echo "SUCCESS"
  cat $WORKSPACE/ami.properties
  cleanup
  exit 0
else
  echo "AMI baking failed"
  cleanup
  exit 1
fi

if [ -n "${SHARE_REGIONS}" ]; then
  echo "--------------------- Share to ${SHARE_REGIONS}"
  for region in ${SHARE_REGIONS//,/ } ; do
    var_region_accounts=REGION_${region//-/_}_ACCOUNTS
    if [ ! "${!var_region_accounts}" ]; then
      echo "Missing setting '${var_region_accounts}' in ${infrapropfile}"
      exit 1
    fi
    $WORKSPACE/aws-utils/share-to-another-region.sh $(cat $WORKSPACE/ami-id.txt) ${region} $(cat $WORKSPACE/name.txt) ${!var_region_accounts}
  done
fi
