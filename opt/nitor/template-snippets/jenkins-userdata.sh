#!/bin/bash -x

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

CF_AWS__StackName=
CF_AWS__Region=
CF_paramAmiName=
CF_paramAdditionalFiles=
CF_paramAmi=
CF_paramAwsUtilsVersion=
CF_paramJenkinsGit=
CF_paramDnsName=
CF_paramEip=
CF_paramEBSTag=
CF_paramEBSSize=32
CF_resourceDeleteSnapshotsLambda=

export HOME=/root
cd $HOME

source /opt/nitor/cloud_init_functions.sh
source /opt/nitor/tool_installers.sh
AWSUTILS_VERSION="${CF_paramAwsUtilsVersion}" update_aws_utils
# reload scripts sourced above in case they changed:
source /opt/nitor/cloud_init_functions.sh
source /opt/nitor/tool_installers.sh

source /opt/nitor/aws_tools.sh
source /opt/nitor/ebs-functions.sh
source /opt/nitor/jenkins_tools.sh
source /opt/nitor/ssh_tools.sh
source /opt/nitor/apache_tools.sh
source /opt/nitor/ssh_tools.sh

fail () {
    echo "FAIL: $@"
    exit 1
}
usermod -s /bin/bash jenkins
set_region
aws_install_metadata_files
set_timezone
set_hostname

apache_replace_domain_vars
apache_install_certs

jenkins_mount_ebs_home ${CF_paramEBSSize}
jenkins_setup_dotssh
jenkins_fetch_repo
jenkins_setup_default_gitignore
jenkins_setup_git_sync_script
jenkins_setup_git_sync_on_shutdown
jenkins_setup_git_sync_job
jenkins_improve_config_security
jenkins_git_commit
# Don't push here - we might not want to push the config automatically - enable & run the "push-latest-jenkins-conf-to-github" jenkins job instead

jenkins_discard_default_install
jenkins_fetch_additional_files
jenkins_set_home
jenkins_enable_and_start_service

apache_enable_and_start_service

jenkins_wait_service_up

ssh_install_hostkeys
ssh_restart_service

aws_ec2_associate_address

source /opt/nitor/cloud_init_footer.sh
