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

die () {
  echo "$@" >&2
  exit 1
}

unset SSH_AUTH_SOCK
unset SSH_AGENT_PID
cleanup() {
  if [ -n "$TMP" ]; then
    rm -f $TMP
  fi
  if [ -n "$SSH_AGENT_PID" ]; then
    if [ -z "$IOTMP" ]; then
      IOTMP=$(mktemp)
    fi
    eval $(ssh-agent -k) > $IOTMP
  fi
  if [ -n "$IOTMP" ]; then
    rm -f $IOTMP
  fi
}
trap cleanup EXIT
IOTMP=$(mktemp)

image="$1" ; shift
[ "${image}" ] || die "You must give the image name as argument"
imagedir=${image}/image

source aws-utils/source_infra_properties.sh "$image" "$stackName"
if ! [ -r "$FETCH_SECRETS" ]; then
  echo "Fetch secrets not defined"
  exit 1
fi

export OPC_API OPC_USER=$CONTAINER/$ORACLE_USER
[ "$SSH_USER" ] || SSH_USER=$IMAGE_TYPE
lpass show --password $ORACLE_USER > .passwd
chmod 600 .passwd
eval $(oracle-compute auth $CONTAINER/$ORACLE_USER .passwd)
rm -f .passwd

[ "$BUILD_NUMBER" ] || BUILD_NUMBER=$(date +%s)
BAKE_ID=bake_${image}_$BUILD_NUMBER
IMAGE_VAR="IMAGE_ID_$IMAGE_TYPE"

INSTANCE_JSON=$(mktemp)
VOLUME_JSON=$(mktemp)
MASTER_JSON=$(mktemp)
jq -n --arg BAKE_ID "$BAKE_ID" --arg SSH_KEY "$SSH_KEY" \
  --arg IMAGE_ID "${!IMAGE_VAR}" \
  --arg SECURITY_GROUP "$SECURITY_GROUP" \
  --arg CONTAINER "$CONTAINER" \
  --arg ORACLE_USER "$ORACLE_USER" \
  "$(cat aws-utils/bakery-templates/opc-instance.json)" > $INSTANCE_JSON
jq -n --arg BAKE_ID "$BAKE_ID" --arg SSH_KEY "$SSH_KEY" \
  --arg IMAGE_ID "${!IMAGE_VAR}" \
  --arg SECURITY_GROUP "$SECURITY_GROUP" \
  --arg CONTAINER "$CONTAINER" \
  --arg ORACLE_USER "$ORACLE_USER" \
  "$(cat aws-utils/bakery-templates/opc-volume.json)" > $VOLUME_JSON
jq -n --arg BAKE_ID "$BAKE_ID" --arg SSH_KEY "$SSH_KEY" \
  --arg IMAGE_ID "${!IMAGE_VAR}" \
  --arg SECURITY_GROUP "$SECURITY_GROUP" \
  --arg CONTAINER "$CONTAINER" \
  --arg ORACLE_USER "$ORACLE_USER" \
  "$(cat aws-utils/bakery-templates/opc-master.json)" > $MASTER_JSON

oracle-compute -f json add orchestration $INSTANCE_JSON
oracle-compute -f json add orchestration $VOLUME_JSON
oracle-compute -f json add orchestration $MASTER_JSON

oracle-compute -f json start orchestration "$CONTAINER/$ORACLE_USER/orchestration_master_$BAKE_ID"

START=$(date +%s)
while ! INSTANCE_JSON="$(oracle-compute -f json list orchestration $CONTAINER --status ready | jq -e ".list[]|select(.name==\"$CONTAINER/$ORACLE_USER/orchestration_instance_$BAKE_ID\")")"; do
  sleep 5;
  ELAPSED=$(($(date +%s) - $START))
  if [ "$ELAPSED" -gt 600 ]; then
    echo "Failed to start orchestration"
    exit 1
  fi
done
INSTANCE_NAME="$(echo "$INSTANCE_JSON" | jq -r '.oplans[]|.objects[]|.instances[]|.name')"
VCABLE_ID="$(oracle-compute get instance $INSTANCE_NAME -F vcable_id -H)"
PUBLIC_IP="$(oracle-compute list ipassociation $CONTAINER --vcable $VCABLE_ID -F ip -H)"

if  ! eval "$(ssh-agent)" > $IOTMP; then
  echo "Failed to start ssh agent"
  cat $IOTMP
  exit 1
fi

KEY_NAME="$(basename $SSH_KEY).rsa"
if ! lpass show --notes $KEY_NAME | ssh-add - > $IOTMP 2>&1; then
  echo "Failed to add key"
  cat $IOTMP
  exit 1
