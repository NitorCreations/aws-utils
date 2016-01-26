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

source "$(dirname "${BASH_SOURCE[0]}")/common_tools.sh"

ssh_install_hostkeys () {
  check_parameters CF_paramDnsName
  /root/fetch-secrets.sh get 500 --optional /etc/ssh/${CF_paramDnsName}-ssh-hostkeys.sh
  if [ -x /etc/ssh/${CF_paramDnsName}-ssh-hostkeys.sh ]; then
    /etc/ssh/${CF_paramDnsName}-ssh-hostkeys.sh
    # ssh is restarted later in the userdata script when elastic ip has been associated
  fi
}
