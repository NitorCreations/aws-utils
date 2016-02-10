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

if [ -z "$1" ]; then
  echo "usage: $0 <domain>"
  exit 1
fi

SERIAL=$(date +%s)
CA_KEY=/etc/certs/${1#*.}.key
CA_CHAIN=/etc/certs/${1#*.}.chain
CRT_KEY=/etc/certs/${1}.key.clear
CSR_PEM=/etc/certs/${1}.csr
CRT_PEM=/etc/certs/${1}.crt

mkdir -p /etc/certs
# CA cert
openssl req -x509 -nodes -days 365 -newkey rsa:4096 -sha256 \
-keyout $CA_KEY -out $CA_CHAIN \
-subj "/C=FI/ST=Uusimaa/L=Helsinki/O=Nitor Creations Oy/OU=IT/CN=$1"

# CSR
openssl req -nodes -days 365 -newkey rsa:4096 -sha256 \
-keyout $CRT_KEY -out $CSR_PEM \
-subj "/C=FI/ST=Uusimaa/L=Helsinki/O=Nitor Creations Oy/OU=IT/CN=$1"

# Cert
openssl x509 -req -in $CSR_PEM -CA $CA_CHAIN -CAkey $CA_KEY \
-set_serial $SERIAL -out $CRT_PEM
