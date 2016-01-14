#!/bin/bash

TSTAMP=$(date +%Y%m%d%H%M%S)
SERIAL=$(date +%s)
mkdir -p /etc/letsencrypt/keys/$1/
mkdir -p /etc/letsencrypt/live/$1/
chmod -R 755 /etc/letsencrypt
# CA cert
openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
-keyout /etc/letsencrypt/keys/$1/chainkey-$TSTAMP.pem \
-out /etc/letsencrypt/keys/$1/chain-$TSTAMP.pem \
-subj "/C=FI/ST=Uusimaa/L=Helsinki/O=Nitor Creations Oy/OU=IT/CN=$1"
# CSR
openssl req -nodes -days 365 -newkey rsa:4096 \
-keyout /etc/letsencrypt/keys/$1/privkey-$TSTAMP.pem \
-out /etc/letsencrypt/keys/$1/certcsr-$TSTAMP.pem \
-subj "/C=FI/ST=Uusimaa/L=Helsinki/O=Nitor Creations Oy/OU=IT/CN=$1"
# Cert
openssl x509 -req -in /etc/letsencrypt/keys/$1/certcsr-$TSTAMP.pem \
-CA /etc/letsencrypt/keys/$1/chain-$TSTAMP.pem \
-CAkey /etc/letsencrypt/keys/$1/chainkey-$TSTAMP.pem \
-set_serial $SERIAL \
-out /etc/letsencrypt/keys/$1/cert-$TSTAMP.pem
# Symlink into place
ln -snf /etc/letsencrypt/keys/$1/chain-$TSTAMP.pem /etc/letsencrypt/live/$1/chain.pem
ln -snf /etc/letsencrypt/keys/$1/cert-$TSTAMP.pem /etc/letsencrypt/live/$1/cert.pem
ln -snf /etc/letsencrypt/keys/$1/privkey-$TSTAMP.pem /etc/letsencrypt/live/$1/privkey.pem
