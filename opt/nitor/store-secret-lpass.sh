#!/bin/bash -xe

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

CF_paramSecretsBucket='nitor-infra-secure'
CF_paramSecretsFolder='Certs'
CF_paramSecretsUser="webmaster@nitorcreations.com"


login_if_not_already () {
  if ! lpass ls not-meant-to-return-anything > /dev/null 2>&1; then
    s3-role-download.sh ${CF_paramSecretsBucket} webmaster.pwd - | lastpass-login.sh ${CF_paramSecretsUser} -
  fi
}
logout() {
  lpass sync
  lastpass-logout.sh
}

if [ -z "$1" ]; then
  echo "usage: $0 logout|<name>"
  echo "   Secret must be given in stdin"
  exit 1
fi

if [ "$1" = "logout" ]; then
  logout
  exit 0
fi

login_if_not_already
lpass edit --sync=now --non-interactive --notes "Shared-${CF_paramSecretsFolder}/$1" <&0
