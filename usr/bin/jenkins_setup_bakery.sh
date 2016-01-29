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

JENKINS_USER="$1" ; shift
REPO_URL="$1" ; shift
PREFIX="$1" ; shift

if [ $# != 0 -o ! "$JENKINS_USER" ]; then
  echo "usage: $0 <jenkins-git-credentials> <infra-repo-url> <prefix>"
  exit 1
fi

OPT_NITOR_PATH="$(dirname "$0")/../../opt/nitor"
TEMPLATE_PATH="${OPT_NITOR_PATH}/jenkins-templates"

source "${OPT_NITOR_PATH}/jenkins_tools.sh"

xpath () {
  xpath="$1" ; shift
  file="$1" ; shift
  echo "cat $xpath" | xmllint --shell "$file" | egrep -v '^/'
}

get_credentials_id_for_user () {
  user="$1" ; shift
  xpath '//com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey[username/text()="'"$user"'"]/id/text()' /var/lib/jenkins/jenkins-home/credentials.xml
}

create_template_and_updater_jobs () {
  perl -pe 's!PREFIX!'"${PREFIX}"'!g; s!GIT_URL!'"${REPO_URL}"'!g; s!CREDENTIALS_ID!'"${CREDENTIALS_ID}"'!g;' \
       < ${TEMPLATE_PATH}/update-template-jobs.xml \
    | cli create-job "${PREFIX}-update-template-jobs"
  perl -pe 's!CREDENTIALS_ID!'"${CREDENTIALS_ID}"'!g;' \
       < ${TEMPLATE_PATH}/deploy-stack-template.xml \
    | cli create-job "TEMPLATE ${PREFIX}-{{image}}-deploy-{{stack}}"
  perl -pe 's!CREDENTIALS_ID!'"${CREDENTIALS_ID}"'!g;' \
       < ${TEMPLATE_PATH}/bake-image-template.xml \
    | cli create-job "TEMPLATE ${PREFIX}-{{image}}-bake"
}

create_aws_view () {
  if ! cli get-view AWS >/dev/null 2>&1 ; then
    cli create-view <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<hudson.model.ListView>
  <name>${PREFIX^^}</name>
  <filterExecutors>false</filterExecutors>
  <filterQueue>false</filterQueue>
  <properties class="hudson.model.View\$PropertyList"/>
  <jobNames>
    <comparator class="hudson.util.CaseInsensitiveComparator"/>
  </jobNames>
  <jobFilters/>
  <columns>
    <hudson.views.StatusColumn/>
    <hudson.views.WeatherColumn/>
    <hudson.views.JobColumn/>
    <hudson.views.LastSuccessColumn/>
    <hudson.views.LastFailureColumn/>
    <hudson.views.LastDurationColumn/>
    <hudson.views.BuildButtonColumn/>
  </columns>
  <includeRegex>(?:TEMPLATE )?${PREFIX}-.*</includeRegex>
  <recurse>false</recurse>
</hudson.model.ListView>
EOF
  fi
}

check_roles () {
  # TODO check that the instance has the required policies
}

CREDENTIALS_ID="$$(set -e ; get_credentials_id_for_user "${JENKINS_USER}")"

if [ ! "${CREDENTIALS_ID}" ]; then
  echo "Could not find SSH credentials for user ${JENKINS_USER}"
  exit 1
fi

create_template_and_updater_jobs
create_aws_view

check_roles
