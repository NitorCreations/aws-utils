#!/bin/bash

DIR=$(cd $(dirname $0); pwd -P)
TSTAMP=$(date +%Y%m%d%H%M%S)

if [ -z "$BUILD_NUMBER" ]; then
  BUILD_NUMBER=$TSTAMP
else
  BUILD_NUMBER=$(printf "%04d\n" $BUILD_NUMBER)
fi
if [ -z "$WORKSPACE" ]; then
  WORKSPACE=$DIR
fi
if [ -z "$JOB_NAME" ]; then
  JOB_NAME="bake-$(basename $(pwd))"
fi
if [ -n "$1" ]; then
  AMI="$1"
else
  AMI="ami-e4ff5c93"
fi
if ! [ -r ./pre_install.sh ]; then
  echo -e "#!/bin/bash\n\nexit 0" > ./pre_install.sh
fi
if ! [ -r ./post_install.sh ]; then
  echo -e "#!/bin/bash\n\nexit 0" > ./post_install.sh
fi
touch ./packages.txt
PACKAGES="$($DIR/list-file-to-json.py packages ./packages.txt)"
JOB=$(echo $JOB_NAME | sed 's/\W/_/g' | tr '[:upper:]' '[:lower:]')
NAME="${JOB}_$BUILD_NUMBER"
AMI_TAG="$NAME"
echo "$AMI_TAG" > ami-tag.txt
echo "$NAME" > name.txt

export ANSIBLE_FORCE_COLOR=true

ansible-playbook -vvvv --flush-cache -i inventory $DIR/bake-ami.yml \
  -e ami_tag=$AMI_TAG -e ami_id_file=$WORKSPACE/ami-id.txt \
  -e job_name=$JOB -e aws_key_name=nitor-intra -e app_user=$APP_USER \
  -e app_home=$APP_HOME -e build_number=$BUILD_NUMBER -e "$PACKAGES" \
  -e root_ami=$AMI -e tstamp=$TSTAMP

echo "AMI_ID=$(cat ami-id.txt)" > ami.properties
echo "NAME=$(cat name.txt)" >> ami.properties
