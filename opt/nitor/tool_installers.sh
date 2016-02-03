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

# Functions to install various tools meant to be sourced and used as Functions
if [ -z "$AWSUTILS_VERSION" ]; then
  if [ -n "${CF_paramAwsUtilsVersion}" ]; then
    AWSUTILS_VERSION="${CF_paramAwsUtilsVersion}"
  else
    AWSUTILS_VERSION=0.15
  fi
fi
if [ -z "$MAVEN_VERSION" ]; then
  MAVEN_VERSION=3.3.9
fi
if [ -z "$PHANTOMJS_VERSION" ]; then
  PHANTOMJS_VERSION=2.1.1
fi

install_lein() {
  wget -O /usr/bin/lein https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
  chmod 755 /usr/bin/lein
}
install_phantomjs() {
  wget -O - https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 | tar -xjvf -
  mv phantomjs-*/bin/phantomjs /usr/bin
  rm -rf phantomjs-*
}
install_cftools() {
  curl -s https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz | tar -xzvf -
  cd aws-cfn-bootstrap-*
  pip install .
}
install_letsencrypt() {
  git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt
  /opt/letsencrypt/letsencrypt-auto --help
}
install_maven() {
  wget -O - http://mirror.netinch.com/pub/apache/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar -xzvf - -C /opt/
  ln -snf /opt/apache-maven-$MAVEN_VERSION /opt/maven
  ln -snf  /opt/maven/bin/mvn /usr/bin/mvn
}
update_aws_utils () {
  echo "Updating aws-utils from version $(cat /opt/nitor/aws-utils.version) to $AWSUTILS_VERSION"
  "$(dirname "${BASH_SOURCE[0]}")/install_tools.sh" "${AWSUTILS_VERSION}"
}
