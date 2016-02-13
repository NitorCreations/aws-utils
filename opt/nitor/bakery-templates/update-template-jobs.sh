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

generate_job_name () {
  template_job="$1"
  shift
  echo "Creating job based on '$template_job' with parameters" "$@" >&2
  new_job="$(set -e ; echo "$template_job" | sed 's!^TEMPLATE !!' | apply_parameters "$@")"
  echo "Job name: '$new_job'" >&2
  echo "${new_job}"
}

generate_job_from_template () {
  template_job="$1"
  shift
  template_job_file="$(set -e ; cli_get_job "$template_job")"
  new_job_file="$(set -e ; mktemp -p "${cli_cache}" job_XXXXXXXX.xml)"
  apply_parameters "$@" template="${template_job}" jobupdater="${JOB_NAME}" jobupdaterbuild="${BUILD_DISPLAY_NAME}" < "${template_job_file}" > "${new_job_file}"
  echo "${new_job_file}"
}

create_or_update_job () {
  new_job="$1"
  new_job_file="$2"
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

# usage get_var <name> [<imagedir> [<stackdir>]]
get_var () {
  (
    source infra.properties
    [ ! "$2" -o ! -r "$2/infra.properties" ] || source "$2/infra.properties"
    [ ! "$3" -o ! -r "$3/infra.properties" ] || source "$3/infra.properties"
    echo -n "${!1}"
  )
}

cli list-jobs > "${orig_jobs_file}"

updatetime="$(date "+%F %T %Z")"
image_template="TEMPLATE {{prefix}}-{{image}}-bake"
deploy_template="TEMPLATE {{prefix}}-{{image}}-deploy-{{stack}}"

for imagebasedir in * ; do
  [ -d "${imagebasedir}" ] || continue
  imagetype="$(set -e ; get_var IMAGETYPE "${imagebasedir}")"
  if [ ! "${imagetype}" ]; then
    echo "Missing IMAGETYPE setting in ${imagebasedir}/infra.properties, skipping ${imagebasedir}..."
    continue
  fi

  autostackjobnames=
  allstackjobnames=

  new_image_job="$(set -e ; generate_job_name "${image_template}" image="${imagebasedir}" imagetype="${imagetype}" updatetime="${updatetime}" giturl="${GIT_URL}" prefix="${PREFIX}")"

  for stackdir in "${imagebasedir}/stack-"* ; do
    if [ -d "${stackdir}" ]; then
      stackname="$(set -e ; basename "${stackdir}")"
      stackname="${stackname#stack-}"
      manual_deploy="$(set -e ; get_var MANUAL_DEPLOY "${imagebasedir}" "${stackdir}")"
      new_job="$(     set -e ; generate_job_name          "${deploy_template}" image="${imagebasedir}" imagetype="${imagetype}" stack="${stackname}" updatetime="${updatetime}" giturl="${GIT_URL}" prefix="${PREFIX}" imagejob="${new_image_job}")"
      new_job_file="$(set -e ; generate_job_from_template "${deploy_template}" image="${imagebasedir}" imagetype="${imagetype}" stack="${stackname}" updatetime="${updatetime}" giturl="${GIT_URL}" prefix="${PREFIX}" imagejob="${new_image_job}")"
      if [ "${manual_deploy}" ]; then
	# disable job triggers
	perl -i -e 'undef $/; my $f=<>; $f =~ s!<triggers>.*?</triggers>!<triggers />!s; print $f;' "${new_job_file}"
      fi
      stackjobname="$(set -e ; create_or_update_job "$new_job" "$new_job_file")"
      allstackjobnames="${allstackjobnames}${stackjobname},"
      if [ ! "${manual_deploy}" ]; then
	autostackjobnames="${autostackjobnames}${stackjobname},"
      fi
    fi
  done

  imagedir="${imagebasedir}/image"
  if [ -d "${imagedir}" ]; then
    new_image_job_file="$(set -e ; generate_job_from_template "${image_template}" image="${imagebasedir}" imagetype="${imagetype}" autostackjobs="${autostackjobnames}" allstackjobs="${allstackjobnames}" updatetime="${updatetime}" giturl="${GIT_URL}" prefix="${PREFIX}")"
    create_or_update_job "$new_image_job" "$new_image_job_file"
  fi
done
