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

import yaml
import json
import sys
import collections
import re

############################################################################
# _THE_ yaml & json deserialize/serialize functions

def yaml_load(stream, Loader=yaml.SafeLoader, object_pairs_hook=collections.OrderedDict):
    class OrderedLoader(Loader):
        pass
    def construct_mapping(loader, node):
        loader.flatten_mapping(node)
        return object_pairs_hook(loader.construct_pairs(node))
    OrderedLoader.add_constructor(
            yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
            construct_mapping)
    return yaml.load(stream, OrderedLoader)

def yaml_save(data, stream=None, Dumper=yaml.SafeDumper, **kwds):
    class OrderedDumper(Dumper):
        pass
    def _dict_representer(dumper, data):
        return dumper.represent_mapping(
            yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
            data.items())
    OrderedDumper.add_representer(collections.OrderedDict, _dict_representer)
    return yaml.dump(data, stream, OrderedDumper, **kwds)

def json_load(stream):
    return json.loads(stream, object_pairs_hook=collections.OrderedDict)

def json_save(data):
    return json.dumps(data, indent=4)

############################################################################
# import_scripts

# the CF_ prefix is expected already to have been stripped
def bash_decode_parameter_name(name):
    return re.sub('__','::',name)

def import_script(filename):
    VAR_DECL_RE = re.compile(r'^CF_([^\s=]+)=')
    arr = []
    with open(filename) as f:
        for line in f:
            result = VAR_DECL_RE.match(line)
            if (result):
                bashVarName = result.group(1)
                varName = bash_decode_parameter_name(bashVarName)
                ref = collections.OrderedDict()
                ref['Ref'] = varName
                arr.append(line[0:result.end()] + "'")
                arr.append(ref)
                arr.append("'\n")
            else:
                arr.append(line)
    return arr

# data argument is mutated
def import_scripts(data, path=""):
    if (not isinstance(data, collections.OrderedDict)):
        return
    for k,v in data.items():
        import_scripts(v, path + k + "_")
        if (k == "Fn::ImportFile"):
            contents = import_script(v)
            del data[k]
            data['Fn::Join'] = [ "", contents ]

############################################################################
# extract_scripts

def bash_encode_parameter_name(name):
    return "CF_" + re.sub('::','__',name)

def encode_script_filename(prefix, path):
    if (path.find("UserData_Fn::Base64") != -1):
        return prefix + "-userdata.sh"
    CFG_PREFIX = "AWS::CloudFormation::Init_config_files_"
    idx = path.find(CFG_PREFIX)
    if (idx != -1):
        soff = idx + len(CFG_PREFIX)
        eoff = path.find("_content_", soff)
        cfgPath = path[soff:eoff]
        return prefix + "-" + cfgPath[cfgPath.rfind("/") + 1:]
    return prefix + "-" + path

def extract_script(prefix, path, joinArgs):
    #print prefix, path
    code = [ "", "" ] # "before" and "after" code blocks, placed before and after var declarations
    varDecls = collections.OrderedDict()
    codeIdx = 0
    for s in joinArgs:
        if (type(s) is collections.OrderedDict):
            varName = s['Ref']
            if (not(len(varName) > 0)):
                raise Exception("Failed to convert reference inside script: " + str(s))
            bashVarName = bash_encode_parameter_name(varName)
            varDecl = ""
            #varDecl += "#" + varName + "\n"
            varDecl += bashVarName + "=... ; echo \"FIXME!\" ; exit 1\n"
            varDecls[varName] = varDecl
            code[codeIdx] += "${" + bashVarName + "}"
        else:
            code[codeIdx] += s
        codeIdx = 1 # switch to "after" block

    filename = encode_script_filename(prefix, path)
    sys.stderr.write(prefix + ": Exported path '" + path + "' contents to file '" + filename + "'\n")
    f = open(filename,"w") #opens file with name of "test.txt"
    f.write(code[0])
    f.write("\n")
    for varName,varDecl in varDecls.items():
        f.write(varDecl)
    f.write("\n")
    f.write(code[1])
    f.close()
    return filename

# data argument is mutated
def extract_scripts(data, prefix, path=""):
    if (not isinstance(data, collections.OrderedDict)):
        return
    for k,v in data.items():
        extract_scripts(v, prefix, path + k + "_")
        if (k == "Fn::Join"):
            if not(v[0] == ""):
                continue
            if (v[1][0].find("#!") != 0):
                continue
            file = extract_script(prefix, path, v[1])
            del data[k]
            data['Fn::ImportFile'] = file

############################################################################
# simple api

def yaml_to_json(yaml_file_to_convert):
    data = yaml_load(open(yaml_file_to_convert))
    import_scripts(data)
    patch_launchconf_userdata_with_metadata_hash_and_params(data)
    return json_save(data)

def json_to_yaml(json_file_to_convert):
    data = json_load(open(json_file_to_convert).read())
    extract_scripts(data, json_file_to_convert)
    return yaml_save(data)


############################################################################
# misc json

def locate_launchconf_metadata(data):
    resources = data["Resources"]
    for k,v in resources.items():
        if (v["Type"] == "AWS::AutoScaling::LaunchConfiguration" and "Metadata" in v):
            return v["Metadata"]
    return None

def locate_launchconf_userdata(data):
    resources = data["Resources"]
    for k,v in resources.items():
        if (v["Type"] == "AWS::AutoScaling::LaunchConfiguration"):
            return v["Properties"]["UserData"]["Fn::Base64"]["Fn::Join"][1]
    return None

def get_refs(data, reflist=[]):
    if (isinstance(data, collections.OrderedDict)):
        if "Ref" in data:
            reflist.append(data["Ref"])
        for k,v in data.items():
            get_refs(v, reflist)
    elif (isinstance(data, list)):
        for e in data:
            get_refs(e, reflist)
    return reflist

def patch_launchconf_userdata_with_metadata_hash_and_params(data):
    lc_meta = locate_launchconf_metadata(data)
    if (not(lc_meta is None)):
        lc_userdata = locate_launchconf_userdata(data)
        lc_userdata.append("\nexit 0\n# metadata hash: " + str(hash(json_save(lc_meta))) + "\n")
        lc_meta_refs = set(get_refs(lc_meta))
        if len(lc_meta_refs) > 0:
            first = 1
            for e in lc_meta_refs:
                lc_userdata.append("# metadata params: " if first else ", ")
                lc_userdata.append({ "Ref" : e })
                first = 0
            lc_userdata.append("\n")
