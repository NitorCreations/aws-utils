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

case  "$SYSTEM_TYPE" in
  ubuntu)
    APACHE_SSL_CONF=/etc/apache2/sites-enabled/default-ssl.conf
    ;;
  centos)
    APACHE_SSL_CONF=/etc/httpd/conf.d/ssl.conf
    ;;
  *)
    echo "Unknown system type $SYSTEM_TYPE"
    exit 1
    ;;
esac

apache_replace_domain_vars () {
  check_parameters APACHE_SSL_CONF CF_paramDnsName
  perl -i -pe 's!%domain%!'"${CF_paramDnsName}"'!g;s!%zone%!'"${CF_paramDnsName#*.}"'!g'  ${APACHE_SSL_CONF}
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
  elif [ "${CF_paramUseLetsencrypt}" = "false" ]; then
    DOMAIN=${CF_paramDnsName#*.}
    (
      perlgrep '^\s*(SSLCertificateFile|SSLCertificateKeyFile|SSLCACertificateFile)' ${APACHE_SSL_CONF} | awk '{ print $2 }'
      echo /etc/certs/$DOMAIN.chain
    ) | sort -u | xargs /root/fetch-secrets.sh get 444
    ln -sv /etc/certs/$DOMAIN.chain $(perlgrep '^\s*SSLCertificateChainFile' ${APACHE_SSL_CONF} | awk '{ print $2 }')
  else
    echo "Invalid parameter CF_paramUseLetsencrypt value '${CF_paramUseLetsencrypt}'"
    exit 1
  fi
}

apache_prepare_ssl_conf() {
  if [ "$SYSTEM_TYPE" = "ubuntu" ]; then
    a2enmod proxy
    a2enmod proxy_http
    a2enmod headers
    a2enmod ssl
    a2ensite default-ssl
    a2dissite 000-default
    sed -i -e 's/#.*$//' -e '/^$/d' -e '/<\/IfModule>/d' -e '/SSLProtocol/d' /etc/apache2/mods-enabled/ssl.conf
    cat >> /etc/apache2/mods-enabled/ssl.conf << MARK
  SSLProtocol all -SSLv2 -SSLv3
</IfModule>
MARK
  fi
  sed -i -e '/^#.*$/d' -e '/^$/d' -e '/<\/VirtualHost>/d' -e '/SSLCertificate/d' -e '/SSLCACertificate/d' -e '/SSLProtocol/d' -e '/SSLCipherSuite/d' ${APACHE_SSL_CONF}

  if [ "$SYSTEM_TYPE" = "centos" ]; then
    # Allow reverse proxy connections
    setsebool -P httpd_can_network_connect 1
  fi
  mkdir /etc/certs
  chmod 700 /etc/certs
  cat >> ${APACHE_SSL_CONF} << MARK
    ServerName https://%domain%
    Alias /.well-known /var/www/%domain%/.well-known
    SSLProtocol all -SSLv2 -SSLv3
    SSLCipherSuite ALL:!DH:!EXPORT:!RC4:+HIGH:+MEDIUM:!LOW:!aNULL:!eNULL
    SSLCertificateFile /etc/certs/%domain%.crt
    SSLCertificateKeyFile /etc/certs/%domain%.key.clear
    SSLCertificateChainFile /etc/certs/%zone%.chain
    ProxyPass /.well-known !
    ProxyPass / http://localhost:8080/
    Header edit Location ^http://%domain% https://%domain%
    ProxyRequests Off
    ProxyPreserveHost On
    ProxyTimeout 600
  </VirtualHost>
MARK
  if [ "$SYSTEM_TYPE" = "ubuntu" ]; then
    echo '</IfModule>' >> ${APACHE_SSL_CONF}
  fi
}

apache_disable_and_shutdown_service () {
  case  "$SYSTEM_TYPE" in
    ubuntu)
      update-rc.d apache2 disable
      service apache2 stop
      ;;
    centos)
      systemctl disable httpd
      systemctl stop httpd
      ;;
    *)
      echo "Unknown system type $SYSTEM_TYPE"
      exit 1
      ;;
  esac
}

apache_enable_and_start_service () {
  case  "$SYSTEM_TYPE" in
    ubuntu)
      update-rc.d apache2 enable
      service apache2 start
      ;;
    centos)
      systemctl enable httpd
      systemctl start httpd
      ;;
    *)
      echo "Unknown system type $SYSTEM_TYPE"
      exit 1
      ;;
  esac
}
