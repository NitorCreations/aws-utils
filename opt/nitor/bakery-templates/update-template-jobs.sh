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

source "$(dirname "$0")/template_tools.sh"

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