fi

SSH_OPTS="-o TCPKeepAlive=yes -o ServerAliveInterval=3 -o ServerAliveCountMax=10 -o ConnectTimeout=5 -o StrictHostKeyChecking=no"

START=$(date +%s)
while ! ssh $SSH_OPTS $SSH_USER@$PUBLIC_IP true; do
  sleep 5
  if [ "$ELAPSED" -gt 600 ]; then
    echo "Failed to start orchestration"
    exit 1
  fi
done

#Install aws-utils
SCRIPT=$(echo '#!/bin/bash -x
update-locale LC_ALL=en_US.UTF-8
wget -O - https://github.com/NitorCreations/aws-utils/archive/master.tar.gz | tar -xzf - --strip 1 -C /
' | ssh $SSH_OPTS $SSH_USER@$PUBLIC_IP 'RUN=`mktemp -p /tmp runit.sh.XXXXX`; cat > $RUN; chmod a+rx $RUN; echo $RUN')

if [ -z "$SCRIPT" ]; then
  echo "Failed to create script"
  exit 1
fi
ssh $SSH_OPTS -tt $SSH_USER@$PUBLIC_IP sudo -u root $SCRIPT
ssh $SSH_OPTS -tt $SSH_USER@$PUBLIC_IP sudo -u root rm -f $SCRIPT


#Install fetch secrets
scp $SSH_OPTS $FETCH_SECRETS $SSH_USER@$PUBLIC_IP:fetch-secrets.sh
ssh $SSH_OPTS $SSH_USER@$PUBLIC_IP 'FETCH_SECRETS=$HOME/fetch-secrets.sh; sudo -u root mv $FETCH_SECRETS /usr/bin/fetch-secrets.sh; sudo -u root chmod 755 /usr/bin/fetch-secrets.sh'

SCRIPT=$(cat ${imagedir}/pre_install.sh | ssh $SSH_OPTS $SSH_USER@$PUBLIC_IP 'RUN=`mktemp -p /tmp runit.sh.XXXXX`; cat > $RUN; chmod a+rx $RUN; echo $RUN')
if [ -z "$SCRIPT" ]; then
  echo "Failed to create script"
  exit 1
fi
ssh $SSH_OPTS -tt $SSH_USER@$PUBLIC_IP sudo -u root $SCRIPT
ssh $SSH_OPTS -tt $SSH_USER@$PUBLIC_IP sudo -u root rm -f $SCRIPT

#Install packages
if [ "$IMAGE_TYPE" = "centos" ]; then
  INSTALL_COMMAND="yum"
  UPDATE_COMMAND="yum update -y"
elif [ "$IMAGE_TYPE" = "ubuntu" ]; then
  INSTALL_COMMAND="apt-get"
  UPDATE_COMMAND="apt-get update; apt-get upgrade -y"
else
  echo "Unknown image type $IMAGE_TYPE"
  exit 1
fi
PACKAGES=$(cat ${imagedir}/packages.txt | tr "\n" " ")
SCRIPT=$(echo -e "#!/bin/bash -x\n\n$UPDATE_COMMAND\n$INSTALL_COMMAND install -y $PACKAGES" | ssh $SSH_OPTS $SSH_USER@$PUBLIC_IP 'RUN=`mktemp -p /tmp runit.sh.XXXXX`; cat > $RUN; chmod a+rx $RUN; echo $RUN')
if [ -z "$SCRIPT" ]; then
  echo "Failed to create script"
  exit 1
fi
ssh $SSH_OPTS -tt $SSH_USER@$PUBLIC_IP sudo -u root $SCRIPT
ssh $SSH_OPTS -tt $SSH_USER@$PUBLIC_IP sudo -u root rm -f $SCRIPT

SCRIPT=$(cat ${imagedir}/post_install.sh | ssh $SSH_OPTS $SSH_USER@$PUBLIC_IP 'RUN=`mktemp -p /tmp runit.sh.XXXXX`; cat > $RUN; chmod a+rx $RUN; echo $RUN')
if [ -z "$SCRIPT" ]; then
  echo "Failed to create script"
  exit 1
fi
ssh $SSH_OPTS -tt $SSH_USER@$PUBLIC_IP sudo -u root $SCRIPT
ssh $SSH_OPTS -tt $SSH_USER@$PUBLIC_IP sudo -u root rm -f $SCRIPT

oracle-compute add snapshot $INSTANCE_NAME --machineimage $CONTAINER/$ORACLE_USER/$BAKE_ID --delay=shutdown

./aws-utils/opc-stopdelete.sh $BAKE_ID
