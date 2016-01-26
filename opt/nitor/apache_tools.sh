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

apache_replace_domain_vars () {
  check_parameters APACHE_SSL_CONF
  perl -i -pe 's!%domain%!'"${CF_paramDnsName}"'!g' ${APACHE_SSL_CONF}
}

perlgrep () { local RE="$1" ; shift ; perl -ne 'print if(m!'"$RE"'!)' "$@" ; }

apache_install_certs () {
  check_parameters APACHE_SSL_CONF CF_paramUseLetsencrypt CF_paramDnsName
  if [ "${CF_paramUseLetsencrypt}" = "true" ]; then
    ln -sv /etc/letsencrypt/live/${CF_paramDnsName}/cert.pem    $(perlgrep '^\s*SSLCertificateFile'      ${APACHE_SSL_CONF} | awk '{ print $2 }')
    ln -sv /etc/letsencrypt/live/${CF_paramDnsName}/privkey.pem $(perlgrep '^\s*SSLCertificateKeyFile'   ${APACHE_SSL_CONF} | awk '{ print $2 }')
    ln -sv /etc/letsencrypt/live/${CF_paramDnsName}/chain.pem   $(perlgrep '^\s*SSLCertificateChainFile' ${APACHE_SSL_CONF} | awk '{ print $2 }')
    # SSLCACertificateFile?
    /opt/letsencrypt/letsencrypt-auto --help
  else
    (
      perlgrep '^\s*(SSLCertificateFile|SSLCertificateKeyFile|SSLCACertificateFile)' ${APACHE_SSL_CONF} | awk '{ print $2 }'
      echo /etc/certs/sub.class1.server.ca.pem
    ) | sort -u | xargs /root/fetch-secrets.sh get 444
    ln -sv /etc/certs/sub.class1.server.ca.pem $(perlgrep '^\s*SSLCertificateChainFile' ${APACHE_SSL_CONF} | awk '{ print $2 }')
  fi
}
