#!/bin/bash -x

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

BAKE_ID=$1
eval $(oracle-compute auth /Compute-nitorcreations/apiuser .passwd)

oracle-compute stop orchestration /Compute-nitorcreations/apiuser/orchestration_master_$BAKE_ID --force

while [ "$STATUS" != "stopped" ]
do
  STATUS=$(oracle-compute list orchestration /Compute-nitorcreations/apiuser/orchestration_master_$BAKE_ID -f json | jq -r '.list[0]|.status')
  sleep 5
done

oracle-compute delete orchestration /Compute-nitorcreations/apiuser/orchestration_master_$BAKE_ID --force
oracle-compute delete orchestration /Compute-nitorcreations/apiuser/orchestration_instance_$BAKE_ID --force
oracle-compute delete orchestration /Compute-nitorcreations/apiuser/orchestration_volume_$BAKE_ID --force
