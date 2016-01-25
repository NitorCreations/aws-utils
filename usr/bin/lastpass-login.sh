#!/bin/bash -e

LPASS_USER="$1"
LPASS_PASSFILE="$2"

if [ ! "$LPASS_USER" -o ! "$LPASS_PASSFILE" ]; then
  echo "usage: $0 <lastpass-username> <lastpass-password-file>" >&2
  echo "lastpass-password-file can be - to read password from stdin."
  exit 1
fi

if [ "$LPASS_PASSFILE" = "-" ]; then
  LPASS_DISABLE_PINENTRY=1 lpass login --plaintext-key -f "$LPASS_USER" 2>&1 >/dev/null
else
  if ! [ -r "$LPASS_PASSFILE" -a "$(stat -c '%a' "$LPASS_PASSFILE")" = "600" ]; then
    echo "Requires $LPASS_PASSFILE with only user access with the lastpass password"
    exit 1
  fi
  LPASS_DISABLE_PINENTRY=1 lpass login --plaintext-key -f "$LPASS_USER" < "$LPASS_PASSFILE" 2>&1 >/dev/null
fi

lpass sync 2>&1 >/dev/null
