#!/bin/bash -x

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
