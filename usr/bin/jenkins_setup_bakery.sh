#!/bin/bash -e

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

JENKINS_USER="$1"
REPO_URL="$2"

if [ $# != 2 -o ! "$JENKINS_USER" -o ! "$REPO_URL" ]; then
  echo "usage: $0 <jenkins-git-credentials> <infra-repo-url>"
  exit 1
fi

OPT_NITOR_PATH="$(dirname "$0")/../../opt/nitor"
TEMPLATE_PATH="${OPT_NITOR_PATH}/bakery-templates"

cd /tmp/ # the template_tools script creates a temp directory under current dir

source "${TEMPLATE_PATH}/template_tools.sh"
source "${OPT_NITOR_PATH}/jenkins_tools.sh"

xpath () {
  xpath="$1" ; shift
  file="$1" ; shift
  echo "cat $xpath" | xmllint --shell "$file" | egrep -v '^/'
}

get_credentials_id_for_user () {
  user="$1" ; shift
  xpath '//com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey[username/text()="'"$user"'"]/id/text()' /var/lib/jenkins/jenkins-home/credentials.xml | fgrep -v -- -------
}

patchcreds () {
  perl -pe 's!CREDENTIALS_ID!'"${CREDENTIALS_ID}"'!g;'
}

patchurl () {
  perl -pe 's!GIT_URL!'"${REPO_URL/@/\\@}"'!g;';
}

create_job () {
  echo "Creating job $1 .."
  cli create-job "$1"
}

create_template_and_updater_jobs () {
  patchcreds < ${TEMPLATE_PATH}/ramp-up-branch.xml                | patchurl | create_job "infra-ramp-up-branch"
  patchcreds < ${TEMPLATE_PATH}/update-template-jobs-template.xml            | create_job "TEMPLATE {{prefix}}-update-template-jobs"
  patchcreds < ${TEMPLATE_PATH}/deploy-stack-template.xml                    | create_job "TEMPLATE {{prefix}}-{{image}}-deploy-{{stack}}"
  patchcreds < ${TEMPLATE_PATH}/undeploy-stack-template.xml                  | create_job "TEMPLATE {{prefix}}-{{image}}-undeploy-{{stack}}"
  patchcreds < ${TEMPLATE_PATH}/bake-image-template.xml                      | create_job "TEMPLATE {{prefix}}-{{image}}-bake"
}

check_roles () {
  : # TODO check that the instance has the required policies
}

CREDENTIALS_ID="$(set -e ; get_credentials_id_for_user "${JENKINS_USER}")"

if [ ! "${CREDENTIALS_ID}" ]; then
  echo "Could not find SSH credentials for user ${JENKINS_USER} in jenkins database"
  exit 1
fi

create_template_and_updater_jobs

check_roles
