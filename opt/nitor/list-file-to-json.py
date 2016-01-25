#!/usr/bin/env python

import json
import sys

content =  [line.rstrip('\n') for line in open(sys.argv[2])]
json.dump({ sys.argv[1] : content }, sys.stdout);
