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

def deploy(stack_names, yaml_templates, ami_id):
    stack_names = stack_names.split(",")
    yaml_templates = yaml_templates.split(",")

    # Assume amibakery role

    p = subprocess.Popen(['aws', 'sts', 'assume-role', '--role-arn', 'arn:aws:iam::832585949989:role/amibakery', '--role-session-name', 'amibakery-deploy'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    output = p.communicate()
    if p.returncode:
       sys.exit("Assume role failed: " + output[1])

    # AWS Credentials

    credentials = aws_infra_util.json_load(output[0])
    aws_access_key_id = credentials['Credentials']['AccessKeyId']
    aws_secret_access_key = credentials['Credentials']['SecretAccessKey']
    aws_session_token = credentials['Credentials']['SessionToken']

    # Get AMI metadata

    describe_ami_command = [ "aws", "ec2", "describe-images", "--image-ids", ami_id ]
    print("Checking AMI " + ami_id + " metadata: " + str(describe_ami_command))
    p = subprocess.Popen(describe_ami_command,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
                         env=dict(os.environ,
                                  AWS_ACCESS_KEY_ID=aws_access_key_id,
                                  AWS_SECRET_ACCESS_KEY=aws_secret_access_key,
                                  AWS_SESSION_TOKEN=aws_session_token))
    output = p.communicate()
    if p.returncode:
        sys.exit("Failed to retrieve ami metadata for " + ami_id)

    ami_meta = aws_infra_util.json_load(output[0])
    print("Result: " + aws_infra_util.json_save(ami_meta))
    ami_name = ami_meta['Images'][0]['Name']
    ami_created = ami_meta['Images'][0]['CreationDate']

    for idx, stack_name in enumerate(stack_names):
        yaml_template = yaml_templates[idx]

        print("\n\n**** Deploying stack '" + stack_name + "' with template '" + yaml_template + "' and ami_id " + ami_id)

        # Load yaml template and import scripts and patch userdata with metadata hash & params

        template_doc = aws_infra_util.yaml_load(open(yaml_template))
        aws_infra_util.import_scripts(template_doc, yaml_template)
        aws_infra_util.patch_launchconf_userdata_with_metadata_hash_and_params(template_doc)

        if "Parameters" not in template_doc:
            template_doc['Parameters'] = [];
        template_doc['Parameters']['paramAmiName']    = collections.OrderedDict([("Description", "AMI Name"), ("Type", "String"), ("Default", "")])
        template_doc['Parameters']['paramAmiCreated'] = collections.OrderedDict([("Description", "AMI Creation Date"), ("Type", "String"), ("Default", "")])

        json_template = aws_infra_util.json_save(template_doc)

        print("** Final template:");
        print(json_template);
        print("");

        # Load previous stack information to know which parameters have been deployed before

        describe_stack_command = [ 'aws', 'cloudformation', 'describe-stacks', '--stack-name', stack_name ]
        print("Checking for previous stack info: " + str(describe_stack_command))
        p = subprocess.Popen(describe_stack_command,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
                             env=dict(os.environ,
                                      AWS_ACCESS_KEY_ID=aws_access_key_id,
                                      AWS_SECRET_ACCESS_KEY=aws_secret_access_key,
                                      AWS_SESSION_TOKEN=aws_session_token))
        output = p.communicate()
        if p.returncode:
            print("Failed to retrieve old stack for " + stack_name + " - assuming first deployment: " + output[1]);
            sys.exit("Not implemented - should probably call create-stack instead of update-stack");

        previous_stack = aws_infra_util.json_load(output[0])
        print("Result: " + aws_infra_util.json_save(previous_stack))
        previous_stack_parameters = collections.OrderedDict()
        if "Stacks" in previous_stack:
            for kv in previous_stack['Stacks'][0]['Parameters']:
                previous_stack_parameters[kv['ParameterKey']] = kv['ParameterValue']

        # Update stack

        tmp = tempfile.NamedTemporaryFile(delete=False)
        tmp.write(json_template)
        tmp.close()

        update_stack_command = \
            ['aws', 'cloudformation', 'update-stack', '--stack-name',
             stack_name,
             '--template-body',
             'file://' + tmp.name,
             '--capabilities',
             'CAPABILITY_IAM',
             '--parameters',
             'ParameterKey=paramAmi,ParameterValue=' + ami_id,
             'ParameterKey=paramAmiName,ParameterValue=' + ami_name,
             'ParameterKey=paramAmiCreated,ParameterValue=' + ami_created
             ]

        for key, value in template_doc['Parameters'].iteritems():
            if "paramAmi" not in key and key in previous_stack_parameters:
                update_stack_command.append('ParameterKey='+key+',UsePreviousValue=true')

        print("Updating stack: " + str(update_stack_command))
        p = subprocess.Popen(update_stack_command,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
                             env=dict(os.environ,
                                      AWS_ACCESS_KEY_ID=aws_access_key_id,
                                      AWS_SECRET_ACCESS_KEY=aws_secret_access_key,
                                      AWS_SESSION_TOKEN=aws_session_token))
        output = p.communicate()
        os.remove(tmp.name)
        if p.returncode:
            sys.exit("Update stack failed: " + output[1])

        print(output[0])

if __name__ == '__main__':
    if len(sys.argv) < 4:
        sys.exit("Usage: deploy.py stack_name yaml_template ami_id")
    deploy(sys.argv[1], sys.argv[2], sys.argv[3])
