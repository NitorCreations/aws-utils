#!/bin/bash

if ! [ -r .lpass-key -a "$(stat -c '%a')" = "600" ]; then
  echo "Requires $(pwd)/.lpass-key with only user access with the lastpass password"
  exit 1
fi

LPASS_DISABLE_PINENTRY=1 lpass login --plaintext-key -f webmaster@nitorcreations.com < .lpass-key 2>&1 >/dev/null
lpass sync 2>&1 >/dev/null

for CERT in "$@"; do
  FNAME=$(basename $CERT)
  DNAME=$(dirname $CERT)
  if ! mkdir -p $DNAME || ! lpass show --notes $FNAME > $CERT; then
    echo "Failed to get cert $CERT"
    exit 1
  else
    chmod 444 $CERT
    echo "Fetched $CERT"
  fi
done
lpass logout -f 2>&1 >/dev/null
