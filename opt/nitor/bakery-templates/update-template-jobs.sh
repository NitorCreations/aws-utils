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
undeploy_template="TEMPLATE {{prefix}}-{{image}}-undeploy-{{stack}}"

for imagebasedir in * ; do
  [ -d "${imagebasedir}" ] || continue
  imagetype="$(set -e ; get_var IMAGETYPE "${imagebasedir}")"
  if [ ! "${imagetype}" ]; then
    echo "Missing IMAGETYPE setting in ${imagebasedir}/infra-<branch>.properties, skipping ${imagebasedir}..."
    continue
  fi

  stack_auto_deploy_job_names=
  stack_all_deploy_job_names=

  common_vars=( image="${imagebasedir}" imagetype="${imagetype}" updatetime="${updatetime}" giturl="${GIT_URL}" prefix="${PREFIX}" branch="${GIT_BRANCH##*/}" )

  new_image_job="$(set -e ; generate_job_name "${image_template}" "${common_vars[@]}")"

  for stackdir in "${imagebasedir}/stack-"* ; do
    if [ -d "${stackdir}" ]; then
      stackname="$(set -e ; basename "${stackdir}")"
      stackname="${stackname#stack-}"
      manual_deploy="$(set -e ; get_var MANUAL_DEPLOY "${imagebasedir}" "${stackdir}")"
      disable_undeploy="$(set -e ; get_var DISABLE_UNDEPLOY "${imagebasedir}" "${stackdir}")"
      stack_vars=( stack="${stackname}" imagejob="${new_image_job}" )

      # prepare

      deploy_job="$(         set -e ; generate_job_name          "${deploy_template}"   "${common_vars[@]}" "${stack_vars[@]}")"
      deploy_job_file="$(    set -e ; generate_job_from_template "${deploy_template}"   "${common_vars[@]}" "${stack_vars[@]}")"

      undeploy_job="$(       set -e ; generate_job_name          "${undeploy_template}" "${common_vars[@]}" "${stack_vars[@]}")"
      if [ "$disable_undeploy" != "y" ]; then
        undeploy_job_file="$(set -e ; generate_job_from_template "${undeploy_template}" "${common_vars[@]}" "${stack_vars[@]}")"
      fi

      # create/update

      if [ "${manual_deploy}" = "y" ]; then
        # disable job triggers
        perl -i -e 'undef $/; my $f=<>; $f =~ s!<triggers>.*?</triggers>!<triggers />!s; print $f;' "${deploy_job_file}"
      fi
      create_or_update_job "$deploy_job" "$deploy_job_file"
      stack_all_deploy_job_names="${stack_all_deploy_job_names}${deploy_job},"
      if [ ! "${manual_deploy}" ]; then
        stack_auto_deploy_job_names="${stack_auto_deploy_job_names}${deploy_job},"
      fi

      if [ "$disable_undeploy" != "y" ]; then
        create_or_update_job "$undeploy_job" "$undeploy_job_file"
      else
        delete_job_if_exists "$undeploy_job"
      fi
    fi
  done

  imagedir="${imagebasedir}/image"
  if [ -d "${imagedir}" ]; then
    image_vars=( autostackjobs="${stack_auto_deploy_job_names}" allstackjobs="${stack_all_deploy_job_names}" )
    new_image_job_file="$(set -e ; generate_job_from_template "${image_template}" "${common_vars[@]}" "${image_vars[@]}")"
    create_or_update_job "$new_image_job" "$new_image_job_file"
  fi
done
