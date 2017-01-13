#!/bin/bash -e

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

source "$(dirname "${BASH_SOURCE[0]}")/common_tools.sh"

configure_and_start_nexus () {
  check_parameters CF_paramDnsName CF_paramSonatypeWorkSize
  volume-from-snapshot.sh nexus-data nexus-data /opt/nexus/sonatype-work ${CF_paramSonatypeWorkSize}
  chown -R nexus:nexus /opt/nexus/sonatype-work

  if ! [ -r /opt/nexus/sonatype-work/nexus/conf/security.xml ]; then
    SECTMP=$(mktemp -d)
    mount tmpfs $SECTMP -t tmpfs -o size=32m
    chmod 700 $SECTMP
    touch .repo.pwd
    chown 600 .repo.pwd
    /opt/nitor/fetch-secrets.sh show ${CF_paramDnsName} | tr -d "\n" > .repo.pwd
    mkdir -p /opt/nexus/sonatype-work/nexus/conf
    wget http://central.maven.org/maven2/org/apache/shiro/tools/shiro-tools-hasher/1.2.4/shiro-tools-hasher-1.2.4-cli.jar
    ADMIN_HASH=$(java -jar shiro-tools-hasher-1.2.4-cli.jar -r .repo.pwd -a SHA-512 -f shiro1)
    cd $HOME
    umount -f $SECTMP
    if [ "$(set -o | grep xtrace | awk '{ print $2 }')" = "on" ]; then
      set +x
      RESET_XTRACE="true"
    fi
    sed -e 's#%ADMIN_HASH%#'"$ADMIN_HASH"'#g' -e 's/%domain%/'"${CF_paramDnsName#*.}"'/g' /root/security.xml > /opt/nexus/sonatype-work/nexus/conf/security.xml
    if [ "$RESET_XTRACE" ]; then
      unset RESET_XTRACE
      set -x
    fi
    chown -R nexus:nexus /opt/nexus
  fi
  sed -i 's#localhost\:8080#localhost\:8081#' /etc/httpd/conf.d/ssl.conf
  systemctl enable nexus
  systemctl start nexus
}

nexus_wait_service_up () {
  # Tests to see if everything is OK
  COUNT=0
  while [ $COUNT -lt 300 ] && [ "$SERVER" != "Sonatype" ]; do
    sleep 1
    SERVER=$(curl -Ls http://localhost:8081 | grep -o Sonatype | head -1)
    COUNT=$(($COUNT + 1))
  done
  if [ "$SERVER" != "Sonatype" ]; then
    fail "Maven repository server not started"
  fi
}

nexus_setup_snapshot_cron () {
  cat > /etc/cron.d/home-snapshot << MARKER
30 * * * * root /usr/bin/snapshot-from-volume.sh nexus-data nexus-data /opt/nexus/sonatype-work >> /var/log/snapshots.log 2>&1
MARKER
}
