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
import datetime

def deploy(stack_name, yaml_template, region):

    # Disable buffering, from http://stackoverflow.com/questions/107705/disable-output-buffering
    sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 0)

    # Get AMI metadata

    describe_ami_command = [ "aws", "ec2", "describe-images", "--region", region, "--image-ids", os.environ["paramAmi"] ]
    print("Checking AMI " + os.environ["paramAmi"] + " metadata: " + str(describe_ami_command))
    p = subprocess.Popen(describe_ami_command,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    output = p.communicate()
    if p.returncode:
        sys.exit("Failed to retrieve ami metadata for " + os.environ["paramAmi"])

    ami_meta = aws_infra_util.json_load(output[0])
    print("Result: " + aws_infra_util.json_save(ami_meta))
    os.environ["paramAmiName"] = ami_meta['Images'][0]['Name']
    os.environ["paramAmiCreated"] = ami_meta['Images'][0]['CreationDate']

    print("\n\n**** Deploying stack '" + stack_name + "' with template '" + yaml_template + "' and ami_id " + os.environ["paramAmi"])

    # Load yaml template and import scripts and patch userdata with metadata hash & params

    template_doc = aws_infra_util.yaml_load(open(yaml_template))
    template_doc = aws_infra_util.import_scripts(template_doc, yaml_template)
    aws_infra_util.patch_launchconf_userdata_with_metadata_hash_and_params(template_doc)

    if "Parameters" not in template_doc:
        template_doc['Parameters'] = []
    template_parameters = template_doc['Parameters']
    if (not "paramAmiName" in template_parameters):
        template_parameters['paramAmiName']    = collections.OrderedDict([("Description", "AMI Name"), ("Type", "String"), ("Default", "")])
    if (not "paramAmiCreated" in template_parameters):
        template_parameters['paramAmiCreated'] = collections.OrderedDict([("Description", "AMI Creation Date"), ("Type", "String"), ("Default", "")])

    json_template = aws_infra_util.json_save(template_doc)

    # save result

    print("** Final template:")
    print(json_template)
    print("")

    tmp = tempfile.NamedTemporaryFile(delete=False)
    tmp.write(json_template)
    tmp.close()

    # Load previous stack information to see if it has been deployed before

    describe_stack_command = [ 'aws', 'cloudformation', 'describe-stacks', "--region", region, '--stack-name', stack_name ]
    print("Checking for previous stack info: " + str(describe_stack_command))
    p = subprocess.Popen(describe_stack_command,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    output = p.communicate()
    if p.returncode:
        if (not output[1].endswith("does not exist\n")):
            sys.exit("Failed to retrieve old stack for " + stack_name + ": " + output[1])
        stack_oper = 'create-stack'
    else:
        stack_oper = 'update-stack'

        # Dump original status, for the record

        stack_info = aws_infra_util.json_load(output[0])
        status = stack_info['Stacks'][0]['StackStatus']
        print("Status: " + status)

    # Create/update stack

    params_doc = []
    for key in template_parameters.keys():
        if (key in os.environ):
            val = os.environ[key]
            print("Parameter " + key + ": using \033[32;1mCUSTOM value " + val + "\033[m")
            params_doc.append({ 'ParameterKey': key, 'ParameterValue': val })
        else:
            val = template_parameters[key]['Default']
            print("Parameter " + key + ": using default value " + val)

    stack_command = \
        ['aws', 'cloudformation', stack_oper, "--region", region, '--stack-name',
         stack_name,
         '--template-body',
         'file://' + tmp.name,
         '--capabilities',
         'CAPABILITY_IAM',
         '--parameters',
         aws_infra_util.json_save(params_doc)
         ]

    currentTimeInCloudWatchFormat = datetime.datetime.now().strftime("%FT%H%%253A%M%%253A%SZ")

    print(stack_oper + ": " + str(stack_command))
    p = subprocess.Popen(stack_command,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    output = p.communicate()
    os.remove(tmp.name)
    if p.returncode:
        sys.exit(stack_oper + " failed: " + output[1])

    print(output[0])

    # Wait for create/update to complete

    cloudWatchNotice = "\nCloudWatch url:  https://console.aws.amazon.com/cloudwatch/home#logEvent:group=instanceDeployment;stream=" + stack_name + ";start=" + currentTimeInCloudWatchFormat + "\n"
    print(cloudWatchNotice)

    print("Waiting for " + stack_oper + " to complete:")
    while (True):
        p = subprocess.Popen(describe_stack_command,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        output = p.communicate()
        if p.returncode:
            sys.exit("Describe stack failed: " + output[1])

        stack_info = aws_infra_util.json_load(output[0])
        status = stack_info['Stacks'][0]['StackStatus']
        print("Status: " + status)
        if (not status.endswith("_IN_PROGRESS")):
            break

        time.sleep(5)

    print(cloudWatchNotice)

    if ((stack_oper == "create-stack" and status != "CREATE_COMPLETE") or (stack_oper == "update-stack" and status != "UPDATE_COMPLETE")):
        sys.exit(stack_oper + " failed: end state " + status)
    else:
        f = open('outputs.json', 'w')
        json.dump(stack_info['Stacks'][0]['Outputs'], f, indent=4)
        f.close()

    print("Done!")

if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit("Usage: deploy.py stack_name yaml_template region\nParameters taken from environment as-is, missing parameters use defaults from template")
    deploy(sys.argv[1], sys.argv[2], sys.argv[3])
