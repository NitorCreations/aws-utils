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

create_temp_file () {
  local pattern="$1"
  mktemp -p "${cli_cache}" "$pattern"
}

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
  local template_job="$1"
  shift
  echo "Creating job based on '$template_job' with parameters" "$@" >&2
  local new_job="$(set -e ; echo "$template_job" | sed 's!^TEMPLATE !!' | apply_parameters "$@")"
  echo "Job name: '$new_job'" >&2
  echo "${new_job}"
}

generate_job_from_template () {
  local template_job="$1"
  shift
  local template_job_file="$(set -e ; cli_get_job "$template_job")"
  local new_job_file="$(set -e ; create_temp_file job_XXXXXXXX.xml)"
  apply_parameters "$@" template="${template_job}" jobupdater="${JOB_NAME}" jobupdaterbuild="${BUILD_DISPLAY_NAME}" < "${template_job_file}" > "${new_job_file}"
  echo "${new_job_file}"
}

job_exists () {
  fgrep -xq "$1" "${orig_jobs_file}"
}

create_or_update_job () {
  local new_job="$1"
  local new_job_file="$2"
  local enable=1
  if job_exists "$new_job" ; then
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

trigger_job () {
  local job="$1"
  cli build "$job"
}

create_view () {
  local new_view_file="$1"
  cli create-view < "$new_view_file"
}

infrapropfile="infra-${GIT_BRANCH##*/}.properties"

# usage get_var <name> [<imagedir> [<stackdir>]]
get_var () {
  (
    source "${infrapropfile}"
    [ ! "$2" -o ! -r "$2/${infrapropfile}" ] || source "$2/${infrapropfile}"
    [ ! "$3" -o ! -r "$3/${infrapropfile}" ] || source "$3/${infrapropfile}"
    echo -n "${!1}"
  )
}

cli list-jobs > "${orig_jobs_file}"
