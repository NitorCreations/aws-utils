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

die () {
  echo "$@" >&2
  exit 1
}

image="$1" ; shift
[ "${image}" ] || die "You must give the image name as argument"

source aws-utils/source_infra_properties.sh "$image" ""

[ ! -d .cache ] || rm -rf .cache
mkdir .cache

cache () {
  cachefile=.cache/"${*// /_}"
  if [ -e "$cachefile" ]; then
    cat $cachefile
  else
    "$@" | tee $cachefile
  fi
}

# Set defaults if not customized

if ! [ "$SSH_USER" ]; then
  if [ "$IMAGETYPE" = "windows" ]; then
    SSH_USER="Administrator"
  else
    SSH_USER="$IMAGETYPE"
  fi
fi
if ! [ "$FETCH_SECRETS" ]; then
  if [ "$IMAGETYPE" = "windows" ]; then
    FETCH_SECRETS=fetch-secrets.bat
  else
    FETCH_SECRETS=fetch-secrets.sh
  fi
fi
[ "$NETWORK_STACK" ] || NETWORK_STACK=infra-network
[ "$NETWORK_PARAMETER" ] || NETWORK_PARAMETER=subnetInfraB
[ "$SUBNET" ] || SUBNET="$(cache show-stack-params-and-outputs.sh $REGION $NETWORK_STACK | jq -r .$NETWORK_PARAMETER)"
if ! [ "$SECURITY_GROUP" ]; then
  if [ "$IMAGETYPE" != "windows" ]; then
    SG_PARAM=".bakeInstanceSg"
  else
    SG_PARAM=".bakeWinInstanceSg"
  fi
  SECURITY_GROUP="$(cache show-stack-params-and-outputs.sh $REGION bakery-roles | jq -r $SG_PARAM)"
fi
[ "$AMIBAKE_INSTANCEPROFILE" ] || AMIBAKE_INSTANCEPROFILE="$(cache show-stack-params-and-outputs.sh $REGION bakery-roles | jq -r .bakeInstanceInstanceprofile)"
[ "$PAUSE_SECONDS" ] || PAUSE_SECONDS=15
for var in REGION SUBNET SECURITY_GROUP AMIBAKE_INSTANCEPROFILE ; do
  [ "${!var}" ] || die "Could not determine $var automatically. Please set ${var} manually in ${infrapropfile}"
done

for var in IMAGETYPE AWS_KEY_NAME paramAwsUtilsVersion APP_USER APP_HOME SSH_USER FETCH_SECRETS ; do
  [ "${!var}" ] || die "Please set ${var} in ${infrapropfile}"
done

imagedir=${image}/image

VAR_AMI="AMIID_${IMAGETYPE}"
AMI="${!VAR_AMI}"

[ "$AMI" ] || die "Please set AMIID_$IMAGETYPE in ${infrapropfile}"

TSTAMP=$(date +%Y%m%d%H%M%S)

cleanup() {
  if [ "$IMAGETYPE" != "windows" ]; then
    eval $(ssh-agent -k)
  fi
}
trap cleanup EXIT
if [ "$IMAGETYPE" != "windows" ]; then
  eval $(ssh-agent)
  if [ -r "$HOME/.ssh/$AWS_KEY_NAME" ]; then
    ssh-add "$HOME/.ssh/$AWS_KEY_NAME"
  elif [ -r "$HOME/.ssh/$AWS_KEY_NAME.pem" ]; then
    ssh-add "$HOME/.ssh/$AWS_KEY_NAME.pem"
  elif [ -r "$HOME/.ssh/$AWS_KEY_NAME.rsa" ]; then
    ssh-add "$HOME/.ssh/$AWS_KEY_NAME.rsa"
  else
    die "Failed to find ssh private key"
  fi
else
  WIN_PASSWD="$(tr -cd '[:alnum:]' < /dev/urandom | head -c16)"
  PASSWD_ARG="{\"ansible_ssh_pass\": \"$WIN_PASSWD\", \"ansible_winrm_operation_timeout_sec\": 60, \"ansible_winrm_read_timeout_sec\": 70, \"ansible_winrm_server_cert_validation\": \"ignore\"}"
fi

