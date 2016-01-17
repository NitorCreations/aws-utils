#!/bin/bash

if ! curl -sf http://169.254.169.254/latest/meta-data/iam/security-credentials/$1 > /dev/null; then
  ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/ | head -n 1)
  BUCKET=$1
  shift
  FILE=$1
  shift
else
  ROLE=$1
  shift
  BUCKET=$1
  shift
  FILE=$1
  shift
fi
if [ -z "$1" ]; then
  OUT=$(basename ${FILE})
else
  OUT=$1
fi

CONTENT_TYPE="application/octet-stream"
DATE=$(date -R)
RESOURCE="/${BUCKET}/${FILE}"
TMP=$(mktemp)
if ! curl -sf http://169.254.169.254/latest/meta-data/iam/security-credentials/${ROLE} \
| egrep ^[[:space:]]*\" | sed 's/[^\"]*\"\([^\"]*\)\".:.\"\([^\"]*\).*/\1=\2/g' > $TMP; then
  echo "Failed to get credentials"
  exit 1
fi
source $TMP
rm -f $TMP
SIGNSTR="GET\n\n${CONTENT_TYPE}\n${DATE}\nx-amz-security-token:${Token}\n${RESOURCE}"
SIGNATURE=$(echo -en ${SIGNSTR} | openssl sha1 -hmac ${SecretAccessKey} -binary | base64)
exec curl -s -o $OUT  -X GET -H "Host: ${BUCKET}.s3.amazonaws.com" -H "Date: ${DATE}" -H "Content-Type: ${CONTENT_TYPE}" -H "Authorization: AWS ${AccessKeyId}:${SIGNATURE}" -H "x-amz-security-token: ${Token}" https://${BUCKET}.s3.amazonaws.com/${FILE}
