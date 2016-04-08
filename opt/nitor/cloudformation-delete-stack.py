#!/usr/bin/env python

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

import subprocess
import sys
import aws_infra_util
import os
import tempfile
import collections
import time

def undeploy(stack_name, region):

    # Disable buffering, from http://stackoverflow.com/questions/107705/disable-output-buffering
    sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 0)

    print("\n\n**** Uneploying stack '" + stack_name + "'")

    # Load previous stack information to see if it has been deployed at all
    describe_stack_command = [ 'aws', 'cloudformation', 'describe-stacks', "--region", region, '--stack-name', stack_name ]
    print("Checking for previous stack info: " + str(describe_stack_command))
    p = subprocess.Popen(describe_stack_command,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    output = p.communicate()
    if p.returncode:
        if (not output[1].endswith("does not exist\n")):
            sys.exit("Failed to retrieve stack for " + stack_name + ": " + output[1])
        print("Stack not deployed, doing nothing.")
        return

    # Dump original status, for the record

    stack_info = aws_infra_util.json_load(output[0])
    status = stack_info['Stacks'][0]['StackStatus']
    print("Status: " + status)

    # Delete stack

    stack_command = \
        ['aws', 'cloudformation', "--region", region, 'delete-stack', '--stack-name',
         stack_name
         ]

    print("Delete stack: " + str(stack_command))
    p = subprocess.Popen(stack_command,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    output = p.communicate()
    if p.returncode:
        sys.exit("Delete stack failed: " + output[1])

    print(output[0])

    # Wait for delete to complete

    print("Waiting for delete stack to complete:")
    while (True):
        p = subprocess.Popen(describe_stack_command,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        output = p.communicate()
        if p.returncode:
            if (output[1].endswith("does not exist\n")):
                break
            sys.exit("Describe stack failed: " + output[1])


        stack_info = aws_infra_util.json_load(output[0])
        status = stack_info['Stacks'][0]['StackStatus']
        print("Status: " + status)
        if (not status.endswith("_IN_PROGRESS")):
            sys.exit("Delete stack failed: end state " + status)

        time.sleep(5)

    print("Done!")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit("Usage: undeploy.py stack_name region")
    undeploy(sys.argv[1], sys.argv[2])