if [ -z "$BUILD_NUMBER" ]; then
  BUILD_NUMBER=$TSTAMP
else
  BUILD_NUMBER=$(printf "%04d\n" $BUILD_NUMBER)
fi
if [ -z "$JOB_NAME" ]; then
  JOB_NAME="${JENKINS_JOB_PREFIX}-${image}-bake"
fi
if [ "$IMAGETYPE" != "windows" ]; then
  if ! [ -r $imagedir/pre_install.sh ]; then
    echo -e "#!/bin/bash\n\nexit 0" > $imagedir/pre_install.sh
  fi
  if ! [ -r $imagedir/post_install.sh ]; then
    echo -e "#!/bin/bash\n\nexit 0" > $imagedir/post_install.sh
  fi
else
  if ! [ -r $imagedir/pre_install.ps1 ]; then
    echo -e "exit 0\r" > $imagedir/pre_install.ps1
  fi
  if ! [ -r $imagedir/post_install.ps1 ]; then
    echo -e "exit 0\r" > $imagedir/post_install.ps1
  fi
fi
touch $imagedir/packages.txt
PACKAGES="$(list-file-to-json packages $imagedir/packages.txt)"
touch $imagedir/files.txt
FILES="$(list-file-to-json files $imagedir/files.txt)"
if [ "$IMAGETYPE" = "ubuntu" ]; then
  touch $imagedir/repos.txt $imagedir/keys.txt
  REPOS="$(list-file-to-json repos $imagedir/repos.txt)"
  KEYS="$(list-file-to-json keys $imagedir/keys.txt)"
  extra_args=( -e "$REPOS" -e "$KEYS" )
else
  extra_args=( -e '{"repos": []}' -e '{"keys": []}' )
fi

JOB=$(echo $JOB_NAME | sed 's/\W/_/g' | tr '[:upper:]' '[:lower:]')
NAME="${JOB}_$BUILD_NUMBER"
AMI_TAG="$NAME"
echo "$AMI_TAG" > ami-tag.txt
echo "$NAME" > name.txt

export ANSIBLE_FORCE_COLOR=true
export ANSIBLE_HOST_KEY_CHECKING=false

if [ "$IMAGETYPE" = "windows" ]; then
  PLAYBOOK="aws-utils/bakery-templates/bake-win-image.yml"
else
  PLAYBOOK="aws-utils/bakery-templates/bake-image.yml"
fi
rm -f ami.properties ||:
if python -u $(which ansible-playbook) \
  -vvvv \
  --flush-cache \
  -i aws-utils/bakery-templates/bake-image-inventory \
  $PLAYBOOK \
  -e tools_version=$paramAwsUtilsVersion \
  -e ami_tag=$AMI_TAG \
  -e ami_id_file=$(pwd -P)/ami-id.txt \
  -e job_name=$JOB \
  -e aws_key_name=$AWS_KEY_NAME \
  -e app_user=$APP_USER \
  -e app_home=$APP_HOME \
  -e build_number=$BUILD_NUMBER \
  -e "$PACKAGES" \
  -e "$FILES" \
  "${extra_args[@]}" \
  -e root_ami=$AMI \
  -e tstamp=$TSTAMP \
  -e aws_region=$REGION \
  -e ansible_ssh_user=$SSH_USER \
  -e imagedir="$(realpath "${imagedir}")" \
  -e fetch_secrets="$(realpath "$FETCH_SECRETS")" \
  -e subnet_id=$SUBNET \
  -e sg_id=$SECURITY_GROUP \
  -e amibake_instanceprofile=$AMIBAKE_INSTANCEPROFILE \
  -e pause_seconds=$PAUSE_SECONDS \
  -e "$PASSWD_ARG"; then

  echo "AMI_ID=$(cat ami-id.txt)" > ami.properties
  echo "NAME=$(cat name.txt)" >> ami.properties
  echo "WIN_PASSWD=$WIN_PASSWD" >> ami.properties
  echo "Baking complete."
  cat ami.properties
else
  echo "AMI baking failed"
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
    aws-utils/share-to-another-region.sh $(cat ami-id.txt) ${region} $(cat name.txt) ${!var_region_accounts}
  done
fi
echo "SUCCESS"
