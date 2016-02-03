#!/bin/bash -ex

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

PREFIX="$1"

apply_parameters () {
  perl -e '
    my @params = map { [split(/=/,$_,2)] } @ARGV;
    while(<STDIN>) {
      foreach my $param (@params) {
        s!\{\{$param->[0]\}\}!$param->[1]!g;
      }
      print;
    }
  ' "$@"
}

cli_cache=.cli-cache
rm -rf ${cli_cache}
mkdir ${cli_cache}
orig_jobs_file="${cli_cache}/jobs.txt"

cli () {
  [ -r ${cli_cache}/jenkins-cli.jar ] || wget -O ${cli_cache}/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar
  java -jar ${cli_cache}/jenkins-cli.jar -s http://localhost:8080/ "$@"
}

cli_get_job () {
  local file="${cli_cache}/${1}.xml"
  [ -r "${file}" ] || cli get-job "$1" > "${file}"
  echo "${file}"
}

create_job_from_template () {
  template_job="$1"
  shift
  echo "Creating job based on '$template_job' with parameters" "$@" >&2
  new_job="$(set -e ; echo "$template_job" | sed 's!^TEMPLATE !!' | apply_parameters "$@")"
  echo "Job name: '$new_job'" >&2
  template_job_file="$(set -e ; cli_get_job "$template_job")"
  new_job_file="${cli_cache}/newjob.xml"
  apply_parameters "$@" template="${template_job}" jobupdater="${JOB_NAME}" jobupdaterbuild="${BUILD_DISPLAY_NAME}" < "${template_job_file}" > "${new_job_file}"
  enable=1
  if fgrep -xq "${new_job}" "${orig_jobs_file}" ; then
    ! cli get-job "${new_job}" | egrep '^  <disabled>true</disabled>$' || enable=0
    cli update-job "${new_job}" < "${new_job_file}"
  else
    cli create-job "${new_job}" < "${new_job_file}"
  fi
  if [ "${enable}" = "1" ]; then
    echo "Enable job." >&2
    cli enable-job "${new_job}"
  else
    echo "Disable job." >&2
    cli disable-job "${new_job}"
  fi
  echo "${new_job}"
}

cli list-jobs > "${orig_jobs_file}"

updatetime="$(date "+%F %T %Z")"
image_template="TEMPLATE ${PREFIX}-{{image}}-bake"
deploy_template="TEMPLATE ${PREFIX}-{{image}}-deploy-{{stack}}"

for imagebasedir in * ; do
  [ -r "${imagebasedir}/infra.properties" ] || continue
  imagetype="$(set -e ; awk -F= '$1=="IMAGETYPE" { print $2 }' -- "${imagebasedir}/infra.properties")"
  if [ ! "${imagetype}" ]; then
    echo "Missing IMAGETYPE setting in ${imagebasedir}/infra.properties, skipping ${imagebasedir}..."
    continue
  fi
  for stackdir in "${imagebasedir}/stack-"* ; do
    stackname="$(set -e ; basename "${stackdir}")"
    stackname="${stackname#stack-}"
    stackjobname="$(set -e ; create_job_from_template "${deploy_template}" image="${imagebasedir}" imagetype="${imagetype}" stack="${stackname}" updatetime="${updatetime}" giturl="${GIT_URL}" prefix="${PREFIX}")"
    stackjobnames="${stackjobnames}${stackjobname},"
  done
  imagedir="${imagebasedir}/image"
  if [ -d "${imagedir}" ]; then
    create_job_from_template "${image_template}" image="${imagebasedir}" imagetype="${imagetype}" stackjobs="${stackjobnames}" updatetime="${updatetime}" giturl="${GIT_URL}" prefix="${PREFIX}"
  fi
done
