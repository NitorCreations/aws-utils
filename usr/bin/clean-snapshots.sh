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
  echo "usage: $0 <lamda-function-name>"
  exit 1
fi
[ "${REGION}" ] || REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}')
OUT=$(mktemp)
echo "["
aws --region $REGION lambda invoke --function-name $1 $OUT
RET=$?
echo ','
cat $OUT
echo ']'
rm -f $OUT
exit $RET
