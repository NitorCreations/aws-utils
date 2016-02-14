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

set -ex

infrapropfile="infra-${GIT_BRANCH##*/}.properties"

source "$(dirname "$0")/template_tools.sh"
source "${infrapropfile}"

rampuptime="$(date "+%F %T %Z")"
update_template="TEMPLATE {{prefix}}-update-template-jobs"

vars=( rampuptime="${rampuptime}" giturl="${GIT_URL}" prefix="${JENKINS_JOB_PREFIX}" branch="${GIT_BRANCH##*/}" )

new_update_job="$(set -e ; generate_job_name "${update_template}" "${vars[@]}")"
new_image_job_file="$(set -e ; generate_job_from_template "${update_template}" "${vars[@]}")"

if job_exists "$new_image_job"; then
  echo "Branch ${GIT_BRANCH##/} already ramped up!"
  exit 1
fi

create_or_update_job "$new_image_job" "$new_image_job_file"

trigger_job "$new_image_job"
