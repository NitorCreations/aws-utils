#!/bin/bash

# Functions to install various tools meant to be sourced and used as Functions
if [ -z "$AWSUTILS_VERSION" ]; then
  AWSUTILS_VERSION=0.9
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
