#!/usr/bin/env python

import json
import sys

userIds=[]
for userId in sys.argv[1:]:
    userIds.append({ "UserId" : userId });
json.dump({ "Add" : userIds }, sys.stdout);
